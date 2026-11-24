from typing import Optional

from fastapi import APIRouter, Body, HTTPException, status

from app.schemas.space_schemas import (
    SyncStatusResponse,
    SyncTriggerRequest,
    SyncTriggerResponse,
)
from app.workers.tasks import enqueue_sync_job, get_sync_job_status

router = APIRouter()


@router.post("/sync", response_model=SyncTriggerResponse, status_code=status.HTTP_202_ACCEPTED)
def trigger_sync(
    payload: Optional[SyncTriggerRequest] = Body(default=None),
) -> SyncTriggerResponse:
    use_seed_only = payload.use_seed_only if payload else False
    job_info = enqueue_sync_job(use_seed_only=use_seed_only)
    return SyncTriggerResponse(**job_info)


@router.get("/sync/{job_id}", response_model=SyncStatusResponse)
def get_sync_status(job_id: str) -> SyncStatusResponse:
    job_info = get_sync_job_status(job_id)
    if job_info is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Sync job '{job_id}' was not found or Redis is unavailable.",
        )
    return SyncStatusResponse(**job_info)