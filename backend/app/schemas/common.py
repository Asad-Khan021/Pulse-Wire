from typing import Optional
from pydantic import BaseModel, ConfigDict


class ErrorDetail(BaseModel):
    code: str
    message: str
    retry_after: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)


class ErrorEnvelope(BaseModel):
    error: ErrorDetail


class HealthCheckResponse(BaseModel):
    status: str
    database: bool
    redis: bool
    version: str
