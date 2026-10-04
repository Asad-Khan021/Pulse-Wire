import logging
import re
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Optional
import feedparser
import httpx

from app.config import settings

logger = logging.getLogger(__name__)

USER_AGENT = "DigestTechNewsBot/1.0 (+https://digest.internal/bot; contact@digest.internal)"

# ---------------------------------------------------------------------------
# Keyword Categorization Engine
# ---------------------------------------------------------------------------

# Machine Learning specific terms
ML_KEYWORDS = re.compile(
    r"\b(machine learning|deep learning|neural|neural network|transformer|pytorch|tensorflow|"
    r"scikit-learn|training data|model weights|reinforcement learning|fine-tuning|backpropagation)\b",
    re.IGNORECASE,
)

# Artificial Intelligence / LLM / GenAI terms
AI_KEYWORDS = re.compile(
    r"\b(ai|artificial intelligence|llm|chatgpt|openai|anthropic|claude|gemini|generative ai|"
    r"copilot|diffusion|multimodal|agentic|prompt engineering|autonomous agent)\b",
    re.IGNORECASE,
)

# Cybersecurity & InfoSec terms
CYBER_KEYWORDS = re.compile(
    r"\b(cybersecurity|hack|breach|malware|vulnerability|ransomware|security|exploit|"
    r"phishing|zero-day|ddos|infosec|credential|threat actor|backdoor)\b",
    re.IGNORECASE,
)

# Cloud & DevOps infrastructure terms
CLOUD_KEYWORDS = re.compile(
    r"\b(cloud|aws|azure|gcp|kubernetes|docker|devops|serverless|microservice|ci/cd|infrastructure|terraform)\b",
    re.IGNORECASE,
)

# Semiconductors & Hardware terms
HARDWARE_KEYWORDS = re.compile(
    r"\b(hardware|chip|semiconductor|nvidia|gpu|intel|amd|processor|arm|quantum computing|tpu|circuit)\b",
    re.IGNORECASE,
)

# Startups & Venture terms
STARTUP_KEYWORDS = re.compile(
    r"\b(startup|funding|venture capital|series a|series b|series c|ipo|valuation|y combinator|seed round)\b",
    re.IGNORECASE,
)


def assign_categories(title: str, description: str = "", content: str = "") -> List[str]:
    """
    Analyzes title, description, and content to automatically route articles to relevant sections:
    - Places Machine Learning news in the 'Machine Learning' section.
    - Places AI news in the 'AI' section.
    - Places Cybersecurity news in the 'Cybersecurity' section.
    - Handles Cloud, Hardware, Startups, and General Tech.
    """
    text = f"{title} {description} {content}".lower()
    categories: List[str] = []

    # Dedicated check for Machine Learning
    if ML_KEYWORDS.search(text):
        categories.append("Machine Learning")

    # Check for AI (Machine Learning articles also cross-route to AI)
    if AI_KEYWORDS.search(text) or "Machine Learning" in categories:
        if "AI" not in categories:
            categories.append("AI")

    # Check for Cybersecurity
    if CYBER_KEYWORDS.search(text):
        categories.append("Cybersecurity")

    # Check for Cloud & Infrastructure
    if CLOUD_KEYWORDS.search(text):
        categories.append("Cloud")

    # Check for Hardware & Silicon
    if HARDWARE_KEYWORDS.search(text):
        categories.append("Hardware")

    # Check for Startups & Venture
    if STARTUP_KEYWORDS.search(text):
        categories.append("Startups")

    if not categories:
        categories.append("General Tech")

    return categories


def assign_category(title: str, description: str = "") -> str:
    """
    Returns the primary single category string for backward compatibility with basic single-tag clients.
    """
    categories = assign_categories(title, description)
    return categories[0] if categories else "General Tech"


# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------

@dataclass
class RawFeedItem:
    """Normalized article metadata parsed from RSS/Atom entry or NewsAPI."""
    title: str
    link: str
    published_at: datetime
    raw_content: str
    author: Optional[str] = None
    tags: List[str] = field(default_factory=list)
    image_url: Optional[str] = None
    source_name: Optional[str] = None


class FeedFetchError(Exception):
    """Raised when an RSS or NewsAPI feed cannot be retrieved or parsed."""
    pass


# ---------------------------------------------------------------------------
# RSS / Atom Ingestion
# ---------------------------------------------------------------------------

async def fetch_feed_xml(url: str, timeout: float = 12.0, max_retries: int = 2) -> str:
    """
    Fetches XML/Atom/JSON feed payload over HTTP with backoff retry.
    """
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.8",
    }

    last_error: Optional[Exception] = None
    for attempt in range(max_retries + 1):
        try:
            async with httpx.AsyncClient(headers=headers, timeout=timeout, follow_redirects=True) as client:
                response = await client.get(url)
                response.raise_for_status()
                return response.text
        except (httpx.HTTPStatusError, httpx.RequestError, httpx.TimeoutException) as exc:
            last_error = exc
            logger.warning(
                f"Attempt {attempt + 1}/{max_retries + 1} failed for feed {url}: {exc}"
            )
            if attempt < max_retries:
                time.sleep(0.5 * (attempt + 1))

    raise FeedFetchError(f"Failed to fetch feed {url} after {max_retries + 1} attempts: {last_error}")


def parse_feed_entries(feed_xml: str) -> List[RawFeedItem]:
    """
    Parses RSS/Atom XML string into a list of normalized RawFeedItem instances.
    Automatically assigns smart category tags if none were supplied by the source.
    """
    parsed = feedparser.parse(feed_xml)
    if parsed.bozo and not parsed.entries:
        logger.error(f"Feedparser parsing error: {parsed.bozo_exception}")
        raise FeedFetchError(f"Malformed feed content: {parsed.bozo_exception}")

    items: List[RawFeedItem] = []
    now = datetime.now(timezone.utc)

    for entry in parsed.entries:
        link = entry.get("link", "").strip()
        title = entry.get("title", "").strip()
        if not link or not title:
            continue

        # Extract publication timestamp
        pub_dt = now
        time_struct = entry.get("published_parsed") or entry.get("updated_parsed")
        if time_struct:
            try:
                pub_dt = datetime(*time_struct[:6], tzinfo=timezone.utc)
            except Exception:
                pub_dt = now

        # Extract body content / summary
        content = ""
        if "content" in entry and entry["content"]:
            content = entry["content"][0].get("value", "")
        if not content:
            content = entry.get("summary", "")

        # Extract source-provided tags
        tags: List[str] = []
        if "tags" in entry and entry["tags"]:
            for t in entry["tags"]:
                term = t.get("term")
                if term and isinstance(term, str):
                    clean_tag = term.strip().title()
                    if clean_tag and clean_tag not in tags:
                        tags.append(clean_tag)

        # Merge with automated categorization
        auto_cats = assign_categories(title, content)
        for cat in auto_cats:
            if cat not in tags:
                tags.append(cat)

        # Extract image URL if available
        image_url = None
        if "media_content" in entry and entry["media_content"]:
            media = entry["media_content"][0]
            if isinstance(media, dict) and "url" in media:
                image_url = media["url"]
        elif "enclosures" in entry and entry["enclosures"]:
            enc = entry["enclosures"][0]
            if isinstance(enc, dict) and enc.get("type", "").startswith("image/"):
                image_url = enc.get("href") or enc.get("url")

        author = entry.get("author")

        items.append(
            RawFeedItem(
                title=title,
                link=link,
                published_at=pub_dt,
                raw_content=content,
                author=author,
                tags=tags,
                image_url=image_url,
            )
        )

    return items


# ---------------------------------------------------------------------------
# NewsAPI Integration & Full Article Scraper
# ---------------------------------------------------------------------------

async def fetch_full_article_content(url: str, timeout: float = 8.0) -> Optional[str]:
    """
    Fetches the full article content from the source URL over HTTP with browser headers,
    strips ads and navigation boilerplate, and returns clean, detailed readable article paragraphs.
    """
    if not url or not url.strip().startswith("http"):
        return None

    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }

    try:
        async with httpx.AsyncClient(headers=headers, timeout=timeout, follow_redirects=True) as client:
            response = await client.get(url)
            if response.status_code == 200 and response.text:
                from app.services.html_cleaner import clean_article_html
                cleaned_text, word_count = clean_article_html(response.text)
                if cleaned_text and word_count >= 20:
                    return cleaned_text
    except Exception as exc:
        logger.debug(f"Could not fetch full article content from {url}: {exc}")

    return None


async def fetch_tech_news_feed(
    api_key: Optional[str] = None,
    page_size: int = 20,
    timeout: float = 12.0,
    fetch_full_content: bool = False,
) -> dict:
    """
    Fetches real-time technology headlines from NewsAPI.org:
    https://newsapi.org/v2/top-headlines?category=technology&language=en&pageSize=20&apiKey=...

    Automatically categorizes articles into AI, Machine Learning, Cybersecurity, Cloud, etc.,
    and optionally fetches the full article content from the source URL.
    """
    key = api_key or settings.NEWS_API_KEY
    url = f"https://newsapi.org/v2/top-headlines?category=technology&language=en&pageSize={page_size}&apiKey={key}"

    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }

    try:
        async with httpx.AsyncClient(headers=headers, timeout=timeout, follow_redirects=True) as client:
            response = await client.get(url)
            data = response.json()

        if data.get("status") != "ok":
            error_msg = data.get("message", "Failed to fetch news from NewsAPI")
            logger.error(f"NewsAPI error response: {error_msg}")
            return {"status": "error", "message": error_msg}

        articles = data.get("articles", [])
        structured_feed: List[dict] = []
        now_ms = int(time.time() * 1000)

        for index, article in enumerate(articles):
            title = article.get("title") or ""
            # Filter out removed/invalid articles
            if not title or title.strip() == "[Removed]":
                continue

            description = article.get("description") or ""
            content = article.get("content") or ""
            categories = assign_categories(title, description, content)
            primary_category = categories[0] if categories else "General Tech"

            source_name = "NewsAPI"
            if isinstance(article.get("source"), dict) and article["source"].get("name"):
                source_name = article["source"]["name"]

            pub_dt_str = article.get("publishedAt")
            pub_dt = datetime.now(timezone.utc)
            if pub_dt_str:
                try:
                    pub_dt = datetime.fromisoformat(pub_dt_str.replace("Z", "+00:00"))
                except Exception:
                    pub_dt = datetime.now(timezone.utc)

            structured_feed.append({
                "id": f"tech-news-{now_ms}-{index}",
                "title": title,
                "summary": description if description else "No description available.",
                "content": content if content else description,
                "category": primary_category,
                "categories": categories,
                "source": source_name,
                "url": article.get("url") or "",
                "imageUrl": article.get("urlToImage"),
                "publishedAt": pub_dt.isoformat(),
            })

        if fetch_full_content:
            import asyncio

            async def _enrich_item(item: dict):
                art_url = item.get("url")
                if art_url:
                    full_text = await fetch_full_article_content(art_url, timeout=timeout)
                    if full_text:
                        item["content"] = full_text
                        item["full_content"] = full_text

            await asyncio.gather(*[_enrich_item(item) for item in structured_feed], return_exceptions=True)

        return {
            "status": "success",
            "totalResults": len(structured_feed),
            "articles": structured_feed,
        }

    except Exception as exc:
        logger.error(f"Error fetching NewsAPI feed: {exc}", exc_info=True)
        return {"status": "error", "message": str(exc)}


async def fetch_newsapi_raw_items(
    api_key: Optional[str] = None,
    page_size: int = 20,
    fetch_full_content: bool = True,
) -> List[RawFeedItem]:
    """
    Fetches NewsAPI articles and transforms them into normalized RawFeedItem instances
    for seamless database ingestion and deduplication, fetching the full article content
    from each source URL when available.
    """
    feed = await fetch_tech_news_feed(api_key=api_key, page_size=page_size, fetch_full_content=fetch_full_content)
    if feed.get("status") != "success":
        return []

    items: List[RawFeedItem] = []
    for art in feed.get("articles", []):
        url = art.get("url")
        if not url:
            continue

        try:
            pub_dt = datetime.fromisoformat(art["publishedAt"])
        except Exception:
            pub_dt = datetime.now(timezone.utc)

        # Prioritize full content fetched from the source URL over the brief summary
        raw_text = art.get("full_content") or art.get("content") or art.get("summary") or art["title"]

        items.append(
            RawFeedItem(
                title=art["title"],
                link=url,
                published_at=pub_dt,
                raw_content=raw_text,
                author=art.get("source"),
                tags=art.get("categories", ["General Tech"]),
                image_url=art.get("imageUrl"),
                source_name=art.get("source"),
            )
        )

    return items
