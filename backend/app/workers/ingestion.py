import inspect
import logging
import uuid
from datetime import datetime, timezone
from typing import List, Optional
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config import settings
from app.db.models import Source, Article
from app.db.session import async_session_factory
from app.services.feed_fetcher import (
    fetch_feed_xml,
    parse_feed_entries,
    fetch_newsapi_raw_items,
    fetch_full_article_content,
    assign_categories,
    RawFeedItem,
)
from app.services.html_cleaner import (
    normalize_canonical_url,
    clean_article_html,
    compute_content_hash,
    is_article_summarizable,
)

logger = logging.getLogger(__name__)

# Singleton scheduler instance
scheduler = AsyncIOScheduler()

NEWSAPI_FEED_URL = "https://newsapi.org/v2/top-headlines?category=technology"


async def get_or_create_newsapi_source(db: AsyncSession) -> Source:
    """Retrieves or registers the default NewsAPI technology feed source."""
    res = await db.execute(
        select(Source).where(Source.feed_url == NEWSAPI_FEED_URL).limit(1)
    )
    src = res.scalar_one_or_none()
    if not src:
        src = Source(
            id=uuid.uuid4(),
            name="NewsAPI Tech",
            feed_url=NEWSAPI_FEED_URL,
            homepage_url="https://newsapi.org",
            category_tags=["Tech", "NewsAPI"],
            is_active=True,
        )
        db.add(src)
        await db.commit()
        await db.refresh(src)
    return src


async def ingest_newsapi_feed(db: AsyncSession, api_key: Optional[str] = None) -> int:
    """
    Fetches, categorizes, deduplicates, and ingests technology headlines from NewsAPI.
    Routes Machine Learning news to 'Machine Learning', AI news to 'AI',
    Cybersecurity to 'Cybersecurity', Cloud to 'Cloud', etc.
    """
    try:
        source = await get_or_create_newsapi_source(db)
        raw_items = await fetch_newsapi_raw_items(api_key=api_key)
        if not raw_items:
            return 0

        inserted_count = 0
        now = datetime.now(timezone.utc)

        for entry in raw_items:
            canonical_url = normalize_canonical_url(entry.link)
            if not canonical_url:
                continue

            cleaned_content, word_count = clean_article_html(entry.raw_content)
            if word_count < 40 and canonical_url:
                full_scraped = await fetch_full_article_content(canonical_url, timeout=5.0)
                if full_scraped:
                    cleaned_content, word_count = clean_article_html(full_scraped)

            content_hash = compute_content_hash(cleaned_content if cleaned_content else entry.title)

            # Deduplication
            existing_res = await db.execute(
                select(Article.id).where(
                    or_(
                        Article.canonical_url == canonical_url,
                        Article.content_hash == content_hash,
                    )
                ).limit(1)
            )
            if existing_res.scalar_one_or_none() is not None:
                continue

            # Route to categories
            auto_tags = assign_categories(entry.title, cleaned_content)
            combined_tags = list(set((source.category_tags or []) + entry.tags + auto_tags))

            article = Article(
                id=uuid.uuid4(),
                source_id=source.id,
                title=entry.title,
                canonical_url=canonical_url,
                content_hash=content_hash,
                cleaned_content=cleaned_content,
                image_url=entry.image_url,
                author=entry.author,
                tags=combined_tags,
                is_summarizable=True,
                published_at=entry.published_at or now,
            )
            db.add(article)
            inserted_count += 1

        await db.commit()
        logger.info(f"NewsAPI feed successfully ingested ({inserted_count} new articles).")
        return inserted_count
    except Exception as exc:
        await db.rollback()
        logger.error(f"Error during NewsAPI ingestion: {exc}", exc_info=True)
        return 0


async def ingest_source(source: Source, db: AsyncSession) -> int:
    """
    Ingests feed items for a single source.
    Returns the count of newly inserted articles.
    Raises an exception on failure so caller can handle source health telemetry.
    """
    logger.info(f"Ingesting feed for source: {source.name} ({source.feed_url})")
    raw_fetch = fetch_feed_xml(source.feed_url)
    feed_xml = await raw_fetch if inspect.isawaitable(raw_fetch) else raw_fetch
    entries: List[RawFeedItem] = parse_feed_entries(feed_xml)

    inserted_count = 0
    now = datetime.now(timezone.utc)

    for entry in entries:
        canonical_url = normalize_canonical_url(entry.link)
        if not canonical_url:
            continue

        cleaned_content, word_count = clean_article_html(entry.raw_content)
        if word_count < 40 and canonical_url:
            full_scraped = await fetch_full_article_content(canonical_url, timeout=5.0)
            if full_scraped:
                cleaned_content, word_count = clean_article_html(full_scraped)
        content_hash = compute_content_hash(cleaned_content if cleaned_content else entry.title)

        # Enforce deduplication: check canonical_url or content_hash
        existing_res = await db.execute(
            select(Article.id).where(
                or_(
                    Article.canonical_url == canonical_url,
                    Article.content_hash == content_hash,
                )
            ).limit(1)
        )
        if existing_res.scalar_one_or_none() is not None:
            continue

        # Quality guardrail: check minimum word count
        summarizable = is_article_summarizable(word_count, min_words=settings.MIN_ARTICLE_WORD_COUNT)

        # Merge source default tags with entry tags and automated categorization
        auto_tags = assign_categories(entry.title, cleaned_content)
        combined_tags = list(set((source.category_tags or []) + entry.tags + auto_tags))

        article = Article(
            id=uuid.uuid4(),
            source_id=source.id,
            title=entry.title,
            canonical_url=canonical_url,
            content_hash=content_hash,
            cleaned_content=cleaned_content,
            image_url=entry.image_url,
            author=entry.author,
            tags=combined_tags,
            is_summarizable=summarizable,
            published_at=entry.published_at or now,
        )
        db.add(article)
        inserted_count += 1

    return inserted_count


async def run_ingestion_cycle(session_factory: Optional[async_sessionmaker] = None) -> dict:
    """
    Executes an ingestion pass across all active sources and NewsAPI.
    Isolates errors per source so one broken feed does not interrupt the entire pipeline.
    """
    factory = session_factory or async_session_factory
    results = {
        "sources_processed": 0,
        "sources_failed": 0,
        "articles_inserted": 0,
    }

    async with factory() as db:
        # 1. Ingest RSS / Atom Sources
        sources_res = await db.execute(
            select(Source).where(Source.is_active == True)
        )
        sources = sources_res.scalars().all()
        results["sources_processed"] = len(sources)

        for source in sources:
            if source.feed_url == NEWSAPI_FEED_URL:
                continue
            try:
                inserted = await ingest_source(source, db)
                source.failure_count = 0
                source.last_fetched_at = datetime.now(timezone.utc)
                await db.commit()
                results["articles_inserted"] += inserted
                logger.info(f"Source '{source.name}' successfully ingested ({inserted} new articles).")
            except Exception as exc:
                await db.rollback()
                source.failure_count += 1
                logger.error(
                    f"Failed to ingest source '{source.name}' (URL: {source.feed_url}, "
                    f"Failures: {source.failure_count}): {exc}"
                )
                try:
                    await db.commit()
                except Exception:
                    await db.rollback()
                results["sources_failed"] += 1

        # 2. Ingest NewsAPI Top Technology Headlines if enabled
        if settings.NEWS_API_ENABLED:
            try:
                newsapi_inserted = await ingest_newsapi_feed(db)
                results["articles_inserted"] += newsapi_inserted
            except Exception as exc:
                logger.error(f"NewsAPI scheduled cycle error: {exc}")

    return results


def start_ingestion_scheduler():
    """Starts the APScheduler background ingestion job."""
    if not settings.INGESTION_ENABLED:
        logger.info("Ingestion scheduler is disabled by configuration.")
        return

    if not scheduler.running:
        scheduler.add_job(
            run_ingestion_cycle,
            "interval",
            minutes=settings.INGESTION_INTERVAL_MINUTES,
            id="rss_ingestion_worker",
            replace_existing=True,
            next_run_time=None,  # Do not block startup; first run scheduled at interval
        )
        scheduler.start()
        logger.info(
            f"Ingestion scheduler started. Interval: {settings.INGESTION_INTERVAL_MINUTES} minutes."
        )


def stop_ingestion_scheduler():
    """Stops the APScheduler worker during shutdown."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Ingestion scheduler gracefully shut down.")
