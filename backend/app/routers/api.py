from fastapi import APIRouter
from app.routers import health, feed, summary, signals

api_v1_router = APIRouter(prefix="/api/v1")

# Mount sub-routers
api_v1_router.include_router(health.router)
api_v1_router.include_router(feed.router)
api_v1_router.include_router(summary.router)
api_v1_router.include_router(signals.router)
