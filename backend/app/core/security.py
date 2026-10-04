from dataclasses import dataclass
from typing import Optional, Dict, Any
from jose import jwt, JWTError
from app.config import settings
from app.core.exceptions import UnauthorizedException


@dataclass(frozen=True)
class UserContext:
    """
    Immutable representation of an authenticated user extracted from Supabase JWT.
    """
    user_id: str
    email: Optional[str] = None
    role: str = "authenticated"


def decode_supabase_jwt(token: str) -> Dict[str, Any]:
    """
    Decodes and validates a Supabase-issued JWT token.
    Enforces signature verification, algorithm whitelist, audience check, and token expiry.

    Raises:
        UnauthorizedException: If token is missing, expired, tampered with, or malformed.
    """
    if not token or not token.strip():
        raise UnauthorizedException("Authentication token is missing.")

    try:
        payload = jwt.decode(
            token,
            key=settings.SUPABASE_JWT_SECRET,
            algorithms=[settings.SUPABASE_JWT_ALGORITHM],
            audience=settings.SUPABASE_JWT_AUDIENCE,
            options={"verify_aud": True, "verify_exp": True},
        )
        return payload
    except JWTError:
        # Uniform error message prevents timing or oracle attacks revealing why token failed
        raise UnauthorizedException("Authentication token is invalid or has expired.")


def extract_user_context(token: str) -> UserContext:
    """Decodes token and maps claims to UserContext."""
    payload = decode_supabase_jwt(token)
    user_id = payload.get("sub")
    if not user_id:
        raise UnauthorizedException("Token missing subject identifier (sub claim).")

    return UserContext(
        user_id=str(user_id),
        email=payload.get("email"),
        role=payload.get("role", "authenticated"),
    )
