import uuid
from typing import List, Optional
from datetime import datetime
from sqlalchemy import (
    Column,
    String,
    Text,
    Boolean,
    Integer,
    DateTime,
    ForeignKey,
    UniqueConstraint,
    Index,
    JSON,
    CHAR,
    TypeDecorator,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, ARRAY as PG_ARRAY
from sqlalchemy.orm import relationship, Mapped, mapped_column
from app.db.base import Base


class GUID(TypeDecorator):
    """
    Platform-independent GUID type.
    Uses PostgreSQL's native UUID type, otherwise uses CHAR(36) on SQLite/other dialects.
    """
    impl = CHAR
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(PG_UUID(as_uuid=True))
        return dialect.type_descriptor(CHAR(36))

    def process_bind_param(self, value, dialect):
        if value is None:
            return value
        if dialect.name == "postgresql":
            return value
        if isinstance(value, uuid.UUID):
            return str(value)
        return str(uuid.UUID(str(value)))

    def process_result_value(self, value, dialect):
        if value is None:
            return value
        if isinstance(value, uuid.UUID):
            return value
        return uuid.UUID(str(value))


ARRAY_STRING = PG_ARRAY(String).with_variant(JSON, "sqlite")


class Source(Base):
    """
    RSS/Atom News Feed source configuration and health telemetry.
    """
    __tablename__ = "sources"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    feed_url: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    homepage_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    category_tags = Column(ARRAY_STRING, nullable=False, default=list)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    failure_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_fetched_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relationships
    articles: Mapped[List["Article"]] = relationship(
        "Article",
        back_populates="source",
        cascade="all, delete-orphan",
    )


class Article(Base):
    """
    Ingested, deduplicated tech article with sanitized body and metadata.
    """
    __tablename__ = "articles"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    source_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("sources.id", ondelete="CASCADE"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(Text, nullable=False)
    canonical_url: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    content_hash: Mapped[str] = mapped_column(String(64), nullable=False)  # SHA-256
    cleaned_content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    author: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    tags = Column(ARRAY_STRING, nullable=False, default=list)
    is_summarizable: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relationships
    source: Mapped["Source"] = relationship("Source", back_populates="articles")
    summaries: Mapped[List["Summary"]] = relationship(
        "Summary",
        back_populates="article",
        cascade="all, delete-orphan",
    )
    signals: Mapped[Optional["Signal"]] = relationship(
        "Signal",
        back_populates="article",
        uselist=False,
        cascade="all, delete-orphan",
    )
    bookmarks: Mapped[List["Bookmark"]] = relationship(
        "Bookmark",
        back_populates="article",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index("idx_articles_published_at", "published_at"),
        Index("idx_articles_content_hash", "content_hash"),
        Index("idx_articles_source_id", "source_id"),
    )


class Summary(Base):
    """
    AI-generated summary bullets per question angle (3-bullet ELI5, simplified, significance, risk).
    """
    __tablename__ = "summaries"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    article_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("articles.id", ondelete="CASCADE"),
        nullable=False,
    )
    question_type: Mapped[str] = mapped_column(String(30), nullable=False)
    content = Column(JSON, nullable=False)  # list of bullet strings
    model_used: Mapped[str] = mapped_column(String(50), nullable=False)
    prompt_version: Mapped[str] = mapped_column(String(20), nullable=False)
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relationships
    article: Mapped["Article"] = relationship("Article", back_populates="summaries")

    __table_args__ = (
        UniqueConstraint("article_id", "question_type", name="uq_summaries_article_question"),
        Index("idx_summaries_article_id", "article_id"),
    )


class Signal(Base):
    """
    Community discussion metrics aggregated from Hacker News (Algolia) and Reddit.
    """
    __tablename__ = "signals"

    article_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("articles.id", ondelete="CASCADE"),
        primary_key=True,
    )
    hn_points: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    hn_comment_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    hn_discussion_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    reddit_thread_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    reddit_comment_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relationships
    article: Mapped["Article"] = relationship("Article", back_populates="signals")


class UserPreference(Base):
    """
    User-specific topic and mute preferences, scoped by Supabase Auth UID.
    """
    __tablename__ = "user_preferences"

    user_id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True)
    followed_tags = Column(ARRAY_STRING, nullable=False, default=list)
    muted_domains = Column(ARRAY_STRING, nullable=False, default=list)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class Bookmark(Base):
    """
    User bookmark join record linking user_id to saved article.
    """
    __tablename__ = "bookmarks"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(GUID(), nullable=False)
    article_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("articles.id", ondelete="CASCADE"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relationships
    article: Mapped["Article"] = relationship("Article", back_populates="bookmarks")

    __table_args__ = (
        UniqueConstraint("user_id", "article_id", name="uq_bookmarks_user_article"),
        Index("idx_bookmarks_user_id", "user_id", "created_at"),
    )
