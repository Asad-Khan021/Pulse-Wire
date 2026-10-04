# Graph Report - proper files making  (2026-09-18)

## Corpus Check
- Large corpus: 2490 files · ~4,095,667 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 735 nodes · 1273 edges · 54 communities (41 shown, 13 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 73 edges (avg confidence: 0.93)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Project Architecture & Design Docs
- Backend DB Models & ORM
- Backend Feed Router & Article API
- Backend Ingestion Worker
- Flutter Article Model
- Backend Summary & Signal Services
- Backend Preferences Router
- Backend Signals Router
- Flutter News API Service
- Backend Bookmarks Router
- Backend Security & JWT Auth
- Backend Test: HTML Cleaner
- Backend Test: Security
- Flutter Feed Provider
- Alembic Migrations
- Backend Config & DB Session
- Flutter Preferences Provider
- Backend Test Fixtures & Conftest
- Flutter App Entry & Theme
- Flutter Summary Provider
- Flutter API Constants
- Redis Cache Service (internals)
- Backend Test: Summarizer
- Flutter Article Detail Screen
- Flutter Summary Bottom Sheet
- Flutter Signal Model
- Flutter Bookmarks Provider
- Backend DB Base & Bookmark Model
- Backend Health Router
- Backend Test: Signals
- Mock Cache Service
- Backend Test: Feed API
- Flutter Feed Screen
- Flutter Article Card Widget
- RSS Sources & Seed Script
- Flutter Bookmarks Screen
- Backend Summary Router
- Redis Cache Service (interface)
- Flutter Shimmer & TTS Widgets
- Custom GUID Type
- Backend Settings & Config
- Preferences Schemas
- Backend Core Init
- Backend DB Init
- Backend App Init
- Backend Schemas Init
- Backend Services Init
- Backend Workers Init
- Flutter Auth Interceptor
- Graphify Agent Config
- DateTime Type
- Exception Type
- QuestionType Enum

## God Nodes (most connected - your core abstractions)
1. `RedisCacheService` - 30 edges
2. `Article` - 25 edges
3. `Source` - 22 edges
4. `ingest_source()` - 15 edges
5. `AppException` - 13 edges
6. `UnauthorizedException` - 13 edges
7. `extract_user_context()` - 13 edges
8. `Base` - 13 edges
9. `get_feed()` - 13 edges
10. `SummarizerService` - 13 edges

## Surprising Connections (you probably didn't know these)
- `HN / Reddit Community Signals` --feature_of--> `Digest`  [EXTRACTED]
  Digest_PRD.md → FINAL PROJECT IDEA.TXT
- `Product Requirements Document` --documents--> `Digest`  [EXTRACTED]
  Digest_PRD.md → FINAL PROJECT IDEA.TXT
- `Functional Specification Document` --documents--> `Digest`  [EXTRACTED]
  FSD_Digest.md → FINAL PROJECT IDEA.TXT
- `Feature Backlog` --tracks_work_for--> `Digest`  [EXTRACTED]
  IT-News-App-Feature-Backlog.md → FINAL PROJECT IDEA.TXT
- `System Architecture & Component Diagram` --documents--> `Digest`  [EXTRACTED]
  SACD_Digest.md → FINAL PROJECT IDEA.TXT

## Import Cycles
- None detected.

## Communities (54 total, 13 thin omitted)

### Community 0 - "Project Architecture & Design Docs"
Cohesion: 0.06
Nodes (38): apscheduler_schedulers_asyncio, async_sessionmaker, app_exception_handler(), AppException, ForbiddenException, generic_exception_handler(), NotSummarizableException, Exception (+30 more)

### Community 1 - "Backend DB Models & ORM"
Cohesion: 0.04
Nodes (45): bool get, dart:async, FlutterTts, articleId, cached, content, fromJson, fromValue (+37 more)

### Community 2 - "Backend Feed Router & Article API"
Cohesion: 0.08
Nodes (43): 401 Unauthorized - missing, invalid, or expired JWT., UnauthorizedException, decode_supabase_jwt(), extract_user_context(), Any, Immutable representation of an authenticated user extracted from Supabase JWT., Decodes and validates a Supabase-issued JWT token. Enforces signature…, Decodes token and maps claims to UserContext. (+35 more)

### Community 3 - "Backend Ingestion Worker"
Cohesion: 0.08
Nodes (34): FeedFetchError, fetch_feed_xml(), parse_feed_entries(), Exception, Normalized article metadata parsed from RSS/Atom entry., Raised when an RSS feed cannot be retrieved or parsed., Fetches XML/Atom/JSON feed payload over HTTP with backoff retry., Parses RSS/Atom XML string into a list of normalized RawFeedItem instances. (+26 more)

### Community 4 - "Flutter Article Model"
Cohesion: 0.08
Nodes (28): Google Gemini API, HN / Reddit Community Signals, Product Requirements Document, RSS Ingestion, Supabase, Text-to-Speech (TTS), API Layer (System B), Content Pipeline (System A) (+20 more)

### Community 5 - "Backend Summary & Signal Services"
Cohesion: 0.07
Nodes (27): ArticleDetail, ArticleListItem, author, canonicalUrl, cleanedContent, FeedResponse, fromJson, hnCommentCount (+19 more)

### Community 6 - "Backend Preferences Router"
Cohesion: 0.12
Nodes (22): get_article_signals(), AsyncSession, get, UUID, Retrieves community discussion telemetry (Hacker News upvotes/comments, Reddit…, BaseModel, Community discussion metrics from Hacker News and Reddit., SignalResponse (+14 more)

### Community 7 - "Backend Signals Router"
Cohesion: 0.14
Nodes (22): NotFoundException, 404 Not Found - resource does not exist., BaseModel, Enum, str, Summary payload returned from 3-tier cache or generation., The four deterministic, cost-bounded summary angles supported by Digest., SummaryResponse (+14 more)

### Community 8 - "Flutter News API Service"
Cohesion: 0.09
Nodes (22): ../core/constants/api_constants.dart, Dio, ApiException, code, _dio, getArticleDetail, getFeed, getSignals (+14 more)

### Community 9 - "Backend Bookmarks Router"
Cohesion: 0.11
Nodes (20): bookmarks_screen.dart, feedProvider, build, _buildFeedBody, createState, dispose, initState, _onScroll (+12 more)

### Community 10 - "Backend Security & JWT Auth"
Cohesion: 0.15
Nodes (19): feed_cache_key(), UUID, rate_limit_cache_key(), Generates a deterministic Redis cache key for paginated feed queries. Format:…, Generates a Redis cache key for an AI article summary. Format:…, Generates a Redis cache key for community discussion signals. Format:…, Generates a Redis key for sliding window rate limiting. Format:…, signals_cache_key() (+11 more)

### Community 11 - "Backend Test: HTML Cleaner"
Cohesion: 0.29
Nodes (12): Article, Community discussion metrics aggregated from Hacker News (Algolia) and Reddit., Ingested, deduplicated tech article with sanitized body and metadata., Signal, datetime, httpx, os, pytest (+4 more)

### Community 12 - "Backend Test: Security"
Cohesion: 0.11
Nodes (17): AppTheme, darkAccent, darkAccentSubtle, darkBg, darkBorder, darkInk, darkInkSecondary, darkSurface (+9 more)

### Community 13 - "Flutter Feed Provider"
Cohesion: 0.12
Nodes (17): api, _apiService, apiServiceProvider, articles, copyWith, errorMessage, FeedNotifier, FeedState (+9 more)

### Community 14 - "Alembic Migrations"
Cohesion: 0.13
Nodes (13): alembic, asyncio, do_run_migrations(), Run migrations in 'offline' mode., In this scenario we need to create an Engine and associate a connection with…, Run migrations in 'online' mode., run_async_migrations(), run_migrations_offline() (+5 more)

### Community 15 - "Backend Config & DB Session"
Cohesion: 0.21
Nodes (12): get_db_session(), AsyncSession, FastAPI dependency yielding an isolated async database session with auto-…, get_cache(), get_db(), AsyncSession, Dependency providing an async database session., Dependency providing the Redis caching service. (+4 more)

### Community 16 - "Flutter Preferences Provider"
Cohesion: 0.13
Nodes (14): AsyncValue, addMutedDomain, PreferencesNotifier, removeMutedDomain, toggleFollowedTag, SummaryNotifier, setTheme, ThemeModeNotifier (+6 more)

### Community 17 - "Backend Test Fixtures & Conftest"
Cohesion: 0.15
Nodes (11): client(), create_test_jwt(), db_session(), AsyncClient, AsyncSession, Helper fixture to mint Supabase-like test JWT tokens., Initializes tables in the in-memory SQLite database., Provides an isolated database session per test with automatic rollback. (+3 more)

### Community 18 - "Flutter App Entry & Theme"
Cohesion: 0.20
Nodes (12): core/theme/app_theme.dart, build, DigestNewsApp, main, preferencesProvider, themeProvider, build, SettingsScreen (+4 more)

### Community 19 - "Flutter Summary Provider"
Cohesion: 0.14
Nodes (13): feed_provider.dart, api, articleId, fetch, hashCode, key, operator, questionType (+5 more)

### Community 20 - "Flutter API Constants"
Cohesion: 0.14
Nodes (13): ApiConstants, articleDetail, articleSignals, articleSummary, bookmarks, connectTimeout, defaultBaseUrl, feed (+5 more)

### Community 21 - "Redis Cache Service (internals)"
Cohesion: 0.15
Nodes (7): Deletes key from Redis; returns False on failure., Asynchronous Redis Cache Service with graceful degradation. If Redis times out…, Initializes the Redis connection pool., Closes all Redis connections in the pool., Health check returns True if Redis responds to ping., Stores raw string in Redis with TTL; returns False on failure., RedisCacheService

### Community 22 - "Backend Test: Summarizer"
Cohesion: 0.24
Nodes (13): AsyncClient, asyncio, AsyncSession, Verifies all four preset question angles can be queried., Verifies that an unsummarizable article returns 422 Unprocessable Entity., Verifies the 3-Tier AI Summarization Flow: Tier 3 (Gemini Generation) -> Tier 1…, Verifies that non-existent article returns 404., Verifies that exceeding the rate limit returns HTTP 429. (+5 more)

### Community 23 - "Flutter Article Detail Screen"
Cohesion: 0.18
Nodes (12): api, articleDetailProvider, ArticleDetailScreen, articleId, build, _buildBottomBar, _buildCommunitySignals, _buildDetailContent (+4 more)

### Community 24 - "Flutter Summary Bottom Sheet"
Cohesion: 0.15
Nodes (12): _activeAngle, articleId, articleTitle, _buildLoadingState, _buildSummaryContent, _buildUnsummarizableState, createState, isSummarizable (+4 more)

### Community 25 - "Flutter Signal Model"
Cohesion: 0.17
Nodes (11): articleId, fetchedAt, fromJson, hnCommentCount, hnDiscussionUrl, hnPoints, redditCommentCount, redditThreadUrl (+3 more)

### Community 26 - "Flutter Bookmarks Provider"
Cohesion: 0.18
Nodes (11): bookmarkedArticles, BookmarksNotifier, BookmarksState, copyWith, errorMessage, isBookmarked, list, removeBookmark (+3 more)

### Community 27 - "Backend DB Base & Bookmark Model"
Cohesion: 0.18
Nodes (10): Base, Base class for all SQLAlchemy ORM models., Bookmark, AI-generated summary bullets per question angle (3-bullet ELI5, simplified,…, User-specific topic and mute preferences, scoped by Supabase Auth UID., User bookmark join record linking user_id to saved article., Summary, UserPreference (+2 more)

### Community 28 - "Backend Health Router"
Cohesion: 0.22
Nodes (10): health_check(), AsyncSession, get, Service health check endpoint verifying database connectivity and Redis…, Health check for Redis connection pool specifically., redis_health(), ErrorDetail, ErrorEnvelope (+2 more)

### Community 29 - "Backend Test: Signals"
Cohesion: 0.24
Nodes (7): AsyncClient, asyncio, AsyncSession, Verifies that HN and Reddit signals are fetched, stored in DB, cached in Redis,…, Verifies that when external signal APIs fail or timeout, the endpoint fails…, test_signals_retrieval_and_caching(), test_signals_silent_fallback_on_network_error()

### Community 31 - "Backend Test: Feed API"
Cohesion: 0.28
Nodes (9): AsyncClient, asyncio, AsyncSession, Verifies that the /api/v1/health endpoint responds with status and version., Verifies that empty feed returns 200 with empty items list., Verifies feed listing, tag filtering, cursor pagination, and detail retrieval., test_feed_empty(), test_feed_pagination_and_detail() (+1 more)

### Community 32 - "Flutter Feed Screen"
Cohesion: 0.25
Nodes (9): ConsumerState, ConsumerStatefulWidget, summaryProvider, FeedScreen, _FeedScreenState, build, _buildErrorState, SummarySheet (+1 more)

### Community 33 - "Flutter Article Card Widget"
Cohesion: 0.25
Nodes (7): ArticleListItem, article, _formatRelativeTime, package:cached_network_image/cached_network_image.dart, package:intl/intl.dart, ../screens/article_detail_screen.dart, summary_sheet.dart

### Community 34 - "RSS Sources & Seed Script"
Cohesion: 0.25
Nodes (8): RSS/Atom News Feed source configuration and health telemetry., Source, Seeds initial curated RSS tech sources if they do not already exist., seed_sources(), asyncio, AsyncSession, Verifies that duplicate entries are ignored during ingestion., test_ingest_source_deduplication()

### Community 35 - "Flutter Bookmarks Screen"
Cohesion: 0.32
Nodes (7): ConsumerWidget, bookmarksProvider, BookmarksScreen, build, ArticleCard, ../../providers/bookmarks_provider.dart, ../widgets/article_card.dart

### Community 36 - "Backend Summary Router"
Cohesion: 0.29
Nodes (7): get_article_summary(), AsyncSession, get, Request, UUID, Retrieves or generates a cost-controlled 3-bullet AI summary for an article. -…, limit

### Community 37 - "Redis Cache Service (interface)"
Cohesion: 0.29
Nodes (4): Any, Retrieves raw string value by key; returns None on miss or error., Retrieves and deserializes JSON from Redis; returns None on miss or error., Serializes and stores value as JSON with TTL; returns False on failure.

### Community 38 - "Flutter Shimmer & TTS Widgets"
Cohesion: 0.29
Nodes (6): build, ShimmerFeedLoading, TtsPlayerButton, package:flutter/material.dart, package:shimmer/shimmer.dart, StatelessWidget

### Community 39 - "Custom GUID Type"
Cohesion: 0.33
Nodes (3): GUID, Platform-independent GUID type. Uses PostgreSQL's native UUID type, otherwise…, TypeDecorator

### Community 40 - "Backend Settings & Config"
Cohesion: 0.40
Nodes (5): get_settings(), Returns cached application settings instance., Centralized application configuration loaded from environment variables and…, Settings, BaseSettings

### Community 41 - "Preferences Schemas"
Cohesion: 0.67
Nodes (3): BaseModel, UserPreferenceResponse, UserPreferenceUpdate

## Knowledge Gaps
- **193 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `feed`, `bookmarks`, `preferences` (+188 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 420 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `RedisCacheService` connect `Redis Cache Service (internals)` to `Backend Feed Router & Article API`, `Backend Summary Router`, `Redis Cache Service (interface)`, `Backend Preferences Router`, `Backend Signals Router`, `Backend Test: HTML Cleaner`, `Backend Config & DB Session`, `Backend Health Router`, `Mock Cache Service`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `Article` connect `Backend Test: HTML Cleaner` to `Project Architecture & Design Docs`, `Backend Feed Router & Article API`, `Backend Ingestion Worker`, `RSS Sources & Seed Script`, `Backend Preferences Router`, `Backend Signals Router`, `Backend Test: Summarizer`, `Backend DB Base & Bookmark Model`, `Backend Test: Signals`, `Backend Test: Feed API`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `MockCacheService` connect `Mock Cache Service` to `Backend Test: HTML Cleaner`, `Redis Cache Service (internals)`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Are the 8 inferred relationships involving `RedisCacheService` (e.g. with `get_cache()` and `get_feed()`) actually correct?**
  _`RedisCacheService` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 12 inferred relationships involving `Article` (e.g. with `get_article_detail()` and `get_feed()`) actually correct?**
  _`Article` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `Source` (e.g. with `ingest_source()` and `run_ingestion_cycle()`) actually correct?**
  _`Source` has 10 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ApiConstants`, `defaultBaseUrl`, `feed` to the rest of the system?**
  _193 weakly-connected nodes found - possible documentation gaps or missing edges._