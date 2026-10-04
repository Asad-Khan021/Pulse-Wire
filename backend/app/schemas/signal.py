import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class SignalResponse(BaseModel):
    """Community discussion metrics from Hacker News and Reddit."""
    article_id: uuid.UUID
    hn_points: Optional[int] = None
    hn_comment_count: Optional[int] = None
    hn_discussion_url: Optional[str] = None
    reddit_thread_url: Optional[str] = None
    reddit_comment_count: Optional[int] = None
    fetched_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
