import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../services/news_api_service.dart';
import '../services/offline_cache_service.dart';
import 'connectivity_provider.dart';
import 'preferences_provider.dart';

final apiServiceProvider = Provider<NewsApiService>((ref) {
  return NewsApiService();
});

class FeedState {
  final List<ArticleListItem> articles;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final List<String> selectedTags;
  final String? errorMessage;
  final bool isOffline;
  final bool isFromCache;
  final DateTime? lastSyncedAt;

  const FeedState({
    this.articles = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.selectedTags = const [],
    this.errorMessage,
    this.isOffline = false,
    this.isFromCache = false,
    this.lastSyncedAt,
  });

  FeedState copyWith({
    List<ArticleListItem>? articles,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    List<String>? selectedTags,
    String? errorMessage,
    bool? isOffline,
    bool? isFromCache,
    DateTime? lastSyncedAt,
  }) {
    return FeedState(
      articles: articles ?? this.articles,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedTags: selectedTags ?? this.selectedTags,
      errorMessage: errorMessage,
      isOffline: isOffline ?? this.isOffline,
      isFromCache: isFromCache ?? this.isFromCache,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final NewsApiService _apiService;
  final OfflineCacheService _cacheService;
  final Ref _ref;

  FeedNotifier(this._apiService, this._cacheService, this._ref)
      : super(const FeedState()) {
    loadInitial();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (previous == false && next == true) {
        // Transitioned back online: silently refresh feed
        debugPrint('[FeedNotifier] Connection restored. Refreshing live feed...');
        refresh();
      }
    });
  }

  /// Initial feed load with transparent offline Hive fallback.
  Future<void> loadInitial() async {
    state = state.copyWith(isLoadingInitial: true, errorMessage: null);

    final isOnline = _ref.read(isOnlineProvider);
    final preferences = _ref.read(preferencesProvider);

    // 1. If currently offline, serve local Hive snapshot immediately
    if (!isOnline) {
      _loadFromCache(preferences.mutedDomains);
      return;
    }

    // 2. Fetch live data from NewsApiService
    try {
      final response = await _apiService.getFeed(
        limit: 20,
        tags: state.selectedTags.isEmpty ? null : state.selectedTags,
        excludeDomains: preferences.mutedDomains.isEmpty ? null : preferences.mutedDomains,
      );

      // Automatically mirror response to Hive box
      await _cacheService.cacheArticles(response.items);

      state = state.copyWith(
        articles: response.items,
        nextCursor: response.nextCursor,
        hasMore: response.nextCursor != null,
        isLoadingInitial: false,
        isOffline: false,
        isFromCache: false,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[FeedNotifier] Online feed fetch failed ($e). Falling back to Hive cache...');
      // 3. Transparent fallback on network/server error
      _loadFromCache(preferences.mutedDomains, errorFallback: e.toString());
    }
  }

  /// Loads cached articles from Hive and applies current tag & domain filters.
  void _loadFromCache(List<String> mutedDomains, {String? errorFallback}) {
    final cached = _cacheService.getCachedArticles(
      tags: state.selectedTags.isEmpty ? null : state.selectedTags,
      excludeDomains: mutedDomains.isEmpty ? null : mutedDomains,
    );
    final lastSync = _cacheService.getLastSyncedTime();

    state = state.copyWith(
      articles: cached,
      hasMore: false,
      nextCursor: null,
      isLoadingInitial: false,
      isOffline: true,
      isFromCache: true,
      lastSyncedAt: lastSync,
      errorMessage: cached.isEmpty ? (errorFallback ?? 'Device is offline and no cached stories were found.') : null,
    );
  }

  /// User pull-to-refresh
  Future<void> refresh() async {
    final isOnline = _ref.read(isOnlineProvider);
    final preferences = _ref.read(preferencesProvider);

    if (!isOnline) {
      _loadFromCache(preferences.mutedDomains);
      return;
    }

    try {
      final response = await _apiService.getFeed(
        limit: 20,
        tags: state.selectedTags.isEmpty ? null : state.selectedTags,
        excludeDomains: preferences.mutedDomains.isEmpty ? null : preferences.mutedDomains,
      );

      await _cacheService.cacheArticles(response.items);

      state = state.copyWith(
        articles: response.items,
        nextCursor: response.nextCursor,
        hasMore: response.nextCursor != null,
        errorMessage: null,
        isOffline: false,
        isFromCache: false,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Paginated infinite scroll
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) return;

    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      // Pagination unavailable offline
      return;
    }

    final preferences = _ref.read(preferencesProvider);
    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _apiService.getFeed(
        limit: 20,
        cursor: state.nextCursor,
        tags: state.selectedTags.isEmpty ? null : state.selectedTags,
        excludeDomains: preferences.mutedDomains.isEmpty ? null : preferences.mutedDomains,
      );

      // Mirror appended articles to Hive
      await _cacheService.cacheArticles(response.items);

      final combined = [...state.articles, ...response.items];
      state = state.copyWith(
        articles: combined,
        nextCursor: response.nextCursor,
        hasMore: response.nextCursor != null,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Updates active tag filter and reloads feed
  void toggleTag(String tag) {
    final current = List<String>.from(state.selectedTags);
    if (tag == 'All') {
      current.clear();
    } else if (current.contains(tag)) {
      current.remove(tag);
    } else {
      current.add(tag);
    }
    state = state.copyWith(selectedTags: current);
    loadInitial();
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return FeedNotifier(api, cache, ref);
});

/// Client-Side Feed Filtering Stream:
/// Purges muted source articles immediately across both online and Hive-cached states.
final filteredFeedArticlesProvider = Provider<List<ArticleListItem>>((ref) {
  final feedState = ref.watch(feedProvider);
  final preferences = ref.watch(preferencesProvider);
  final muted = preferences.mutedDomains.map((d) => d.toLowerCase().trim()).toSet();

  if (muted.isEmpty) {
    return feedState.articles;
  }

  return feedState.articles.where((article) {
    final urlLower = article.canonicalUrl.toLowerCase();
    final sourceLower = article.sourceName.toLowerCase();
    return !muted.any((domain) =>
        domain.isNotEmpty && (urlLower.contains(domain) || sourceLower.contains(domain)));
  }).toList();
});
