import json
import logging
from typing import Any, Iterable, Optional

import redis
from redis import Redis
from redis.exceptions import RedisError

from app.core.config import settings

logger = logging.getLogger(__name__)

_redis_client: Optional[Redis] = None


def get_redis_client() -> Optional[Redis]:
    """Return a Redis client if reachable, or None for graceful degradation."""
    global _redis_client
    try:
        if _redis_client is None:
            _redis_client = redis.Redis.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2,
            )
        _redis_client.ping()
        return _redis_client
    except RedisError as exc:
        logger.warning("Redis unavailable (%s). Continuing without cache.", exc)
        return None
    except Exception as exc:  # pragma: no cover - defensive guard
        logger.warning("Unexpected Redis initialization error (%s).", exc)
        return None


def reset_redis_client() -> None:
    """Reset the cached Redis connection (useful for tests)."""
    global _redis_client
    _redis_client = None


def is_redis_available() -> bool:
    """Check whether Redis responds to PING."""
    return get_redis_client() is not None


def cache_get(key: str) -> Optional[Any]:
    """Read and JSON-decode a value from Redis; returns None on miss or failure."""
    client = get_redis_client()
    if client is None:
        return None
    try:
        raw = client.get(key)
        if raw is None:
            return None
        return json.loads(raw)
    except (RedisError, json.JSONDecodeError) as exc:
        logger.warning("Failed to read cache key '%s': %s", key, exc)
        return None


def cache_set(key: str, value: Any, ttl_seconds: Optional[int] = None) -> bool:
    """JSON-encode and store a value in Redis with TTL."""
    client = get_redis_client()
    if client is None:
        return False
    ttl = ttl_seconds if ttl_seconds is not None else settings.CACHE_TTL_SECONDS
    try:
        serialized = json.dumps(value, default=str)
        client.setex(name=key, time=ttl, value=serialized)
        return True
    except (RedisError, TypeError, ValueError) as exc:
        logger.warning("Failed to write cache key '%s': %s", key, exc)
        return False


def cache_delete(key: str) -> bool:
    """Delete a single key from Redis safely."""
    client = get_redis_client()
    if client is None:
        return False
    try:
        client.delete(key)
        return True
    except RedisError as exc:
        logger.warning("Failed to delete cache key '%s': %s", key, exc)
        return False


def invalidate_cache_patterns(patterns: Iterable[str]) -> int:
    """Delete all keys matching the given glob patterns without blocking Redis."""
    client = get_redis_client()
    if client is None:
        return 0

    deleted_count = 0
    try:
        for pattern in patterns:
            keys = list(client.scan_iter(match=pattern, count=100))
            if keys:
                deleted_count += int(client.delete(*keys))
        return deleted_count
    except RedisError as exc:
        logger.warning("Failed to invalidate Redis cache patterns: %s", exc)
        return deleted_count