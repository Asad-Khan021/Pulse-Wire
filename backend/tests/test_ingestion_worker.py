import uuid
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models import Source, Article
from app.workers.ingestion import ingest_source
from app.services.feed_fetcher import RawFeedItem
from datetime import datetime, timezone


@pytest.mark.asyncio
async def test_ingest_source_deduplication(db_session: AsyncSession, monkeypatch):
    """Verifies that duplicate entries are ignored during ingestion."""
    source = Source(
        id=uuid.uuid4(),
        name="Ars Technica",
        feed_url="https://feeds.arstechnica.com/arstechnica/index",
        category_tags=["Tech"],
        is_active=True,
    )
    db_session.add(source)
    await db_session.commit()

    # Mock fetch and parse to return 2 items
    now = datetime.now(timezone.utc)
    mock_items = [
        RawFeedItem(
            title="Next-Gen Solid State Batteries Enter Production",
            link="https://arstechnica.com/science/2026/09/solid-state/?utm_source=rss",
            published_at=now,
            raw_content="<p>" + ("Solid state electrolyte technology represents a massive leap forward. " * 15) + "</p>",
            tags=["Batteries", "Energy"],
        ),
        RawFeedItem(
            title="Brief: Server Incident Resolved",
            link="https://arstechnica.com/brief-incident",
            published_at=now,
            raw_content="<p>Brief incident fixed.</p>",  # short -> is_summarizable=False
            tags=["Operations"],
        ),
    ]

    monkeypatch.setattr("app.workers.ingestion.fetch_feed_xml", lambda url: "mock-xml")
    monkeypatch.setattr("app.workers.ingestion.parse_feed_entries", lambda xml: mock_items)

    # First pass: should insert 2 articles
    inserted_first = await ingest_source(source, db_session)
    assert inserted_first == 2
    await db_session.flush()

    # Verify attributes of inserted articles
    art_res = await db_session.execute(select(Article).where(Article.source_id == source.id))
    articles = art_res.scalars().all()
    assert len(articles) == 2

    long_art = next(a for a in articles if "Solid State" in a.title)
    short_art = next(a for a in articles if "Brief" in a.title)

    # Canonical URL normalized (utm stripped)
    assert long_art.canonical_url == "https://arstechnica.com/science/2026/09/solid-state"
    assert long_art.is_summarizable is True
    assert short_art.is_summarizable is False

    # Second pass: duplicate articles must be skipped
    inserted_second = await ingest_source(source, db_session)
    assert inserted_second == 0

    art_res_after = await db_session.execute(select(Article).where(Article.source_id == source.id))
    assert len(art_res_after.scalars().all()) == 2
