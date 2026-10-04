import json
import logging
from typing import Optional, Any
from redis.asyncio import Redis, ConnectionPool
from app.config import settings

logger = logging.getLogger("digest.cache")


class RedisCacheService:
    """
    Asynchronous Redis Cache Service with graceful degradation.
    If Redis times out or is unreachable, methods return None/False without crashing callers.
    """

    def __init__(self, redis_url: str):
        self.redis_url = redis_url
        self.pool: Optional[ConnectionPool] = None
        self.client: Optional[Redis] = None

    async def initialize(self) -> None:
        """Initializes the Redis connection pool."""
        if not settings.REDIS_CACHE_ENABLED:
            logger.info("Redis cache is disabled via configuration.")
            return

        try:
            self.pool = ConnectionPool.from_url(
                self.redis_url,
                max_connections=20,
                decode_responses=True,
                socket_timeout=settings.REDIS_TIMEOUT_SECONDS,
            )
            self.client = Redis(connection_pool=self.pool)
            await self.client.ping()
            logger.info("Redis connection pool established successfully.")
        except Exception as e:
            logger.warning(f"Could not establish Redis connection at startup: {e}. Degrading to database-only.")
            self.client = None

    async def close(self) -> None:
        """Closes all Redis connections in the pool."""
        if self.client:
            try:
                await self.client.close()
            except Exception as e:
                logger.warning(f"Error closing Redis client: {e}")
        if self.pool:
            try:
                await self.pool.disconnect()
            except Exception as e:
                logger.warning(f"Error disconnecting Redis pool: {e}")

    async def is_healthy(self) -> bool:
        """Health check returns True if Redis responds to ping."""
        if not self.client:
            return False
        try:
            return bool(await self.client.ping())
        except Exception:
            return False

    async def get(self, key: str) -> Optional[str]:
        """Retrieves raw string value by key; returns None on miss or error."""
        if not self.client:
            return None
        try:
            return await self.client.get(key)
        except Exception as e:
            logger.warning(f"Redis GET failed for key '{key}': {e}")
            return None

    async def get_json(self, key: str) -> Optional[Any]:
        """Retrieves and deserializes JSON from Redis; returns None on miss or error."""
        raw = await self.get(key)
        if not raw:
            return None
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return None

    async def set(self, key: str, value: str, ttl_seconds: int = 300, ttl: Optional[int] = None) -> bool:
        """Stores raw string in Redis with TTL; returns False on failure."""
        effective_ttl = ttl if ttl is not None else ttl_seconds
        if not self.client:
            return False
        try:
            await self.client.set(key, value, ex=effective_ttl)
            return True
        except Exception as e:
            logger.warning(f"Redis SET failed for key '{key}': {e}")
            return False

    async def set_json(self, key: str, value: Any, ttl_seconds: int = 300, ttl: Optional[int] = None) -> bool:
        """Serializes and stores value as JSON with TTL; returns False on failure."""
        effective_ttl = ttl if ttl is not None else ttl_seconds
        try:
            serialized = json.dumps(value)
            return await self.set(key, serialized, ttl_seconds=effective_ttl)
        except Exception as e:
            logger.warning(f"JSON serialization failed for key '{key}': {e}")
            return False

    async def delete(self, key: str) -> bool:
        """Deletes key from Redis; returns False on failure."""
        if not self.client:
            return False
        try:
            await self.client.delete(key)
            return True
        except Exception as e:
            logger.warning(f"Redis DELETE failed for key '{key}': {e}")
            return False


# Global singleton cache service instance
cache_service = RedisCacheService(settings.REDIS_URL)
