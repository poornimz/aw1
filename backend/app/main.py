import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from http import HTTPStatus
from typing import Any, Dict

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import SessionLocal, init_db
from app.core.redis_client import is_redis_available
from app.models.space_models import Mission
from app.services.ingestion import run_ingestion_pipeline

logger = logging.getLogger(__name__)


def _problem_response(
    *,
    request: Request,
    status_code: int,
    title: str,
    detail: str,
    error_type: str = "about:blank",
    extra: Dict[str, Any] | None = None,
) -> JSONResponse:
    payload: Dict[str, Any] = {
        "type": error_type,
        "title": title,
        "status": status_code,
        "detail": detail,
        "instance": str(request.url.path),
    }
    if extra:
        payload.update(extra)
    return JSONResponse(
        status_code=status_code,
        content=payload,
        media_type="application/problem+json",
    )


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    if settings.AUTO_SEED_ON_STARTUP:
        db = SessionLocal()
        try:
            if db.query(Mission).count() == 0:
                logger.info("Database is empty on startup. Auto-seeding offline dataset...")
                run_ingestion_pipeline(db=db, use_seed_only=True)
        finally:
            db.close()
    yield


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    try:
        title = HTTPStatus(exc.status_code).phrase
    except ValueError:
        title = "HTTP Error"
    return _problem_response(
        request=request,
        status_code=exc.status_code,
        title=title,
        detail=str(exc.detail),
        error_type=f"https://httpstatuses.com/{exc.status_code}",
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    return _problem_response(
        request=request,
        status_code=422,
        title="Unprocessable Entity",
        detail="One or more request parameters failed validation.",
        error_type="https://httpstatuses.com/422",
        extra={"errors": exc.errors()},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled server exception on %s", request.url.path, exc_info=exc)
    return _problem_response(
        request=request,
        status_code=500,
        title="Internal Server Error",
        detail="An unexpected error occurred while processing the request.",
        error_type="https://httpstatuses.com/500",
    )


@app.get("/health", tags=["Health"])
def health_check() -> Dict[str, Any]:
    return {
        "status": "ok",
        "redis_available": is_redis_available(),
        "server_time_utc": datetime.now(timezone.utc).isoformat(),
    }


app.include_router(api_router, prefix=settings.API_V1_PREFIX)