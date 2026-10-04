import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../services/news_api_service.dart';
import '../services/offline_cache_service.dart';
import 'connectivity_provider.dart';
import 'feed_provider.dart';

class BookmarksState {
  final Map<String, ArticleListItem> bookmarkedArticles;
  final String? errorMessage;
  final int pendingSyncCount;

  const BookmarksState({
    this.bookmarkedArticles = const {},
    this.errorMessage,
    this.pendingSyncCount = 0,
  });

  bool isBookmarked(String articleId) => bookmarkedArticles.containsKey(articleId);

  List<ArticleListItem> get list => bookmarkedArticles.values.toList();

  BookmarksState copyWith({
    Map<String, ArticleListItem>? bookmarkedArticles,
    String? errorMessage,
    int? pendingSyncCount,
  }) {
    return BookmarksState(
      bookmarkedArticles: bookmarkedArticles ?? this.bookmarkedArticles,
      errorMessage: errorMessage,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }
}

class BookmarksNotifier extends StateNotifier<BookmarksState> {
  final NewsApiService _apiService;
  final OfflineCacheService _cacheService;
  final Ref _ref;

  BookmarksNotifier(this._apiService, this._cacheService, this._ref)
      : super(const BookmarksState()) {
    _initBookmarks();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (previous == false && next == true) {
        // Reconnected to internet: refresh pending count and synchronize
        _refreshPendingCount();
        _syncServerBookmarks();
      }
    });
  }

  Future<void> _initBookmarks() async {
    // 1. Instant local restore from Hive cache
    final localBookmarks = _cacheService.getCachedBookmarks();
    final pending = _cacheService.getPendingActions();

    state = state.copyWith(
      bookmarkedArticles: localBookmarks,
      pendingSyncCount: pending.length,
    );

    // 2. Fetch server bookmarks if online
    await _syncServerBookmarks();
  }

  Future<void> _syncServerBookmarks() async {
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) return;

    try {
      final serverBookmarks = await _apiService.getBookmarks();
      if (serverBookmarks.isNotEmpty) {
        final Map<String, ArticleListItem> map = {};
        for (final item in serverBookmarks) {
          map[item.id] = item;
        }

        // Merge with any uncommitted offline additions
        final pending = _cacheService.getPendingActions();
        for (final action in pending) {
          if (action.actionType == 'add_bookmark' && action.articleData != null) {
            map[action.articleId] = ArticleListItem.fromJson(action.articleData!);
          } else if (action.actionType == 'remove_bookmark') {
            map.remove(action.articleId);
          }
        }

        state = state.copyWith(bookmarkedArticles: map);
        await _cacheService.replaceCachedBookmarks(map.values.toList());
      }
      _refreshPendingCount();
    } catch (e) {
      debugPrint('[BookmarksNotifier] Server bookmark fetch failed ($e). Preserving local cache.');
    }
  }

  void _refreshPendingCount() {
    final count = _cacheService.getPendingActions().length;
    state = state.copyWith(pendingSyncCount: count);
  }

  /// Optimistically toggles bookmark status with offline write queue support.
  Future<void> toggleBookmark(ArticleListItem article) async {
    final isCurrentlyBookmarked = state.isBookmarked(article.id);
    final isOnline = _ref.read(isOnlineProvider);

    // 1. Optimistic UI update
    final updatedMap = Map<String, ArticleListItem>.from(state.bookmarkedArticles);
    if (isCurrentlyBookmarked) {
      updatedMap.remove(article.id);
      await _cacheService.removeCachedBookmark(article.id);
    } else {
      updatedMap[article.id] = article;
      await _cacheService.cacheBookmark(article);
    }

    state = state.copyWith(bookmarkedArticles: updatedMap, errorMessage: null);

    // 2. If Offline: queue in Hive pending_actions write queue
    if (!isOnline) {
      await _cacheService.queueAction(
        actionType: isCurrentlyBookmarked ? 'remove_bookmark' : 'add_bookmark',
        articleId: article.id,
        articleData: isCurrentlyBookmarked ? null : article.toJson(),
      );
      _refreshPendingCount();
      return;
    }

    // 3. If Online: Attempt live API call
    try {
      if (isCurrentlyBookmarked) {
        await _apiService.removeBookmark(article.id);
      } else {
        await _apiService.addBookmark(article.id);
      }
      _refreshPendingCount();
    } catch (e) {
      debugPrint('[BookmarksNotifier] Live bookmark sync failed ($e). Queuing offline action for retry.');
      // Enqueue to pending_actions for sequential replay upon reconnection
      await _cacheService.queueAction(
        actionType: isCurrentlyBookmarked ? 'remove_bookmark' : 'add_bookmark',
        articleId: article.id,
        articleData: isCurrentlyBookmarked ? null : article.toJson(),
      );
      _refreshPendingCount();
    }
  }

  /// Removes a bookmark from the saved list.
  Future<void> removeBookmark(String articleId) async {
    final article = state.bookmarkedArticles[articleId];
    if (article == null) return;
    await toggleBookmark(article);
  }
}

final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, BookmarksState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return BookmarksNotifier(api, cache, ref);
});
