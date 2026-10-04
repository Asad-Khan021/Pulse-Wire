# Digest — Technical Architecture Document (TAD)

**Version:** 1.0
**System:** Cross-Platform IT Technology News & AI Summarization App
**Stack:** Flutter · FastAPI · PostgreSQL · Redis (Upstash) · Supabase Auth · Google Gemini
**Audience:** Development team, academic examiners, future maintainers

---

## Table of Contents

1. System Overview & High-Level Architecture
2. Backend Architecture & Data Pipeline (FastAPI)
3. Data Architecture & Relational Schema (PostgreSQL DDL)
4. Caching & AI Summarization Flow (Redis + PostgreSQL + Gemini)
5. Flutter Client Architecture & Offline Synchronization
6. API Specification & Data Contracts
7. Security, Rate Limiting & Scalability Blueprint

---

## 1. System Overview & High-Level Architecture

### 1.1 Architectural Style

Digest is built as a **decoupled service architecture** with three independently-deployable units that communicate through PostgreSQL as the shared source of truth, and never call each other directly:

- **System A** writes to the database on a schedule and has no callers.
- **System B** reads/writes the database on demand and has no knowledge of System A's internal scheduling.
- **Client** never touches the database or third-party APIs directly — it only speaks to System B over REST.

This separation means System A can be scaled, paused, or migrated to a different runtime (e.g. a cron-based serverless function) without touching System B's code, and vice versa.

### 1.2 High-Level Architecture Diagram

```
                                   ┌────────────────────────────────────────┐
                                   │              EXTERNAL WORLD             │
                                   │                                        │
                                   │   RSS/Atom Feeds (10+ tech publishers) │
                                   │   Google Gemini API (1.5 Flash)        │
                                   │   Algolia HN Search API                │
                                   │   Reddit Public JSON Endpoints         │
                                   │   Supabase Auth (JWT issuer)           │
                                   └───────────────┬───────────┬────────────┘
                                                   │           │
                    ┌──────────────────────────────┘           └───────────────────────┐
                    │                                                                  │
                    ▼                                                                  ▼
        ┌───────────────────────────┐                                    ┌─────────────────────────────┐
        │        SYSTEM A           │                                    │          SYSTEM B            │
        │  Ingestion Pipeline       │                                    │   On-Demand API Service      │
        │  (FastAPI + APScheduler)  │                                    │   (FastAPI, stateless)       │
        │                           │                                    │                               │
        │  ┌─────────────────────┐  │                                    │  ┌─────────────────────────┐  │
        │  │ 1. Feed Poller      │  │                                    │  │ JWT Auth Middleware      │  │
        │  │ 2. Readability      │  │                                    │  │ Rate Limiter (slowapi)   │  │
        │  │    Cleaner          │  │                                    │  │ Routers:                 │  │
        │  │ 3. URL Normalizer   │  │                                    │  │  /feed  /articles        │  │
        │  │ 4. Dedup Engine     │  │                                    │  │  /summaries /signals     │  │
        │  │    (URL + SHA-256)  │  │                                    │  │  /me/preferences         │  │
        │  │ 5. DB Writer        │  │                                    │  │  /me/bookmarks           │  │
        │  └─────────┬───────────┘  │                                    │  └────────────┬────────────┘  │
        └────────────┼──────────────┘                                    └───────────────┼───────────────┘
                     │                                                                    │
                     ▼                                                                    ▼
        ┌───────────────────────────────────────────────────────────────────────────────────────────┐
        │                                PostgreSQL (Supabase)                                        │
        │   sources │ articles │ summaries │ signals │ user_preferences │ bookmarks                   │
        │   Row-Level Security enforced on user_preferences & bookmarks                                │
        └───────────────────────────┬───────────────────────────────────────────────┬──────────────────┘
                                    │                                               │
                                    ▼                                               ▼
                         ┌─────────────────────┐                        ┌───────────────────────┐
                         │  Redis (Upstash)     │                        │   Gemini API           │
                         │  Tier-1 summary      │◄──── cache miss ──────►│   Tier-3 generation    │
                         │  cache, TTL-bound     │                        │   (rate-limited call)  │
                         └─────────────────────┘                        └───────────────────────┘
                                    ▲
                                    │ REST/JSON over HTTPS
                                    │
                     ┌──────────────┴───────────────────────────────────┐
                     │                FLUTTER CLIENT                    │
                     │                                                  │
                     │  screens/ → widgets/ → providers(Riverpod)/       │
                     │  → services(Dio,TTS,Hive)/ → models/              │
                     │                                                  │
                     │  Hive: cached_articles │ cached_summaries         │
                     │        pending_actions (offline bookmark queue)   │
                     │                                                  │
                     │  flutter_tts → on-device audio, zero backend cost │
                     └──────────────────────────────────────────────────┘
```

### 1.3 Rationale for Key Architectural Choices

| Decision | Rationale |
|---|---|
| Two independent FastAPI systems instead of one monolith with an internal cron | Ingestion failures (a bad RSS feed, a slow parse) must never degrade user-facing API latency. Separate deployables mean System B's uptime is not coupled to System A's schedule. |
| PostgreSQL as source of truth, Redis as accelerator only | Free-tier Redis (Upstash) has request-volume caps. If Digest treated Redis as authoritative, an Upstash outage or quota exhaustion would break summarization entirely. Instead Redis is purely a read-through cache in front of PostgreSQL — the feature degrades gracefully (slower, not broken) if Redis is unavailable. |
| Fixed-set "preset angle" AI interaction instead of open-ended chat | Open-ended chat produces an unbounded, non-cacheable query space — every unique user question is a full-price Gemini call. A finite set of four question_type values means the cache converges toward a near-100% hit rate as more users read the same article, which is the entire cost-control thesis of this system. |
| Client never calls Gemini/Algolia/Reddit/Redis directly | Keeps all third-party secrets server-side, centralizes rate-limiting in one place (System B), and allows the AI provider to be swapped without a client release. |
| Hive-based local mirror instead of a full local relational DB | The client only ever needs read-through caching of already-fetched cards/summaries and a small write-queue for bookmarks — a key-value store is sufficient and lower-overhead than embedding SQLite for this access pattern. |

---

## 2. Backend Architecture & Data Pipeline (FastAPI)

### 2.1 Repository Layout

```
backend/
├── app/
│   ├── main.py                     # FastAPI app factory, router registration, middleware
│   ├── config.py                   # Pydantic Settings: env vars for DB, Redis, Gemini, Supabase
│   ├── dependencies.py             # get_db(), get_current_user(), get_redis()
│   ├── db/
│   │   ├── base.py                 # SQLAlchemy declarative base
│   │   ├── models.py               # ORM models: Source, Article, Summary, Signal, Preference, Bookmark
│   │   └── session.py              # async engine + sessionmaker
│   ├── schemas/
│   │   ├── article.py              # Pydantic request/response models
│   │   ├── summary.py
│   │   ├── signal.py
│   │   └── preference.py
│   ├── routers/
│   │   ├── feed.py                 # GET /feed, GET /articles/{id}
│   │   ├── summaries.py            # GET /articles/{id}/summary
│   │   ├── signals.py              # GET /articles/{id}/signals
│   │   ├── preferences.py          # GET/PUT /me/preferences
│   │   └── bookmarks.py            # GET/POST/DELETE /me/bookmarks
│   ├── services/
│   │   ├── rss_ingestor.py         # feed polling orchestration
│   │   ├── readability_cleaner.py  # HTML → clean text extraction
│   │   ├── url_normalizer.py       # strip tracking params, resolve AMP
│   │   ├── dedup_engine.py         # canonical_url + content_hash logic
│   │   ├── gemini_service.py       # prompt templates, versioned, Gemini SDK calls
│   │   ├── cache_service.py        # 3-tier cache resolution (Redis → PG → Gemini)
│   │   └── signals_service.py      # Algolia HN + Reddit JSON lookups
│   ├── workers/
│   │   └── scheduled_fetch.py      # APScheduler job definition, runs rss_ingestor every 15–30 min
│   ├── middleware/
│   │   ├── auth_middleware.py      # Supabase JWT validation
│   │   └── rate_limit.py           # slowapi + Redis-backed limiter config
│   └── core/
│       └── exceptions.py           # custom exception classes + handlers
├── alembic/                        # DB migrations
├── requirements.txt
└── .env.example
```

### 2.2 Ingestion Pipeline Sequence (System A)

```
┌──────────────┐   ┌──────────────┐   ┌───────────────┐   ┌────────────────┐   ┌─────────────┐
│ 1. Scheduler │──►│ 2. Feed Fetch│──►│ 3. Readability │──►│ 4. URL Normalize│──►│ 5. Dedup    │
│ (every 15–30 │   │ per source,  │   │    Cleaner     │   │ + content_hash  │   │ Check       │
│  min tick)   │   │ isolated try │   │ (strip ads/nav)│   │  generation     │   │ (DB lookup) │
└──────────────┘   └──────┬───────┘   └────────────────┘   └────────────────┘   └──────┬──────┘
                          │ on failure:                                                │
                          │ increment failure_count,                          ┌────────┴────────┐
                          │ log, continue loop                                │  Exists already? │
                          ▼                                                   └───┬─────────┬───┘
                   (does NOT halt                                              Yes│         │No
                    other sources)                                                ▼         ▼
                                                                             Discard   ┌─────────────┐
                                                                                        │ 6. DB Write │
                                                                                        │ articles +  │
                                                                                        │ mark        │
                                                                                        │ is_summariz-│
                                                                                        │ able flag   │
                                                                                        └─────────────┘
```

**Pseudocode — orchestration loop (`rss_ingestor.py`):**

```python
async def run_ingestion_cycle(db: AsyncSession):
    active_sources = await get_active_sources(db)
    for source in active_sources:
        try:
            raw_entries = await fetch_feed(source.feed_url)
        except (TimeoutError, FeedParseError) as e:
            await increment_failure_count(db, source.id)
            logger.warning(f"Source {source.name} failed: {e}")
            continue  # isolate failure, proceed to next source

        for entry in raw_entries:
            canonical_url = normalize_url(entry.link)
            cleaned = extract_readable_content(entry.raw_html)
            content_hash = sha256(cleaned.text.encode()).hexdigest()

            if await article_exists(db, canonical_url, content_hash):
                continue  # already ingested, skip

            is_summarizable = len(cleaned.text) >= MIN_CONTENT_LENGTH

            await insert_article(
                db,
                source_id=source.id,
                title=entry.title,
                canonical_url=canonical_url,
                content_hash=content_hash,
                cleaned_content=cleaned.text,
                image_url=cleaned.top_image,
                tags=source.category_tags,
                is_summarizable=is_summarizable,
                published_at=entry.published,
            )

        await update_last_fetched(db, source.id)
```

### 2.3 API Layer Design (System B)

**Middleware stack (applied in `main.py`, order matters):**

1. `CORSMiddleware` — restricts origins to the Flutter app's bundle identifiers / known dev origins.
2. `auth_middleware` — extracts `Authorization: Bearer <jwt>`, validates against Supabase's JWKS endpoint, attaches `request.state.user`.
3. `rate_limit` (slowapi, Redis-backed storage) — applied selectively via decorator on cost-sensitive routes (`/articles/{id}/summary`).
4. Global exception handler — catches `HTTPException`, `ValidationError`, and unhandled exceptions, returning the standard error envelope (Section 6.4).

```python
# main.py (excerpt)
app = FastAPI(title="Digest API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(feed_router, prefix="/api/v1")
app.include_router(summaries_router, prefix="/api/v1")
app.include_router(signals_router, prefix="/api/v1")
app.include_router(preferences_router, prefix="/api/v1")
app.include_router(bookmarks_router, prefix="/api/v1")

app.add_exception_handler(AppException, app_exception_handler)
```

**JWT validation dependency:**

```python
# dependencies.py
async def get_current_user(
    authorization: str = Header(...),
) -> UserContext:
    token = authorization.replace("Bearer ", "")
    try:
        payload = jwt.decode(
            token,
            key=settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except JWTError:
        raise AppException(code="UNAUTHORIZED", message="Invalid or expired token", status_code=401)
    return UserContext(user_id=payload["sub"], email=payload.get("email"))
```

---

## 3. Data Architecture & Relational Schema (PostgreSQL DDL)

### 3.1 Entity Relationship Summary

```
sources 1───* articles 1───* summaries      (article_id, question_type) UNIQUE
                  │
                  1
                  │
                  1
               signals

auth.users 1───1 user_preferences
auth.users 1───* bookmarks *───1 articles
```

### 3.2 Full Migration DDL

```sql
-- =========================================================
-- Digest — Initial Schema Migration
-- =========================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- for gen_random_uuid()

-- ---------------------------------------------------------
-- Table: sources
-- ---------------------------------------------------------
CREATE TABLE sources (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(120) NOT NULL,
    feed_url         TEXT NOT NULL UNIQUE,
    homepage_url     TEXT,
    category_tags    TEXT[] NOT NULL DEFAULT '{}',
    is_active        BOOLEAN NOT NULL DEFAULT true,
    failure_count    INTEGER NOT NULL DEFAULT 0,
    last_fetched_at  TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------
-- Table: articles
-- ---------------------------------------------------------
CREATE TABLE articles (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id         UUID NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    title             TEXT NOT NULL,
    canonical_url     TEXT NOT NULL UNIQUE,
    content_hash      VARCHAR(64) NOT NULL,
    cleaned_content   TEXT,
    image_url         TEXT,
    author            VARCHAR(200),
    tags              TEXT[] NOT NULL DEFAULT '{}',
    is_summarizable   BOOLEAN NOT NULL DEFAULT true,
    published_at      TIMESTAMPTZ NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_articles_published_at ON articles (published_at DESC);
CREATE INDEX idx_articles_tags_gin      ON articles USING GIN (tags);
CREATE INDEX idx_articles_content_hash  ON articles (content_hash);
CREATE INDEX idx_articles_source_id     ON articles (source_id);

-- ---------------------------------------------------------
-- Table: summaries
-- ---------------------------------------------------------
CREATE TABLE summaries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id      UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    question_type   VARCHAR(30) NOT NULL
                    CHECK (question_type IN ('core_summary', 'explain_simpler', 'why_it_matters', 'risk_analysis')),
    content         JSONB NOT NULL,
    model_used      VARCHAR(50) NOT NULL,
    prompt_version  VARCHAR(20) NOT NULL,
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_summaries_article_question UNIQUE (article_id, question_type)
);

CREATE INDEX idx_summaries_article_id ON summaries (article_id);

-- ---------------------------------------------------------
-- Table: signals
-- ---------------------------------------------------------
CREATE TABLE signals (
    article_id            UUID PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
    hn_points             INTEGER,
    hn_comment_count      INTEGER,
    hn_discussion_url     TEXT,
    reddit_thread_url     TEXT,
    reddit_comment_count  INTEGER,
    fetched_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------
-- Table: user_preferences  (references Supabase-managed auth.users)
-- ---------------------------------------------------------
CREATE TABLE user_preferences (
    user_id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    followed_tags   TEXT[] NOT NULL DEFAULT '{}',
    muted_domains   TEXT[] NOT NULL DEFAULT '{}',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------
-- Table: bookmarks
-- ---------------------------------------------------------
CREATE TABLE bookmarks (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    article_id   UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_bookmarks_user_article UNIQUE (user_id, article_id)
);

CREATE INDEX idx_bookmarks_user_id ON bookmarks (user_id, created_at DESC);

-- =========================================================
-- Row-Level Security
-- =========================================================
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmarks        ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_preferences_owner_select ON user_preferences
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY user_preferences_owner_upsert ON user_preferences
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY user_preferences_owner_update ON user_preferences
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY bookmarks_owner_select ON bookmarks
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY bookmarks_owner_insert ON bookmarks
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY bookmarks_owner_delete ON bookmarks
    FOR DELETE USING (auth.uid() = user_id);
```

### 3.3 Cascading & Constraint Notes

| Rule | Behavior |
|---|---|
| `articles.source_id` → `sources.id` | `ON DELETE CASCADE` — removing a source removes its articles (used only for admin cleanup, not runtime deactivation, which uses `is_active` instead) |
| `summaries.article_id` → `articles.id` | `ON DELETE CASCADE` — summaries are meaningless without their parent article |
| `signals.article_id` → `articles.id` | `PRIMARY KEY` doubling as `FOREIGN KEY` enforces the 1:1 relationship without a separate surrogate key |
| `(article_id, question_type)` unique constraint on `summaries` | This is the compound key the entire caching strategy depends on — it makes an upsert (`ON CONFLICT DO UPDATE`) the natural write pattern for regenerated summaries |
| `(user_id, article_id)` unique constraint on `bookmarks` | Makes bookmark toggling idempotent — a duplicate `POST` is a no-op conflict, not an error |

---

## 4. Caching & AI Summarization Flow (Redis + PostgreSQL + Gemini)

### 4.1 Resolution Decision Tree

```
GET /articles/{id}/summary?type={question_type}
        │
        ▼
┌───────────────────────────┐
│ Tier 1: Redis GET         │
│ key = summary:{article_id}│
│       :{question_type}    │
└─────────────┬─────────────┘
              │
      HIT ────┴──── MISS
       │              │
       ▼              ▼
  Return cached   ┌───────────────────────────────┐
  JSON, mark      │ Tier 2: PostgreSQL SELECT      │
  cached=true     │ summaries WHERE article_id=..  │
                  │ AND question_type=..            │
                  └─────────────┬─────────────────┘
                                │
                       HIT ─────┴───── MISS
                        │               │
                        ▼               ▼
                 Write-through to  ┌─────────────────────────────┐
                 Redis (SETEX),    │ Tier 3: Gemini API call      │
                 return JSON,      │ using versioned prompt        │
                 cached=true       │ template for question_type    │
                                   └─────────────┬───────────────┘
                                                 │
                                        success ─┴─ failure
                                          │             │
                                          ▼             ▼
                                 INSERT INTO       Return 503 with
                                 summaries         retry-after hint;
                                 (upsert),          do NOT cache
                                 write-through      failure state
                                 to Redis,
                                 return JSON,
                                 cached=false
```

### 4.2 Redis Key Design

| Key pattern | Value | TTL | Notes |
|---|---|---|---|
| `summary:{article_id}:{question_type}` | JSON-serialized `{content, model_used, generated_at}` | 6 hours | Summaries are stable content; TTL exists mainly to bound memory usage on the free tier, not because the data goes stale |
| `signal:{article_id}` | JSON-serialized `{hn_points, hn_comment_count, ...}` | 30 minutes | Community metrics genuinely drift; short TTL keeps them reasonably fresh |
| `ratelimit:{user_id}:summary` | Request counter (slowapi-managed) | 1 minute sliding window | Backs the rate limiter described in Section 7 |

### 4.3 Serialization Strategy

Summaries are stored in Redis as a flat JSON string (not a Redis hash), since the entire object is always read/written atomically and never partially updated:

```json
{
  "content": [
    "Google released Gemini 2.0 with native multimodal reasoning.",
    "The model outperforms prior versions on coding benchmarks.",
    "Available now via API with a generous free tier."
  ],
  "model_used": "gemini-1.5-flash",
  "prompt_version": "v1.2",
  "generated_at": "2026-09-10T14:32:00Z"
}
```

### 4.4 Prompt Template Versioning (`gemini_service.py`)

```python
PROMPT_TEMPLATES = {
    "core_summary": {
        "version": "v1.2",
        "template": (
            "Summarize the following technology article in exactly 3 bullet points, "
            "written for a reader with no prior context, plain language, no jargon:\n\n{article_text}"
        ),
    },
    "explain_simpler": {
        "version": "v1.0",
        "template": (
            "Explain the core idea of this article as if to a complete beginner, "
            "in 2-3 short sentences:\n\n{article_text}"
        ),
    },
    "why_it_matters": {
        "version": "v1.0",
        "template": (
            "In 2-3 sentences, explain why this development matters for the technology "
            "industry or its users:\n\n{article_text}"
        ),
    },
    "risk_analysis": {
        "version": "v1.0",
        "template": (
            "In 2-3 sentences, identify the main risk, limitation, or counterargument "
            "relevant to this development:\n\n{article_text}"
        ),
    },
}

async def generate_summary(article_text: str, question_type: str) -> dict:
    template = PROMPT_TEMPLATES[question_type]
    prompt = template["template"].format(article_text=article_text[:8000])
    response = await gemini_client.generate_content_async(prompt)
    return {
        "content": parse_response(response, question_type),
        "model_used": "gemini-1.5-flash",
        "prompt_version": template["version"],
    }
```

### 4.5 Error Handling & Fallback Behavior

| Failure scenario | Behavior |
|---|---|
| Redis unreachable (timeout/connection error) | Caught at the `cache_service.py` boundary; system logs a warning and proceeds directly to Tier 2 (PostgreSQL) as if Tier 1 were a miss. No user-facing error. |
| PostgreSQL unreachable | This is a hard dependency failure for System B generally (not summary-specific); returns `503 Service Unavailable` with the standard error envelope. |
| Gemini API timeout or non-2xx response | Retried once with exponential backoff (base 500ms); on second failure, returns `503` with `retry_after` hint. The failure is **not** cached, so the next request retries Gemini rather than being stuck behind a cached error. |
| Gemini returns malformed/unparseable output | Falls back to a generic message ("Summary temporarily unavailable") returned to the client with `cached: false`; not persisted to PostgreSQL, allowing a future request to retry generation cleanly. |
| Algolia HN / Reddit JSON timeout | Caught independently per-provider; the `/signals` endpoint returns whatever subset succeeded (e.g. HN only) rather than failing the whole request. |

---

## 5. Flutter Client Architecture & Offline Synchronization

### 5.1 Layered Architecture

```
screens/            ── full-page compositions, minimal logic, consume providers
   │
   ▼
widgets/             ── reusable presentational components
   │
   ▼
providers/ (Riverpod) ── state + business logic, orchestrate services
   │
   ▼
services/            ── Dio HTTP client, Hive persistence, TTS binding
   │
   ▼
models/              ── plain Dart data classes (fromJson/toJson)
```

Data flows strictly downward for rendering (screens read providers) and strictly upward for mutation (widgets call provider methods, providers call services, services touch network/disk).

### 5.2 Riverpod Provider Map

```dart
// feed_provider.dart
final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(
    api: ref.watch(newsApiServiceProvider),
    cache: ref.watch(offlineCacheServiceProvider),
    connectivity: ref.watch(connectivityProvider),
  );
});

// summary_provider.dart — family provider keyed by (articleId, questionType)
final summaryProvider = FutureProvider.family<Summary, SummaryRequest>((ref, req) async {
  final api = ref.watch(newsApiServiceProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  if (!ref.watch(connectivityProvider).isOnline) {
    return cache.getCachedSummary(req.articleId, req.questionType);
  }
  final result = await api.fetchSummary(req.articleId, req.questionType);
  await cache.cacheSummary(req.articleId, req.questionType, result);
  return result;
});

// bookmarks_provider.dart
final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<Article>>((ref) {
  return BookmarksNotifier(
    api: ref.watch(newsApiServiceProvider),
    cache: ref.watch(offlineCacheServiceProvider),
  );
});
```

### 5.3 Hive Box Strategy

| Box name | Contents | Write trigger | Read trigger |
|---|---|---|---|
| `cached_articles` | Serialized `Article` objects from the most recent successful `/feed` fetch | On every successful feed response | On feed load when `connectivityProvider.isOnline == false` |
| `cached_summaries` | Serialized `Summary` objects keyed by `"{articleId}_{questionType}"` | On every successful summary fetch | On summary request when offline, or as an instant-render placeholder while a fresh network call is in flight |
| `pending_actions` | Queued bookmark add/remove actions: `{action: 'add'|'remove', articleId, timestamp}` | On bookmark toggle while offline | Flushed sequentially when connectivity is restored |

**Offline bookmark queue flush logic:**

```dart
class OfflineCacheService {
  Future<void> flushPendingActions(NewsApiService api) async {
    final box = Hive.box<PendingAction>('pending_actions');
    final actions = box.values.toList();
    for (final action in actions) {
      try {
        if (action.type == 'add') {
          await api.addBookmark(action.articleId);
        } else {
          await api.removeBookmark(action.articleId);
        }
        await box.delete(action.key); // remove only after confirmed success
      } catch (e) {
        break; // stop on first failure, retry whole queue next connectivity event
      }
    }
  }
}
```

This is idempotent by design: because `bookmarks` has a `UNIQUE (user_id, article_id)` constraint, a duplicate `add` is a harmless conflict, and a `remove` on an already-removed bookmark is a harmless no-op — no custom conflict resolution logic is required.

### 5.4 Text-to-Speech Integration Pattern

```dart
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final _stateController = StreamController<TtsPlaybackState>.broadcast();
  Stream<TtsPlaybackState> get playbackState => _stateController.stream;

  TtsService() {
    _tts.setStartHandler(() => _stateController.add(TtsPlaybackState.playing));
    _tts.setCompletionHandler(() => _stateController.add(TtsPlaybackState.stopped));
    _tts.setErrorHandler((_) => _stateController.add(TtsPlaybackState.stopped));
  }

  Future<void> speak(List<String> bullets) async {
    final text = bullets.join('. ');
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
```

No audio data ever leaves the device or touches System B — `flutter_tts` invokes the platform's native speech engine (AVSpeechSynthesizer on iOS, TextToSpeech on Android) entirely locally.

---

## 6. API Specification & Data Contracts

All endpoints are prefixed `/api/v1`. Authenticated endpoints require `Authorization: Bearer <supabase_jwt>`.

### 6.1 `GET /feed`

**Query parameters:**

| Param | Type | Required | Notes |
|---|---|---|---|
| `tags` | string (comma-separated) | No | Filter by topic tags |
| `exclude_domains` | string (comma-separated) | No | Applies user's muted domains |
| `cursor` | string | No | Opaque pagination cursor |
| `limit` | integer | No | Default 20, max 50 |

**Response `200`:**

```json
{
  "items": [
    {
      "id": "b3f1...",
      "title": "Gemini 2.0 launches with native multimodal reasoning",
      "source": "TechCrunch",
      "canonical_url": "https://techcrunch.com/...",
      "image_url": "https://...",
      "tags": ["AI"],
      "published_at": "2026-09-12T08:00:00Z"
    }
  ],
  "next_cursor": "eyJvZmZzZXQiOjIwfQ=="
}
```

### 6.2 `GET /articles/{id}`

**Response `200`:**

```json
{
  "id": "b3f1...",
  "title": "Gemini 2.0 launches with native multimodal reasoning",
  "source": "TechCrunch",
  "cleaned_content": "Google today announced Gemini 2.0 ...",
  "canonical_url": "https://techcrunch.com/...",
  "tags": ["AI"],
  "is_summarizable": true,
  "published_at": "2026-09-12T08:00:00Z"
}
```

**Response `404`:** article not found (see error envelope, 6.6).

### 6.3 `GET /articles/{id}/summary`

**Query parameters:**

| Param | Type | Required | Allowed values |
|---|---|---|---|
| `type` | string | Yes | `core_summary`, `explain_simpler`, `why_it_matters`, `risk_analysis` |

**Response `200`:**

```json
{
  "article_id": "b3f1...",
  "question_type": "core_summary",
  "content": [
    "Google released Gemini 2.0 with native multimodal reasoning.",
    "The model outperforms prior versions on coding benchmarks.",
    "Available now via API with a generous free tier."
  ],
  "cached": true,
  "model_used": "gemini-1.5-flash",
  "generated_at": "2026-09-10T14:32:00Z"
}
```

**Response `422`:** `is_summarizable = false` for this article.
**Response `429`:** rate limit exceeded (see Section 7.2).
**Response `503`:** Gemini call failed after retry.

### 6.4 `GET /articles/{id}/signals`

**Response `200`:**

```json
{
  "article_id": "b3f1...",
  "hn_points": 342,
  "hn_comment_count": 128,
  "hn_discussion_url": "https://news.ycombinator.com/item?id=...",
  "reddit_thread_url": "https://reddit.com/r/technology/...",
  "reddit_comment_count": 76,
  "fetched_at": "2026-09-12T09:00:00Z"
}
```

**Response `200` (no matches found):** returns the object with all signal fields `null` — never a `404`, since the absence of discussion is a valid state, not an error.

### 6.5 Preferences & Bookmarks

```
GET  /me/preferences         → { "followed_tags": ["AI","DevOps"], "muted_domains": ["example.com"] }
PUT  /me/preferences         ← { "followed_tags": [...], "muted_domains": [...] }
GET  /me/bookmarks           → { "items": [ Article, ... ] }
POST /me/bookmarks           ← { "article_id": "b3f1..." }        → 201 Created
DELETE /me/bookmarks/{id}    →                                     → 204 No Content
```

### 6.6 Standard Error Envelope

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Summary requests are limited to 20 per minute per user.",
    "retry_after": 15
  }
}
```

| HTTP Status | `code` | Used for |
|---|---|---|
| 401 | `UNAUTHORIZED` | Missing/invalid JWT |
| 404 | `NOT_FOUND` | Unknown article/resource id |
| 422 | `NOT_SUMMARIZABLE` | Article failed extraction threshold |
| 429 | `RATE_LIMITED` | Summary endpoint quota exceeded |
| 503 | `UPSTREAM_UNAVAILABLE` | Gemini/DB unavailable after retry |

---

## 7. Security, Rate Limiting & Scalability Blueprint

### 7.1 Secret Management

| Secret | Storage | Never appears in |
|---|---|---|
| Gemini API key | Backend environment variable (`.env`, injected via deployment platform's secret store) | Client bundle, client-side network logs, Git history |
| Upstash Redis URL/token | Backend environment variable | Client bundle |
| Supabase service role key | Backend environment variable, used only for admin operations | Client bundle (client uses the anon/public key + user JWT instead) |
| Supabase JWT secret (for validation) | Backend environment variable | Client bundle |

All secrets are loaded via a single `config.py` using `pydantic-settings`, so there is exactly one code path that reads environment variables — simplifying auditing.

### 7.2 Rate Limiting Strategy

```python
# middleware/rate_limit.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(
    key_func=lambda request: request.state.user.user_id if hasattr(request.state, "user") else get_remote_address(request),
    storage_uri=settings.REDIS_URL,
)

# summaries.py
@router.get("/articles/{article_id}/summary")
@limiter.limit("20/minute")
async def get_summary(article_id: str, type: str, request: Request, user=Depends(get_current_user)):
    ...
```

- Rate limiting is keyed by **authenticated user ID** where available, falling back to IP address for any unauthenticated preview endpoints.
- Redis-backed storage means limits are consistent across multiple backend instances if System B is horizontally scaled.
- The summary endpoint is the only route with an aggressive limit, since it is the only route capable of triggering a billable/quota-consuming external call on a cache miss.

### 7.3 CORS Policy

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://digest-app.web.app",   # if a companion web build ever exists
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

Native mobile clients (Flutter iOS/Android) are not subject to browser CORS restrictions, so this policy primarily protects against unauthorized web-based misuse of the API.

### 7.4 Scalability Considerations Beyond Free Tier

| Component | Current (free tier) | Scale-up path |
|---|---|---|
| PostgreSQL | Supabase free tier (shared compute, 500MB) | Upgrade to Supabase Pro / dedicated instance; schema requires no changes |
| Redis | Upstash free tier (request-capped) | Upstash pay-as-you-go tier; cache logic is TTL/key-compatible, no code changes needed |
| Gemini | Free tier (rate-capped requests/day) | Paid tier or model downgrade for cost control; abstracted behind `gemini_service.py` so the provider/model is swappable without touching callers |
| FastAPI (System B) | Single instance | Stateless design (no in-process session state) allows horizontal scaling behind a load balancer with zero code changes; rate limiter already uses shared Redis storage, not in-memory counters |
| FastAPI (System A) | Single scheduled worker | Can be migrated to a serverless cron function (e.g. Cloud Run Jobs) since it has no persistent in-memory state between runs |

### 7.5 Defense-in-Depth Summary

1. **Transport:** HTTPS enforced on all endpoints.
2. **AuthN:** Supabase-issued JWT validated on every authenticated route.
3. **AuthZ:** PostgreSQL Row-Level Security as a second enforcement layer beneath application-level checks — a bug in route logic cannot leak another user's bookmarks or preferences.
4. **Input validation:** Pydantic schemas reject malformed payloads before they reach service logic.
5. **Rate limiting:** Protects the one endpoint capable of incurring real external cost.
6. **Secret isolation:** No third-party credential ever reaches the client bundle.

---

*End of Technical Architecture Document.*
