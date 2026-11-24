from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import asc, desc
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.core.database import get_db
from app.core.redis_client import cache_get, cache_set
from app.models.space_models import LaunchVehicle
from app.schemas.space_schemas import (
    LaunchVehicleOut,
    PaginationMeta,
    VehicleListResponse,
)

router = APIRouter()


@router.get("", response_model=VehicleListResponse)
def list_vehicles(
    status: Optional[str] = Query(default=None),
    organization_id: Optional[int] = Query(default=None, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> VehicleListResponse:
    cache_key = f"vehicles:list:{status or ''}:{organization_id or ''}:{limit}:{offset}"
    cached = cache_get(cache_key)
    if cached is not None:
        cached["cache_hit"] = True
        return VehicleListResponse.model_validate(cached)

    query = db.query(LaunchVehicle).options(joinedload(LaunchVehicle.organization))
    if status:
        query = query.filter(LaunchVehicle.status.ilike(status.strip()))
    if organization_id is not None:
        query = query.filter(LaunchVehicle.organization_id == organization_id)

    total = query.count()
    rows = (
        query.order_by(desc(LaunchVehicle.leo_payload_kg).nullslast(), asc(LaunchVehicle.name))
        .offset(offset)
        .limit(limit)
        .all()
    )

    items = [
        LaunchVehicleOut(
            id=v.id,
            name=v.name,
            slug=v.slug,
            organization_id=v.organization_id,
            organization_name=v.organization.name if v.organization else None,
            status=v.status,
            stages=v.stages,
            height_m=v.height_m,
            liftoff_mass_tonnes=v.liftoff_mass_tonnes,
            leo_payload_kg=v.leo_payload_kg,
            gto_payload_kg=v.gto_payload_kg,
            sso_payload_kg=v.sso_payload_kg,
            first_flight_date=v.first_flight_date,
            total_launches=v.total_launches,
            successful_launches=v.successful_launches,
            description=v.description,
            image_url=v.image_url,
            last_synced_at=v.last_synced_at,
        )
        for v in rows
    ]
    last_synced = max((v.last_synced_at for v in items), default=None)

    response = VehicleListResponse(
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