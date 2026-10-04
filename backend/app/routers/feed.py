import base64
import json
import uuid
from datetime import datetime
from typing import Optional, List
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.db.models import Article, Source, Signal, UserPreference
from app.dependencies import get_db, get_cache, get_optional_user
from app.core.security import UserContext
from app.core.exceptions import NotFoundException
from app.services.cache_service import RedisCacheService
from app.services.cache_keys import feed_cache_key
from app.schemas.article import ArticleListItem, ArticleDetail, FeedResponse, ArticleSourceInfo
from app.services.feed_fetcher import fetch_tech_news_feed, fetch_full_article_content
from app.services.html_cleaner import is_article_summarizable
from app.workers.ingestion import ingest_newsapi_feed

router = APIRouter(tags=["Feed & Articles"])


def _encode_cursor(published_at: datetime, article_id: uuid.UUID) -> str:
    """Encodes pagination position into an opaque base64 string."""
    payload = f"{published_at.isoformat()}|{str(article_id)}"
    return base64.urlsafe_b64encode(payload.encode("utf-8")).decode("utf-8")


def _decode_cursor(cursor: str) -> Optional[tuple[datetime, uuid.UUID]]:
    """Decodes opaque cursor into published_at timestamp and article UUID."""
    try:
        decoded = base64.urlsafe_b64decode(cursor.encode("utf-8")).decode("utf-8")
        parts = decoded.split("|")
        if len(parts) != 2:
            return None
        dt = datetime.fromisoformat(parts[0])
        uid = uuid.UUID(parts[1])
        return dt, uid
    except Exception:
        return None


@router.get("/feed", response_model=FeedResponse)
async def get_feed(
    limit: int = Query(20, ge=1, le=50, description="Max articles to return per page"),
    cursor: Optional[str] = Query(None, description="Opaque pagination cursor from previous page"),
    tags: Optional[str] = Query(None, description="Comma-separated topic tags to filter by"),
    exclude_domains: Optional[str] = Query(None, description="Comma-separated domains to exclude"),
    current_user: Optional[UserContext] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
    cache: RedisCacheService = Depends(get_cache),
):
    """
    Public paginated article feed.
    - Supports cursor-based pagination for stable scrolling under frequent ingestion.
    - Supports topic tag filtering and domain exclusion.
    - If user is authenticated and no explicit filters are provided, applies saved preferences.
    - Uses read-through Redis caching (5 min TTL) for standard queries.
    """
    requested_tags: List[str] = []
    if tags:
        requested_tags = [t.strip() for t in tags.split(",") if t.strip()]

    requested_exclude_domains: List[str] = []
    if exclude_domains:
        requested_exclude_domains = [d.strip().lower() for d in exclude_domains.split(",") if d.strip()]

    # If authenticated and query parameters are omitted, apply user preferences
    if current_user and not requested_tags and not requested_exclude_domains:
        pref_res = await db.execute(
            select(UserPreference).where(UserPreference.user_id == uuid.UUID(current_user.user_id))
        )
        pref = pref_res.scalar_one_or_none()
        if pref:
            if pref.followed_tags:
                requested_tags = list(pref.followed_tags)
            if pref.muted_domains:
                requested_exclude_domains = [d.lower() for d in pref.muted_domains]

    # --- Cache Check (Read-Through) ---
    cache_key = feed_cache_key(
        cursor=cursor,
        limit=limit,
        tags=requested_tags,
        exclude_domains=requested_exclude_domains,
    )
    cached_data = await cache.get_json(cache_key)
    if cached_data:
        return FeedResponse(**cached_data)

    # --- Database Query ---
    query = (
        select(Article)
        .options(
            joinedload(Article.source),
            joinedload(Article.signals),
        )
        .order_by(Article.published_at.desc(), Article.id.desc())
    )

    # Apply cursor filter
    if cursor:
        cursor_data = _decode_cursor(cursor)
        if cursor_data:
            c_published_at, c_id = cursor_data
            query = query.where(
                or_(
                    Article.published_at < c_published_at,
                    and_(
                        Article.published_at == c_published_at,
                        Article.id < c_id,
                    ),
                )
            )

    # Fetch one extra item to check for next page
    query = query.limit(limit + 1)
    result = await db.execute(query)
    articles = result.scalars().all()

    # Filter in Python for cross-dialect compatibility (supports both PostgreSQL ARRAY/GIN and SQLite JSON)
    filtered_articles: List[Article] = []
    for art in articles:
        # Check domain exclusion
        if requested_exclude_domains:
            domain = None
            if art.canonical_url:
                parsed = urlparse(art.canonical_url)
                domain = (parsed.hostname or "").lower()
            if domain and any(ex_d in domain for ex_d in requested_exclude_domains):
                continue

        # Check tag filtering
        if requested_tags:
            art_tags = [t.lower() for t in (art.tags or [])]
            if not any(req_t.lower() in art_tags for req_t in requested_tags):
                continue

        filtered_articles.append(art)

    has_more = len(filtered_articles) > limit
    page_items = filtered_articles[:limit]

    next_cursor = None
    if has_more and page_items:
        last_item = page_items[-1]
        next_cursor = _encode_cursor(last_item.published_at, last_item.id)

    # Build response DTOs
    response_items: List[ArticleListItem] = []
    for art in page_items:
        hn_pts = art.signals.hn_points if art.signals else None
        reddit_cmts = art.signals.reddit_comment_count if art.signals else None
        response_items.append(
            ArticleListItem(
                id=art.id,
                title=art.title,
                source_name=art.source.name if art.source else "Unknown",
                canonical_url=art.canonical_url,
                image_url=art.image_url,
                author=art.author,
                tags=art.tags or [],
                is_summarizable=art.is_summarizable,
                published_at=art.published_at,
                hn_points=hn_pts,
                reddit_comments=reddit_cmts,
            )
        )

    feed_response = FeedResponse(
        items=response_items,
        next_cursor=next_cursor,
        total_returned=len(response_items),
    )

    # Cache response in Redis with 5-minute TTL (300s)
    await cache.set_json(cache_key, feed_response.model_dump(mode="json"), ttl_seconds=300)

    return feed_response


@router.get("/articles/{article_id}", response_model=ArticleDetail)
async def get_article_detail(
    article_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """
    Public article detail endpoint.
    Retrieves full sanitized content and publisher metadata for reading.
    Automatically fetches full article content from the source URL if not already stored.
    """
    result = await db.execute(
        select(Article)
        .options(joinedload(Article.source))
        .where(Article.id == article_id)
    )
    article = result.scalar_one_or_none()

    if not article:
        raise NotFoundException(resource="Article", identifier=str(article_id))

    # If article content is missing or just a brief snippet (< 40 words), fetch the full article content from the source URL
    if not article.cleaned_content or len(article.cleaned_content.split()) < 40:
        if article.canonical_url:
            full_text = await fetch_full_article_content(article.canonical_url, timeout=6.0)
            if full_text:
                article.cleaned_content = full_text
                article.is_summarizable = is_article_summarizable(len(full_text.split()))
                try:
                    await db.commit()
                    await db.refresh(article)
                except Exception:
                    await db.rollback()

    return ArticleDetail(
        id=article.id,
        source=ArticleSourceInfo(
            id=article.source.id,
            name=article.source.name,
            feed_url=article.source.feed_url,
            homepage_url=article.source.homepage_url,
        ),
        title=article.title,
        canonical_url=article.canonical_url,
        content_hash=article.content_hash,
        cleaned_content=article.cleaned_content,
        image_url=article.image_url,
        author=article.author,
        tags=article.tags or [],
        is_summarizable=article.is_summarizable,
        published_at=article.published_at,
        created_at=article.created_at,
    )


@router.get("/feed/newsapi", summary="Fetch real-time categorized technology news feed from NewsAPI")
async def get_newsapi_feed(
    page_size: int = Query(20, ge=1, le=100, description="Max news headlines to fetch"),
    category: Optional[str] = Query(None, description="Filter by category (e.g. AI, Machine Learning, Cybersecurity, Cloud)"),
):
    """
    Fetches real-time technology news from NewsAPI.org and automatically categorizes
    articles into AI, Machine Learning, Cybersecurity, Cloud, Hardware, etc.
    """
    res = await fetch_tech_news_feed(page_size=page_size)
    if res.get("status") != "success":
        from fastapi import HTTPException
        raise HTTPException(status_code=502, detail=res.get("message", "NewsAPI request failed"))

    articles = res.get("articles", [])
    if category:
        cat_lower = category.strip().lower()
        articles = [
            a for a in articles
            if any(cat_lower == c.lower() for c in a.get("categories", []))
            or cat_lower == a.get("category", "").lower()
        ]
        res["articles"] = articles
        res["totalResults"] = len(articles)

    return res


@router.post("/feed/sync-newsapi", summary="Trigger instant NewsAPI tech headline ingestion")
async def sync_newsapi(
    db: AsyncSession = Depends(get_db),
    cache: RedisCacheService = Depends(get_cache),
):
    """
    Fetches latest NewsAPI tech headlines, categorizes articles, and stores them in the database.
    Invalidates feed Redis caches so new articles surface immediately.
    """
    inserted = await ingest_newsapi_feed(db)
    await cache.delete_pattern("feed:*")
    return {"status": "success", "articles_inserted": inserted}

