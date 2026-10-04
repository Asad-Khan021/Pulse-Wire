"""Initial core schema for Digest platform

Revision ID: 0001_initial_core_schema
Revises: 
Create Date: 2026-09-14 14:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0001_initial_core_schema"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Enable pgcrypto extension for gen_random_uuid() if running on PostgreSQL
    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        op.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto"')

    # 1. Table: sources
    op.create_table(
        "sources",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("feed_url", sa.Text(), nullable=False, unique=True),
        sa.Column("homepage_url", sa.Text(), nullable=True),
        sa.Column("category_tags", postgresql.ARRAY(sa.String()).with_variant(sa.JSON(), "sqlite"), nullable=False, server_default="{}"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("failure_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_fetched_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    # 2. Table: articles
    op.create_table(
        "articles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("source_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sources.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("canonical_url", sa.Text(), nullable=False, unique=True),
        sa.Column("content_hash", sa.String(length=64), nullable=False),
        sa.Column("cleaned_content", sa.Text(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("author", sa.String(length=200), nullable=True),
        sa.Column("tags", postgresql.ARRAY(sa.String()).with_variant(sa.JSON(), "sqlite"), nullable=False, server_default="{}"),
        sa.Column("is_summarizable", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("idx_articles_published_at", "articles", ["published_at"])
    op.create_index("idx_articles_content_hash", "articles", ["content_hash"])
    op.create_index("idx_articles_source_id", "articles", ["source_id"])

    # 3. Table: summaries
    op.create_table(
        "summaries",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("article_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("articles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("question_type", sa.String(length=30), nullable=False),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column("model_used", sa.String(length=50), nullable=False),
        sa.Column("prompt_version", sa.String(length=20), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("article_id", "question_type", name="uq_summaries_article_question"),
    )
    op.create_index("idx_summaries_article_id", "summaries", ["article_id"])

    # 4. Table: signals
    op.create_table(
        "signals",
        sa.Column("article_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("articles.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("hn_points", sa.Integer(), nullable=True),
        sa.Column("hn_comment_count", sa.Integer(), nullable=True),
        sa.Column("hn_discussion_url", sa.Text(), nullable=True),
        sa.Column("reddit_thread_url", sa.Text(), nullable=True),
        sa.Column("reddit_comment_count", sa.Integer(), nullable=True),
        sa.Column("fetched_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    # 5. Table: user_preferences
    op.create_table(
        "user_preferences",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("followed_tags", postgresql.ARRAY(sa.String()).with_variant(sa.JSON(), "sqlite"), nullable=False, server_default="{}"),
        sa.Column("muted_domains", postgresql.ARRAY(sa.String()).with_variant(sa.JSON(), "sqlite"), nullable=False, server_default="{}"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    # 6. Table: bookmarks
    op.create_table(
        "bookmarks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("article_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("articles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "article_id", name="uq_bookmarks_user_article"),
    )
    op.create_index("idx_bookmarks_user_id", "bookmarks", ["user_id", "created_at"])


def downgrade() -> None:
    op.drop_index("idx_bookmarks_user_id", table_name="bookmarks")
    op.drop_table("bookmarks")
    op.drop_table("user_preferences")
    op.drop_table("signals")
    op.drop_index("idx_summaries_article_id", table_name="summaries")
    op.drop_table("summaries")
    op.drop_index("idx_articles_source_id", table_name="articles")
    op.drop_index("idx_articles_content_hash", table_name="articles")
    op.drop_index("idx_articles_published_at", table_name="articles")
    op.drop_table("articles")
    op.drop_table("sources")
