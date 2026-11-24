from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import asc, or_
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.redis_client import cache_get, cache_set
from app.models.space_models import ISROCentre
from app.schemas.space_schemas import (
    CentreListResponse,
    ISROCentreOut,
    PaginationMeta,
)

router = APIRouter()


@router.get("", response_model=CentreListResponse)
def list_centres(
    state: Optional[str] = Query(default=None),
    search: Optional[str] = Query(default=None, min_length=1, max_length=100),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> CentreListResponse:
    cache_key = f"centres:list:{state or ''}:{search or ''}:{limit}:{offset}"
    cached = cache_get(cache_key)
    if cached is not None:
        cached["cache_hit"] = True
        return CentreListResponse.model_validate(cached)

    query = db.query(ISROCentre)
    if state:
        query = query.filter(ISROCentre.state.ilike(f"%{state.strip()}%"))
    if search:
        term = f"%{search.strip()}%"
        query = query.filter(
            or_(
                ISROCentre.code.ilike(term),
                ISROCentre.name.ilike(term),
                ISROCentre.city.ilike(term),
                ISROCentre.specialization.ilike(term),
            )
        )

    total = query.count()
    rows = query.order_by(asc(ISROCentre.code)).offset(offset).limit(limit).all()

    items = [ISROCentreOut.model_validate(c) for c in rows]
    last_synced = max((c.last_synced_at for c in items), default=None)

    response = CentreListResponse(
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