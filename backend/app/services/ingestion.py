import argparse
import json
import logging
import re
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import SessionLocal, init_db
from app.core.redis_client import invalidate_cache_patterns
from app.models.space_models import (
    ISROCentre,
    LaunchVehicle,
    Mission,
    Organization,
    Payload,
)

logger = logging.getLogger(__name__)

SEED_DATA_PATH = Path(__file__).resolve().parent / "seed_data.json"


def _slugify(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9]+", "-", value.strip().lower()).strip("-")
    return cleaned or "unknown"


def _parse_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    text = value.strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except ValueError:
        for fmt in ("%d-%m-%Y", "%Y-%m-%d", "%d/%m/%Y"):
            try:
                dt = datetime.strptime(value.strip(), fmt)
                return dt.replace(tzinfo=timezone.utc)
            except ValueError:
                continue
        return None


def _parse_date(value: Optional[str]) -> Optional[date]:
    if not value:
        return None
    try:
        return date.fromisoformat(value.strip())
    except ValueError:
        return None


def load_seed_data(seed_path: Path = SEED_DATA_PATH) -> Dict[str, Any]:
    with seed_path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _infer_program(name: str, mission_code: str) -> str:
    combined = f"{name} {mission_code}".lower()
    if "gaganyaan" in combined or "tv-d" in combined or "hlvm3" in combined:
        return "Gaganyaan"
    if "chandrayaan" in combined:
        return "Chandrayaan"
    if "nvs-" in combined or "irnss" in combined or "navic" in combined:
        return "NavIC"
    if "aditya" in combined or "mangalyaan" in combined or "xpo" in combined:
        return "Science & Exploration"
    if "eos-" in combined or "risat" in combined or "cartosat" in combined or "oceansat" in combined:
        return "Earth Observation"
    if "vikram" in combined or "agnibaan" in combined:
        return "Private Launches"
    return "Commercial"


def _infer_vehicle_slug(mission_name: str, vehicle_name: str = "") -> Optional[str]:
    text = f"{mission_name} {vehicle_name}".lower()
    if "lvm3" in text or "gslv mk iii" in text or "gslv-mk3" in text or "hlvm3" in text:
        return "lvm3"
    if "gslv" in text:
        return "gslv-mk-ii"
    if "pslv" in text:
        return "pslv"
    if "sslv" in text:
        return "sslv"
    if "vikram" in text:
        return "vikram-1"
    if "agnibaan" in text:
        return "agnibaan"
    return None


def fetch_upstream_space_data(
    base_url: Optional[str] = None,
    timeout_seconds: Optional[float] = None,
) -> Dict[str, Any]:
    """
    Fetch launches/centres from Space Veerexa / open ISRO endpoints.
    Raises httpx.HTTPError or ValueError if the upstream API fails or returns unusable payloads.
    """
    api_base = (base_url or settings.SPACE_API_BASE_URL).rstrip("/")
    timeout = timeout_seconds if timeout_seconds is not None else settings.HTTP_TIMEOUT_SECONDS

    normalized: Dict[str, Any] = {"launches": [], "centres": []}

    with httpx.Client(timeout=timeout, follow_redirects=True) as client:
        launches_resp = client.get(f"{api_base}/launches")
        launches_resp.raise_for_status()
        launches_payload = launches_resp.json()

        raw_launches: List[Dict[str, Any]] = []
        if isinstance(launches_payload, dict):
            if isinstance(launches_payload.get("launches"), list):
                raw_launches = launches_payload["launches"]
            elif isinstance(launches_payload.get("data"), list):
                raw_launches = launches_payload["data"]
        elif isinstance(launches_payload, list):
            raw_launches = launches_payload

        if not raw_launches:
            raise ValueError("Upstream launches endpoint returned an empty dataset.")

        for item in raw_launches:
            if not isinstance(item, dict):
                continue
            mission_name = str(
                item.get("Name") or item.get("name") or item.get("mission_name") or ""
            ).strip()
            if not mission_name:
                continue

            mission_code = str(
                item.get("mission_code") or item.get("SerialNumber") or mission_name
            ).strip()
            launch_dt = _parse_datetime(
                item.get("LaunchDate") or item.get("launch_date") or item.get("launch_date_utc")
            )
            raw_status = str(item.get("MissionStatus") or item.get("status") or "").strip().lower()
            if "success" in raw_status:
                status = "Successful"
            elif "fail" in raw_status:
                status = "Failed"
            elif "sched" in raw_status:
                status = "Scheduled"
            elif launch_dt and launch_dt > datetime.now(timezone.utc):
                status = "Upcoming"
            else:
                status = "Successful"

            vehicle_raw = str(item.get("LaunchType") or item.get("vehicle") or "")
            normalized["launches"].append(
                {
                    "mission_code": mission_code[:100],
                    "name": mission_name[:200],
                    "program": item.get("program") or _infer_program(mission_name, mission_code),
                    "status": status,
                    "organization_slug": "isro",
                    "vehicle_slug": _infer_vehicle_slug(mission_name, vehicle_raw),
                    "launch_site": str(item.get("launch_site") or "SDSC SHAR, Sriharikota"),
                    "launch_pad": item.get("launch_pad"),
                    "orbit_type": item.get("orbit_type"),
                    "launch_date_utc": launch_dt,
                    "is_crewed": bool(item.get("is_crewed", False)),
                    "summary": str(item.get("Payload") or item.get("summary") or "").strip() or None,
                    "external_id": str(item.get("UUID") or item.get("id") or mission_code),
                    "source_name": "upstream_api",
                }
            )

        # Optionally fetch centres endpoint if supported by upstream API
        try:
            centres_resp = client.get(f"{api_base}/centres")
            if centres_resp.status_code == 200:
                centres_json = centres_resp.json()
                raw_centres = (
                    centres_json.get("centres", [])
                    if isinstance(centres_json, dict)
                    else centres_json
                )
                if isinstance(raw_centres, list):
                    normalized["centres"] = raw_centres
        except httpx.HTTPError:
            pass

    return normalized


def _upsert_organization(db: Session, item: Dict[str, Any], synced_at: datetime) -> Organization:
    slug = item.get("slug") or _slugify(item["name"])
    org = db.query(Organization).filter(Organization.slug == slug).first()
    if org is None:
        org = Organization(slug=slug, name=item["name"])
        db.add(org)

    org.name = item["name"]
    org.org_type = item.get("org_type", "startup")
    org.focus_area = item.get("focus_area", "Space Systems")
    org.is_startup = bool(item.get("is_startup", org.org_type == "startup"))
    org.founded_year = item.get("founded_year")
    org.headquarters = item.get("headquarters")
    org.city = item.get("city")
    org.state = item.get("state")
    org.funding_stage = item.get("funding_stage")
    org.website = item.get("website")
    org.description = item.get("description")
    org.last_synced_at = synced_at
    db.flush()
    return org


def _upsert_vehicle(
    db: Session,
    item: Dict[str, Any],
    org_map: Dict[str, Organization],
    synced_at: datetime,
) -> LaunchVehicle:
    slug = item.get("slug") or _slugify(item["name"])
    vehicle = db.query(LaunchVehicle).filter(LaunchVehicle.slug == slug).first()
    org = org_map.get(item.get("organization_slug", "isro")) or org_map["isro"]

    if vehicle is None:
        vehicle = LaunchVehicle(slug=slug, name=item["name"], organization_id=org.id)
        db.add(vehicle)

    vehicle.name = item["name"]
    vehicle.organization_id = org.id
    vehicle.status = item.get("status", "Operational")
    vehicle.stages = item.get("stages")
    vehicle.height_m = item.get("height_m")
    vehicle.liftoff_mass_tonnes = item.get("liftoff_mass_tonnes")
    vehicle.leo_payload_kg = item.get("leo_payload_kg")
    vehicle.gto_payload_kg = item.get("gto_payload_kg")
    vehicle.sso_payload_kg = item.get("sso_payload_kg")
    vehicle.first_flight_date = _parse_date(item.get("first_flight_date"))
    vehicle.total_launches = int(item.get("total_launches", 0))
    vehicle.successful_launches = int(item.get("successful_launches", 0))
    vehicle.description = item.get("description")
    vehicle.image_url = item.get("image_url")
    vehicle.last_synced_at = synced_at
    db.flush()
    return vehicle


def _upsert_centre(db: Session, item: Dict[str, Any], synced_at: datetime) -> ISROCentre:
    code = str(item["code"]).strip()
    centre = db.query(ISROCentre).filter(ISROCentre.code == code).first()
    if centre is None:
        centre = ISROCentre(
            code=code,
            name=item["name"],
            city=item["city"],
            state=item["state"],
            latitude=float(item["latitude"]),
            longitude=float(item["longitude"]),
            specialization=item["specialization"],
        )
        db.add(centre)

    centre.name = item["name"]
    centre.city = item["city"]
    centre.state = item["state"]
    centre.latitude = float(item["latitude"])
    centre.longitude = float(item["longitude"])
    centre.specialization = item["specialization"]
    centre.established_year = item.get("established_year")
    centre.website = item.get("website")
    centre.description = item.get("description")
    centre.last_synced_at = synced_at
    db.flush()
    return centre


def _upsert_mission_and_payloads(
    db: Session,
    item: Dict[str, Any],
    org_map: Dict[str, Organization],
    vehicle_map: Dict[str, LaunchVehicle],
    synced_at: datetime,
    source_name: str,
) -> Tuple[Mission, int]:
    mission_code = str(item["mission_code"]).strip()
    mission = db.query(Mission).filter(Mission.mission_code == mission_code).first()

    org = org_map.get(item.get("organization_slug", "isro")) or org_map["isro"]
    vehicle_slug = item.get("vehicle_slug")
    vehicle = vehicle_map.get(vehicle_slug) if vehicle_slug else None

    raw_dt = item.get("launch_date_utc")
    launch_dt = raw_dt if isinstance(raw_dt, datetime) else _parse_datetime(raw_dt)

    if mission is None:
        mission = Mission(
            mission_code=mission_code,
            name=item["name"],
            organization_id=org.id,
        )
        db.add(mission)

    mission.name = item["name"]
    mission.program = item.get("program", "General")
    mission.status = item.get("status", "Upcoming")
    mission.organization_id = org.id
    mission.vehicle_id = vehicle.id if vehicle else mission.vehicle_id
    mission.launch_site = item.get("launch_site")
    mission.launch_pad = item.get("launch_pad")
    mission.orbit_type = item.get("orbit_type")
    mission.launch_date_utc = launch_dt
    mission.is_crewed = bool(item.get("is_crewed", False))
    mission.summary = item.get("summary")
    mission.source_name = item.get("source_name", source_name)
    mission.external_id = item.get("external_id")
    mission.last_synced_at = synced_at
    db.flush()

    payload_count = 0
    for p_item in item.get("payloads", []):
        payload_name = str(p_item["name"]).strip()
        payload = (
            db.query(Payload)
            .filter(Payload.mission_id == mission.id, Payload.name == payload_name)
            .first()
        )
        p_org_slug = p_item.get("organization_slug")
        p_org = org_map.get(p_org_slug) if p_org_slug else org

        if payload is None:
            payload = Payload(
                mission_id=mission.id,
                name=payload_name,
            )
            db.add(payload)

        payload.organization_id = p_org.id if p_org else None
        payload.payload_type = p_item.get("payload_type", "Satellite")
        payload.mass_kg = p_item.get("mass_kg")
        payload.orbit = p_item.get("orbit")
        payload.customer = p_item.get("customer")
        payload.description = p_item.get("description")
        payload_count += 1

    db.flush()
    return mission, payload_count


def run_ingestion_pipeline(
    db: Session,
    use_seed_only: bool = False,
    base_url: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Idempotent upsert pipeline:
    1. Always ensures curated organizations, vehicles, ISRO centres, and baseline missions from seed_data.json.
    2. Attempts upstream Space Veerexa / open ISRO API sync unless `use_seed_only=True`.
    3. Gracefully falls back to seed_data.json on upstream HTTP errors or timeouts.
    4. Invalidates stale Redis cache keys after commit.
    """
    synced_at = datetime.now(timezone.utc)
    seed_data = load_seed_data()

    # Step 1: Upsert organizations, launch vehicles, and ISRO centres
    org_map: Dict[str, Organization] = {}
    for org_item in seed_data.get("organizations", []):
        org = _upsert_organization(db, org_item, synced_at)
        org_map[org.slug] = org

    vehicle_map: Dict[str, LaunchVehicle] = {}
    for vehicle_item in seed_data.get("launch_vehicles", []):
        vehicle = _upsert_vehicle(db, vehicle_item, org_map, synced_at)
        vehicle_map[vehicle.slug] = vehicle

    centres_count = 0
    for centre_item in seed_data.get("isro_centres", []):
        _upsert_centre(db, centre_item, synced_at)
        centres_count += 1

    # Step 2: Upsert baseline seed missions & payloads
    missions_count = 0
    payloads_count = 0
    for mission_item in seed_data.get("missions", []):
        _, p_count = _upsert_mission_and_payloads(
            db=db,
            item=mission_item,
            org_map=org_map,
            vehicle_map=vehicle_map,
            synced_at=synced_at,
            source_name="seed",
        )
        missions_count += 1
        payloads_count += p_count

    # Step 3: Optionally merge upstream live launches
    used_fallback = use_seed_only
    upstream_error: Optional[str] = None
    upstream_missions_synced = 0
    source = "seed_data.json"

    if not use_seed_only:
        try:
            upstream_data = fetch_upstream_space_data(base_url=base_url)
            for launch_item in upstream_data.get("launches", []):
                _upsert_mission_and_payloads(
                    db=db,
                    item=launch_item,
                    org_map=org_map,
                    vehicle_map=vehicle_map,
                    synced_at=synced_at,
                    source_name="upstream_api",
                )
                upstream_missions_synced += 1
            source = "upstream_api+seed"
            used_fallback = False
        except (httpx.HTTPError, ValueError, KeyError, json.JSONDecodeError) as exc:
            used_fallback = True
            upstream_error = str(exc)
            source = "seed_fallback"
            logger.warning(
                "Upstream space API sync failed (%s). Falling back to seed_data.json.",
                exc,
            )

    db.commit()

    # Step 4: Invalidate stale Redis cache keys
    invalidated_keys = invalidate_cache_patterns(
        ["missions:*", "vehicles:*", "startups:*", "centres:*"]
    )

    return {
        "status": "completed",
        "source": source,
        "used_fallback": used_fallback,
        "upstream_error": upstream_error,
        "synced_at": synced_at.isoformat(),
        "invalidated_cache_keys": invalidated_keys,
        "counts": {
            "organizations": len(org_map),
            "launch_vehicles": len(vehicle_map),
            "isro_centres": centres_count,
            "seed_missions": missions_count,
            "upstream_missions": upstream_missions_synced,
            "payloads": payloads_count,
        },
    }


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    parser = argparse.ArgumentParser(
        description="Seed or sync Indian Space Mission & Startup Tracker database."
    )
    parser.add_argument(
        "--seed",
        action="store_true",
        help="Populate the database using offline seed_data.json only.",
    )
    args = parser.parse_args()

    init_db()
    db = SessionLocal()
    try:
        result = run_ingestion_pipeline(db=db, use_seed_only=args.seed)
        print(json.dumps(result, indent=2))
    finally:
        db.close()


if __name__ == "__main__":
    main()