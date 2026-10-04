import uuid
from app.services.cache_keys import (
    feed_cache_key,
    summary_cache_key,
    signals_cache_key,
    rate_limit_cache_key,
)


def test_feed_cache_key_determinism():
    """Verifies that feed cache keys are deterministic regardless of tag/domain order."""
    key1 = feed_cache_key(limit=20, tags=["AI", "Security"], exclude_domains=["spam.com", "ad.net"])
    key2 = feed_cache_key(limit=20, tags=["security", "ai"], exclude_domains=["ad.net", "spam.com"])

    assert key1 == key2
    assert key1.startswith("feed:v1:")


def test_feed_cache_key_differentiation():
    """Verifies that different query parameters generate distinct keys."""
    key_head = feed_cache_key(cursor=None, limit=20)
    key_page2 = feed_cache_key(cursor="abc123cursor", limit=20)
    key_tags = feed_cache_key(cursor=None, limit=20, tags=["DevOps"])

    assert key_head != key_page2
    assert key_head != key_tags


def test_summary_cache_key_format():
    """Verifies summary cache key formatting matches TAD specification."""
    test_id = uuid.uuid4()
    key = summary_cache_key(test_id, "core_summary")
    assert key == f"summary:{test_id}:core_summary"


def test_signals_cache_key_format():
    """Verifies community signals cache key formatting."""
    test_id = uuid.uuid4()
    key = signals_cache_key(test_id)
    assert key == f"signal:{test_id}"


def test_rate_limit_cache_key():
    """Verifies rate limit key generator."""
    key = rate_limit_cache_key("user_123", "summary")
    assert key == "ratelimit:user_123:summary"
