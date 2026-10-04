# Digest — Frontend Specification Document (FSD)

**Version:** 1.1 (revised design reference: GoRead — News App, Kretya Studio, Dribbble #20776712)
**System:** Cross-Platform IT Technology News App — Flutter Client
**Audience:** Flutter engineers, UX reviewers, academic examiners

> **Note on the design reference:** Dribbble renders shot pages client-side via JavaScript, so this document is built from GoRead's known, well-documented design language (large featured-story hero treatment, bold editorial serif headlines, warm minimal card list, single-accent restraint) rather than a pixel-sampled extraction. Where a specific value below can't be verified against the live shot, it's a deliberate, stated design decision rather than a guess presented as fact.

---

## Table of Contents

1. UX Vision, Design System & Theme Architecture
2. App Navigation Architecture & Screen Hierarchy
3. Screen-by-Screen UI & Component Specifications
4. Riverpod State Management Architecture
5. Offline Support & Local Persistence Strategy
6. Animations, Micro-Interactions & Polish

---

## 1. UX Vision, Design System & Theme Architecture

### 1.1 Design Thesis

GoRead's defining structural idea — distinct from a uniform card grid — is **hierarchy through scale, not through chrome**: one story earns a large, image-forward "featured" treatment at the top of the feed, and everything beneath it steps down into a quieter, text-led list. Digest adopts this same hierarchy: the single most recent or most-discussed article gets the featured slot; the rest of the feed reads more like a table of contents than a wall of identical cards. This solves a real problem for a tech-news aggregator specifically — when ten sources publish in the same 15-minute window, treating all ten as equally weighted visually would bury the story that actually matters.

The second defining trait is **bold editorial serif headlines** paired with a quiet sans-serif body — a more pronounced type contrast than the previous sans-only direction, giving headlines the weight of a magazine masthead rather than an app-UI label.

Digest's established dual-accent grammar carries forward unchanged in principle: **one accent marks anything the user does, a second marks anything the AI generates** — but both are retuned here to sit comfortably against a warmer base than a neutral SaaS palette would use, matching GoRead's quieter, warmer tone.

### 1.2 Color Palette

**Light Mode** ("Warm Paper")

| Token | Hex | Usage |
|---|---|---|
| `--surface-base` | `#F6F2E9` | Screen background — warm, paper-like, not clinical white |
| `--surface-elevated` | `#FFFDF9` | Card surfaces, sheets — barely lifted off the base, not stark white |
| `--surface-outline` | `#E4DCC8` | Card border outlines |
| `--text-primary` | `#241F16` | Headlines, primary reading text — warm near-black, not cool grey-black |
| `--text-secondary` | `#786F5C` | Source names, timestamps, metadata |
| `--text-tertiary` | `#B0A78F` | Disabled states, placeholder text |
| `--accent-signal` (user actions) | `#A34424` | Muted brick/paprika — bookmark filled, active filter chip, settings toggles |
| `--accent-signal-soft` | `#F1DCCD` | Tint background for active signal-accent chips |
| `--accent-synth` (AI surfaces) | `#0F6E63` | Deep pine teal — summary sheet header, angle tabs, TTS waveform |
| `--accent-synth-soft` | `#D9EAE6` | Tint background for AI bottom sheet body |
| `--divider` | `#EBE4D3` | Hairline dividers |
| `--danger` | `#A63B32` | Destructive actions |

**Dark Mode** ("Ink & Charcoal")

| Token | Hex | Usage |
|---|---|---|
| `--surface-base` | `#16140F` | Screen background — warm-tinted charcoal, not blue-black |
| `--surface-elevated` | `#211E17` | Card surfaces, sheets |
| `--surface-outline` | `#332E23` | Card border outlines |
| `--text-primary` | `#F3EEE2` | Headlines |
| `--text-secondary` | `#AFA48D` | Metadata |
| `--text-tertiary` | `#71685A` | Disabled/placeholder |
| `--accent-signal` | `#D97B4F` | Brightened brick tone for dark-surface contrast |
| `--accent-signal-soft` | `#3A2618` | Tint background on dark |
| `--accent-synth` | `#3FB3A1` | Brightened pine teal for dark-surface contrast |
| `--accent-synth-soft` | `#12302B` | Tint background on dark |
| `--divider` | `#2A261D` | Hairline dividers |
| `--danger` | `#E1685C` | Destructive actions |

**Rationale for this specific pairing:** the base leans warm (paper/ink) rather than cool-neutral, matching GoRead's quieter editorial tone, but the accent pair (brick + pine, rather than a single terracotta-on-cream combination) is chosen specifically to avoid the generic warm-cream-plus-terracotta pairing that shows up by default across a lot of AI-generated design — Digest needs two functionally distinct accents anyway (user vs. AI), so that constraint naturally pushes the palette away from that single-accent cliché.

### 1.3 Typography

| Role | Typeface | Weight | Size / Line-height | Usage |
|---|---|---|---|---|
| Display / Headline | **Fraunces** (serif) | SemiBold (600), optical size "display" | 26sp / 34 (1.3) | Featured story headline, article detail headline |
| Card headline | Fraunces | Medium (500) | 19sp / 26 (1.37) | Secondary feed-list headlines (smaller than featured, still serif) |
| Subhead | **Inter** | Medium (500) | 17sp / 24 (1.4) | Bottom sheet section titles, settings group labels |
| Body | Inter | Regular (400) | 15sp / 23 (1.5) | Article body copy, summary bullets |
| Body — emphasis | Inter | Medium (500) | 15sp / 23 | Preset angle chip labels, source badge text |
| Metadata | Inter | Regular (400) | 13sp / 18 (1.4) | Timestamps, reading-time estimates, tag pills |
| Caption / Micro | Inter | Medium (500) | 11sp / 14 | Tab bar labels, signal pill counts |

The serif/sans split does real work here, not just decoration: **Fraunces appears only on headlines** — the moment a reader decides whether a story is worth their time — and steps down in size (not weight) between the featured slot and the list, so the hierarchy reads clearly even before a reader processes the actual words. Inter carries everything meant to be read continuously, since a full article set in a display serif at length would slow reading rather than support it.

**Type scale ratio:** 1.318 between the two headline tiers (26 → 19), intentionally closer together than a full type-scale step — GoRead's list headlines are still clearly headlines, just quieter ones, not a drop all the way to body-text weight.

### 1.4 Spatial Scale

| Token | Value | Usage |
|---|---|---|
| `space-2xs` | 4px | Icon-to-label gaps |
| `space-xs` | 8px | Pill internal padding, chip gaps |
| `space-sm` | 12px | Compact list-card internal padding |
| `space-md` | 16px | Card outer padding, standard element gaps |
| `space-lg` | 24px | Section spacing, screen horizontal margins |
| `space-xl` | 32px | Gap between featured card and list section |
| `space-2xl` | 48px | Empty-state vertical centering offset |

### 1.5 Radii & Elevation

| Token | Value | Usage |
|---|---|---|
| `radius-card-featured` | 20px | Featured hero card — largest radius, matching its visual weight |
| `radius-card-list` | 16px | Secondary list cards (within reference's 16–20px range, at the lower end since these are quieter elements) |
| `radius-pill` | 999px (full) | Tag pills, filter chips, angle-tab pills |
| `radius-sheet` | 28px (top corners only) | AI summary bottom sheet |
| `radius-thumbnail` | 14px | Thumbnail image corners inside list cards |
| `elevation-card` | `0 1px 2px rgba(36,31,22,0.05)` + 1px `--surface-outline` border | Outline-led depth, shadow is minimal |
| `elevation-featured` | `0 4px 16px rgba(36,31,22,0.08)` | Featured card gets a slightly more pronounced lift, reinforcing its hierarchy without becoming a heavy drop-shadow |
| `elevation-sheet` | `0 -8px 24px rgba(0,0,0,0.14)` | Bottom sheet only |

### 1.6 Icon Library

**Library:** Lucide Icons (`lucide_icons`) — unchanged from prior direction; geometric 2px-stroke icons read cleanly against both the warm-paper and ink-charcoal surfaces.

| Icon | Usage |
|---|---|
| `LucideIcons.bookmark` / `bookmarkCheck` | Bookmark toggle |
| `LucideIcons.volume2` / `pause` | TTS play/pause |
| `LucideIcons.messageSquare` | Community discussion signal pill |
| `LucideIcons.arrowUpRight` | Open original article externally |
| `LucideIcons.slidersHorizontal` | Filter drawer trigger |
| `LucideIcons.moon` / `sun` | Theme switcher |
| `LucideIcons.wifiOff` | Offline banner |

### 1.7 GoRead Reference → Flutter Component Mapping

| Reference trait | Flutter implementation |
|---|---|
| Large featured hero story at top of feed | `FeaturedArticleCard` widget — full-bleed `AspectRatio(4/3)` image, `radius-card-featured`, Fraunces 26sp headline overlaid or stacked directly beneath (see §3.1) |
| Secondary list rows, smaller and text-led | `ArticleListRow` widget — small thumbnail (fixed 88×88), Fraunces 19sp headline, metadata row beneath |
| Bold serif editorial headline | `Theme.textTheme.headlineMedium` mapped to `GoogleFonts.fraunces(fontWeight: FontWeight.w600)` |
| Warm, minimal card outlines | `Border.all(color: surfaceOutline, width: 1)`, no heavy shadow except on the featured card |
| Inline category/tag pills | `Wrap` of pill-shaped `Chip` equivalents, `radius-pill`, signal-accent tint when active |
| Draggable summary sheet with pill tabs | `DraggableScrollableSheet` + custom pill-tab row (unchanged pattern from prior revision, retuned to the new accent-synth color) |
| Skeleton shimmer loaders | `shimmer` package, shaped to match both `FeaturedArticleCard` and `ArticleListRow` skeleton variants distinctly, since they're different shapes |

---

## 2. App Navigation Architecture & Screen Hierarchy

### 2.1 Route Map

```
AppRouter (go_router)
│
├── /                         → SplashScreen (auth check redirect)
├── /onboarding               → OnboardingScreen (first-run tag selection)
├── /auth                     → AuthScreen (Supabase sign-in/sign-up)
│
└── /home  (ShellRoute — persistent BottomNavigationBar)
    ├── /home/feed            → FeedScreen              [Tab 1: Home Feed]
    │     └── /home/feed/article/:id
    │                         → ArticleDetailScreen (pushes over shell)
    │                              ⤷ presents SummarySheet (modal, not a route)
    ├── /home/explore         → ExploreScreen            [Tab 2: Explore/Tags]
    ├── /home/bookmarks       → BookmarksScreen          [Tab 3: Bookmarks]
    └── /home/settings        → SettingsScreen           [Tab 4: Settings]
```

### 2.2 Bottom Navigation Bar

| Tab | Icon (Lucide) | Label |
|---|---|---|
| Home Feed | `home` | Feed |
| Explore/Tags | `compass` | Explore |
| Bookmarks | `bookmark` | Saved |
| Settings | `settings` | Settings |

Active tab renders filled + `--accent-signal` tinted; inactive tabs render outline-style in `--text-tertiary`.

### 2.3 Modal & Sheet Flows

```
FeedScreen / ArticleDetailScreen
        │
        │  tap "Summarize" affordance
        ▼
┌─────────────────────────────┐
│  SummarySheet                │  DraggableScrollableSheet
│  (initialChildSize: 0.55,     │  min: 0.3, max: 0.92
│   snap: true)                 │
│                               │
│  [Core] [Simpler] [Matters]  │ ← pill tab row, pine-teal accent on active
│  [Risks]                      │
│  ─────────────────────────    │
│  • bullet content or          │
│    shimmer skeleton            │
│  ─────────────────────────    │
│  ▶ Listen to summary          │
└─────────────────────────────┘

FeedScreen
        │  tap filter icon in header
        ▼
┌─────────────────────────────┐
│  FilterDrawer                │  showModalBottomSheet, fixed fraction 0.6
│  Tags: [#AI ✓] [#DevOps]      │
│  [#Cybersecurity ✓]           │
│  [Apply Filters]              │ ← brick-accent CTA
└─────────────────────────────┘

FeedScreen
        │  tap search icon in header
        ▼
┌─────────────────────────────┐
│  SearchOverlay                │  full-screen route, fade+scale transition
│  [ search input, autofocus ]  │
│  Recent / live filtered       │
│  results as-you-type          │
└─────────────────────────────┘
```

Same governing rule as before: augment-in-place → bottom sheet (summary, filters); change context → routed screen (search, article detail).

---

## 3. Screen-by-Screen UI & Component Specifications

### 3.1 Feed Screen

```
┌──────────────────────────────────────┐
│  Digest              [🔍] [≡]         │  ← header
│                                        │
│  ( #AI ) ( #DevOps ) ( #Security )    │  ← tag filter pill bar
│                                        │
│  ┌──────────────────────────────────┐ │
│  │                                    │ │
│  │      [featured image, 4:3]        │ │  ← FeaturedArticleCard
│  │                                    │ │     radius-card-featured (20px)
│  ├──────────────────────────────────┤ │     elevation-featured
│  │  TechCrunch · 2h ago               │ │
│  │  Gemini 2.0 launches with          │ │  ← Fraunces 26sp, headline weight
│  │  native multimodal reasoning       │ │
│  │  ( #AI )               ⏱4m  💬128 [♡]│ │
│  └──────────────────────────────────┘ │
│                                        │
│  More stories                          │  ← Inter 13sp Medium section label
│  ┌──────────────────────────────────┐ │
│  │ [88x88]  Security patch closes    │ │  ← ArticleListRow, radius-card-list
│  │  thumb   zero-day in widely-used  │ │     Fraunces 19sp headline
│  │          library                   │ │
│  │          Ars Technica · 3h · #Sec │ │
│  └──────────────────────────────────┘ │
│  ┌──────────────────────────────────┐ │
│  │  ...next list row...               │ │
│  └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Component: `FeaturedArticleCard`** — one instance, always the top item (most recent article matching the user's active filters, or the article with the strongest community signal if tied).

| Element | Spec |
|---|---|
| Image | `AspectRatio(4/3)`, `CachedNetworkImage`, top corners `radius-card-featured`, no corner radius at the image/text seam (image sits flush into a text block below, not floating as a separate rounded tile) |
| Headline | Fraunces 26sp/34, SemiBold, max 3 lines |
| Meta row | Source · relative time (Inter 13sp secondary), tag pill, reading time + signal pill, bookmark icon — all on one row beneath the headline, wrapping to a second row only on narrow devices |

**Component: `ArticleListRow`** — every subsequent feed item.

| Element | Spec |
|---|---|
| Thumbnail | Fixed 88×88, `radius-thumbnail` (14px), left-aligned |
| Headline | Fraunces 19sp/26, Medium, max 2 lines, right of thumbnail |
| Meta row | Source · relative time · tag pill, Inter 13sp, beneath headline |
| Bookmark | Small icon-only button, top-right of the row's text column, not full 44px card-spanning — this is a quieter, denser row than the featured card |
| Community signal | Only rendered inline in the meta row (icon + count) when present, per FR-4.4 — omitted entirely otherwise, never an empty placeholder |

### 3.2 Article Detail & AI Bottom Sheet

**Article Detail Screen**

```
┌──────────────────────────────────────┐
│  [←]                          [⤴] [♡] │  ← persistent action bar
│                                        │
│  [Hero image — full width, Hero-tagged]│
│                                        │
│  Gemini 2.0 launches with native      │  ← Fraunces 26sp, same display size
│  multimodal reasoning                  │     as the featured card treatment,
│  TechCrunch · Sep 12 · 4 min read     │     for visual continuity across the
│                                        │     Hero transition
│  Google today announced Gemini 2.0... │  ← body copy, Inter 15sp/23
│  [full cleaned_content, scrollable]    │
│                                        │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │
│  ┃  ✦ Summarize with AI              ┃ │  ← pine-teal sticky CTA
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
└──────────────────────────────────────┘
```

**SummarySheet**

```
┌──────────────────────────────────────┐
│              ▬▬▬                      │  ← drag handle
│  ( Core )( Simpler )( Matters )(Risk) │  ← pill tabs, pine-teal fill on active
│  ─────────────────────────────────    │
│  •  Google released Gemini 2.0 with   │  ← Inter 15sp bullets, staggered
│     native multimodal reasoning        │     fade-in on cache-miss only
│  •  The model outperforms prior        │
│     versions on coding benchmarks       │
│  •  Available now via API with a       │
│     generous free tier                  │
│  ─────────────────────────────────    │
│  [ ▶ ]  Listen to summary    0:00/0:24 │
└──────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Drag handle | 36×4px rounded rect, `--text-tertiary` |
| Pill tabs | Equal-width `Expanded` pills, active = `--accent-synth` fill + `#FFFDF9` text, inactive = 1px `--accent-synth` border on transparent |
| Content area | `AnimatedSwitcher` (250ms fade+slide) between angles; pine-teal-tinted shimmer during cache-miss wait |
| TTS control | Icon button in a `--accent-synth-soft` pill, elapsed/total time, thin teal `LinearProgressIndicator` |
| Unavailable state | Centered message + muted icon if `is_summarizable == false` |

### 3.3 Bookmarks & Offline View

```
┌──────────────────────────────────────┐
│  Saved                                │
│  ⚠ You're offline — showing saved     │  ← brick-accent-soft banner
│    content                             │
│  ─────────────────────────────────    │
│  ┌──────────────────────────────────┐ │
│  │ [88x88]  Gemini 2.0 launches...   │ │  ← ArticleListRow reused as-is
│  │  thumb   TechCrunch · Saved 2d ago│ │     (same component as feed list,
│  └──────────────────────────────────┘ │     consistency over novelty)
│  ┌──────────────────────────────────┐ │
│  │ [88x88]  ...next bookmark...      │ │
│  └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Offline banner | `--accent-signal-soft` background, `wifiOff` icon, slides in/out with `AnimatedContainer` on connectivity change |
| Swipe-to-remove | `Dismissible(endToStart)`, reveals `--danger` background + trash icon, `confirmDismiss` shows undo snackbar rather than removing irreversibly |
| Empty state | Centered: bookmark outline icon (`--text-tertiary`), "Nothing saved yet" (Fraunces, since even this small moment gets the editorial headline treatment), "Articles you bookmark will appear here" (Inter, secondary) |

### 3.4 Settings & Preferences

```
┌──────────────────────────────────────┐
│  Settings                             │
│                                        │
│  Followed tags                        │  ← Inter 13sp Medium, sentence case
│  ( #AI ✓ )( #DevOps ✓ )( #Security )  │
│                                        │
│  Muted sources                        │
│  example.com               [remove]   │
│  + Add a domain to mute                │
│                                        │
│  Appearance                            │
│  Theme          [ Light | Dark | Auto ]│  ← segmented control, brick-accent
│                                        │     active segment
│  Storage                               │
│  Offline cache: 4.2 MB                 │
│  [ Clear cache ]                       │
│                                        │
│  Account                               │
│  ayesha@example.com                    │
│  [ Sign out ]                          │
└──────────────────────────────────────┘
```

Spec details unchanged from the prior revision (§3.4 of v1.0): sentence-case group labels, shared pill component for tags, confirmation dialog before cache clear — only the underlying color tokens shift to the new palette.

---

## 4. Riverpod State Management Architecture

*(Unchanged from v1.0 — the provider architecture is independent of visual design direction.)*

### 4.1 Provider Tree

```
┌─────────────────────────────────────────────────────────────────┐
│                     Root ProviderScope                          │
│                                                                   │
│  connectivityProvider ──────┐  (StreamProvider<ConnectivityState>│
│                              │   wrapping connectivity_plus)      │
│                              ▼                                    │
│  newsApiServiceProvider   dioClientProvider   secureStorageProvider│
│         │                                                          │
│         ▼                                                          │
│  feedProvider  (AsyncNotifierProvider<FeedNotifier, FeedState>)    │
│         │  consumes: newsApiServiceProvider, offlineCacheServiceProvider,│
│         │             connectivityProvider, preferencesProvider    │
│  summaryProvider  (family: AsyncNotifierProvider.family keyed by   │
│         │          SummaryRequest{articleId, questionType})        │
│  bookmarkProvider  (AsyncNotifierProvider<BookmarkNotifier,        │
│         │           List<Article>>)                                 │
│  preferenceProvider  (AsyncNotifierProvider<PreferenceNotifier,    │
│         │             UserPreferences>)                             │
│  ttsProvider  (NotifierProvider<TtsNotifier, TtsPlaybackState>)     │
│  themeModeProvider  (NotifierProvider<ThemeModeNotifier, ThemeMode>)│
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Provider Definitions

```dart
// feed_provider.dart
@riverpod
class Feed extends _$Feed {
  @override
  Future<FeedState> build() async {
    final connectivity = ref.watch(connectivityProvider);
    final api = ref.watch(newsApiServiceProvider);
    final cache = ref.watch(offlineCacheServiceProvider);
    final prefs = await ref.watch(preferenceProvider.future);

    if (connectivity.valueOrNull?.isOnline == false) {
      return FeedState.fromArticles(await cache.getCachedArticles());
    }

    final response = await api.fetchFeed(
      tags: prefs.followedTags,
      excludeDomains: prefs.mutedDomains,
    );
    await cache.cacheArticles(response.items);
    // Featured-card selection: highest community signal among the first
    // page's items, falling back to most-recent if no signals present.
    return FeedState.fromResponse(response, featuredSelector: pickFeatured);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.nextCursor == null) return;
    state = const AsyncValue.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final api = ref.read(newsApiServiceProvider);
      final more = await api.fetchFeed(cursor: current.nextCursor);
      return current.appending(more);
    });
  }

  Future<void> refresh() => ref.invalidateSelf();
}

FeedItem pickFeatured(List<FeedItem> items) {
  final withSignal = items.where((i) => (i.hnPoints ?? 0) > 0 || (i.redditComments ?? 0) > 0);
  if (withSignal.isEmpty) return items.first; // most recent, list is already time-sorted
  return withSignal.reduce((a, b) =>
      (a.hnPoints ?? 0) + (a.redditComments ?? 0) > (b.hnPoints ?? 0) + (b.redditComments ?? 0) ? a : b);
}
```

```dart
// summary_provider.dart
@riverpod
class Summary extends _$Summary {
  @override
  Future<SummaryResult> build(String articleId, String questionType) async {
    final connectivity = ref.watch(connectivityProvider);
    final cache = ref.watch(offlineCacheServiceProvider);

    if (connectivity.valueOrNull?.isOnline == false) {
      final cached = await cache.getCachedSummary(articleId, questionType);
      if (cached != null) return cached;
      throw OfflineSummaryUnavailableException();
    }

    final api = ref.watch(newsApiServiceProvider);
    final result = await api.fetchSummary(articleId, questionType);
    await cache.cacheSummary(articleId, questionType, result);
    return result;
  }
}
```

```dart
// bookmark_provider.dart
@riverpod
class Bookmark extends _$Bookmark {
  @override
  Future<List<Article>> build() async {
    final api = ref.watch(newsApiServiceProvider);
    return (await api.fetchBookmarks()).items;
  }

  Future<void> toggle(Article article, {required bool isOnline}) async {
    final current = state.valueOrNull ?? [];
    final isBookmarked = current.any((a) => a.id == article.id);

    state = AsyncValue.data(
      isBookmarked
          ? current.where((a) => a.id != article.id).toList()
          : [...current, article],
    );

    final cache = ref.read(offlineCacheServiceProvider);
    if (!isOnline) {
      await cache.queuePendingAction(article.id, isBookmarked ? 'remove' : 'add');
      return;
    }

    try {
      final api = ref.read(newsApiServiceProvider);
      if (isBookmarked) {
        await api.removeBookmark(article.id);
      } else {
        await api.addBookmark(article.id);
      }
    } catch (e) {
      state = AsyncValue.data(current); // roll back optimistic update
      rethrow;
    }
  }
}
```

### 4.3 `AsyncValue` Lifecycle Handling Pattern

```dart
// feed_screen.dart (excerpt)
Widget build(BuildContext context, WidgetRef ref) {
  final feedAsync = ref.watch(feedProvider);

  return feedAsync.when(
    loading: () => const FeedSkeletonList(), // includes a featured-card skeleton
    error: (err, stack) => FeedErrorState(onRetry: () => ref.invalidate(feedProvider)),
    data: (feed) => feed.items.isEmpty
        ? const FeedEmptyState()
        : FeedList(featured: feed.featured, rest: feed.rest),
  );
}
```

| State | UI treatment |
|---|---|
| `loading` (initial) | `FeedSkeletonList` — one featured-shaped shimmer block + several list-row shimmer blocks, matching the new two-tier layout exactly |
| `loading` (pagination) | Existing list stays visible; inline end-of-list loading indicator |
| `error` | Plain-language inline message + "Retry" button; never a raw exception string |
| `data` (empty) | Feed-specific empty state suggesting the user check their tag filters |
| `data` (populated) | Featured card + list, per §3.1 |

`summaryProvider`'s error branch still distinguishes `OfflineSummaryUnavailableException` from a generic upstream failure, with distinct copy for each.

---

## 5. Offline Support & Local Persistence Strategy

*(Unchanged from v1.0 — persistence strategy is independent of visual design direction.)*

### 5.1 Hive Box Schemas

```dart
// models/hive/article_box_entry.dart
@HiveType(typeId: 0)
class ArticleBoxEntry extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String title;
  @HiveField(2) late String source;
  @HiveField(3) late String canonicalUrl;
  @HiveField(4) late String? imageUrl;
  @HiveField(5) late List<String> tags;
  @HiveField(6) late DateTime publishedAt;
  @HiveField(7) late bool isSummarizable;
  @HiveField(8) late String? cleanedContentSnapshot;
  @HiveField(9) late int? hnPoints;        // used by pickFeatured() offline too
  @HiveField(10) late int? redditComments;
}

// models/hive/summary_box_entry.dart
@HiveType(typeId: 1)
class SummaryBoxEntry extends HiveObject {
  @HiveField(0) late String articleId;
  @HiveField(1) late String questionType;
  @HiveField(2) late List<String> content;
  @HiveField(3) late DateTime cachedAt;
}
// Box key convention: "{articleId}_{questionType}"

// models/hive/pending_action_box_entry.dart
@HiveType(typeId: 2)
class PendingActionBoxEntry extends HiveObject {
  @HiveField(0) late String articleId;
  @HiveField(1) late String actionType; // 'add' | 'remove'
  @HiveField(2) late DateTime queuedAt;
}
```

| Box | Type ID | Encrypted | Eviction |
|---|---|---|---|
| `article_box` | 0 | No | Capped at 200 most-recent, LRU |
| `summary_box` | 1 | No | Capped at 500 most-recent |
| `pending_action_box` | 2 | Yes (`HiveAesCipher`, key in `flutter_secure_storage`) | Removed only on confirmed sync |

### 5.2 Offline User Journey

```
┌─────────────────┐     online     ┌──────────────────────┐
│  App launches     │───────────────►│  Fetch /feed, write   │
│                    │                │  through to article_box│
└─────────────────┘                └──────────────────────┘
         │ offline
         ▼
┌─────────────────────────┐
│  Read article_box         │──► FeedList (featured + rest) from cache,
│  (last-synced snapshot)   │    offline banner shown
└─────────────────────────┘

┌─────────────────────────┐
│  User taps bookmark        │
│  while offline              │
└──────────┬──────────────┘
           ▼
┌─────────────────────────┐
│  Optimistic UI update      │  + write to pending_action_box
└──────────┬──────────────┘
           │  connectivity_plus reports reconnection
           ▼
┌─────────────────────────┐
│  flushPendingActions()     │  Sequential; delete on success,
│                              │  halt-and-retry-whole-queue on failure
└─────────────────────────┘  (idempotent add/remove, safe to retry)
```

### 5.3 Connectivity Detection Wiring

```dart
// connectivity_provider.dart
@riverpod
Stream<ConnectivityState> connectivity(ConnectivityRef ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    return ConnectivityState(isOnline: isOnline);
  });
}

// app_bootstrap.dart
ref.listen(connectivityProvider, (previous, next) {
  final wasOffline = previous?.valueOrNull?.isOnline == false;
  final isNowOnline = next.valueOrNull?.isOnline == true;
  if (wasOffline && isNowOnline) {
    ref.read(offlineCacheServiceProvider).flushPendingActions(
      ref.read(newsApiServiceProvider),
    );
  }
});
```

---

## 6. Animations, Micro-Interactions & Polish

### 6.1 Skeleton Shimmer Specification

| Property | Value |
|---|---|
| Package | `shimmer` |
| Base / highlight (light) | `--surface-outline` (`#E4DCC8`) / `#FFFDF9` |
| Base / highlight (dark) | `--surface-outline` (`#332E23`) / `#3D3829` |
| Sweep | Left-to-right, 1400ms |
| Shape fidelity | **Two distinct skeleton shapes** now, matching the two-tier layout: `FeaturedCardSkeleton` (4:3 block + headline lines at 26sp height) and `ListRowSkeleton` (88×88 block + headline lines at 19sp height) — using one generic skeleton shape for both would misrepresent the layout during load |
| Applies to | `FeedSkeletonList`, `SummarySheet` content area (pine-teal-tinted highlight during cache-miss wait) |

### 6.2 Haptic Feedback Triggers

| Interaction | Haptic |
|---|---|
| Bookmark toggle (add) | `HapticFeedback.lightImpact()` |
| Bookmark toggle (remove) | `HapticFeedback.selectionClick()` |
| Swipe-to-remove confirmed | `HapticFeedback.mediumImpact()` at threshold crossing |
| Summary angle tab switch | `HapticFeedback.selectionClick()` |
| Pull-to-refresh triggered | `HapticFeedback.lightImpact()` at threshold |

Unchanged principle: haptics only on discrete, user-confirmed actions.

### 6.3 Hero Transitions — Feed → Detail

```dart
// Featured card and list-row thumbnails both use the same Hero tag convention,
// so either entry point into an article animates consistently:
Hero(
  tag: 'article-thumbnail-${article.id}',
  child: ClipRRect(
    borderRadius: BorderRadius.circular(
      isFromFeatured ? 20 : 14, // matches the source card's own radius
    ),
    child: CachedNetworkImage(imageUrl: article.imageUrl),
  ),
)
```

The detail screen's hero image morphs from whichever radius its source card used (20px if opened from the featured card, 14px if opened from a list row) down to a full-bleed square-cornered hero — handled by the same `RadiusMorphTransition` shuttle builder as before. Headline text uses a coordinated `FadeTransition` rather than being included in the Hero itself, for the same reason as the prior revision: a font-size jump inside a Hero flight (19–26sp list → 26sp detail, or 26→26sp featured → detail) produces visible layout distortion mid-flight if the text itself is animated as one continuous Hero.

### 6.4 Swipe-to-Dismiss Spring Physics

```dart
Dismissible(
  key: ValueKey(article.id),
  direction: DismissDirection.endToStart,
  movementDuration: const Duration(milliseconds: 300),
  resizeDuration: const Duration(milliseconds: 250),
  background: RemoveBackground(),
  confirmDismiss: (direction) async {
    HapticFeedback.mediumImpact();
    return await showUndoSnackbar(context, article);
  },
  onDismissed: (_) => ref.read(bookmarkProvider.notifier).remove(article),
  child: BookmarkListRow(article: article), // reuses ArticleListRow, §3.1
)
```

Cancelled-swipe return-to-position uses a custom `Curves.easeOutCubic` reset (overriding `Dismissible`'s default linear snap-back), unchanged from the prior revision.

### 6.5 SummarySheet Streaming Reveal

Unchanged mechanism: on a cache-miss (first request for that angle), bullets fade+slide in with a 120ms stagger (~500ms total); on a cache hit, content renders with a plain 150ms fade — the reveal never fakes a "thinking" delay when the answer was actually instant.

### 6.6 Reduced Motion Compliance

All non-essential animation (staggered reveals, Hero radius-morph, shimmer sweep) respects `MediaQuery.of(context).disableAnimations`, falling back to instant state changes with opacity-only cross-fades retained.

---

*End of Frontend Specification Document.*
