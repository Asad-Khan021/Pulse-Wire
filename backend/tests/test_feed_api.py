import uuid
from datetime import datetime, timezone, timedelta
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models import Source, Article, Signal


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    """Verifies that the /api/v1/health endpoint responds with status and version."""
    response = await client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["database"] is True
    assert "version" in data


@pytest.mark.asyncio
async def test_feed_empty(client: AsyncClient):
    """Verifies that empty feed returns 200 with empty items list."""
    response = await client.get("/api/v1/feed")
    assert response.status_code == 200
    data = response.json()
    assert data["items"] == []
    assert data["total_returned"] == 0
    assert data["next_cursor"] is None


@pytest.mark.asyncio
async def test_feed_pagination_and_detail(client: AsyncClient, db_session: AsyncSession):
    """Verifies feed listing, tag filtering, cursor pagination, and detail retrieval."""
    # 1. Create a Source
    source = Source(
        id=uuid.uuid4(),
        name="TechCrunch",
        feed_url="https://techcrunch.com/feed/",
        homepage_url="https://techcrunch.com",
        category_tags=["AI", "Startups"],
        is_active=True,
    )
    db_session.add(source)
    await db_session.flush()

    # 2. Create 3 articles with staggered published_at timestamps
    now = datetime.now(timezone.utc)
    art1 = Article(
        id=uuid.uuid4(),
        source_id=source.id,
        title="Gemini 2.0 Launches",
        canonical_url="https://techcrunch.com/article-1",
        content_hash="hash1",
        cleaned_content="Detailed cleaned body of article 1.",
        tags=["AI", "Google"],
        published_at=now,
    )
    art2 = Article(
        id=uuid.uuid4(),
        source_id=source.id,
        title="Zero-Day Vulnerability Found",
        canonical_url="https://techcrunch.com/article-2",
        content_hash="hash2",
        cleaned_content="Detailed cleaned body of article 2.",
        tags=["Security"],
        published_at=now - timedelta(hours=1),
    )
    art3 = Article(
        id=uuid.uuid4(),
        source_id=source.id,
        title="New Cloud Architecture",
        canonical_url="https://techcrunch.com/article-3",
        content_hash="hash3",
        cleaned_content="Detailed cleaned body of article 3.",
        tags=["DevOps", "Cloud"],
        published_at=now - timedelta(hours=2),
    )
    db_session.add_all([art1, art2, art3])

    # Add signal for art1
    sig1 = Signal(
        article_id=art1.id,
        hn_points=350,
        hn_comment_count=120,
        hn_discussion_url="https://news.ycombinator.com/item?id=123",
    )
    db_session.add(sig1)
    await db_session.commit()

    # 3. Test GET /api/v1/feed with limit=2 (tests pagination cursor)
    res_page1 = await client.get("/api/v1/feed?limit=2")
    assert res_page1.status_code == 200
    p1_data = res_page1.json()
    assert len(p1_data["items"]) == 2
    assert p1_data["items"][0]["title"] == "Gemini 2.0 Launches"
    assert p1_data["items"][0]["hn_points"] == 350
    assert p1_data["next_cursor"] is not None

    # Fetch page 2 using cursor
    cursor = p1_data["next_cursor"]
    res_page2 = await client.get(f"/api/v1/feed?limit=2&cursor={cursor}")
    assert res_page2.status_code == 200
    p2_data = res_page2.json()
    assert len(p2_data["items"]) == 1
    assert p2_data["items"][0]["title"] == "New Cloud Architecture"
    assert p2_data["next_cursor"] is None

    # 4. Test Tag Filtering (only "Security")
    res_tag = await client.get("/api/v1/feed?tags=Security")
    assert res_tag.status_code == 200
    tag_data = res_tag.json()
    assert len(tag_data["items"]) == 1
    assert tag_data["items"][0]["title"] == "Zero-Day Vulnerability Found"

    # 5. Test Article Detail GET /api/v1/articles/{id}
    res_detail = await client.get(f"/api/v1/articles/{art1.id}")
    assert res_detail.status_code == 200
    detail_data = res_detail.json()
    assert detail_data["id"] == str(art1.id)
    assert detail_data["title"] == "Gemini 2.0 Launches"
    assert detail_data["cleaned_content"] == "Detailed cleaned body of article 1."
    assert detail_data["source"]["name"] == "TechCrunch"

    # 6. Test 404 for unknown article id
    unknown_id = uuid.uuid4()
    res_404 = await client.get(f"/api/v1/articles/{unknown_id}")
    assert res_404.status_code == 404
    err_data = res_404.json()
    assert err_data["error"]["code"] == "NOT_FOUND"
