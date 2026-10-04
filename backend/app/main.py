from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.config import settings
from app.core.exceptions import (
    AppException,
    app_exception_handler,
    generic_exception_handler,
)
from app.core.limiter import limiter
from app.services.cache_service import cache_service
from app.workers.ingestion import start_ingestion_scheduler, stop_ingestion_scheduler
from app.routers.api import api_v1_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifecycle management:
    - Startup: Connects to Redis pool and launches background RSS ingestion scheduler.
    - Shutdown: Gracefully halts background scheduler and disconnects Redis pool.
    """
    # Startup tasks
    if "sqlite" in settings.DATABASE_URL:
        from app.db.base import Base
        from app.db.session import engine
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    await cache_service.initialize()
    start_ingestion_scheduler()
    yield
    # Shutdown tasks
    stop_ingestion_scheduler()
    await cache_service.close()


def create_application() -> FastAPI:
    """FastAPI application factory."""
    application = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        lifespan=lifespan,
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
    )

    # Attach SlowAPI Limiter
    application.state.limiter = limiter
    application.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    # CORS Middleware configuration
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

    # Standardized Exception Handlers
    application.add_exception_handler(AppException, app_exception_handler)
    if not settings.DEBUG:
        application.add_exception_handler(Exception, generic_exception_handler)

    # Include master API v1 router
    application.include_router(api_v1_router)

    return application


app = create_application()
