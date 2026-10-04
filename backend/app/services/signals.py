import asyncio
import logging
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any
import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.exceptions import NotFoundException
from app.db.models import Article, Signal
from app.schemas.signal import SignalResponse
from app.services.cache_keys import signals_cache_key
from app.services.cache_service import RedisCacheService

logger = logging.getLogger(__name__)

HN_SEARCH_URL = "https://hn.algolia.com/api/v1/search"
REDDIT_SEARCH_URL = "https://www.reddit.com/search.json"
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) DigestApp/1.0 (contact@digest.internal)"


async def fetch_hn_signals(url: str, title: str, client: httpx.AsyncClient) -> Dict[str, Any]:
    """
    Queries Algolia Hacker News Search API by canonical URL, falling back to title.
    Returns: dict with hn_points, hn_comment_count, and hn_discussion_url.
    """
    try:
        # 1. Search by canonical URL first
        resp = await client.get(
            HN_SEARCH_URL,
            params={"query": url, "restrictSearchableAttributes": "url", "hitsPerPage": 3},
            timeout=4.0,
        )
        if resp.status_code == 200:
            hits = resp.json().get("hits", [])
            if hits:
                best = max(hits, key=lambda h: h.get("points") or 0)
                item_id = best.get("objectID")
                return {
                    "hn_points": best.get("points") or 0,
                    "hn_comment_count": best.get("num_comments") or 0,
                    "hn_discussion_url": f"https://news.ycombinator.com/item?id={item_id}" if item_id else None,
                }

        # 2. Fallback search by title
        if title:
            resp_title = await client.get(
                HN_SEARCH_URL,
                params={"query": title, "tags": "story", "hitsPerPage": 3},
                timeout=4.0,
            )
            if resp_title.status_code == 200:
                hits = resp_title.json().get("hits", [])
                if hits:
                    best = max(hits, key=lambda h: h.get("points") or 0)
                    item_id = best.get("objectID")
                    return {
                        "hn_points": best.get("points") or 0,
                        "hn_comment_count": best.get("num_comments") or 0,
                        "hn_discussion_url": f"https://news.ycombinator.com/item?id={item_id}" if item_id else None,
                    }
    except Exception as exc:
        logger.debug(f"HN signal lookup failed silently: {exc}")

    return {
        "hn_points": None,
        "hn_comment_count": None,
        "hn_discussion_url": None,
    }


async def fetch_reddit_signals(url: str, title: str, client: httpx.AsyncClient) -> Dict[str, Any]:
    """
    Queries Reddit Search JSON endpoint by canonical URL.
    Returns: dict with reddit_thread_url and reddit_comment_count.
    """
    try:
        query = f'url:"{url}"'
        resp = await client.get(
            REDDIT_SEARCH_URL,
            params={"q": query, "sort": "relevance", "limit": 3},
            headers={"User-Agent": USER_AGENT},
            timeout=4.0,
        )
        if resp.status_code == 200:
            data = resp.json().get("data", {})
            children = data.get("children", [])
            if children:
                best = max(children, key=lambda c: c.get("data", {}).get("num_comments") or 0)
                item_data = best.get("data", {})
                permalink = item_data.get("permalink")
                return {
                    "reddit_thread_url": f"https://www.reddit.com{permalink}" if permalink else None,
                    "reddit_comment_count": item_data.get("num_comments") or 0,
                }
    except Exception as exc:
        logger.debug(f"Reddit signal lookup failed silently: {exc}")

    return {
        "reddit_thread_url": None,
        "reddit_comment_count": None,
    }


class SignalsAggregatorService:
    """
    Community Signals Aggregator with 30-minute Redis caching and PostgreSQL persistence.
    Operates with strict timeouts and silent failover to protect user-facing response times.
    """

    @staticmethod
    async def get_or_fetch_signals(
        article_id: uuid.UUID,
        db: AsyncSession,
        cache: RedisCacheService,
    ) -> SignalResponse:
        cache_key = signals_cache_key(str(article_id))

        # ----------------------------------------------------
        # 1. Redis Cache Check (30-min TTL)
        # ----------------------------------------------------
        cached = await cache.get_json(cache_key)
        if cached:
            fetched_at = cached.get("fetched_at")
            if isinstance(fetched_at, str):
                fetched_at = datetime.fromisoformat(fetched_at)
            return SignalResponse(
                article_id=article_id,
                hn_points=cached.get("hn_points"),
                hn_comment_count=cached.get("hn_comment_count"),
                hn_discussion_url=cached.get("hn_discussion_url"),
                reddit_thread_url=cached.get("reddit_thread_url"),
                reddit_comment_count=cached.get("reddit_comment_count"),
                fetched_at=fetched_at,
            )

        # ----------------------------------------------------
        # 2. Database Check
        # ----------------------------------------------------
        sig_res = await db.execute(
            select(Signal).where(Signal.article_id == article_id)
        )
        existing_signal = sig_res.scalar_one_or_none()

        now = datetime.now(timezone.utc)
        freshness_threshold = now - timedelta(seconds=settings.SIGNALS_CACHE_TTL_SECONDS)

        # If DB signal is fresh, rehydrate Redis and return
        if existing_signal and existing_signal.fetched_at and existing_signal.fetched_at > freshness_threshold:
            payload = {
                "hn_points": existing_signal.hn_points,
                "hn_comment_count": existing_signal.hn_comment_count,
                "hn_discussion_url": existing_signal.hn_discussion_url,
                "reddit_thread_url": existing_signal.reddit_thread_url,
                "reddit_comment_count": existing_signal.reddit_comment_count,
                "fetched_at": existing_signal.fetched_at.isoformat(),
            }
            await cache.set_json(cache_key, payload, ttl=settings.SIGNALS_CACHE_TTL_SECONDS)
            return SignalResponse.model_validate(existing_signal)

        # ----------------------------------------------------
        # 3. Retrieve Article details for query matching
        # ----------------------------------------------------
        art_res = await db.execute(
            select(Article).where(Article.id == article_id)
        )
        article = art_res.scalar_one_or_none()
        if not article:
            raise NotFoundException(resource="Article", identifier=str(article_id))

        # ----------------------------------------------------
        # 4. Fetch from Algolia HN & Reddit in Parallel
        # ----------------------------------------------------
        hn_data = {"hn_points": None, "hn_comment_count": None, "hn_discussion_url": None}
        reddit_data = {"reddit_thread_url": None, "reddit_comment_count": None}

        try:
            async with httpx.AsyncClient(headers={"User-Agent": USER_AGENT}) as client:
                hn_task = fetch_hn_signals(article.canonical_url, article.title, client)
                reddit_task = fetch_reddit_signals(article.canonical_url, article.title, client)
                results = await asyncio.gather(hn_task, reddit_task, return_exceptions=True)

                if not isinstance(results[0], Exception):
                    hn_data = results[0]
                if not isinstance(results[1], Exception):
                    reddit_data = results[1]
        except Exception as exc:
            logger.warning(f"Community signal gathering error for article {article_id}: {exc}")

        # ----------------------------------------------------
        # 5. Persist / Upsert into DB and Cache
        # ----------------------------------------------------
        if existing_signal:
            existing_signal.hn_points = hn_data.get("hn_points") or existing_signal.hn_points
            existing_signal.hn_comment_count = hn_data.get("hn_comment_count") or existing_signal.hn_comment_count
            existing_signal.hn_discussion_url = hn_data.get("hn_discussion_url") or existing_signal.hn_discussion_url
            existing_signal.reddit_thread_url = reddit_data.get("reddit_thread_url") or existing_signal.reddit_thread_url
            existing_signal.reddit_comment_count = reddit_data.get("reddit_comment_count") or existing_signal.reddit_comment_count
            existing_signal.fetched_at = now
            sig_to_return = existing_signal
        else:
            sig_to_return = Signal(
                article_id=article.id,
                hn_points=hn_data.get("hn_points"),
                hn_comment_count=hn_data.get("hn_comment_count"),
                hn_discussion_url=hn_data.get("hn_discussion_url"),
                reddit_thread_url=reddit_data.get("reddit_thread_url"),
                reddit_comment_count=reddit_data.get("reddit_comment_count"),
                fetched_at=now,
            )
            db.add(sig_to_return)

        try:
            await db.commit()
        except Exception as db_exc:
            await db.rollback()
            logger.warning(f"Failed to commit signal record for article {article_id}: {db_exc}")

        # Cache in Redis with 30-min TTL
        cache_payload = {
            "hn_points": sig_to_return.hn_points,
            "hn_comment_count": sig_to_return.hn_comment_count,
            "hn_discussion_url": sig_to_return.hn_discussion_url,
            "reddit_thread_url": sig_to_return.reddit_thread_url,
            "reddit_comment_count": sig_to_return.reddit_comment_count,
            "fetched_at": now.isoformat(),
        }
        await cache.set_json(cache_key, cache_payload, ttl=settings.SIGNALS_CACHE_TTL_SECONDS)

        return SignalResponse(
            article_id=article_id,
            hn_points=sig_to_return.hn_points,
            hn_comment_count=sig_to_return.hn_comment_count,
            hn_discussion_url=sig_to_return.hn_discussion_url,
            reddit_thread_url=sig_to_return.reddit_thread_url,
            reddit_comment_count=sig_to_return.reddit_comment_count,
            fetched_at=now,
        )
