import hashlib
from typing import Optional, List
from uuid import UUID


def feed_cache_key(
    cursor: Optional[str] = None,
    limit: int = 20,
    tags: Optional[List[str]] = None,
    exclude_domains: Optional[List[str]] = None,
) -> str:
    """
    Generates a deterministic Redis cache key for paginated feed queries.
    Format: feed:v1:{query_hash}
    """
    sorted_tags = ",".join(sorted(t.strip().lower() for t in tags)) if tags else "all"
    sorted_domains = (
        ",".join(sorted(d.strip().lower() for d in exclude_domains))
        if exclude_domains
        else "none"
    )
    raw_signature = f"cur={cursor or 'head'}|lim={limit}|tags={sorted_tags}|exc={sorted_domains}"
    signature_hash = hashlib.sha256(raw_signature.encode("utf-8")).hexdigest()[:16]
    return f"feed:v1:{signature_hash}"


def summary_cache_key(article_id: UUID | str, question_type: str) -> str:
    """
    Generates a Redis cache key for an AI article summary.
    Format: summary:{article_id}:{question_type}
    """
    clean_type = question_type.strip().lower()
    return f"summary:{str(article_id)}:{clean_type}"


def signals_cache_key(article_id: UUID | str) -> str:
    """
    Generates a Redis cache key for community discussion signals.
    Format: signal:{article_id}
    """
    return f"signal:{str(article_id)}"


def rate_limit_cache_key(identifier: str, route_name: str) -> str:
    """
    Generates a Redis key for sliding window rate limiting.
    Format: ratelimit:{identifier}:{route_name}
    """
    clean_id = identifier.strip().lower()
    return f"ratelimit:{clean_id}:{route_name}"
