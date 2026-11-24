from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import asc, desc, or_
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.config import settings
from app.core.database import get_db
from app.core.redis_client import cache_get, cache_set
from app.models.space_models import Mission
from app.schemas.space_schemas import (
    MissionListResponse,
    MissionOut,
    NextMissionResponse,
    PaginationMeta,
    PayloadOut,
)

router = APIRouter()


def _serialize_mission(mission: Mission) -> MissionOut:
    return MissionOut(
        id=mission.id,
        mission_code=mission.mission_code,
        name=mission.name,
        program=mission.program,
        status=mission.status,
        organization_id=mission.organization_id,
        organization_name=mission.organization.name if mission.organization else None,
        vehicle_id=mission.vehicle_id,
        vehicle_name=mission.vehicle.name if mission.vehicle else None,
        launch_site=mission.launch_site,
        launch_pad=mission.launch_pad,
        orbit_type=mission.orbit_type,
        launch_date_utc=mission.launch_date_utc,
        is_crewed=mission.is_crewed,
        summary=mission.summary,
        source_name=mission.source_name,
        last_synced_at=mission.last_synced_at,
        payloads=[PayloadOut.model_validate(p) for p in mission.payloads],
    )


@router.get("", response_model=MissionListResponse)
def list_missions(
    program: Optional[str] = Query(default=None, description="Filter by mission program"),
    status: Optional[str] = Query(default=None, description="Filter by launch status"),
    organization_id: Optional[int] = Query(default=None, ge=1),
    vehicle_id: Optional[int] = Query(default=None, ge=1),
    search: Optional[str] = Query(default=None, min_length=1, max_length=100),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> MissionListResponse:
    cache_key = (
        f"missions:list:{program or ''}:{status or ''}:"
        f"{organization_id or ''}:{vehicle_id or ''}:{search or ''}:{limit}:{offset}"
    )
    cached = cache_get(cache_key)
    if cached is not None:
        cached["cache_hit"] = True
        return MissionListResponse.model_validate(cached)

    query = db.query(Mission).options(
        joinedload(Mission.organization),
        joinedload(Mission.vehicle),
        selectinload(Mission.payloads),
    )

    if program:
        query = query.filter(Mission.program.ilike(program.strip()))
    if status:
        query = query.filter(Mission.status.ilike(status.strip()))
    if organization_id is not None:
        query = query.filter(Mission.organization_id == organization_id)
    if vehicle_id is not None:
        query = query.filter(Mission.vehicle_id == vehicle_id)
    if search:
        term = f"%{search.strip()}%"
        query = query.filter(
            or_(
                Mission.name.ilike(term),
                Mission.mission_code.ilike(term),
                Mission.summary.ilike(term),
                Mission.program.ilike(term),
            )
        )

    total = query.count()
    rows = (
        query.order_by(desc(Mission.launch_date_utc).nullslast(), asc(Mission.id))
        .offset(offset)
        .limit(limit)
        .all()
    )

    items = [_serialize_mission(m) for m in rows]
    last_synced = max((m.last_synced_at for m in items), default=None)

    response = MissionListResponse(
        items=items,
        pagination=PaginationMeta(
            total=total,
            limit=limit,
            offset=offset,
            has_more=(offset + len(items)) < total,
        ),
        last_synced_at=last_synced,
        cache_hit=False,
    )

    cache_set(
        cache_key,
        response.model_dump(mode="json"),
        ttl_seconds=settings.CACHE_TTL_SECONDS,
    )
    return response


@router.get("/next", response_model=NextMissionResponse)
def get_next_mission(db: Session = Depends(get_db)) -> NextMissionResponse:
    now_utc = datetime.now(timezone.utc)

    base_query = db.query(Mission).options(
        joinedload(Mission.organization),
        joinedload(Mission.vehicle),
        selectinload(Mission.payloads),
    )

    next_mission = (
        base_query.filter(
            Mission.status.in_(["Upcoming", "Scheduled"]),
            Mission.launch_date_utc.isnot(None),
            Mission.launch_date_utc >= now_utc,
        )
        .order_by(asc(Mission.launch_date_utc))
        .first()
    )

    if next_mission is None:
        next_mission = (
            base_query.filter(
                Mission.status.in_(["Upcoming", "Scheduled"]),
                Mission.launch_date_utc.isnot(None),
            )
            .order_by(desc(Mission.launch_date_utc))
            .first()
        )

    serialized = _serialize_mission(next_mission) if next_mission else None
    return NextMissionResponse(
        mission=serialized,
        server_time_utc=now_utc,
        last_synced_at=serialized.last_synced_at if serialized else None,
    )