import uuid
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.limiter import limiter
from app.dependencies import get_db, get_cache
from app.schemas.summary import SummaryResponse
from app.services.cache_service import RedisCacheService
from app.services.prompts import QuestionType
from app.services.summarizer import SummarizerService

router = APIRouter(tags=["AI Summaries"])


@router.get("/articles/{article_id}/summary", response_model=SummaryResponse)
@router.get("/feed/{article_id}/summary", response_model=SummaryResponse, include_in_schema=False)
@limiter.limit(settings.RATE_LIMIT_SUMMARY)
async def get_article_summary(
    request: Request,
    article_id: uuid.UUID,
    question_type: QuestionType = Query(
        QuestionType.CORE,
        description="Preset summary angle: core (overview), simpler (ELI5), significance (why it matters), risk (downside analysis)",
    ),
    db: AsyncSession = Depends(get_db),
    cache: RedisCacheService = Depends(get_cache),
):
    """
    Retrieves or generates a cost-controlled 3-bullet AI summary for an article.
    - Tier 1: In-memory Redis cache lookup.
    - Tier 2: PostgreSQL persistent storage lookup.
    - Tier 3: Google Gemini API generation (gemini-1.5-flash) with rate limiting.
    """
    return await SummarizerService.get_or_generate_summary(
        article_id=article_id,
        question_type=question_type,
        db=db,
        cache=cache,
    )
