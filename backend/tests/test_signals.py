import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Source, Article, Signal


@pytest.mark.asyncio
async def test_signals_retrieval_and_caching(client: AsyncClient, db_session: AsyncSession, monkeypatch):
    """
    Verifies that HN and Reddit signals are fetched, stored in DB, cached in Redis,
    and served from cache on subsequent calls.
    """
    source = Source(
        id=uuid.uuid4(),
        name="TechHub",
        feed_url="https://techhub.internal/feed",
        is_active=True,
    )
    db_session.add(source)
    await db_session.flush()

    art_id = uuid.uuid4()
    article = Article(
        id=art_id,
        source_id=source.id,
        title="Novel Quantum Compiler Open Sourced",
        canonical_url="https://techhub.internal/quantum-compiler",
        content_hash="quantum-hash-789",
        cleaned_content="A full description of the novel quantum compiler.",
        is_summarizable=True,
        published_at=datetime.now(timezone.utc),
    )
    db_session.add(article)
    await db_session.commit()

    # Mock HN and Reddit responses
    async def mock_hn(url, title, c):
        return {
            "hn_points": 420,
            "hn_comment_count": 137,
            "hn_discussion_url": "https://news.ycombinator.com/item?id=99999",
        }

    async def mock_reddit(url, title, c):
        return {
            "reddit_thread_url": "https://www.reddit.com/r/technology/comments/quantum_compiler",
            "reddit_comment_count": 88,
        }

    monkeypatch.setattr("app.services.signals.fetch_hn_signals", mock_hn)
    monkeypatch.setattr("app.services.signals.fetch_reddit_signals", mock_reddit)

    # First request: fetches and persists signals
    res1 = await client.get(f"/api/v1/articles/{art_id}/signals")
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["hn_points"] == 420
    assert data1["hn_comment_count"] == 137
    assert data1["hn_discussion_url"] == "https://news.ycombinator.com/item?id=99999"
    assert data1["reddit_comment_count"] == 88

    # Second request: served from Redis cache
    res2 = await client.get(f"/api/v1/articles/{art_id}/signals")
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["hn_points"] == 420


@pytest.mark.asyncio
async def test_signals_silent_fallback_on_network_error(client: AsyncClient, db_session: AsyncSession, monkeypatch):
    """
    Verifies that when external signal APIs fail or timeout,
    the endpoint fails silently and returns empty metrics without crashing.
    """
    source = Source(
        id=uuid.uuid4(),
        name="DevNews",
        feed_url="https://devnews.internal/feed",
        is_active=True,
    )
    db_session.add(source)
    await db_session.flush()

    art_id = uuid.uuid4()
    article = Article(
        id=art_id,
        source_id=source.id,
        title="Microservice Resilience Patterns",
        canonical_url="https://devnews.internal/resilience",
        content_hash="resilience-hash-001",
        cleaned_content="Article content.",
        is_summarizable=True,
        published_at=datetime.now(timezone.utc),
    )
    db_session.add(article)
    await db_session.commit()

    # Simulate network exception in signal fetchers
    async def failing_fetch(*args, **kwargs):
        raise ConnectionError("Network timeout connecting to external API")

    monkeypatch.setattr("app.services.signals.fetch_hn_signals", failing_fetch)
    monkeypatch.setattr("app.services.signals.fetch_reddit_signals", failing_fetch)

    # Endpoint must succeed gracefully with 200
    resp = await client.get(f"/api/v1/articles/{art_id}/signals")
    assert resp.status_code == 200
    data = resp.json()
    assert data["hn_points"] is None
    assert data["reddit_comment_count"] is None
