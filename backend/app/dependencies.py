from typing import AsyncGenerator, Optional
from fastapi import Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db_session
from app.services.cache_service import RedisCacheService, cache_service
from app.core.security import UserContext, extract_user_context
from app.core.exceptions import UnauthorizedException


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency providing an async database session."""
    async for session in get_db_session():
        yield session


def get_cache() -> RedisCacheService:
    """Dependency providing the Redis caching service."""
    return cache_service


async def get_current_user(
    authorization: Optional[str] = Header(None, description="Supabase JWT Bearer token"),
) -> UserContext:
    """
    Mandatory authentication dependency for protected routes.
    Validates Supabase-issued JWT and injects UserContext.

    Raises:
        UnauthorizedException: If header is missing, malformed, or signature/claims fail validation.
    """
    if not authorization:
        raise UnauthorizedException("Missing Authorization header.")

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise UnauthorizedException("Authorization header must be formatted as 'Bearer <token>'.")

    token = parts[1]
    return extract_user_context(token)


async def get_optional_user(
    authorization: Optional[str] = Header(None, description="Optional Supabase JWT Bearer token"),
) -> Optional[UserContext]:
    """
    Optional authentication dependency for public endpoints (like /feed) that support
    personalized filtering if the user is signed in, but allow anonymous access.
    """
    if not authorization:
        return None

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None

    try:
        return extract_user_context(parts[1])
    except Exception:
        # Invalid optional token is treated as unauthenticated rather than blocking public access
        return None
