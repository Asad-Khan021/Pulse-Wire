import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/article.dart';
import '../models/summary.dart';
import '../models/user_preference.dart';
import 'news_api_service.dart';

/// Representation of an action queued while offline for eventual sequential synchronization.
class PendingAction {
  final String id;
  final String actionType; // 'add_bookmark' | 'remove_bookmark'
  final String articleId;
  final Map<String, dynamic>? articleData;
  final DateTime createdAt;
  final int retryCount;

  const PendingAction({
    required this.id,
    required this.actionType,
    required this.articleId,
    this.articleData,
    required this.createdAt,
    this.retryCount = 0,
  });

  PendingAction copyWith({
    String? id,
    String? actionType,
    String? articleId,
    Map<String, dynamic>? articleData,
    DateTime? createdAt,
    int? retryCount,
  }) {
    return PendingAction(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      articleId: articleId ?? this.articleId,
      articleData: articleData ?? this.articleData,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'] as String,
      actionType: json['action_type'] as String,
      articleId: json['article_id'] as String,
      articleData: json['article_data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action_type': actionType,
      'article_id': articleId,
      'article_data': articleData,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }
}

/// OfflineCacheService manages Hive-backed local caching for Pulse Wire.
///
/// Features:
/// - Box `cached_articles`: Mirrors online feed articles and preserves chronological order.
/// - Box `cached_summaries`: Stores multi-angle AI summaries keyed by composite IDs.
/// - Box `cached_bookmarks`: Preserves user bookmarked stories for offline reading.
/// - Box `cached_preferences`: Preserves followed tags and muted domains offline.
/// - Box `pending_actions`: Idempotent offline write queue for bookmarks with sequential replay.
class OfflineCacheService {
  static const String articlesBoxName = 'cached_articles';
  static const String summariesBoxName = 'cached_summaries';
  static const String pendingActionsBoxName = 'pending_actions';
  static const String bookmarksBoxName = 'cached_bookmarks';
  static const String preferencesBoxName = 'cached_preferences';
  static const String metadataBoxName = 'cache_metadata';

  static bool _isInitialized = false;

  /// In-memory store fallback for environments where Hive boxes are not yet initialized (e.g. tests)
  static final Map<String, Map<dynamic, dynamic>> _inMemoryStore = {};

  /// Initializes Hive Flutter and opens all critical boxes with error resilience.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Hive.initFlutter();
      await Future.wait([
        Hive.openBox<dynamic>(articlesBoxName),
        Hive.openBox<dynamic>(summariesBoxName),
        Hive.openBox<dynamic>(pendingActionsBoxName),
        Hive.openBox<dynamic>(bookmarksBoxName),
        Hive.openBox<dynamic>(preferencesBoxName),
        Hive.openBox<dynamic>(metadataBoxName),
      ]);
      _isInitialized = true;
      debugPrint('[OfflineCacheService] Successfully initialized Hive boxes.');
    } catch (e, st) {
      debugPrint('[OfflineCacheService] Error initializing Hive: $e\n$st');
      _isInitialized = true;
    }
  }

  // --- Safe Storage Operations (Hive with In-Memory Fallback) ---

  dynamic _getFromStore(String boxName, dynamic key) {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName).get(key);
    }
    return _inMemoryStore[boxName]?[key];
  }

  Future<void> _putInStore(String boxName, dynamic key, dynamic value) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<dynamic>(boxName).put(key, value);
    } else {
      _inMemoryStore.putIfAbsent(boxName, () => {})[key] = value;
    }
  }

  Future<void> _putAllInStore(String boxName, Map<dynamic, dynamic> entries) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<dynamic>(boxName).putAll(entries);
    } else {
      _inMemoryStore.putIfAbsent(boxName, () => {}).addAll(entries);
    }
  }

  Future<void> _deleteFromStore(String boxName, dynamic key) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<dynamic>(boxName).delete(key);
    } else {
      _inMemoryStore[boxName]?.remove(key);
    }
  }

  Future<void> _clearStore(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<dynamic>(boxName).clear();
    } else {
      _inMemoryStore[boxName]?.clear();
    }
  }

  Iterable<dynamic> _keysFromStore(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName).keys;
    }
    return _inMemoryStore[boxName]?.keys ?? const [];
  }

  Iterable<dynamic> _valuesFromStore(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName).values;
    }
    return _inMemoryStore[boxName]?.values ?? const [];
  }

  // ===========================================================================
  // 1. ARTICLES CACHE (Feed Mirroring)
  // ===========================================================================

  /// Mirrors fetched articles into the local Hive store.
  Future<void> cacheArticles(List<ArticleListItem> articles) async {
    try {
      final Map<String, dynamic> entries = {};
      final List<String> currentOrder = List<String>.from(
        (_getFromStore(metadataBoxName, 'feed_order') as List<dynamic>?) ?? [],
      );

      for (final article in articles) {
        entries[article.id] = article.toJson();
        if (!currentOrder.contains(article.id)) {
          currentOrder.add(article.id);
        }
      }

      await _putAllInStore(articlesBoxName, entries);
      await _putInStore(metadataBoxName, 'feed_order', currentOrder);
      await _putInStore(metadataBoxName, 'last_articles_sync', DateTime.now().toIso8601String());
      debugPrint('[OfflineCacheService] Cached ${articles.length} articles into Hive.');
    } catch (e) {
      debugPrint('[OfflineCacheService] Failed to cache articles: $e');
    }
  }

  /// Retrieves articles from local Hive cache with optional tag filtering and domain exclusion.
  List<ArticleListItem> getCachedArticles({
    List<String>? tags,
    List<String>? excludeDomains,
  }) {
    try {
      final order = (_getFromStore(metadataBoxName, 'feed_order') as List<dynamic>?)?.cast<String>() ?? [];
      final List<ArticleListItem> results = [];

      // Retrieve in stored feed order
      for (final id in order) {
        final raw = _getFromStore(articlesBoxName, id);
        if (raw != null) {
          final map = Map<String, dynamic>.from(raw as Map);
          results.add(ArticleListItem.fromJson(map));
        }
      }

      // If feed_order was empty, scan box values directly
      if (results.isEmpty) {
        for (final raw in _valuesFromStore(articlesBoxName)) {
          if (raw is Map) {
            results.add(ArticleListItem.fromJson(Map<String, dynamic>.from(raw)));
          }
        }
        // Sort descending by publishedAt
        results.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      }

      // Filter by tags if specified
      var filtered = results;
      if (tags != null && tags.isNotEmpty) {
        final lowerTags = tags.map((t) => t.toLowerCase()).toSet();
        filtered = filtered.where((article) {
          return article.tags.any((t) => lowerTags.contains(t.toLowerCase()));
        }).toList();
      }

      // Filter by muted domains if specified
      if (excludeDomains != null && excludeDomains.isNotEmpty) {
        final lowerDomains = excludeDomains.map((d) => d.toLowerCase().trim()).toSet();
        filtered = filtered.where((article) {
          final urlLower = article.canonicalUrl.toLowerCase();
          final sourceLower = article.sourceName.toLowerCase();
          return !lowerDomains.any((domain) =>
              domain.isNotEmpty && (urlLower.contains(domain) || sourceLower.contains(domain)));
        }).toList();
      }

      return filtered;
    } catch (e) {
      debugPrint('[OfflineCacheService] Error reading cached articles: $e');
      return [];
    }
  }

  /// Returns timestamp of the most recent online feed synchronization.
  DateTime? getLastSyncedTime() {
    try {
      final raw = _getFromStore(metadataBoxName, 'last_articles_sync') as String?;
      if (raw != null) return DateTime.tryParse(raw);
    } catch (_) {}
    return null;
  }

  /// Clears the entire articles cache.
  Future<void> clearArticleCache() async {
    try {
      await _clearStore(articlesBoxName);
      await _deleteFromStore(metadataBoxName, 'feed_order');
    } catch (e) {
      debugPrint('[OfflineCacheService] Error clearing article cache: $e');
    }
  }

  // ===========================================================================
  // 2. SUMMARIES CACHE (Perspective Mirroring)
  // ===========================================================================

  static String summaryCacheKey(String articleId, QuestionType questionType) =>
      '${articleId}_${questionType.value}';

  /// Mirrors an AI perspective summary to Hive cache.
  Future<void> cacheSummary(SummaryResponse summary) async {
    try {
      final key = summaryCacheKey(summary.articleId, summary.questionType);
      await _putInStore(summariesBoxName, key, summary.toJson());
      debugPrint('[OfflineCacheService] Cached summary for $key');
    } catch (e) {
      debugPrint('[OfflineCacheService] Failed to cache summary: $e');
    }
  }

  /// Retrieves a cached summary for a specific article and question angle.
  SummaryResponse? getCachedSummary(String articleId, QuestionType questionType) {
    try {
      final key = summaryCacheKey(articleId, questionType);
      final raw = _getFromStore(summariesBoxName, key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw as Map);
        // Mark as cached explicitly when served from offline cache
        map['cached'] = true;
        return SummaryResponse.fromJson(map);
      }
    } catch (e) {
      debugPrint('[OfflineCacheService] Error reading cached summary: $e');
    }
    return null;
  }

  // ===========================================================================
  // 3. BOOKMARKS CACHE & OFFLINE SNAPSHOTS
  // ===========================================================================

  /// Caches a bookmarked story locally.
  Future<void> cacheBookmark(ArticleListItem article) async {
    try {
      await _putInStore(bookmarksBoxName, article.id, article.toJson());
      debugPrint('[OfflineCacheService] Cached bookmark ${article.id}');
    } catch (e) {
      debugPrint('[OfflineCacheService] Failed to cache bookmark: $e');
    }
  }

  /// Removes a cached bookmark from Hive.
  Future<void> removeCachedBookmark(String articleId) async {
    try {
      await _deleteFromStore(bookmarksBoxName, articleId);
      debugPrint('[OfflineCacheService] Removed bookmark $articleId from cache');
    } catch (e) {
      debugPrint('[OfflineCacheService] Failed to remove cached bookmark: $e');
    }
  }

  /// Returns all cached bookmarks.
  Map<String, ArticleListItem> getCachedBookmarks() {
    try {
      final Map<String, ArticleListItem> results = {};
      for (final key in _keysFromStore(bookmarksBoxName)) {
        final raw = _getFromStore(bookmarksBoxName, key);
        if (raw is Map) {
          results[key.toString()] = ArticleListItem.fromJson(
            Map<String, dynamic>.from(raw),
          );
        }
      }
      return results;
    } catch (e) {
      debugPrint('[OfflineCacheService] Error reading cached bookmarks: $e');
      return {};
    }
  }

  /// Replaces the entire local bookmarks cache with a fresh server snapshot.
  Future<void> replaceCachedBookmarks(List<ArticleListItem> serverBookmarks) async {
    try {
      await _clearStore(bookmarksBoxName);
      final Map<String, dynamic> entries = {};
      for (final article in serverBookmarks) {
        entries[article.id] = article.toJson();
      }
      await _putAllInStore(bookmarksBoxName, entries);
    } catch (e) {
      debugPrint('[OfflineCacheService] Error replacing cached bookmarks: $e');
    }
  }

  // ===========================================================================
  // 4. USER PREFERENCES CACHE
  // ===========================================================================

  /// Caches followed tags and muted domains locally.
  Future<void> cachePreferences(UserPreference preferences) async {
    try {
      await _putInStore(preferencesBoxName, 'user_preference', preferences.toJson());
    } catch (e) {
      debugPrint('[OfflineCacheService] Failed to cache preferences: $e');
    }
  }

  /// Retrieves user preferences from Hive cache.
  UserPreference? getCachedPreferences() {
    try {
      final raw = _getFromStore(preferencesBoxName, 'user_preference');
      if (raw is Map) {
        return UserPreference.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('[OfflineCacheService] Error reading cached preferences: $e');
    }
    return null;
  }

  // ===========================================================================
  // 5. IDEMPOTENT ACTION QUEUE ENGINE (`pending_actions`)
  // ===========================================================================

  /// Queues an action locally when offline or during transient network drops.
  Future<void> queueAction({
    required String actionType,
    required String articleId,
    Map<String, dynamic>? articleData,
  }) async {
    try {
      String? existingKey;
      PendingAction? existingAction;
      for (final key in _keysFromStore(pendingActionsBoxName)) {
        final raw = _getFromStore(pendingActionsBoxName, key);
        if (raw is Map) {
          final action = PendingAction.fromJson(Map<String, dynamic>.from(raw));
          if (action.articleId == articleId) {
            existingKey = key.toString();
            existingAction = action;
            break;
          }
        }
      }

      if (existingAction != null && existingKey != null) {
        if (existingAction.actionType == actionType) {
          return;
        }

        if (existingAction.actionType == 'add_bookmark' && actionType == 'remove_bookmark') {
          await _deleteFromStore(pendingActionsBoxName, existingKey);
          debugPrint('[OfflineCacheService] Coalesced and cancelled pending bookmark action for $articleId');
          return;
        }

        if (existingAction.actionType == 'remove_bookmark' && actionType == 'add_bookmark') {
          final updated = existingAction.copyWith(
            actionType: 'add_bookmark',
            articleData: articleData,
            createdAt: DateTime.now(),
          );
          await _putInStore(pendingActionsBoxName, existingKey, updated.toJson());
          debugPrint('[OfflineCacheService] Coalesced pending removal to add for $articleId');
          return;
        }
      }

      final actionId = 'action_${DateTime.now().millisecondsSinceEpoch}_$articleId';
      final action = PendingAction(
        id: actionId,
        actionType: actionType,
        articleId: articleId,
        articleData: articleData,
        createdAt: DateTime.now(),
      );

      await _putInStore(pendingActionsBoxName, actionId, action.toJson());
      debugPrint('[OfflineCacheService] Enqueued pending action: $actionType for $articleId');
    } catch (e) {
      debugPrint('[OfflineCacheService] Failed to queue pending action: $e');
    }
  }

  /// Returns all pending actions currently waiting to be synchronized.
  List<PendingAction> getPendingActions() {
    try {
      final List<PendingAction> list = [];
      for (final key in _keysFromStore(pendingActionsBoxName)) {
        final raw = _getFromStore(pendingActionsBoxName, key);
        if (raw is Map) {
          list.add(PendingAction.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    } catch (e) {
      debugPrint('[OfflineCacheService] Error reading pending actions: $e');
      return [];
    }
  }

  /// Flushes all pending actions sequentially upon network restoration.
  Future<int> flushPendingActions(NewsApiService apiService) async {
    final pending = getPendingActions();
    if (pending.isEmpty) {
      debugPrint('[OfflineCacheService] No pending actions to flush.');
      return 0;
    }

    debugPrint('[OfflineCacheService] Replaying ${pending.length} pending actions sequentially...');
    int flushedCount = 0;

    for (final action in pending) {
      try {
        if (action.actionType == 'add_bookmark') {
          await apiService.addBookmark(action.articleId);
        } else if (action.actionType == 'remove_bookmark') {
          await apiService.removeBookmark(action.articleId);
        }

        await _deleteFromStore(pendingActionsBoxName, action.id);
        flushedCount++;
        debugPrint('[OfflineCacheService] Replayed action ${action.id} (${action.actionType}) successfully.');
      } catch (e) {
        debugPrint('[OfflineCacheService] Failed to replay action ${action.id}: $e');

        if (e is ApiException && e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          await _deleteFromStore(pendingActionsBoxName, action.id);
        } else {
          final updated = action.copyWith(retryCount: action.retryCount + 1);
          await _putInStore(pendingActionsBoxName, action.id, updated.toJson());
          debugPrint('[OfflineCacheService] Reconnection flush suspended due to network drop. Will retry.');
          break;
        }
      }
    }

    debugPrint('[OfflineCacheService] Flush completed. Successfully committed $flushedCount actions.');
    return flushedCount;
  }
}
