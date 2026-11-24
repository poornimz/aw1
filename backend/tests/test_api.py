import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Generator, List

import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

# Ensure `backend/` is importable regardless of how pytest is invoked
BACKEND_ROOT = Path(__file__).resolve().parent.parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

# Configure isolated test settings before importing app modules
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["AUTO_SEED_ON_STARTUP"] = "false"

from app.core.database import Base, get_db  # noqa: E402
from app.core import redis_client  # noqa: E402
from app.main import app  # noqa: E402
from app.services.ingestion import run_ingestion_pipeline  # noqa: E402

class FakeRedis:
    """Minimal in-memory Redis double supporting string + RQ hash/list lookups."""

    def __init__(self) -> None:
        self.store: Dict[str, str] = {}
        self.hashes: Dict[str, Dict[str, Any]] = {}

    def ping(self) -> bool:
        return True

    def get(self, key: str) -> str | None:
        return self.store.get(key)

    def setex(self, name: str, time: int, value: str) -> bool:  # noqa: ARG002
        self.store[name] = value
        return True

    def delete(self, *keys: str) -> int:
        deleted = 0
        for key in keys:
            if key in self.store:
                del self.store[key]
                deleted += 1
        return deleted

    def scan_iter(self, match: str = "*", count: int = 100) -> List[str]:  # noqa: ARG002
        if match.endswith("*"):
            prefix = match[:-1]
            return [k for k in list(self.store.keys()) if k.startswith(prefix)]
        return [k for k in list(self.store.keys()) if k == match]

    def hgetall(self, name: str) -> Dict[str, Any]:
        return self.hashes.get(name, {})

    def hget(self, name: str, key: str) -> Any:
        return self.hashes.get(name, {}).get(key)

    def hset(self, name: str, key: str | None = None, value: Any = None, mapping: Dict[str, Any] | None = None) -> int:
        bucket = self.hashes.setdefault(name, {})
        if mapping:
            bucket.update(mapping)
            return len(mapping)
        if key is not None:
            bucket[key] = value
            return 1
        return 0

    def exists(self, *names: str) -> int:
        return sum(1 for n in names if n in self.store or n in self.hashes)

    def lrem(self, name: str, count: int, value: Any) -> int:  # noqa: ARG002
        return 0

    def expire(self, name: str, time: int) -> bool:  # noqa: ARG002
        return name in self.store or name in self.hashes


@pytest.fixture()
def test_db(monkeypatch: pytest.MonkeyPatch) -> Generator[Session, None, None]:
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(
        bind=engine, autocommit=False, autoflush=False, expire_on_commit=False
    )
    Base.metadata.create_all(bind=engine)

    fake_redis = FakeRedis()
    monkeypatch.setattr(redis_client, "_redis_client", fake_redis)
    monkeypatch.setattr(redis_client, "get_redis_client", lambda: fake_redis)

    db = TestingSessionLocal()
    run_ingestion_pipeline(db=db, use_seed_only=True)

    def override_get_db() -> Generator[Session, None, None]:
        session = TestingSessionLocal()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    try:
        yield db
    finally:
        app.dependency_overrides.clear()
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client(test_db: Session) -> Generator[TestClient, None, None]:  # noqa: ARG001
    with TestClient(app) as test_client:
        yield test_client


def test_mission_filtering_and_pagination(client: TestClient) -> None:
    # Filter by program
    resp = client.get("/api/v1/missions", params={"program": "Gaganyaan", "limit": 2, "offset": 0})
    assert resp.status_code == 200
    data = resp.json()
    assert data["pagination"]["total"] >= 3
    assert len(data["items"]) == 2
    assert data["pagination"]["has_more"] is True
    assert all(item["program"] == "Gaganyaan" for item in data["items"])

    # Second page
    resp_page2 = client.get(
        "/api/v1/missions", params={"program": "Gaganyaan", "limit": 2, "offset": 2}
    )
    assert resp_page2.status_code == 200
    page2 = resp_page2.json()
    assert len(page2["items"]) >= 1
    page1_codes = {m["mission_code"] for m in data["items"]}
    page2_codes = {m["mission_code"] for m in page2["items"]}
    assert page1_codes.isdisjoint(page2_codes)

    # Search filter
    search_resp = client.get("/api/v1/missions", params={"search": "NVS-03"})
    assert search_resp.status_code == 200
    search_data = search_resp.json()
    assert search_data["pagination"]["total"] == 1
    assert search_data["items"][0]["mission_code"] == "GSLV-F18/NVS-03"


def test_redis_cache_hit_and_miss_behavior(client: TestClient) -> None:
    # First call should be a cache miss
    first = client.get("/api/v1/missions", params={"status": "Upcoming", "limit": 5})
    assert first.status_code == 200
    first_json = first.json()
    assert first_json["cache_hit"] is False
    assert len(first_json["items"]) > 0

    # Second identical call should hit Redis cache
    second = client.get("/api/v1/missions", params={"status": "Upcoming", "limit": 5})
    assert second.status_code == 200
    second_json = second.json()
    assert second_json["cache_hit"] is True
    assert second_json["items"] == first_json["items"]


def test_graceful_fallback_when_upstream_times_out(
    test_db: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    def raise_timeout(*args: Any, **kwargs: Any) -> Any:
        raise httpx.ReadTimeout("Simulated upstream API timeout")

    monkeypatch.setattr(httpx.Client, "get", raise_timeout)

    result = run_ingestion_pipeline(db=test_db, use_seed_only=False)
    assert result["status"] == "completed"
    assert result["used_fallback"] is True
    assert result["source"] == "seed_fallback"
    assert "timeout" in (result["upstream_error"] or "").lower()
    assert result["counts"]["seed_missions"] >= 10
    assert result["counts"]["isro_centres"] >= 5


def test_next_mission_returns_valid_server_time_utc(client: TestClient) -> None:
    resp = client.get("/api/v1/missions/next")
    assert resp.status_code == 200
    payload = resp.json()

    assert "server_time_utc" in payload
    server_time = datetime.fromisoformat(payload["server_time_utc"].replace("Z", "+00:00"))
    assert server_time.tzinfo is not None

    assert payload["mission"] is not None
    assert payload["mission"]["status"] in {"Upcoming", "Scheduled"}
    launch_dt = datetime.fromisoformat(
        payload["mission"]["launch_date_utc"].replace("Z", "+00:00")
    )
    assert launch_dt.tzinfo == timezone.utc


def test_vehicles_startups_centres_and_problem_details(client: TestClient) -> None:
    vehicles_resp = client.get("/api/v1/vehicles")
    assert vehicles_resp.status_code == 200
    vehicle_names = {v["name"] for v in vehicles_resp.json()["items"]}
    assert {"LVM3", "PSLV", "Vikram-1", "Agnibaan"}.issubset(vehicle_names)

    startups_resp = client.get("/api/v1/startups", params={"focus_area": "Launch Vehicles"})
    assert startups_resp.status_code == 200
    startup_names = {s["name"] for s in startups_resp.json()["items"]}
    assert {"Skyroot Aerospace", "Agnikul Cosmos"}.issubset(startup_names)

    centres_resp = client.get("/api/v1/centres")
    assert centres_resp.status_code == 200
    centre_codes = {c["code"] for c in centres_resp.json()["items"]}
    assert {"VSSC", "URSC", "SDSC SHAR", "SAC", "ISTRAC"}.issubset(centre_codes)

    # RFC 7807 Problem Details check on missing job
    missing_job = client.get("/api/v1/admin/sync/does-not-exist")
    assert missing_job.status_code == 404
    assert missing_job.headers["content-type"].startswith("application/problem+json")
    problem = missing_job.json()
    assert problem["status"] == 404
    assert problem["title"] == "Not Found"