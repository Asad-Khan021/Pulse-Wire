# IT Technology News App — Feature Ticket Backlog
**Stack:** Flutter · FastAPI · PostgreSQL · Redis · Supabase · Google Gemini
**Format:** Jira/GitHub-Issue style, sprint-ready
**Legend:** Priority = High / Medium / Low | Effort = Fibonacci Story Points (1, 2, 3, 5, 8)

---

## EPIC 1: Core Database, Infrastructure & Auth Setup

### [DB-001]: Design & Migrate Core PostgreSQL Schema
**Epic Category:** EPIC 1: Database & Infra

**User Story:**
As a backend developer, I want a normalized, versioned PostgreSQL schema for sources, articles, summaries, signals, user_preferences, and bookmarks so that both ingestion and API systems share a single reliable data contract.

**Technical Tasks / Sub-tasks:**
- [ ] Define `sources` table (id, name, rss_url, category, is_active, last_fetched_at)
- [ ] Define `articles` table (id, source_id FK, canonical_url, content_hash, title, cleaned_html, published_at, created_at)
- [ ] Define `summaries` table (id, article_id FK, summary_type enum, content, model_version, created_at)
- [ ] Define `signals` table (id, article_id FK, platform enum[hn|reddit], score, comment_count, permalink, fetched_at)
- [ ] Define `user_preferences` table (user_id FK to Supabase auth.users, tags[], notification_opt_in, theme_pref)
- [ ] Define `bookmarks` table (id, user_id FK, article_id FK, created_at, synced boolean)
- [ ] Add composite unique constraints (`articles.canonical_url`, `articles.content_hash`)
- [ ] Add indexes on `articles.published_at`, `signals.article_id`, `bookmarks.user_id`
- [ ] Write initial Alembic migration and seed script for `sources`

**Acceptance Criteria (Gherkin):**
```
Given a fresh PostgreSQL instance
When the initial Alembic migration is applied
Then all six core tables exist with correct types, foreign keys, and constraints

Given two articles with an identical canonical_url
When a second insert is attempted
Then the database rejects it via the unique constraint
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: None (foundational ticket)

---

### [DB-002]: Configure Supabase Auth & JWT Verification Middleware
**Epic Category:** EPIC 1: Database & Infra

**User Story:**
As an API developer, I want FastAPI to verify Supabase-issued JWTs on protected routes so that only authenticated users can access personal data like bookmarks and preferences.

**Technical Tasks / Sub-tasks:**
- [ ] Configure Supabase project auth settings (email/OAuth providers)
- [ ] Add `python-jose`/`PyJWT` dependency and Supabase JWKS fetch utility
- [ ] Build FastAPI dependency `get_current_user()` that validates signature, expiry, and audience
- [ ] Cache JWKS keys in-memory with TTL refresh
- [ ] Apply middleware/dependency to all user-scoped routers
- [ ] Return standardized 401/403 error payloads on invalid/expired tokens

**Acceptance Criteria (Gherkin):**
```
Given a request to a protected endpoint with a valid Supabase JWT
When the middleware verifies the token
Then the request proceeds and `current_user.id` is injected into the route handler

Given a request with an expired or tampered JWT
When the middleware attempts verification
Then the API responds with 401 Unauthorized and no data is leaked
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: DB-001

---

### [DB-003]: Provision Redis Instance & Build Cache Key Helper Module
**Epic Category:** EPIC 1: Database & Infra

**User Story:**
As a backend developer, I want a standardized Redis connection and cache-key naming convention so that all caching logic across the app is consistent and collision-free.

**Technical Tasks / Sub-tasks:**
- [ ] Provision Redis (local Docker container for dev, Upstash for prod)
- [ ] Add async Redis client (`redis.asyncio`) with connection pooling
- [ ] Build `cache_keys.py` helper with functions: `summary_key(article_id, summary_type)`, `feed_key(page, tags)`
- [ ] Define default TTLs per cache type (e.g., summaries: 7d, feed pages: 5m)
- [ ] Add health-check endpoint `/health/redis`
- [ ] Write unit tests for key generation determinism

**Acceptance Criteria (Gherkin):**
```
Given the FastAPI app starts up
When it attempts to connect to Redis
Then the connection pool initializes successfully and /health/redis returns 200

Given two identical summary requests for the same article and summary_type
When cache keys are generated
Then both calls produce an identical Redis key string
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 3
- Dependencies: None

---

### [DB-004]: Implement Row-Level Security (RLS) Policies for User-Scoped Tables
**Epic Category:** EPIC 1: Database & Infra

**User Story:**
As a security-conscious engineer, I want PostgreSQL RLS policies on `bookmarks` and `user_preferences` so that users can only ever read or modify their own data, even if API-layer checks are bypassed.

**Technical Tasks / Sub-tasks:**
- [ ] Enable RLS on `bookmarks` and `user_preferences` tables
- [ ] Write policy: `USING (auth.uid() = user_id)` for SELECT/UPDATE/DELETE
- [ ] Write policy: `WITH CHECK (auth.uid() = user_id)` for INSERT
- [ ] Configure Supabase service-role bypass for ingestion/admin jobs only
- [ ] Add integration tests using two distinct test users to confirm isolation

**Acceptance Criteria (Gherkin):**
```
Given User A and User B each have bookmarks
When User A queries the bookmarks endpoint
Then only User A's rows are returned, even with a crafted request for User B's user_id

Given an unauthenticated service role connection
When it performs an ingestion write
Then RLS does not block the operation
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 3
- Dependencies: DB-001, DB-002

---

### [DB-005]: Set Up Alembic Migration Pipeline & CI Schema Validation
**Epic Category:** EPIC 1: Database & Infra

**User Story:**
As a lead developer, I want an automated migration pipeline validated in CI so that schema drift between environments is caught before deployment.

**Technical Tasks / Sub-tasks:**
- [ ] Configure Alembic `env.py` to read connection string from environment variables
- [ ] Add `alembic upgrade head` step to CI pipeline against an ephemeral test DB
- [ ] Add pre-commit hook to flag missing migrations when models change
- [ ] Document migration workflow in `CONTRIBUTING.md`

**Acceptance Criteria (Gherkin):**
```
Given a pull request that modifies a SQLAlchemy model without a matching migration
When CI runs
Then the pipeline fails with a clear "missing migration" error

Given a clean CI database
When `alembic upgrade head` runs
Then all migrations apply without error in sequential order
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 2
- Dependencies: DB-001

---

## EPIC 2: System A — Background Ingestion Pipeline

### [ING-001]: Build APScheduler Cron Worker Service
**Epic Category:** EPIC 2: Background Ingestion

**User Story:**
As a system operator, I want a scheduled background worker that triggers ingestion on a fixed interval so that fresh articles are pulled without manual intervention.

**Technical Tasks / Sub-tasks:**
- [ ] Add APScheduler `AsyncIOScheduler` as a FastAPI lifespan-managed background process
- [ ] Configure interval trigger (e.g., every 15 minutes) pulling active `sources`
- [ ] Add job locking (Redis-based) to prevent overlapping runs
- [ ] Expose `/admin/ingestion/trigger` for manual/manual-test runs
- [ ] Log job start/end timestamps and article counts processed

**Acceptance Criteria (Gherkin):**
```
Given the FastAPI app is running
When the scheduler's interval elapses
Then the ingestion job fires exactly once, even under concurrent app workers

Given an ingestion job is already running
When the interval trigger fires again
Then the new run is skipped and logged as "locked"
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 3
- Dependencies: DB-001, DB-003

---

### [ING-002]: Implement RSS Feed Fetcher with Async HTTP Client
**Epic Category:** EPIC 2: Background Ingestion

**User Story:**
As the ingestion system, I want to asynchronously fetch and parse RSS feeds from all active sources so that new article metadata is discovered efficiently at scale.

**Technical Tasks / Sub-tasks:**
- [ ] Use `httpx.AsyncClient` with connection pooling and timeout config
- [ ] Integrate `feedparser` for RSS/Atom parsing
- [ ] Fetch feeds concurrently via `asyncio.gather` with a semaphore to cap concurrency
- [ ] Handle malformed/unreachable feeds gracefully (log + skip, don't crash job)
- [ ] Update `sources.last_fetched_at` on success

**Acceptance Criteria (Gherkin):**
```
Given 20 active RSS sources
When the fetcher runs
Then all reachable feeds are fetched concurrently within the configured timeout

Given a source returns a malformed XML feed
When parsing fails
Then the error is logged, the source is skipped, and the job continues for remaining sources
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: ING-001

---

### [ING-003]: Integrate Readability-Based HTML Content Cleaner
**Epic Category:** EPIC 2: Background Ingestion

**User Story:**
As a reader, I want article content stripped of ads, navigation, and clutter so that I get a clean, readable article body in the app.

**Technical Tasks / Sub-tasks:**
- [ ] Set up a Node.js microservice (or subprocess bridge) wrapping `@mozilla/readability`
- [ ] Define request/response contract: raw HTML in → `{title, byline, cleaned_html, excerpt}` out
- [ ] Call the cleaner from the Python ingestion worker via HTTP or subprocess
- [ ] Add fallback: if readability extraction fails, store raw excerpt from RSS description
- [ ] Sanitize output HTML (strip scripts/styles) before persistence

**Acceptance Criteria (Gherkin):**
```
Given a full raw HTML article page
When it is passed through the readability cleaner
Then the response contains a cleaned_html field free of nav/ads/script tags

Given the readability service is unreachable
When cleaning is attempted
Then the pipeline falls back to the RSS description without failing the whole job
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 8
- Dependencies: ING-002

---

### [ING-004]: Implement Canonical URL & SHA-256 Content Deduplication
**Epic Category:** EPIC 2: Background Ingestion

**User Story:**
As a system maintainer, I want duplicate articles (same story from multiple feeds or re-published URLs) filtered out so that users never see repeated content in their feed.

**Technical Tasks / Sub-tasks:**
- [ ] Normalize incoming URLs (strip tracking params, enforce lowercase host, trailing slash rules) to derive `canonical_url`
- [ ] Compute SHA-256 hash of cleaned article text as `content_hash`
- [ ] Query existing `articles` table for matches on either field before insert
- [ ] Add unit tests covering near-duplicate cases (same content, different query params)
- [ ] Add metrics counter for "duplicates skipped per run"

**Acceptance Criteria (Gherkin):**
```
Given two RSS sources publish the same article with different tracking query parameters
When both are ingested
Then only one row exists in `articles` after canonical URL normalization

Given an article's content hash matches an existing row exactly
When ingestion attempts to insert it again
Then the insert is skipped and logged as a duplicate
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: ING-002, ING-003, DB-001

---

### [ING-005]: Persist Parsed Articles to PostgreSQL with Source Metadata
**Epic Category:** EPIC 2: Background Ingestion

**User Story:**
As the ingestion system, I want cleaned, deduplicated articles written to PostgreSQL with full source attribution so that downstream API consumers have complete, queryable records.

**Technical Tasks / Sub-tasks:**
- [ ] Build async SQLAlchemy repository `ArticleRepository.bulk_upsert()`
- [ ] Map RSS + readability output fields to the `articles` schema
- [ ] Wrap writes in a transaction per source to avoid partial-batch corruption
- [ ] Emit a "new article" event (e.g., to a Redis pub/sub channel) for future notification hooks
- [ ] Add structured logging for insert counts per run

**Acceptance Criteria (Gherkin):**
```
Given a batch of 10 newly parsed, deduplicated articles
When persistence runs
Then all 10 rows are committed atomically and visible via the articles table

Given a database write fails mid-batch for one source
When the transaction rolls back
Then no partial rows for that source are persisted, and other sources are unaffected
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 3
- Dependencies: ING-004

---

### [ING-006]: Ingestion Pipeline Error Handling & Dead-Letter Logging
**Epic Category:** EPIC 2: Background Ingestion

**User Story:**
As a system operator, I want failed ingestion items captured in a dead-letter log rather than silently dropped so that I can diagnose and reprocess problematic sources.

**Technical Tasks / Sub-tasks:**
- [ ] Wrap each pipeline stage (fetch, clean, dedupe, persist) in scoped try/except
- [ ] Write failures to a `ingestion_failures` table (source_id, stage, error_message, raw_payload, created_at)
- [ ] Add retry-with-backoff (max 3 attempts) for transient network errors
- [ ] Build `/admin/ingestion/failures` endpoint to list recent failures
- [ ] Alert (log-level CRITICAL) if a single source fails 3 consecutive scheduled runs

**Acceptance Criteria (Gherkin):**
```
Given a source's feed URL times out
When the fetch stage fails after 3 retries
Then a row is written to ingestion_failures with stage="fetch" and the error detail

Given a source has failed 3 consecutive scheduled runs
When the 3rd failure is logged
Then a CRITICAL-level alert log entry is emitted
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 3
- Dependencies: ING-001, ING-005

---

## EPIC 3: System B — On-Demand API & AI Caching Engine

### [API-001]: Build Paginated Feed Endpoint with Tag Filtering
**Epic Category:** EPIC 3: API & AI Engine

**User Story:**
As a mobile user, I want to fetch a paginated, filterable article feed so that I can browse tech news by topic without long load times.

**Technical Tasks / Sub-tasks:**
- [ ] Build `GET /feed` with query params: `page`, `page_size`, `tags[]`, `source_id`
- [ ] Implement cursor-based or offset-based pagination on `articles.published_at`
- [ ] Add Redis caching for common queries via `feed_key()` helper (DB-003)
- [ ] Return lightweight DTOs (id, title, excerpt, source, published_at, thumbnail) — not full HTML body
- [ ] Add response schema validation with Pydantic models

**Acceptance Criteria (Gherkin):**
```
Given 200 articles exist across 5 tags
When a client requests GET /feed?tags=ai&page=1&page_size=20
Then exactly 20 AI-tagged articles are returned, sorted by most recent

Given the same feed query is requested twice within the cache TTL window
When the second request arrives
Then it is served from Redis without hitting PostgreSQL
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: DB-001, DB-002, DB-003

---

### [API-002]: Implement 3-Tier AI Summarization Pipeline (Redis → Postgres → Gemini)
**Epic Category:** EPIC 3: API & AI Engine

**User Story:**
As a user, I want AI-generated article summaries to load instantly on repeat requests so that I don't wait on expensive LLM calls for content that's already been summarized.

**Technical Tasks / Sub-tasks:**
- [ ] Build `SummaryService.get_summary(article_id, summary_type)` orchestrator
- [ ] Tier 1: check Redis via `summary_key()`; return immediately on hit
- [ ] Tier 2: on Redis miss, query `summaries` table in Postgres; populate Redis on hit
- [ ] Tier 3: on full miss, call Gemini API with the article's cleaned content + prompt template, persist to Postgres, then populate Redis
- [ ] Add request-level in-flight de-duplication (prevent duplicate concurrent Gemini calls for the same article+type)
- [ ] Add timeout/circuit breaker around Gemini calls with graceful error response

**Acceptance Criteria (Gherkin):**
```
Given a summary exists in Redis
When a request for that article_id and summary_type arrives
Then it is returned in under 50ms with no Postgres or Gemini call

Given a summary exists in Postgres but not Redis
When requested
Then it is returned from Postgres and Redis is backfilled for future requests

Given no summary exists in either cache layer
When requested
Then Gemini is called once, the result is persisted to Postgres and Redis, and returned to the client

Given two identical concurrent requests for an uncached summary
When both arrive simultaneously
Then only one Gemini API call is made and both requests receive the same result
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 8
- Dependencies: DB-001, DB-003, ING-005

---

### [API-003]: Build Preset Summary Query Router
**Epic Category:** EPIC 3: API & AI Engine

**User Story:**
As a user, I want to choose between preset summary styles (core summary, explain simpler, why it matters, risk analysis) so that I can consume an article at the depth and angle I need.

**Technical Tasks / Sub-tasks:**
- [ ] Define `SummaryType` enum: `core_summary`, `explain_simpler`, `why_it_matters`, `risk_analysis`
- [ ] Build a prompt template registry mapping each enum value to a distinct Gemini system prompt
- [ ] Build `POST /articles/{id}/summary` endpoint accepting `summary_type` in the body
- [ ] Validate summary_type against the enum, returning 422 on invalid values
- [ ] Version prompt templates (`model_version` / `prompt_version` field) for future tuning

**Acceptance Criteria (Gherkin):**
```
Given a request with summary_type="risk_analysis"
When the router processes it
Then the risk_analysis-specific prompt template is used for the Gemini call

Given a request with an invalid summary_type value
When the endpoint validates the payload
Then it returns HTTP 422 with a descriptive validation error
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 3
- Dependencies: API-002

---

### [API-004]: Integrate Algolia Hacker News Search API for Community Signals
**Epic Category:** EPIC 3: API & AI Engine

**User Story:**
As a user, I want to see how the Hacker News community is discussing an article so that I can gauge community reception before diving deeper.

**Technical Tasks / Sub-tasks:**
- [ ] Integrate Algolia HN Search API (`https://hn.algolia.com/api/v1/search`) by canonical URL match
- [ ] Build `SignalService.fetch_hn_signal(article_url)` with response mapping to `signals` table
- [ ] Cache HN signal lookups in Redis (short TTL, e.g., 30 min) to respect rate limits
- [ ] Handle "no discussion found" case gracefully (return null signal, not an error)
- [ ] Add scheduled background refresh for trending articles' signal counts

**Acceptance Criteria (Gherkin):**
```
Given an article has a matching Hacker News discussion thread
When the signal service queries Algolia
Then score, comment_count, and permalink are persisted to the signals table

Given an article has no HN discussion
When the signal lookup runs
Then the API returns a null/empty signal object without throwing an error
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 3
- Dependencies: DB-001, DB-003

---

### [API-005]: Integrate Reddit JSON Signal Lookup Service
**Epic Category:** EPIC 3: API & AI Engine

**User Story:**
As a user, I want to see relevant Reddit discussion activity for an article so that I get a broader sense of community reaction beyond Hacker News.

**Technical Tasks / Sub-tasks:**
- [ ] Query Reddit's public JSON search endpoint (`/search.json?q=<url>`) with a proper User-Agent header
- [ ] Parse top matching post's subreddit, score, and comment count into the `signals` table
- [ ] Apply Redis caching identical in structure to API-004
- [ ] Implement basic rate-limit backoff handling for Reddit's 429 responses
- [ ] Merge HN + Reddit signals into a single `GET /articles/{id}/signals` response

**Acceptance Criteria (Gherkin):**
```
Given an article has a matching Reddit thread
When the signal service queries Reddit's JSON endpoint
Then subreddit, score, and comment_count are persisted and returned

Given Reddit responds with HTTP 429
When the lookup is retried
Then the service backs off exponentially and does not crash the request
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 3
- Dependencies: API-004

---

### [API-006]: Build Bookmarks CRUD API with RLS Enforcement
**Epic Category:** EPIC 3: API & AI Engine

**User Story:**
As a logged-in user, I want to save, view, and remove bookmarked articles so that I can revisit content later.

**Technical Tasks / Sub-tasks:**
- [ ] Build `POST /bookmarks`, `GET /bookmarks`, `DELETE /bookmarks/{id}` endpoints
- [ ] Enforce `current_user` dependency (DB-002) on all routes
- [ ] Rely on RLS policies (DB-004) as the authoritative access boundary
- [ ] Return joined article summary data in `GET /bookmarks` (avoid N+1 queries)
- [ ] Add idempotency check to prevent duplicate bookmarks of the same article

**Acceptance Criteria (Gherkin):**
```
Given an authenticated user bookmarks an article
When they call GET /bookmarks
Then the article appears in the response with its core metadata

Given a user attempts to bookmark an article they've already bookmarked
When POST /bookmarks is called again
Then the API returns the existing bookmark instead of creating a duplicate
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 3
- Dependencies: DB-002, DB-004, API-001

---

### [API-007]: Build User Preferences CRUD API
**Epic Category:** EPIC 3: API & AI Engine

**User Story:**
As a user, I want to set my preferred tech topics and theme so that my feed and app experience are personalized.

**Technical Tasks / Sub-tasks:**
- [ ] Build `GET /preferences` and `PUT /preferences` endpoints
- [ ] Validate `tags[]` against the known tag/category list
- [ ] Persist `theme_pref` (light/dark/system) and `notification_opt_in`
- [ ] Wire preference `tags[]` into the `/feed` default filter when no explicit tags are passed
- [ ] Add default preference auto-creation on first login (trigger or app-side upsert)

**Acceptance Criteria (Gherkin):**
```
Given a first-time authenticated user with no preferences row
When GET /preferences is called
Then a default preferences record is created and returned

Given a user updates their preferred tags via PUT /preferences
When they subsequently call GET /feed with no tag filter
Then results are scoped to their preferred tags
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 2
- Dependencies: DB-002, DB-004

---

## EPIC 4: Flutter Frontend & UI Implementation

### [UI-001]: Implement Editorial Theme System (Light/Dark Obsidian Mode)
**Epic Category:** EPIC 4: Flutter UI & State

**User Story:**
As a user, I want a polished, editorial-style visual theme with a true dark "obsidian" mode so that the app feels premium and is comfortable to read in any lighting.

**Technical Tasks / Sub-tasks:**
- [ ] Define `AppTheme` with `ThemeData.light()` and `ThemeData.dark()` (obsidian palette: near-black surfaces, high-contrast type)
- [ ] Select and configure editorial typography (serif/sans pairing) via `google_fonts`
- [ ] Build a `ThemeModeProvider` (Riverpod) synced with `preferenceProvider` (UI-003)
- [ ] Implement smooth theme-transition animation on toggle
- [ ] Document design tokens (spacing, radii, elevation) referencing the "News app uix" Dribbble concept

**Acceptance Criteria (Gherkin):**
```
Given a user toggles dark mode in settings
When the theme provider updates
Then the entire app repaints in obsidian dark theme without requiring a restart

Given a user's theme_pref is stored as "dark" in preferences
When the app launches
Then it loads directly into dark mode without a light-mode flash
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 3
- Dependencies: None (can start in parallel once design tokens are ready)

---

### [UI-002]: Build Dribbble-Inspired Article Feed Card Component
**Epic Category:** EPIC 4: Flutter UI & State

**User Story:**
As a user, I want visually rich, scannable article cards in my feed so that I can quickly judge relevance before tapping in.

**Technical Tasks / Sub-tasks:**
- [ ] Build reusable `ArticleCard` widget (thumbnail, source badge, title, excerpt, published time, signal badges)
- [ ] Implement responsive layout variants (compact list vs. large hero card for top story)
- [ ] Add skeleton/shimmer loading state for cards while feed data loads
- [ ] Wire tap-to-navigate to article detail screen
- [ ] Add subtle entrance animation (staggered fade/slide) matching the editorial design reference

**Acceptance Criteria (Gherkin):**
```
Given the feed screen is loading data
When the network request is in flight
Then shimmer placeholder cards are shown instead of a blank screen

Given feed data has loaded
When the list renders
Then each ArticleCard displays title, source, excerpt, and timestamp correctly bound to its article
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: UI-001

---

### [UI-003]: Set Up Riverpod State Providers
**Epic Category:** EPIC 4: Flutter UI & State

**User Story:**
As a Flutter developer, I want centralized, testable Riverpod providers for feed, summary, bookmark, and preference state so that UI widgets stay declarative and business logic stays decoupled.

**Technical Tasks / Sub-tasks:**
- [ ] Build `feedProvider` (AsyncNotifier) handling pagination state and refresh
- [ ] Build `summaryProvider` (family provider keyed by article_id + summary_type)
- [ ] Build `bookmarkProvider` managing bookmark set + optimistic UI updates
- [ ] Build `preferenceProvider` syncing local state with `/preferences` API
- [ ] Add provider-level error and loading state handling (`AsyncValue.when`)
- [ ] Write unit tests for each provider using `ProviderContainer` mocks

**Acceptance Criteria (Gherkin):**
```
Given feedProvider is watched by the feed screen
When the user pulls to refresh
Then feedProvider re-fetches page 1 and the UI reflects the new AsyncValue.loading then .data states

Given a user taps "bookmark" on an article
When bookmarkProvider updates optimistically
Then the UI reflects the bookmarked state immediately, before the API call resolves
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: API-001, API-006, API-007, UI-004

---

### [UI-004]: Integrate Dio Networking Layer with Interceptors
**Epic Category:** EPIC 4: Flutter UI & State

**User Story:**
As a Flutter developer, I want a centralized Dio client with auth and error-handling interceptors so that every network call consistently attaches auth tokens and handles failures.

**Technical Tasks / Sub-tasks:**
- [ ] Configure a singleton `Dio` instance with base URL and timeouts
- [ ] Add auth interceptor injecting the Supabase session JWT into headers
- [ ] Add response interceptor for standardized error mapping (network/timeout/4xx/5xx)
- [ ] Add automatic token refresh on 401 with request retry
- [ ] Add logging interceptor gated behind debug builds only

**Acceptance Criteria (Gherkin):**
```
Given a valid Supabase session exists
When any API request is made through the Dio client
Then the Authorization header is automatically populated with the current JWT

Given an API call returns 401 due to an expired token
When the interceptor catches it
Then the session is refreshed and the original request is retried once automatically
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 3
- Dependencies: DB-002

---

### [UI-005]: Build Draggable AI Summary Bottom Sheet with Preset Query Buttons
**Epic Category:** EPIC 4: Flutter UI & State

**User Story:**
As a user, I want to drag up a bottom sheet from an article and tap preset buttons (core summary, explain simpler, why it matters, risk analysis) so that I can get the right kind of AI insight without leaving the article view.

**Technical Tasks / Sub-tasks:**
- [ ] Implement `DraggableScrollableSheet` anchored to the article detail screen
- [ ] Build preset button row bound to the `SummaryType` enum (mirrors API-003)
- [ ] Wire button taps to `summaryProvider` and display loading/typing-indicator state during Gemini calls
- [ ] Render Markdown-formatted summary content in the sheet body
- [ ] Persist last-selected preset per article session for quick re-open
- [ ] Add haptic feedback on drag snap points

**Acceptance Criteria (Gherkin):**
```
Given a user is viewing an article
When they drag the bottom sheet handle upward
Then the sheet expands smoothly to reveal the four preset summary buttons

Given a user taps "Why It Matters"
When the request is in flight
Then a loading indicator is shown in the sheet, replaced by the rendered summary on completion
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: UI-003, API-003

---

### [UI-006]: Integrate Native Text-to-Speech Playback Control
**Epic Category:** EPIC 4: Flutter UI & State

**User Story:**
As a user, I want to have an article or its AI summary read aloud so that I can consume content hands-free while multitasking.

**Technical Tasks / Sub-tasks:**
- [ ] Integrate `flutter_tts` package with platform-specific setup (iOS/Android)
- [ ] Build a `TtsController` (Riverpod) managing play/pause/stop state
- [ ] Add a floating audio control button on article detail and summary sheet
- [ ] Handle text chunking for long articles to avoid TTS engine truncation
- [ ] Sync TTS highlight/progress indicator with currently spoken sentence (stretch)
- [ ] Handle interruption events gracefully (phone call, other audio app)

**Acceptance Criteria (Gherkin):**
```
Given a user taps the TTS play button on an article
When playback starts
Then the button state changes to "pause" and audio begins reading the cleaned article text

Given a phone call interrupts playback
When the interruption ends
Then TTS playback pauses gracefully and does not crash or restart from the beginning unexpectedly
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 5
- Dependencies: UI-005

---

## EPIC 5: Offline Mode, Storage & System Polish

### [OFF-001]: Implement Hive Box for Feed Snapshot Caching
**Epic Category:** EPIC 5: Offline & Native

**User Story:**
As a user with unreliable connectivity, I want my last-loaded feed cached locally so that I can still browse recent articles when offline.

**Technical Tasks / Sub-tasks:**
- [ ] Define Hive TypeAdapters for `ArticleModel` and register them at app startup
- [ ] Open a `feed_cache` Hive box and persist the latest successful feed page(s)
- [ ] Update `feedProvider` (UI-003) to fall back to Hive data on network failure
- [ ] Add a visible "offline — showing cached feed" banner in the UI
- [ ] Implement cache eviction/refresh policy (e.g., keep last 100 articles, replace on successful fetch)

**Acceptance Criteria (Gherkin):**
```
Given the device has previously loaded a feed successfully
When the device goes offline and the feed screen is reopened
Then cached articles from Hive are displayed with an "offline" indicator banner

Given the device reconnects to the network
When the feed is refreshed
Then live data replaces the cached snapshot and the Hive box is updated
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 5
- Dependencies: UI-003

---

### [OFF-002]: Build Offline Action Queue for Bookmarks with Auto-Sync
**Epic Category:** EPIC 5: Offline & Native

**User Story:**
As a user, I want to bookmark articles while offline and have those actions automatically sync once I reconnect so that I never lose an action due to poor connectivity.

**Technical Tasks / Sub-tasks:**
- [ ] Define a `PendingAction` Hive model (action_type, article_id, timestamp, status)
- [ ] Queue bookmark add/remove actions locally when a network call fails
- [ ] Implement a `connectivity_plus` listener that triggers queue flush on reconnect
- [ ] Process queued actions sequentially against `bookmarkProvider`/API-006, handling conflicts (already-exists, already-deleted)
- [ ] Mark actions as `synced` or `failed` and surface failures subtly in a "sync issues" UI state
- [ ] Add exponential backoff retry for repeated sync failures

**Acceptance Criteria (Gherkin):**
```
Given the device is offline
When a user bookmarks an article
Then the action is queued locally in Hive and the UI reflects the bookmark optimistically

Given the device regains network connectivity
When the connectivity listener fires
Then all queued bookmark actions are sent to the API in order and marked synced on success

Given a queued "remove bookmark" action targets a bookmark that no longer exists server-side
When sync is attempted
Then the conflict is resolved gracefully (treated as success) without crashing the sync process
```

**Dependencies & Complexity:**
- Priority: High
- Effort: 8
- Dependencies: OFF-001, API-006, UI-003

---

### [OFF-003]: Implement Backend Rate Limiting with slowapi
**Epic Category:** EPIC 5: Offline & Native

**User Story:**
As a system operator, I want per-user and per-IP rate limiting on the API so that the service is protected from abuse and excessive Gemini API cost exposure.

**Technical Tasks / Sub-tasks:**
- [ ] Integrate `slowapi` middleware into the FastAPI app
- [ ] Apply stricter limits on cost-sensitive routes (`/articles/{id}/summary`) vs. general read routes
- [ ] Key rate limits by authenticated `user_id` where available, falling back to IP for anonymous routes
- [ ] Return standardized 429 responses with `Retry-After` headers
- [ ] Add configuration via environment variables for per-environment tuning (dev vs. prod limits)

**Acceptance Criteria (Gherkin):**
```
Given a user exceeds the configured summary-request rate limit
When they make an additional request within the window
Then the API returns HTTP 429 with a Retry-After header

Given normal usage within limits
When requests are made to /feed
Then no rate-limit rejections occur
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 2
- Dependencies: API-002, DB-002

---

### [OFF-004]: End-to-End Integration Testing Suite
**Epic Category:** EPIC 5: Offline & Native

**User Story:**
As a lead developer, I want an automated end-to-end test suite covering ingestion, API, and critical Flutter flows so that regressions are caught before release.

**Technical Tasks / Sub-tasks:**
- [ ] Set up `pytest` + `httpx.AsyncClient` integration tests against a test database for API-001, API-002, API-006
- [ ] Add an ingestion pipeline integration test using mocked RSS feeds and a mocked readability service
- [ ] Set up Flutter `integration_test` covering: login → feed load → open article → request summary → bookmark → go offline → verify cached feed
- [ ] Wire all test suites into CI (GitHub Actions) with test DB and Redis service containers
- [ ] Add coverage reporting threshold gate (e.g., minimum 70% on core services)

**Acceptance Criteria (Gherkin):**
```
Given the full CI pipeline runs on a pull request
When backend and Flutter integration tests execute
Then all critical-path tests (ingestion, summarization, bookmarking, offline fallback) pass before merge is allowed

Given a code change breaks the offline fallback flow
When the Flutter integration test suite runs
Then the relevant test fails and blocks the CI pipeline
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 8
- Dependencies: ING-005, API-002, API-006, OFF-001, OFF-002

---

### [OFF-005]: Global Error Handling & Offline/Online State Indicators
**Epic Category:** EPIC 5: Offline & Native

**User Story:**
As a user, I want clear, consistent feedback when something goes wrong or when I'm offline so that I always understand the app's current state rather than seeing a blank screen or silent failure.

**Technical Tasks / Sub-tasks:**
- [ ] Build a global `ConnectivityBanner` widget reacting to `connectivity_plus` status changes
- [ ] Standardize error UI states (empty state, network error, server error, timeout) as reusable widgets
- [ ] Add a global Riverpod error observer/logger for uncaught provider exceptions
- [ ] Map backend error codes (from UI-004's Dio interceptor) to user-friendly messages
- [ ] Add retry affordance ("Tap to retry") on all failed-state widgets

**Acceptance Criteria (Gherkin):**
```
Given the device loses network connectivity
When connectivity_plus reports the change
Then a persistent banner appears across the app indicating offline status

Given an API call fails with a 500 error
When the relevant provider catches the exception
Then a standardized error widget is shown with a "Tap to retry" action instead of a blank or crashed screen
```

**Dependencies & Complexity:**
- Priority: Medium
- Effort: 3
- Dependencies: UI-004, OFF-001

---

## Summary Table

| Ticket ID | Title | Epic | Priority | Effort |
|---|---|---|---|---|
| DB-001 | Design & Migrate Core PostgreSQL Schema | 1 | High | 5 |
| DB-002 | Supabase Auth & JWT Middleware | 1 | High | 5 |
| DB-003 | Redis Instance & Cache Key Helpers | 1 | High | 3 |
| DB-004 | RLS Policies for User-Scoped Tables | 1 | High | 3 |
| DB-005 | Alembic Pipeline & CI Schema Validation | 1 | Medium | 2 |
| ING-001 | APScheduler Cron Worker Service | 2 | High | 3 |
| ING-002 | RSS Feed Fetcher (Async) | 2 | High | 5 |
| ING-003 | Readability HTML Content Cleaner | 2 | High | 8 |
| ING-004 | URL/Hash Deduplication Logic | 2 | High | 5 |
| ING-005 | Persist Articles to PostgreSQL | 2 | High | 3 |
| ING-006 | Ingestion Error Handling & Dead-Letter Log | 2 | Medium | 3 |
| API-001 | Paginated Feed Endpoint w/ Tag Filters | 3 | High | 5 |
| API-002 | 3-Tier AI Summarization Pipeline | 3 | High | 8 |
| API-003 | Preset Summary Query Router | 3 | High | 3 |
| API-004 | Algolia HN Signal Integration | 3 | Medium | 3 |
| API-005 | Reddit JSON Signal Integration | 3 | Medium | 3 |
| API-006 | Bookmarks CRUD API + RLS | 3 | High | 3 |
| API-007 | Preferences CRUD API | 3 | Medium | 2 |
| UI-001 | Editorial Theme System (Obsidian Dark) | 4 | High | 3 |
| UI-002 | Dribbble-Inspired Feed Card | 4 | High | 5 |
| UI-003 | Riverpod State Providers | 4 | High | 5 |
| UI-004 | Dio Networking Layer + Interceptors | 4 | High | 3 |
| UI-005 | Draggable AI Summary Bottom Sheet | 4 | High | 5 |
| UI-006 | Native TTS Playback Control | 4 | Medium | 5 |
| OFF-001 | Hive Feed Snapshot Caching | 5 | High | 5 |
| OFF-002 | Offline Bookmark Action Queue + Auto-Sync | 5 | High | 8 |
| OFF-003 | Backend Rate Limiting (slowapi) | 5 | Medium | 2 |
| OFF-004 | End-to-End Integration Testing Suite | 5 | Medium | 8 |
| OFF-005 | Global Error Handling & Connectivity UI | 5 | Medium | 3 |

**Total Story Points: 118** — sized for planning across multiple 2-week sprints depending on team velocity.
