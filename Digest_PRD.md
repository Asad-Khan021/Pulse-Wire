**DIGEST**

AI-Powered Cross-Platform Technology News Application

*Product Requirements Document*

  ---------------------------- ------------------------------------------
  **Document Version**         1.0 (Initial Release)

  **Date**                     September 12, 2026

  **Project Type**             Final Year Software Engineering Project

  **Platform**                 Flutter (iOS / Android), FastAPI Backend

  **Status**                   Approved for Implementation

  **Classification**           Academic / Internal Use
  ---------------------------- ------------------------------------------

1\. Document Control & Executive Summary

1.1 Document Control

  -----------------------------------------------------------------------
  **Field**             **Detail**
  --------------------- -------------------------------------------------
  Author                Product & Engineering (Solo Developer, FYP)

  Reviewers             Academic Supervisor / Final Year Project Panel

  Revision History      v1.0 --- Initial comprehensive PRD

  Distribution          Development team (self), academic examiners,
                        project supervisor

  Related Documents     System Architecture Diagram, Database ERD, API
                        Swagger/OpenAPI spec (generated from FastAPI)
  -----------------------------------------------------------------------

1.2 Executive Summary

Digest is a cross-platform mobile application that aggregates real-time
technology news from curated RSS sources, algorithmically removes
advertising and navigational clutter from article bodies, and augments
each article with AI-generated summaries, guided interactive Q&A, and
community discussion signals sourced from Hacker News and Reddit. The
system is architected specifically to operate entirely within free-tier
infrastructure limits (Google Gemini API, Upstash Redis, Supabase,
Algolia HN Search) while remaining horizontally scalable if migrated to
paid tiers post-graduation.

The defining engineering constraint of this project is cost-bounded AI
usage. Rather than exposing an open-ended conversational interface per
article --- which would create unbounded, non-cacheable API consumption
--- Digest restricts AI interactivity to a fixed set of pre-defined
\"angles\" (core summary, simplified explanation, significance framing,
and risk framing). Because the question space is finite and
deterministic per article, the system achieves a high cache-hit ratio
via a three-tier caching strategy (Redis → PostgreSQL → Gemini), meaning
the marginal cost of serving the 1,000th reader of an article approaches
zero.

This document defines the complete product scope, functional and
non-functional requirements, data architecture, API contract, mobile
application architecture, and phased delivery roadmap required to
design, build, and evaluate the system as a final year project.

1.3 Scope Boundaries

-   In scope: RSS ingestion and cleaning, card-based feed UI, AI
    summarization with 4 fixed angles, HN/Reddit community signal
    display, on-device TTS, tag/domain personalization, bookmarking, and
    offline card caching.

-   Out of scope (v1.0): open-ended free-text AI chat, push
    notifications, social features (comments, sharing between users),
    web/desktop clients, multi-language summarization, and monetization.

-   Explicitly deferred to a stretch/Phase 5 backlog: free-text chat
    with per-user rate limiting, reading streak gamification, and
    dark-mode theming.

2\. Product Goals & Objectives

2.1 Problem Statement

Technology news consumption today is fragmented across dozens of
publisher websites, each cluttered with ads, auto-playing media, and
paywall prompts. Readers who want to stay current on developments across
AI, cybersecurity, and DevOps must either subscribe to multiple sources
or rely on algorithmic aggregators (e.g. Google News) that optimize for
engagement rather than comprehension. There is no lightweight, free tool
that (a) consolidates multiple technical RSS sources, (b) reduces an
article to its essential meaning before the reader commits time to it,
and (c) surfaces whether the wider engineering community considers the
story significant --- all without requiring a paid subscription or
exposing the user\'s data to ad-tech.

2.2 Product Goals

1.  Deliver a single, unified feed of deduplicated technology news from
    multiple publishers, refreshed automatically without user-triggered
    polling.

2.  Reduce the time-to-comprehension of any article to under 15 seconds
    via AI-generated 3-bullet summaries, available in both text and
    audio form.

3.  Surface community validation signals (HN points, Reddit discussion)
    so users can gauge real-world significance before reading in full.

4.  Operate the entire product --- ingestion, AI inference, caching,
    auth, and storage --- within free-tier infrastructure limits
    indefinitely at moderate usage volumes.

5.  Support full offline reading of previously-loaded content, including
    summaries and bookmarks.

2.3 Key Performance Indicators (KPIs)

  -----------------------------------------------------------------------
  **KPI**                  **Target**         **Rationale**
  ------------------------ ------------------ ---------------------------
  Cache hit rate on        \> 90% after 2     Validates the cost-control
  summary requests         weeks of usage     thesis of the architecture

  Average                  \< 400ms           Perceived as instantaneous
  article-to-summary                          by the user
  latency (cache hit)                         

  Average                  \< 4s              Acceptable wait for a
  article-to-summary                          first-time Gemini call
  latency (cache miss)                        

  RSS ingestion success    \> 95% of active   Measures pipeline
  rate per cycle           sources per run    resilience to source
                                              failures

  Offline feed             100% of            Core reliability
  availability             last-synced        requirement, not
                           session            aspirational

  Gemini free-tier quota   Stay under daily   Hard operational constraint
  consumption              free-tier request  
                           cap                

  Crash-free session rate  \> 99%             Baseline mobile quality bar
  -----------------------------------------------------------------------

2.4 Target Audience

-   Primary: university students and early-career software engineers who
    want a fast, low-noise way to track AI, cybersecurity, and DevOps
    news.

-   Secondary: hobbyist developers and technology enthusiasts who follow
    Hacker News / Reddit but want a cleaner reading surface than either
    platform provides natively.

-   Tertiary (academic context): the project examiner/supervisor
    evaluating the system\'s architectural soundness, cost-awareness,
    and engineering completeness.

3\. User Personas & Key User Journeys

3.1 Persona: Ayesha --- The Time-Constrained CS Student

**Context:** Final-year Computer Science student, follows AI and DevOps
news between classes, has 5--10 minute windows to catch up.

**Goal:** Understand what happened in tech today without reading five
full articles.

**Frustration:** News apps are either full of clickbait or require too
much reading before the point becomes clear.

**Success looks like:** Opens the app, skims 8--10 cards, taps 2 for the
AI summary, bookmarks 1 for later, closes the app in under 3 minutes.

3.2 Persona: Bilal --- The Backend Engineer Tracking Security

**Context:** Working professional focused specifically on
#Cybersecurity, wants to filter out noise from other tags.

**Goal:** See only cybersecurity-tagged stories, and gauge which ones
are being seriously discussed on HN before spending time reading.

**Frustration:** Generic tech feeds bury security stories under generic
startup/funding news.

**Success looks like:** Sets a tag filter once, mutes two low-quality
domains, and thereafter only sees relevant, community-validated stories.

3.3 Key User Journeys

Journey 1 --- First-Time Onboarding

6.  User installs the app and signs up via Supabase Auth (email or
    OAuth).

7.  User is prompted to select initial topic tags of interest (#AI,
    #Cybersecurity, #DevOps, etc.).

8.  The feed loads, pre-filtered by selected tags; onboarding completes
    in under 60 seconds.

Journey 2 --- Daily Reading Session

9.  User opens the app; the feed loads from local Hive cache instantly,
    then refreshes silently from the API.

10. User scrolls the card feed, taps a card to expand the AI summary
    bottom sheet.

11. Summary bullets render (cache hit, near-instant). User taps \"Why
    does this matter?\" to get a second angle.

12. User taps the speaker icon to hear the summary while multitasking.

13. User bookmarks the article and continues scrolling.

Journey 3 --- Offline Commute Reading

14. User loses connectivity (e.g. subway commute).

15. App detects offline state and serves the last-synced Hive snapshot
    of cards, including cached summaries already viewed.

16. User bookmarks an article while offline; the action is queued
    locally.

17. On reconnect, the queued bookmark syncs to the backend automatically
    without user action.

4\. Functional Requirements

4.1 News Ingestion & Content Cleaning

4.1.1 Description

A scheduled background process (System A) polls a configured list of RSS
sources on a fixed interval, extracts each entry, resolves it to a
canonical URL, cleans the full article body of advertising/navigation
markup, and persists the result. This process runs independently of any
user request.

4.1.2 Detailed Requirements

-   FR-1.1: The system SHALL poll all sources marked is_active = true
    every 15--30 minutes via a scheduled job.

-   FR-1.2: For each feed entry, the system SHALL normalize the URL by
    stripping tracking query parameters (utm\_\*, fbclid, gclid) and
    resolving AMP variants to their canonical equivalent where
    discoverable.

-   FR-1.3: The system SHALL deduplicate articles using a composite key
    of normalized canonical_url and a content_hash (hash of cleaned body
    text), so that syndicated reposts with different URLs but identical
    content are not stored twice.

-   FR-1.4: The system SHALL extract and clean the full article HTML
    using a Readability-equivalent parser, removing navigation, ads, and
    boilerplate, retaining only the primary article body.

-   FR-1.5: If a source fails to respond or returns malformed XML/JSON,
    the system SHALL log the failure against that source\'s
    failure_count and continue processing all other sources without
    interruption (per-source failure isolation).

-   FR-1.6: If cleaned content falls below a minimum length threshold
    (indicating a failed extraction, e.g. paywall or JS-rendered page),
    the article SHALL still be stored for feed display, but flagged as
    ineligible for AI summarization until manually reviewed or
    re-attempted.

-   FR-1.7: Each article SHALL be tagged with one or more topic tags,
    either inherited from the source\'s default category_tags or derived
    from keyword matching against the title/body.

4.2 Feed Display & Card Management

4.2.1 Description

The Flutter client renders ingested articles as a scrollable, filterable
card feed. Each card presents enough information for a user to decide
whether to engage further, without needing to open the source website.

4.2.2 Detailed Requirements

-   FR-2.1: Each feed card SHALL display: source name, thumbnail image
    (if available), headline, relative publish time, and associated
    topic tags.

-   FR-2.2: Users SHALL be able to filter the feed by one or more topic
    tags via a persistent filter bar.

-   FR-2.3: Users SHALL be able to mute a domain/source, after which
    articles from that source are excluded from their feed going
    forward.

-   FR-2.4: The feed SHALL support pull-to-refresh, triggering an
    on-demand fetch of the latest articles from System B.

-   FR-2.5: The feed SHALL paginate (cursor or offset-based) to avoid
    loading the entire article history on first load.

-   FR-2.6: Tapping a card SHALL open a detail view showing the cleaned
    article body, with an affordance to open the original source URL in
    an in-app browser.

4.3 AI Summarization & Preset Angle Chat

4.3.1 Description

Each article can be reduced to a 3-bullet ELI5-style summary by Gemini,
and the user may request up to three additional fixed \"angles\" on the
same article. This is the system\'s core differentiator and its primary
cost-control surface.

4.3.2 Detailed Requirements

-   FR-3.1: Tapping the summarize affordance on a card SHALL open a
    bottom sheet requesting the core 3-bullet summary for that article.

-   FR-3.2: The backend SHALL check Redis, then PostgreSQL, before
    calling Gemini, per the 3-tier caching strategy defined in Section
    6.

-   FR-3.3: The bottom sheet SHALL present exactly four selectable
    angles: (1) Core Summary, (2) Explain Simpler, (3) Why Does This
    Matter, (4) What\'s the Risk/Counterargument.

-   FR-3.4: Each angle SHALL be cached independently, keyed by
    (article_id, question_type), so repeat requests for the same angle
    on the same article never re-invoke Gemini.

-   FR-3.5: If an article is flagged ineligible for summarization
    (FR-1.6), the UI SHALL display a fallback message (\"Summary
    unavailable for this article\") rather than attempting a Gemini
    call.

-   FR-3.6: All Gemini prompts SHALL be versioned (prompt_version field)
    so that summary quality regressions can be traced to a specific
    prompt revision.

-   FR-3.7 (Non-goal, explicit exclusion): The system SHALL NOT expose
    free-text conversational input against arbitrary user questions in
    v1.0.

4.4 Community Signals (Hacker News / Reddit)

4.4.1 Description

For each article, the system opportunistically checks whether it has
been discussed on Hacker News or Reddit, surfacing engagement metrics as
a lightweight trust/relevance signal.

4.4.2 Detailed Requirements

-   FR-4.1: The backend SHALL query the Algolia HN Search API using the
    article\'s canonical URL (and title as fallback) to find matching
    discussion threads.

-   FR-4.2: The backend SHALL query Reddit\'s public JSON search
    endpoints for matching submissions across a configured set of
    relevant subreddits (e.g. r/technology, r/programming).

-   FR-4.3: Retrieved signals (points, comment count, discussion URL)
    SHALL be cached with a short TTL (\~30 minutes) since these values
    change over time, unlike AI summaries which are stable.

-   FR-4.4: If neither API returns a match, the UI SHALL simply omit the
    community signal section for that article rather than displaying an
    error.

-   FR-4.5: Community signal lookups SHALL fail silently and
    asynchronously --- a failure or timeout on this call SHALL NEVER
    block feed rendering or summary display.

4.5 On-Device Text-to-Speech & Offline Synchronization

4.5.1 Description

Summaries can be played back as audio using the device\'s native TTS
engine, and the app must remain functional (read-only) without network
connectivity.

4.5.2 Detailed Requirements

-   FR-5.1: A play/pause control SHALL be available on any rendered AI
    summary, invoking flutter_tts to read the bullet text aloud.

-   FR-5.2: TTS playback SHALL be entirely on-device; no audio file
    SHALL be generated, transmitted, or stored server-side.

-   FR-5.3: On each successful feed fetch, the client SHALL persist the
    current card set (metadata + any already-fetched summaries) into a
    local Hive box.

-   FR-5.4: When the device is offline, the app SHALL detect
    connectivity loss and transparently serve the last-synced Hive
    snapshot instead of showing an error state.

-   FR-5.5: Bookmark actions performed while offline SHALL be queued in
    a local Hive-backed action queue and flushed to the backend
    automatically upon reconnection, using an \"add/remove\" idempotent
    model that requires no conflict resolution.

4.6 User Preferences, Tag Filtering & Bookmarking

4.6.1 Detailed Requirements

-   FR-6.1: Authenticated users SHALL be able to set and update a list
    of followed_tags, persisted server-side via Supabase-backed
    PostgreSQL.

-   FR-6.2: Authenticated users SHALL be able to mute one or more source
    domains, persisted server-side.

-   FR-6.3: Users SHALL be able to bookmark and un-bookmark any article;
    bookmarks SHALL be visible in a dedicated Bookmarks screen, sorted
    by most recently saved.

-   FR-6.4: All preference and bookmark data SHALL be scoped to the
    authenticated user via PostgreSQL Row-Level Security (RLS) policies,
    not solely application-layer checks.

5\. Non-Functional Requirements

5.1 Performance

  -----------------------------------------------------------------------
  **Requirement**                            **Target**
  ------------------------------------------ ----------------------------
  Feed initial load (cold start, cached)     \< 1s to first render from
                                             Hive

  Feed initial load (network fetch)          \< 2.5s on 4G

  Summary retrieval --- cache hit            \< 400ms end-to-end

  Summary retrieval --- cache miss (Gemini   \< 4s end-to-end
  call)                                      

  Community signal retrieval                 \< 2s, non-blocking to UI
                                             thread

  RSS ingestion cycle duration               \< 5 minutes for up to 10
                                             sources
  -----------------------------------------------------------------------

5.2 Security

-   NFR-SEC-1: All API keys (Gemini, Algolia, Upstash, Supabase service
    role) SHALL reside exclusively on the backend; the Flutter client
    SHALL never embed or transmit third-party API secrets.

-   NFR-SEC-2: Authentication SHALL be handled via Supabase Auth using
    JWT-based session tokens; the FastAPI backend SHALL validate tokens
    on every authenticated request.

-   NFR-SEC-3: PostgreSQL Row-Level Security SHALL be enabled on
    user_preferences and bookmarks tables from initial schema creation,
    not retrofitted later.

-   NFR-SEC-4: All backend endpoints SHALL enforce HTTPS-only
    communication.

-   NFR-SEC-5: User-submitted data (none expected in v1.0 beyond
    preferences/bookmarks) SHALL be validated and sanitized via Pydantic
    schema enforcement at the API boundary.

5.3 API Rate Limiting & Cost Constraints

-   NFR-RATE-1: The backend SHALL enforce per-IP and/or per-user rate
    limiting on the /summaries endpoint to prevent quota exhaustion from
    abusive polling.

-   NFR-RATE-2: The system SHALL track daily Gemini API call volume and
    expose a lightweight internal metric/log to confirm the application
    remains within the free-tier daily request cap.

-   NFR-RATE-3: Community signal lookups (Algolia/Reddit) SHALL be
    cached with a minimum 30-minute TTL to avoid redundant external
    calls per article per session.

-   NFR-RATE-4: All external API calls (Gemini, Algolia, Reddit) SHALL
    implement timeout and retry-with-backoff handling to avoid cascading
    latency into the request/response cycle.

5.4 Reliability & Availability

-   NFR-REL-1: A failure in the RSS ingestion pipeline for any single
    source SHALL NOT halt ingestion for other sources (per-source
    isolation, per FR-1.5).

-   NFR-REL-2: A failure or outage of Redis SHALL degrade the system to
    PostgreSQL-only cache lookups without any loss of summarization
    functionality (Redis is an accelerator, not a dependency).

-   NFR-REL-3: A failure or outage of the Algolia/Reddit community
    signal APIs SHALL NOT affect core feed, summary, or bookmark
    functionality.

5.5 Usability & Accessibility

-   NFR-UX-1: The application SHALL support standard mobile
    accessibility features (font scaling, screen reader labels on
    interactive elements).

-   NFR-UX-2: TTS playback SHALL provide a visible playback state
    (playing/paused) so users relying on audio are not left uncertain of
    app state.

5.6 Maintainability

-   NFR-MAINT-1: Backend code SHALL be organized into
    routers/services/schemas layers (see Section 8) to keep ingestion,
    AI, and signal logic independently testable.

-   NFR-MAINT-2: All Gemini prompts SHALL be stored as versioned,
    isolated constants/templates rather than inline strings, to support
    future prompt iteration without code changes elsewhere.

6\. Data Architecture & Schema Design

6.1 Entity-Relationship Overview

The schema is organized around six core tables. sources feeds into
articles (1-to-many). articles is the central entity referenced by
summaries (1-to-many, differentiated by question_type) and signals
(1-to-1, refreshed periodically). User-scoped data --- user_preferences
and bookmarks --- reference Supabase-managed auth.users and are
protected by Row-Level Security.

6.1.1 Relationship Summary

  -----------------------------------------------------------------------
  **Relationship**                           **Cardinality**
  ------------------------------------------ ----------------------------
  sources → articles                         1 : many

  articles → summaries                       1 : many (one row per
                                             question_type)

  articles → signals                         1 : 1 (upserted on refresh)

  auth.users → user_preferences              1 : 1

  auth.users → bookmarks → articles          many : many (via bookmarks
                                             join table)
  -----------------------------------------------------------------------

6.2 Table: sources

  -------------------------------------------------------------------------
  **Column**        **Type**           **Notes**
  ----------------- ------------------ ------------------------------------
  id                UUID / SERIAL PK   Primary key

  name              VARCHAR(120)       Publisher display name

  feed_url          TEXT               RSS/Atom feed URL, unique

  homepage_url      TEXT               Canonical publisher homepage

  category_tags     TEXT\[\]           Default tags applied to ingested
                                       articles

  is_active         BOOLEAN            Toggle without deleting source
                                       config

  failure_count     INTEGER, default 0 Incremented on ingestion failure;
                                       used for health monitoring

  last_fetched_at   TIMESTAMPTZ        Last successful poll timestamp
  -------------------------------------------------------------------------

6.3 Table: articles

  -----------------------------------------------------------------------
  **Column**        **Type**           **Notes**
  ----------------- ------------------ ----------------------------------
  id                UUID PK            Primary key

  source_id         UUID FK →          Origin source
                    sources.id         

  title             TEXT               Headline

  canonical_url     TEXT, UNIQUE       Normalized URL, tracking params
                                       stripped

  content_hash      VARCHAR(64)        SHA-256 of cleaned body; secondary
                                       dedup key

  cleaned_content   TEXT               Readability-extracted article body

  image_url         TEXT, nullable     Thumbnail

  author            VARCHAR(200),      
                    nullable           

  tags              TEXT\[\]           Topic tags for filtering

  is_summarizable   BOOLEAN, default   False if extraction failed
                    true               threshold check (FR-1.6)

  published_at      TIMESTAMPTZ        Original publish time

  created_at        TIMESTAMPTZ        Ingestion timestamp
  -----------------------------------------------------------------------

*Indexes: UNIQUE(canonical_url); INDEX on published_at (feed sort); GIN
INDEX on tags (array filtering); INDEX on content_hash.*

6.4 Table: summaries

  ------------------------------------------------------------------------
  **Column**        **Type**             **Notes**
  ----------------- -------------------- ---------------------------------
  id                UUID PK              Primary key

  article_id        UUID FK →            
                    articles.id          

  question_type     VARCHAR(30)          \'core\' \| \'simpler\' \|
                                         \'significance\' \| \'risk\'

  content           JSONB                Bullet array or plain text
                                         response

  model_used        VARCHAR(50)          e.g. \'gemini-1.5-flash\'

  prompt_version    VARCHAR(20)          For traceability of prompt
                                         iterations

  generated_at      TIMESTAMPTZ          
  ------------------------------------------------------------------------

*Unique constraint on (article_id, question_type) --- this is the single
table serving both the core summary and every preset angle, and is the
anchor of the 3-tier caching strategy.*

6.5 Table: signals

  ---------------------------------------------------------------------------
  **Column**             **Type**           **Notes**
  ---------------------- ------------------ ---------------------------------
  article_id             UUID PK/FK →       1:1 with articles
                         articles.id        

  hn_points              INTEGER, nullable  

  hn_comment_count       INTEGER, nullable  

  hn_discussion_url      TEXT, nullable     

  reddit_thread_url      TEXT, nullable     

  reddit_comment_count   INTEGER, nullable  

  fetched_at             TIMESTAMPTZ        Used to enforce \~30 min TTL
                                            refresh
  ---------------------------------------------------------------------------

6.6 Table: user_preferences

  -----------------------------------------------------------------------
  **Column**         **Type**           **Notes**
  ------------------ ------------------ ---------------------------------
  user_id            UUID PK/FK →       Supabase-managed identity
                     auth.users.id      

  followed_tags      TEXT\[\]           

  muted_domains      TEXT\[\]           

  updated_at         TIMESTAMPTZ        
  -----------------------------------------------------------------------

6.7 Table: bookmarks

  -----------------------------------------------------------------------
  **Column**         **Type**           **Notes**
  ------------------ ------------------ ---------------------------------
  id                 UUID PK            

  user_id            UUID FK →          RLS-scoped
                     auth.users.id      

  article_id         UUID FK →          
                     articles.id        

  created_at         TIMESTAMPTZ        
  -----------------------------------------------------------------------

*Unique constraint on (user_id, article_id) to make bookmark toggling
idempotent.*

7\. API Contract & Endpoint Specifications (System B)

All endpoints are prefixed /api/v1 and require a valid Supabase JWT via
the Authorization: Bearer header unless marked Public.

7.1 Feed & Articles

  ------------------------------------------------------------------------
  **Method & Path**          **Description**                 **Auth**
  -------------------------- ------------------------------- -------------
  GET /feed                  Paginated article feed;         Optional
                             supports ?tags=,                
                             ?exclude_domains=, ?cursor=     

  GET /articles/{id}         Full cleaned article detail     Optional
  ------------------------------------------------------------------------

7.2 AI Summarization

  ---------------------------------------------------------------------------------------------------
  **Method & Path**                  **Description**                                    **Auth**
  ---------------------------------- -------------------------------------------------- -------------
  GET                                Retrieve or generate a summary for the given       Required
  /articles/{id}/summary?type=core   question_type                                      
                                     (\'core\',\'simpler\',\'significance\',\'risk\')   

  ---------------------------------------------------------------------------------------------------

*Response shape: { article_id, question_type, content: \[\"bullet 1\",
\"bullet 2\", \"bullet 3\"\], cached: true\|false, model_used,
generated_at }*

7.3 Community Signals

  ------------------------------------------------------------------------
  **Method & Path**          **Description**                 **Auth**
  -------------------------- ------------------------------- -------------
  GET /articles/{id}/signals Retrieve cached or              Optional
                             freshly-fetched HN/Reddit       
                             signal data                     

  ------------------------------------------------------------------------

7.4 Preferences

  ------------------------------------------------------------------------
  **Method & Path**          **Description**                 **Auth**
  -------------------------- ------------------------------- -------------
  GET /me/preferences        Retrieve current user\'s        Required
                             followed tags and muted domains 

  PUT /me/preferences        Update followed_tags /          Required
                             muted_domains                   
  ------------------------------------------------------------------------

7.5 Bookmarks

  --------------------------------------------------------------------------
  **Method & Path**            **Description**                 **Auth**
  ---------------------------- ------------------------------- -------------
  GET /me/bookmarks            List current user\'s bookmarks, Required
                               most recent first               

  POST /me/bookmarks           Add a bookmark; body: {         Required
                               article_id }                    

  DELETE                       Remove a bookmark               Required
  /me/bookmarks/{article_id}                                   
  --------------------------------------------------------------------------

7.6 Ingestion Health (Admin/Internal)

  ------------------------------------------------------------------------
  **Method & Path**          **Description**                 **Auth**
  -------------------------- ------------------------------- -------------
  GET /admin/sources/status  Per-source last_fetched_at and  Admin
                             failure_count, for monitoring   
                             pipeline health                 

  ------------------------------------------------------------------------

*Standard error envelope: { \"error\": { \"code\": string, \"message\":
string } }, with 4xx for client errors (invalid tag, unauthenticated)
and 429 for rate-limit rejections on the summary endpoint.*

8\. Mobile System Architecture (Flutter)

8.1 State Management --- Riverpod

-   feedProvider: holds the current paginated article list, active tag
    filters, and muted-domain exclusions; exposes refresh() and
    loadMore().

-   summaryProvider(articleId, questionType): family provider
    fetching/caching a single summary angle, backed by the API client
    with an in-memory + Hive fallback.

-   bookmarksProvider: holds the user\'s bookmarked article set;
    supports optimistic add/remove with rollback on API failure.

-   preferencesProvider: holds followed_tags and muted_domains, synced
    against /me/preferences.

-   connectivityProvider: exposes online/offline state, consumed by
    feedProvider and bookmarksProvider to decide between network and
    Hive fallback paths.

8.2 Services Layer

-   news_api_service.dart --- Dio-based HTTP client wrapping all System
    B endpoints; attaches Supabase JWT to every request via an
    interceptor; handles 401 refresh flow.

-   tts_service.dart --- thin wrapper around flutter_tts exposing
    speak(text), pause(), stop(), and a playback-state stream consumed
    by the UI.

-   offline_cache_service.dart --- manages Hive boxes for
    cached_articles, cached_summaries, and a pending_actions queue for
    offline bookmark writes; exposes a flush() method invoked when
    connectivity is restored.

8.3 Screen Hierarchy

-   FeedScreen --- root tab; hosts TagFilterBar + infinite-scroll
    ListView of ArticleCard widgets.

-   ArticleDetailScreen --- full cleaned article view, entry point to
    SummarySheet.

-   BookmarksScreen --- list of saved articles, reusing ArticleCard.

-   SettingsScreen --- tag preferences, muted domains, account/auth
    management.

8.4 Key Widgets

-   ArticleCard --- headline, source, thumbnail, tags, relative
    timestamp, bookmark toggle icon.

-   SummarySheet --- modal bottom sheet (showModalBottomSheet) with four
    angle-selector chips (Core / Simpler / Significance / Risk), a
    bullet-list render area, a TTS play button, and a loading skeleton
    state for cache-miss latency.

-   TtsPlayerButton --- icon button bound to tts_service.dart\'s
    playback stream.

-   TagFilterBar --- horizontally scrollable chip row bound to
    preferencesProvider / local feed filter state.

8.5 Offline Data Flow

On every successful /feed and /articles/{id}/summary response, the
corresponding data is mirrored into Hive. connectivityProvider listens
for connectivity changes; on transition to offline, feedProvider and
summaryProvider transparently read from Hive instead of Dio. Bookmark
writes performed offline are appended to the pending_actions Hive box
and are flushed sequentially against the API the moment connectivity is
restored, using an idempotent add/remove model that requires no
server-side conflict resolution.

9\. Implementation Timeline & Phase Roadmap

Phase 1 --- Backend Foundation & Database (Weeks 1--2)

-   Provision Supabase project; define and migrate the six-table schema;
    enable RLS on user_preferences and bookmarks.

-   Scaffold FastAPI project structure (routers/services/schemas/db
    layers); configure environment-based settings (Gemini key, Upstash
    Redis URL, Supabase connection).

-   Implement /feed and /articles/{id} read endpoints against seed/mock
    data to unblock frontend work early.

Phase 2 --- Ingestion Pipeline & AI Integration (Weeks 3--5)

-   Build the RSS ingestion worker: polling, URL normalization,
    Readability-equivalent cleaning, dedup logic, per-source failure
    isolation.

-   Integrate Gemini for the four fixed summary angles; implement the
    3-tier cache lookup (Redis → PostgreSQL → Gemini) with prompt
    versioning.

-   Integrate Algolia HN Search and Reddit JSON signal lookups with
    short-TTL caching and failure-silent behavior.

-   Implement backend rate limiting on the summary endpoint.

Phase 3 --- Flutter Application Core (Weeks 6--8)

-   Build FeedScreen, ArticleDetailScreen, SummarySheet, and
    BookmarksScreen against the now-live API.

-   Wire up Riverpod providers and Dio-based news_api_service.dart,
    including Supabase Auth session handling.

-   Implement flutter_tts playback and the four-angle SummarySheet
    interaction.

Phase 4 --- Offline Support & Polish (Weeks 9--10)

-   Implement Hive-backed offline_cache_service.dart, connectivity
    detection, and the pending-actions bookmark queue.

-   Implement tag filtering, domain muting, and settings persistence
    end-to-end.

-   UI polish pass: loading skeletons, empty states, error states;
    accessibility pass (font scaling, semantic labels).

Phase 5 --- Evaluation, Documentation & Stretch Goals (Weeks 11--12)

-   End-to-end QA across online/offline transitions, cache-hit/miss
    paths, and source-failure scenarios.

-   Prepare architecture write-up, ERD diagrams, and demo script for
    academic evaluation.

-   If time permits: rate-limited free-text chat, dark mode,
    reading-streak stat (explicitly deferred, non-blocking to core
    submission).

*End of document.*
