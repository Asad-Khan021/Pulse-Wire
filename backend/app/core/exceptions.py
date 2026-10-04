from typing import Any, Dict, Optional
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse


class AppException(HTTPException):
    """Base application domain exception mapped to standard error envelope."""

    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        retry_after: Optional[int] = None,
        headers: Optional[Dict[str, str]] = None,
    ):
        super().__init__(status_code=status_code, detail=message, headers=headers)
        self.code = code
        self.message = message
        self.retry_after = retry_after


class UnauthorizedException(AppException):
    """401 Unauthorized - missing, invalid, or expired JWT."""

    def __init__(self, message: str = "Authentication required or token invalid."):
        super().__init__(
            code="UNAUTHORIZED",
            message=message,
            status_code=status.HTTP_401_UNAUTHORIZED,
            headers={"WWW-Authenticate": "Bearer"},
        )


class ForbiddenException(AppException):
    """403 Forbidden - authenticated user lacks permissions for resource."""

    def __init__(self, message: str = "You do not have permission to access this resource."):
        super().__init__(
            code="FORBIDDEN",
            message=message,
            status_code=status.HTTP_403_FORBIDDEN,
        )


class NotFoundException(AppException):
    """404 Not Found - resource does not exist."""

    def __init__(self, resource: str = "Resource", identifier: Optional[str] = None):
        msg = f"{resource} not found" if not identifier else f"{resource} with id '{identifier}' not found"
        super().__init__(
            code="NOT_FOUND",
            message=msg,
            status_code=status.HTTP_404_NOT_FOUND,
        )


class RateLimitedException(AppException):
    """429 Rate Limited - request limit exceeded."""

    def __init__(self, retry_after: int = 60, message: str = "Rate limit exceeded. Please slow down."):
        super().__init__(
            code="RATE_LIMITED",
            message=message,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            retry_after=retry_after,
            headers={"Retry-After": str(retry_after)},
        )


class NotSummarizableException(AppException):
    """422 Unprocessable Entity - article failed extraction threshold check."""

    def __init__(self, message: str = "Article is ineligible for AI summarization."):
        super().__init__(
            code="NOT_SUMMARIZABLE",
            message=message,
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )


class UpstreamUnavailableException(AppException):
    """503 Service Unavailable - upstream AI/DB dependency failure."""

    def __init__(self, message: str = "Upstream service temporarily unavailable.", retry_after: int = 5):
        super().__init__(
            code="UPSTREAM_UNAVAILABLE",
            message=message,
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            retry_after=retry_after,
            headers={"Retry-After": str(retry_after)},
        )


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    """Serializes AppException into the standard error envelope JSON."""
    payload: Dict[str, Any] = {
        "error": {
            "code": exc.code,
            "message": exc.message,
        }
    }
    if exc.retry_after is not None:
        payload["error"]["retry_after"] = exc.retry_after

    return JSONResponse(
        status_code=exc.status_code,
        content=payload,
        headers=exc.headers,
    )


async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Catches unhandled server exceptions, preventing stack trace disclosure to clients."""
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "code": "INTERNAL_ERROR",
                "message": "An unexpected server error occurred.",
            }
        },
    )
