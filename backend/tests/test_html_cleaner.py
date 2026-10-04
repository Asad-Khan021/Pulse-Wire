import pytest
from app.services.html_cleaner import (
    normalize_canonical_url,
    clean_article_html,
    compute_content_hash,
    is_article_summarizable,
)


def test_normalize_canonical_url_strips_tracking():
    raw_url = "https://TechCrunch.COM/2026/09/15/gemini-launch/?utm_source=twitter&utm_medium=social&fbclid=xyz123&ref=rss&id=42#section-comments"
    clean_url = normalize_canonical_url(raw_url)
    assert clean_url == "https://techcrunch.com/2026/09/15/gemini-launch?id=42"


def test_normalize_canonical_url_preserves_root_and_plain():
    assert normalize_canonical_url("https://example.com/") == "https://example.com/"
    assert normalize_canonical_url("https://example.com/blog/") == "https://example.com/blog"
    assert normalize_canonical_url("") == ""


def test_clean_article_html_strips_boilerplate():
    raw_html = """
    <html>
        <head><script>alert('malicious')</script><style>.ad{color:red}</style></head>
        <body>
            <nav><a href="/">Home</a><a href="/news">News</a></nav>
            <header><h1>Welcome to Tech Blog</h1></header>
            <article>
                <h1>Major Breakthrough in Quantum Computing Announced</h1>
                <p>Researchers today announced a novel architecture for high-coherence topological qubits that operates at ambient temperature.</p>
                <div class="advertisement">Buy this product now!</div>
                <p>The team demonstrated fault-tolerant quantum error correction with a threshold reduction exceeding prior benchmarks by three orders of magnitude.</p>
            </article>
            <footer>Copyright 2026 All Rights Reserved.</footer>
        </body>
    </html>
    """
    cleaned_text, word_count = clean_article_html(raw_html)
    assert "alert" not in cleaned_text
    assert "color:red" not in cleaned_text
    assert "Copyright" not in cleaned_text
    assert "Major Breakthrough in Quantum Computing Announced" in cleaned_text
    assert "Researchers today announced a novel architecture" in cleaned_text
    assert word_count > 20


def test_compute_content_hash_deterministic():
    text1 = "This is a breaking news story about AI infrastructure."
    text2 = "  This   is a breaking news story    about AI infrastructure.  "
    hash1 = compute_content_hash(text1)
    hash2 = compute_content_hash(text2)
    assert hash1 == hash2
    assert len(hash1) == 64  # SHA-256 hex string


def test_is_article_summarizable():
    short_text = "Breaking: Cloud outage resolved."
    long_text = " ".join(["word"] * 100)

    assert is_article_summarizable(len(short_text.split()), min_words=80) is False
    assert is_article_summarizable(len(long_text.split()), min_words=80) is True
