import pytest
from app.services.feed_fetcher import parse_feed_entries, RawFeedItem

SAMPLE_RSS_XML = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
    <channel>
        <title>Tech Insights Feed</title>
        <link>https://techinsights.internal</link>
        <description>Cutting edge technology updates</description>
        <item>
            <title>Rust 2.0 Compiler Performance Breakthrough</title>
            <link>https://techinsights.internal/rust-2-release</link>
            <description>&lt;p&gt;The Rust compiler team announced today that parallel codegen is now enabled by default.&lt;/p&gt;</description>
            <pubDate>Mon, 15 Sep 2026 12:00:00 GMT</pubDate>
            <category>Rust</category>
            <category>Systems</category>
            <author>Jane Doe</author>
        </item>
        <item>
            <title>Distributed Database Consensus Re-imagined</title>
            <link>https://techinsights.internal/consensus-raft</link>
            <description>&lt;p&gt;A new paper introduces an adaptive consensus algorithm.&lt;/p&gt;</description>
            <pubDate>Sun, 14 Sep 2026 09:30:00 GMT</pubDate>
            <category>Databases</category>
        </item>
    </channel>
</rss>
"""


def test_parse_feed_entries_valid_rss():
    items = parse_feed_entries(SAMPLE_RSS_XML)
    assert len(items) == 2

    first = items[0]
    assert first.title == "Rust 2.0 Compiler Performance Breakthrough"
    assert first.link == "https://techinsights.internal/rust-2-release"
    assert "parallel codegen" in first.raw_content
    assert "Rust" in first.tags
    assert "Systems" in first.tags
    assert first.author == "Jane Doe"
    assert first.published_at is not None

    second = items[1]
    assert second.title == "Distributed Database Consensus Re-imagined"
    assert "Databases" in second.tags


def test_parse_feed_entries_empty_feed():
    empty_rss = """<?xml version="1.0"?><rss version="2.0"><channel><title>Empty</title></channel></rss>"""
    items = parse_feed_entries(empty_rss)
    assert items == []


@pytest.mark.asyncio
async def test_fetch_full_article_content_success():
    from unittest.mock import AsyncMock, MagicMock, patch
    from app.services.feed_fetcher import fetch_full_article_content

    html_page = """
    <!DOCTYPE html>
    <html>
    <head><title>Quantum Computing</title></head>
    <body>
        <nav><a href="/">Home</a></nav>
        <article class="article-body">
            <h2>Breakthrough in Quantum Teleportation</h2>
            <p>Researchers at the global quantum institute have successfully achieved fault-tolerant quantum teleportation across a metropolitan fiber network.</p>
            <p>The demonstration paves the way for scalable quantum internet architecture and ultra-secure communication channels across long geographical distances.</p>
        </article>
        <footer>Copyright 2026</footer>
    </body>
    </html>
    """

    mock_client = AsyncMock()
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.text = html_page
    mock_client.get.return_value = mock_resp
    mock_client.__aenter__.return_value = mock_client
    mock_client.__aexit__.return_value = None

    with patch("httpx.AsyncClient", return_value=mock_client):
        content = await fetch_full_article_content("https://news.example.com/quantum")

    assert content is not None
    assert "Breakthrough in Quantum Teleportation" in content
    assert "metropolitan fiber network" in content
    assert "Copyright" not in content
    assert len(content.split()) > 20


@pytest.mark.asyncio
async def test_fetch_full_article_content_invalid_url():
    from app.services.feed_fetcher import fetch_full_article_content
    assert await fetch_full_article_content("") is None
    assert await fetch_full_article_content("invalid-url") is None
