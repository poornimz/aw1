from functools import lru_cache
from typing import List

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables / .env file."""

    APP_NAME: str = "Indian Space Mission & Startup Tracker API"
    APP_VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = False

    # Database & Cache
    DATABASE_URL: str = (
        "postgresql+psycopg2://postgres:postgres@localhost:5432/indian_space_tracker"
    )
    REDIS_URL: str = "redis://localhost:6379/0"
    CACHE_TTL_SECONDS: int = 600  # 10 minutes

    # External Space Data API
    SPACE_API_BASE_URL: str = "https://isro.vercel.app/api"
    HTTP_TIMEOUT_SECONDS: float = 10.0

    # CORS (supports comma-separated string or JSON array in .env)
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://10.0.2.2:8000",
    ]

    # Startup behavior
    AUTO_SEED_ON_STARTUP: bool = True

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_allowed_origins(cls, value: object) -> List[str]:
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            if stripped.startswith("["):
                import json

                return json.loads(stripped)
            return [origin.strip() for origin in stripped.split(",") if origin.strip()]
        if isinstance(value, list):
            return [str(item).strip() for item in value if str(item).strip()]
        return ["*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()