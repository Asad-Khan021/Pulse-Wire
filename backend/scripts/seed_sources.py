import asyncio
import uuid
import logging
from datetime import datetime, timezone
from sqlalchemy import select
from app.db.session import async_session_factory
from app.db.models import Source

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("digest.seed")

INITIAL_SOURCES = [
    {
        "name": "TechCrunch",
        "feed_url": "https://techcrunch.com/feed/",
        "homepage_url": "https://techcrunch.com",
        "category_tags": ["AI", "Startups", "Venture", "Mobile"],
        "is_active": True,
    },
    {
        "name": "Ars Technica",
        "feed_url": "https://feeds.arstechnica.com/arstechnica/index",
        "homepage_url": "https://arstechnica.com",
        "category_tags": ["Technology", "Science", "Security", "OS"],
        "is_active": True,
    },
    {
        "name": "BleepingComputer",
        "feed_url": "https://www.bleepingcomputer.com/feed/",
        "homepage_url": "https://www.bleepingcomputer.com",
        "category_tags": ["Cybersecurity", "ZeroDay", "Malware", "Privacy"],
        "is_active": True,
    },
    {
        "name": "The Verge",
        "feed_url": "https://www.theverge.com/rss/index.xml",
        "homepage_url": "https://www.theverge.com",
        "category_tags": ["Tech", "AI", "Gadgets"],
        "is_active": True,
    },
    {
        "name": "InfoQ",
        "feed_url": "https://feed.infoq.com/",
        "homepage_url": "https://www.infoq.com",
        "category_tags": ["DevOps", "Architecture", "Cloud", "Backend"],
        "is_active": True,
    },
    {
        "name": "Hacker News Frontpage",
        "feed_url": "https://news.ycombinator.com/rss",
        "homepage_url": "https://news.ycombinator.com",
        "category_tags": ["AI", "Engineering", "HackerNews", "ShowHN"],
        "is_active": True,
    },
]


async def seed_sources():
    """Seeds initial curated RSS tech sources if they do not already exist."""
    async with async_session_factory() as session:
        logger.info("Checking initial RSS sources...")
        added_count = 0
        for src_data in INITIAL_SOURCES:
            stmt = select(Source).where(Source.feed_url == src_data["feed_url"])
            result = await session.execute(stmt)
            existing = result.scalar_one_or_none()

            if not existing:
                source = Source(
                    id=uuid.uuid4(),
                    name=src_data["name"],
                    feed_url=src_data["feed_url"],
                    homepage_url=src_data["homepage_url"],
                    category_tags=src_data["category_tags"],
                    is_active=src_data["is_active"],
                    failure_count=0,
                    created_at=datetime.now(timezone.utc),
                )
                session.add(source)
                added_count += 1
                logger.info(f"Added source: {src_data['name']}")
            else:
                logger.info(f"Source already exists: {src_data['name']}")

        await session.commit()
        logger.info(f"Seeding completed. {added_count} new sources added.")


if __name__ == "__main__":
    asyncio.run(seed_sources())
