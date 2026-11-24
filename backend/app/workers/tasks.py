import logging
from typing import Any, Dict, Optional

from redis.exceptions import RedisError
from rq import Queue
from rq.exceptions import NoSuchJobError

from app.core.database import SessionLocal, init_db
from app.core.redis_client import get_redis_client
from app.services.ingestion import run_ingestion_pipeline

logger = logging.getLogger(__name__)

QUEUE_NAME = "space_sync"


def sync_space_data(use_seed_only: bool = False) -> Dict[str, Any]:
    """RQ background job that runs the idempotent space data ingestion pipeline."""
    init_db()
    db = SessionLocal()
    try:
        logger.info("Starting sync_space_data job (use_seed_only=%s)", use_seed_only)
        summary = run_ingestion_pipeline(db=db, use_seed_only=use_seed_only)
        logger.info("Finished sync_space_data job: %s", summary["source"])
        return summary
    except Exception:
        db.rollback()
        logger.exception("sync_space_data job failed")
        raise
    finally:
        db.close()


def enqueue_sync_job(use_seed_only: bool = False) -> Dict[str, Any]:
    """
    Enqueue `sync_space_data` onto the RQ Redis queue.
    If Redis is unreachable, executes synchronously as a graceful fallback.
    """
    redis_conn = get_redis_client()
    if redis_conn is None:
        logger.warning("Redis unavailable; executing sync_space_data synchronously.")
        result = sync_space_data(use_seed_only=use_seed_only)
        return {
            "job_id": "local-sync-fallback",
            "status": "finished",
            "mode": "synchronous_fallback",
            "result": result,
        }

    try:
        queue = Queue(name=QUEUE_NAME, connection=redis_conn)
        job = queue.enqueue(sync_space_data, use_seed_only=use_seed_only, job_timeout=180)
        return {
            "job_id": job.id,
            "status": job.get_status(),
            "mode": "queued",
            "result": None,
        }
    except RedisError as exc:
        logger.warning("Failed to enqueue RQ job (%s); running synchronously.", exc)
        result = sync_space_data(use_seed_only=use_seed_only)
        return {
            "job_id": "local-sync-fallback",
            "status": "finished",
            "mode": "synchronous_fallback",
            "result": result,
        }


def get_sync_job_status(job_id: str) -> Optional[Dict[str, Any]]:
    """Fetch RQ job status and result by job_id."""
    if job_id == "local-sync-fallback":
        return {"job_id": job_id, "status": "finished", "result": None}

    redis_conn = get_redis_client()
    if redis_conn is None:
        return None

    try:
        queue = Queue(name=QUEUE_NAME, connection=redis_conn)
        job = queue.fetch_job(job_id)
    except (NoSuchJobError, RedisError):
        return None

    if job is None:
        return None

    return {
        "job_id": job.id,
        "status": job.get_status(),
        "result": job.result if job.is_finished else None,
        "error": str(job.exc_info) if job.is_failed else None,
    }