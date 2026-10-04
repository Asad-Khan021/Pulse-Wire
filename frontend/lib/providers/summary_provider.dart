import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/summary.dart';
import '../services/news_api_service.dart';
import '../services/offline_cache_service.dart';
import 'connectivity_provider.dart';
import 'feed_provider.dart';

class SummaryQueryKey {
  final String articleId;
  final QuestionType questionType;

  const SummaryQueryKey({
    required this.articleId,
    required this.questionType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SummaryQueryKey &&
          runtimeType == other.runtimeType &&
          articleId == other.articleId &&
          questionType == other.questionType;

  @override
  int get hashCode => articleId.hashCode ^ questionType.hashCode;
}

final summaryProvider = StateNotifierProvider.family<
    SummaryNotifier,
    AsyncValue<SummaryResponse>,
    SummaryQueryKey>((ref, key) {
  final api = ref.watch(apiServiceProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return SummaryNotifier(api, cache, ref, key);
});

class SummaryNotifier extends StateNotifier<AsyncValue<SummaryResponse>> {
  final NewsApiService _api;
  final OfflineCacheService _cache;
  final Ref _ref;
  final SummaryQueryKey _key;

  SummaryNotifier(this._api, this._cache, this._ref, this._key)
      : super(const AsyncValue.loading()) {
    fetch();
  }

  /// Transparently serves offline Hive cache or fetches live perspective from API.
  Future<void> fetch() async {
    state = const AsyncValue.loading();

    // 1. Check local Hive cache first
    final cached = _cache.getCachedSummary(_key.articleId, _key.questionType);
    final isOnline = _ref.read(isOnlineProvider);

    // 2. If offline, immediately serve cached snapshot or informative offline error
    if (!isOnline) {
      if (cached != null) {
        state = AsyncValue.data(cached);
        return;
      }
      state = AsyncValue.error(
        const ApiException(
          message: 'Offline perspective not cached. Please connect to the internet to generate this summary.',
        ),
        StackTrace.current,
      );
      return;
    }

    // 3. Online fetch: Serve cache immediately if available, then revalidate, or fetch live
    if (cached != null) {
      state = AsyncValue.data(cached);
    }

    try {
      final summary = await _api.getSummary(_key.articleId, _key.questionType);
      // Automatically mirror response to Hive box
      await _cache.cacheSummary(summary);
      state = AsyncValue.data(summary);
    } catch (e, st) {
      // If live fetch failed but we had a cache hit, keep the cache
      if (cached != null) {
        state = AsyncValue.data(cached);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> retry() => fetch();
}
