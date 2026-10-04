from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.dependencies import get_db, get_cache
from app.services.cache_service import RedisCacheService
from app.schemas.common import HealthCheckResponse

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthCheckResponse)
async def health_check(
    db: AsyncSession = Depends(get_db),
    cache: RedisCacheService = Depends(get_cache),
):
    """
    Service health check endpoint verifying database connectivity and Redis availability.
    """
    db_ok = False
    try:
        res = await db.execute(text("SELECT 1"))
        db_ok = res.scalar() == 1
    except Exception:
        db_ok = False

    redis_ok = await cache.is_healthy()

    overall_status = "healthy" if (db_ok and (redis_ok or not settings.REDIS_CACHE_ENABLED)) else "degraded"

    return HealthCheckResponse(
        status=overall_status,
        database=db_ok,
        redis=redis_ok,
        version=settings.APP_VERSION,
    )


@router.get("/health/redis")
async def redis_health(cache: RedisCacheService = Depends(get_cache)):
    """Health check for Redis connection pool specifically."""
    is_ok = await cache.is_healthy()
    return {"redis_connected": is_ok}
