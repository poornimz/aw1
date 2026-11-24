from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import asc, or_
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.redis_client import cache_get, cache_set
from app.models.space_models import Organization
from app.schemas.space_schemas import (
    OrganizationOut,
    PaginationMeta,
    StartupListResponse,
)

router = APIRouter()


@router.get("", response_model=StartupListResponse)
def list_startups(
    focus_area: Optional[str] = Query(default=None, description="Filter by startup focus_area tag"),
    search: Optional[str] = Query(default=None, min_length=1, max_length=100),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> StartupListResponse:
    cache_key = f"startups:list:{focus_area or ''}:{search or ''}:{limit}:{offset}"
    cached = cache_get(cache_key)
    if cached is not None:
        cached["cache_hit"] = True
        return StartupListResponse.model_validate(cached)

    query = db.query(Organization).filter(Organization.is_startup.is_(True))

    if focus_area:
        query = query.filter(Organization.focus_area.ilike(f"%{focus_area.strip()}%"))
    if search:
        term = f"%{search.strip()}%"
        query = query.filter(
            or_(
                Organization.name.ilike(term),
                Organization.city.ilike(term),
                Organization.focus_area.ilike(term),
                Organization.description.ilike(term),
            )
        )

    total = query.count()
    rows = query.order_by(asc(Organization.name)).offset(offset).limit(limit).all()

    items = [OrganizationOut.model_validate(org) for org in rows]
    last_synced = max((org.last_synced_at for org in items), default=None)

    response = StartupListResponse(
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