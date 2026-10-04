import uuid
from enum import Enum
from datetime import datetime
from typing import List
from pydantic import BaseModel, ConfigDict, Field


class SummaryType(str, Enum):
    """The four deterministic, cost-bounded summary angles supported by Digest."""
    CORE = "core"
    SIMPLER = "simpler"
    SIGNIFICANCE = "significance"
    RISK = "risk"

    # Backward compatibility aliases
    CORE_SUMMARY = "core"
    EXPLAIN_SIMPLER = "simpler"
    WHY_IT_MATTERS = "significance"
    RISK_ANALYSIS = "risk"


class SummaryResponse(BaseModel):
    """Summary payload returned from 3-tier cache or generation."""
    article_id: uuid.UUID
    question_type: SummaryType
    content: List[str] = Field(description="Bullet points or concise explanation sentences")
    cached: bool = Field(description="True if served from Redis or PostgreSQL cache")
    model_used: str = Field(description="AI model version that produced summary")
    prompt_version: str
    generated_at: datetime

    model_config = ConfigDict(from_attributes=True)
