import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Source, Article, Summary
from app.services.cache_keys import summary_cache_key
from tests.conftest import mock_cache


@pytest.mark.asyncio
async def test_3_tier_summarization_flow(client: AsyncClient, db_session: AsyncSession, monkeypatch):
    """
    Verifies the 3-Tier AI Summarization Flow:
    Tier 3 (Gemini Generation) -> Tier 1 (Redis Cache Hit) -> Tier 2 (DB Hit & Redis Rehydration).
    """
    # 1. Seed Source and Article
    source = Source(
        id=uuid.uuid4(),
        name="Wired",
        feed_url="https://wired.com/feed",
        category_tags=["AI"],
        is_active=True,
    )
    db_session.add(source)
    await db_session.flush()

    art_id = uuid.uuid4()
    article = Article(
        id=art_id,
        source_id=source.id,
        title="Autonomous AI Agents in Cloud Infrastructure",
        canonical_url="https://wired.com/ai-agents",
        content_hash="wired-hash-123",
        cleaned_content="Autonomous AI agents are being deployed in cloud infrastructure to optimize resource allocation and remediate security vulnerabilities in real time. Several hyperscalers announced general availability of agentic monitoring pipelines today.",
        is_summarizable=True,
        published_at=datetime.now(timezone.utc),
    )
    db_session.add(article)
    await db_session.commit()

    # Mock Gemini API response
    mock_bullets = [
        "Hyperscalers launch production-ready autonomous infrastructure management agents.",
        "Pipelines automate runtime resource allocation and real-time security remediation.",
        "Deployment reduces incident resolution times from hours to milliseconds.",
    ]
    monkeypatch.setattr(
        "app.services.summarizer.call_gemini_api",
        lambda prompt: mock_bullets,
    )

    # -----------------------------------------------------------------
    # STEP 1: First Request -> Tier 3 (Gemini Call -> DB -> Redis)
    # -----------------------------------------------------------------
    res1 = await client.get(f"/api/v1/articles/{art_id}/summary?question_type=core")
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["cached"] is False
    assert data1["content"] == mock_bullets
    assert data1["question_type"] == "core"

    # Verify Summary record saved in DB
    s_query = await db_session.execute(
        select(Summary).where(Summary.article_id == art_id, Summary.question_type == "core")
    )
    summary_in_db = s_query.scalar_one_or_none()
    assert summary_in_db is not None
    assert summary_in_db.question_type == "core"

    # -----------------------------------------------------------------
    # STEP 2: Second Request -> Tier 1 (Redis Cache Hit)
    # -----------------------------------------------------------------
    res2 = await client.get(f"/api/v1/articles/{art_id}/summary?question_type=core")
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["cached"] is True
    assert data2["content"] == mock_bullets

    # -----------------------------------------------------------------
    # STEP 3: Clear Redis -> Tier 2 (Postgres DB Hit & Rehydrate)
    # -----------------------------------------------------------------
    cache_key = summary_cache_key(str(art_id), "core")
    await mock_cache.delete(cache_key)

    res3 = await client.get(f"/api/v1/articles/{art_id}/summary?question_type=core")
    assert res3.status_code == 200
    data3 = res3.json()
    assert data3["cached"] is True
    assert data3["content"] == mock_bullets

    # Cache should now be rehydrated
    assert await mock_cache.get(cache_key) is not None


@pytest.mark.asyncio
async def test_summary_question_angles(client: AsyncClient, db_session: AsyncSession, monkeypatch):
    """Verifies all four preset question angles can be queried."""
    source = Source(
        id=uuid.uuid4(),
        name="MIT Tech Review",
        feed_url="https://technologyreview.com/feed",
        category_tags=["Science"],
        is_active=True,
    )
    db_session.add(source)
    await db_session.flush()

    art_id = uuid.uuid4()
    article = Article(
        id=art_id,
        source_id=source.id,
        title="Photonic Computing Reaches Exascale Efficiency",
        canonical_url="https://technologyreview.com/photonic-exascale",
        content_hash="photonic-hash-456",
        cleaned_content="Photonic integrated circuits have demonstrated exascale compute throughput with 90 percent reduced thermal dissipation. Optical matrix multipliers enable deep learning models to execute inference using light waves.",
        is_summarizable=True,
        published_at=datetime.now(timezone.utc),
    )
    db_session.add(article)
    await db_session.commit()

    monkeypatch.setattr(
        "app.services.summarizer.call_gemini_api",
        lambda prompt: ["Bullet A", "Bullet B", "Bullet C"],
    )

    angles = ["core", "simpler", "significance", "risk"]
    for angle in angles:
        resp = await client.get(f"/api/v1/articles/{art_id}/summary?question_type={angle}")
        assert resp.status_code == 200
        assert resp.json()["question_type"] == angle


@pytest.mark.asyncio
async def test_summary_unsummarizable_article(client: AsyncClient, db_session: AsyncSession):
    """Verifies that an unsummarizable article returns 422 Unprocessable Entity."""
    source = Source(
        id=uuid.uuid4(),
        name="Briefs",
        feed_url="https://briefs.internal/feed",
        is_active=True,
    )
    db_session.add(source)
    await db_session.flush()

    art_id = uuid.uuid4()
    article = Article(
        id=art_id,
        source_id=source.id,
        title="Micro Announcement",
        canonical_url="https://briefs.internal/micro-1",
        content_hash="micro-hash",
        cleaned_content="Short snippet.",
        is_summarizable=False,
        published_at=datetime.now(timezone.utc),
    )
    db_session.add(article)
    await db_session.commit()

    resp = await client.get(f"/api/v1/articles/{art_id}/summary")
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "NOT_SUMMARIZABLE"


@pytest.mark.asyncio
async def test_summary_not_found(client: AsyncClient):
    """Verifies that non-existent article returns 404."""
    random_id = uuid.uuid4()
    resp = await client.get(f"/api/v1/articles/{random_id}/summary")
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "NOT_FOUND"


@pytest.mark.asyncio
async def test_summary_rate_limiting(client: AsyncClient, db_session: AsyncSession, monkeypatch):
    """Verifies that exceeding the rate limit returns HTTP 429."""
    source = Source(
        id=uuid.uuid4(),
        name="RateLimitNews",
        feed_url="https://ratelimit.internal/feed",
        is_active=True,
    )
    db_session.add(source)
    await db_session.flush()

    art_id = uuid.uuid4()
    article = Article(
        id=art_id,
        source_id=source.id,
        title="Testing Rate Limiter Behavior",
        canonical_url="https://ratelimit.internal/article-1",
        content_hash="rate-limit-hash-01",
        cleaned_content="Valid long content for testing rate limits on the summary endpoint.",
        is_summarizable=True,
        published_at=datetime.now(timezone.utc),
    )
    db_session.add(article)
    await db_session.commit()

    monkeypatch.setattr(
        "app.services.summarizer.call_gemini_api",
        lambda prompt: ["Bullet 1", "Bullet 2", "Bullet 3"],
    )

    # Issue 16 requests (limit is 15/minute)
    statuses = []
    for _ in range(16):
        res = await client.get(f"/api/v1/articles/{art_id}/summary")
        statuses.append(res.status_code)

    # At least one request should be rate-limited (429)
    assert 429 in statuses
