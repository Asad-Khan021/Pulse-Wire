import os
import uuid
from datetime import datetime, timezone, timedelta
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from jose import jwt
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

# Override settings for testing before loading app modules
os.environ["ENVIRONMENT"] = "testing"
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
os.environ["REDIS_CACHE_ENABLED"] = "False"
os.environ["SUPABASE_JWT_SECRET"] = "test-secret-key-that-is-at-least-32-characters-long"
os.environ["SUPABASE_JWT_ALGORITHM"] = "HS256"
os.environ["SUPABASE_JWT_AUDIENCE"] = "authenticated"

from app.config import settings
from app.db.base import Base
from app.db.models import Source, Article, Signal
from app.dependencies import get_db, get_cache
from app.services.cache_service import RedisCacheService
from app.main import app

# In-memory SQLite async engine
test_engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
TestingSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class MockCacheService(RedisCacheService):
    """In-memory dictionary cache for test isolation."""

    def __init__(self):
        super().__init__("redis://mock:6379")
        self._storage = {}

    async def initialize(self) -> None:
        pass

    async def close(self) -> None:
        self._storage.clear()

    async def is_healthy(self) -> bool:
        return True

    async def get(self, key: str):
        return self._storage.get(key)

    async def set(self, key: str, value: str, *args, **kwargs) -> bool:
        self._storage[key] = value
        return True

    async def delete(self, key: str) -> bool:
        self._storage.pop(key, None)
        return True


mock_cache = MockCacheService()


@pytest_asyncio.fixture(scope="session", autouse=True)
async def setup_test_db():
    """Initializes tables in the in-memory SQLite database."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provides an isolated database session per test with automatic rollback."""
    async with TestingSessionLocal() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """HTTP async test client with overridden dependencies."""

    async def override_get_db():
        yield db_session

    def override_get_cache():
        return mock_cache

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_cache] = override_get_cache

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest.fixture
def create_test_jwt():
    """Helper fixture to mint Supabase-like test JWT tokens."""
    def _generator(
        user_id: Optional[str] = None,
        email: str = "testuser@example.com",
        role: str = "authenticated",
        expires_delta: Optional[timedelta] = None,
    ) -> str:
        uid = user_id or str(uuid.uuid4())
        delta = expires_delta or timedelta(hours=1)
        now = datetime.now(timezone.utc)
        claims = {
            "sub": uid,
            "email": email,
            "role": role,
            "aud": settings.SUPABASE_JWT_AUDIENCE,
            "iat": int(now.timestamp()),
            "exp": int((now + delta).timestamp()),
        }
        return jwt.encode(
            claims,
            key=settings.SUPABASE_JWT_SECRET,
            algorithm=settings.SUPABASE_JWT_ALGORITHM,
        )

    return _generator
