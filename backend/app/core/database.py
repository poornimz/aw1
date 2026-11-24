from collections.abc import Generator
from typing import Any, Dict

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings


def _build_engine_kwargs(database_url: str) -> Dict[str, Any]:
    if database_url.startswith("sqlite"):
        return {
            "connect_args": {"check_same_thread": False},
        }
    return {
        "pool_pre_ping": True,
        "pool_size": 10,
        "max_overflow": 20,
    }


engine = create_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    **_build_engine_kwargs(settings.DATABASE_URL),
)

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy ORM models."""


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency yielding a scoped SQLAlchemy session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Create database tables for all registered ORM models."""
    import app.models.space_models  # noqa: F401

    Base.metadata.create_all(bind=engine)