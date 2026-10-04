from slowapi import Limiter
from slowapi.util import get_remote_address
from app.config import settings

# Global rate limiter instance keyed by client remote IP address
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[],
    storage_uri=settings.REDIS_URL if settings.REDIS_CACHE_ENABLED and not settings.DEBUG else "memory://",
)
