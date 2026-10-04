import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ArticleSourceInfo(BaseModel):
    id: uuid.UUID
    name: str
    feed_url: str
    homepage_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ArticleListItem(BaseModel):
    """Compact article card projection for feed list view."""
    id: uuid.UUID
    title: str
    source_name: str
    canonical_url: str
    image_url: Optional[str] = None
    author: Optional[str] = None
    tags: List[str] = Field(default_factory=list)
    is_summarizable: bool = True
    published_at: datetime
    hn_points: Optional[int] = None
    reddit_comments: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)


class ArticleDetail(BaseModel):
    """Complete article model returned for detail view."""
    id: uuid.UUID
    source: ArticleSourceInfo
    title: str
    canonical_url: str
    content_hash: str
    cleaned_content: Optional[str] = None
    image_url: Optional[str] = None
    author: Optional[str] = None
    tags: List[str] = Field(default_factory=list)
    is_summarizable: bool = True
    published_at: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class FeedResponse(BaseModel):
    """Paginated feed response containing articles and opaque next cursor."""
    items: List[ArticleListItem]
    next_cursor: Optional[str] = None
    total_returned: int

    model_config = ConfigDict(from_attributes=True)
