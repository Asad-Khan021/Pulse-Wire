import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, get_cache
from app.schemas.signal import SignalResponse
from app.services.cache_service import RedisCacheService
from app.services.signals import SignalsAggregatorService

router = APIRouter(tags=["Community Signals"])


@router.get("/articles/{article_id}/signals", response_model=SignalResponse)
@router.get("/feed/{article_id}/signals", response_model=SignalResponse, include_in_schema=False)
async def get_article_signals(
    article_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    cache: RedisCacheService = Depends(get_cache),
):
    """
    Retrieves community discussion telemetry (Hacker News upvotes/comments, Reddit threads)
    with a 30-minute Redis caching window and fallback to persistent database storage.
    """
    return await SignalsAggregatorService.get_or_fetch_signals(
        article_id=article_id,
        db=db,
        cache=cache,
    )
