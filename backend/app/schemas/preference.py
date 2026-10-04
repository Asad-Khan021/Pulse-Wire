from datetime import datetime
from typing import List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class UserPreferenceResponse(BaseModel):
    user_id: UUID
    followed_tags: List[str] = Field(default_factory=list)
    muted_domains: List[str] = Field(default_factory=list)
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserPreferenceUpdate(BaseModel):
    followed_tags: List[str] = Field(default_factory=list)
    muted_domains: List[str] = Field(default_factory=list)
