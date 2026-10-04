import hashlib
import re
from typing import Tuple, Set
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode
from bs4 import BeautifulSoup

# Tracking and analytics query parameters to strip
TRACKING_PARAMS: Set[str] = {
    "fbclid",
    "gclid",
    "dclid",
    "gbraid",
    "wbraid",
    "msclkid",
    "ref",
    "ref_src",
    "source",
    "mc_cid",
    "mc_eid",
    "_hsenc",
    "_hsmi",
    "igshid",
}

# Tags to completely remove from article bodies
TAGS_TO_REMOVE = {
    "script",
    "style",
    "nav",
    "footer",
    "header",
    "aside",
    "form",
    "iframe",
    "noscript",
    "svg",
    "button",
    "figcaption",
    "advertisement",
    "banner",
}


def normalize_canonical_url(raw_url: str) -> str:
    """
    Normalizes a canonical article URL:
    - Normalizes scheme and domain to lowercase.
    - Strips fragment identifiers (#...).
    - Strips marketing/tracking query parameters (utm_*, fbclid, gclid, etc.).
    - Normalizes path slashes and sorts remaining query parameters.
    """
    if not raw_url or not raw_url.strip():
        return ""

    parsed = urlsplit(raw_url.strip())
    scheme = (parsed.scheme or "https").lower()
    netloc = parsed.netloc.lower()

    # Normalize path: strip trailing slash unless path is empty or root
    path = parsed.path
    if path != "/" and path.endswith("/"):
        path = path.rstrip("/")

    # Filter out tracking query parameters
    filtered_query_params = []
    if parsed.query:
        for key, value in parse_qsl(parsed.query, keep_blank_values=False):
            key_lower = key.lower()
            if key_lower.startswith("utm_") or key_lower in TRACKING_PARAMS:
                continue
            filtered_query_params.append((key, value))

    # Deterministically sort query params
    filtered_query_params.sort(key=lambda x: x[0])
    query_string = urlencode(filtered_query_params)

    # Fragment is intentionally omitted
    return urlunsplit((scheme, netloc, path, query_string, ""))


def extract_article_content(raw_html: str) -> Tuple[str, int]:
    """
    Intelligently extracts the full detailed article text from a complete webpage HTML,
    prioritizing standard article containers (<article>, <main>, .article-body, etc.)
    and stripping navigation, scripts, ads, and boilerplate.
    Returns:
        tuple of (cleaned_text_content, word_count)
    """
    if not raw_html or not raw_html.strip():
        return "", 0

    soup = BeautifulSoup(raw_html, "html.parser")

    # Remove non-content tags
    for tag in soup.find_all(TAGS_TO_REMOVE):
        tag.decompose()

    # Search for high-probability article containers to omit sidebar/footer noise
    article_container = (
        soup.find("article")
        or soup.find("main")
        or soup.find(attrs={"itemprop": "articleBody"})
        or soup.find("div", class_=re.compile(r"(article[-_]?body|post[-_]?content|entry[-_]?content|story[-_]?body|body[-_]?content)", re.I))
    )

    target_node = article_container if article_container else soup

    paragraphs = []
    for element in target_node.find_all(["p", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote"]):
        text = element.get_text(separator=" ", strip=True)
        if text and len(text) > 15:  # Filter out tiny icon labels / copyright lines
            paragraphs.append(text)

    # If container had very few paragraphs, fallback to full document search
    if len(paragraphs) < 2 and target_node is not soup:
        paragraphs = []
        for element in soup.find_all(["p", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote"]):
            text = element.get_text(separator=" ", strip=True)
            if text and len(text) > 15:
                paragraphs.append(text)

    if not paragraphs:
        cleaned_text = soup.get_text(separator=" ", strip=True)
    else:
        cleaned_text = "\n\n".join(paragraphs)

    # Collapse excessive internal whitespace
    cleaned_text = re.sub(r"[ \t]+", " ", cleaned_text)
    cleaned_text = re.sub(r"\n{3,}", "\n\n", cleaned_text).strip()

    words = cleaned_text.split()
    word_count = len(words)
    return cleaned_text, word_count


def clean_article_html(raw_html: str) -> Tuple[str, int]:
    """
    Strips boilerplate, navigation, scripts, ads, and formatting noise from HTML content.
    Returns:
        tuple of (cleaned_text_content, word_count)
    """
    return extract_article_content(raw_html)


def compute_content_hash(text: str) -> str:
    """Calculates deterministic SHA-256 hash over normalized text content."""
    normalized = " ".join(text.strip().split())
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def is_article_summarizable(word_count: int, min_words: int = 80) -> bool:
    """Validates whether article meets the minimum word threshold for AI summarization."""
    return word_count >= min_words
