from functools import lru_cache
from typing import List
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Centralized application configuration loaded from environment variables and .env file.
    Security Notice:
    Secrets (DB passwords, JWT secret, Gemini key) are only read here and must never
    be sent to client applications or logged in plain text.
    """
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Core App
    ENVIRONMENT: str = "development"
    APP_NAME: str = "Pulse Wire API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Database (PostgreSQL with asyncpg)
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/digest_db",
        description="Async PostgreSQL connection URI",
    )
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 20
    DATABASE_ECHO: bool = False

    # Redis Cache (Upstash / Local)
    REDIS_URL: str = Field(
        default="redis://localhost:6379/0",
        description="Redis connection URL (rediss:// for TLS)",
    )
    REDIS_CACHE_ENABLED: bool = True
    REDIS_TIMEOUT_SECONDS: float = 2.0

    # Supabase Authentication
    SUPABASE_URL: str = "https://your-project.supabase.co"
    SUPABASE_JWT_SECRET: str = "development-secret-jwt-key-replace-in-production-min-32-chars"
    SUPABASE_JWT_ALGORITHM: str = "HS256"
    SUPABASE_JWT_AUDIENCE: str = "authenticated"

    # Google Gemini API
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-1.5-flash"

    # Ingestion Pipeline
    INGESTION_INTERVAL_MINUTES: int = 20
    INGESTION_ENABLED: bool = True
    MIN_ARTICLE_WORD_COUNT: int = 80

    # NewsAPI Integration
    NEWS_API_KEY: str = Field(
        default="5a0882eac8064e06a7376d73e3d2fa73",
        description="NewsAPI.org API key for fetching tech headlines",
    )
    NEWS_API_ENABLED: bool = True

    # Cache TTLs & Rate Limits
    SUMMARY_CACHE_TTL_SECONDS: int = 86400  # 24 hours
    SIGNALS_CACHE_TTL_SECONDS: int = 1800   # 30 minutes
    RATE_LIMIT_SUMMARY: str = "15/minute"

    # Security & CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "https://digest-app.web.app",
    ]


@lru_cache()
def get_settings() -> Settings:
    """Returns cached application settings instance."""
    return Settings()


settings = get_settings()
