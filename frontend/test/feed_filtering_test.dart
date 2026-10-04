import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_wire/models/article.dart';
import 'package:pulse_wire/models/user_preference.dart';
import 'package:pulse_wire/providers/feed_provider.dart';
import 'package:pulse_wire/providers/preferences_provider.dart';

void main() {
  group('Personalization Engine Client-Side Filtering Tests', () {
    test('filteredFeedArticlesProvider immediately purges muted source articles', () {
      final articleA = ArticleListItem(
        id: '1',
        sourceId: 'techcrunch',
        title: 'TechCrunch Article',
        canonicalUrl: 'https://techcrunch.com/article-1',
        tags: const ['AI'],
        isSummarizable: true,
        publishedAt: DateTime.now(),
        sourceName: 'TechCrunch',
      );

      final articleB = ArticleListItem(
        id: '2',
        sourceId: 'theverge',
        title: 'The Verge Article',
        canonicalUrl: 'https://theverge.com/article-2',
        tags: const ['Hardware'],
        isSummarizable: true,
        publishedAt: DateTime.now(),
        sourceName: 'The Verge',
      );

      final articleC = ArticleListItem(
        id: '3',
        sourceId: 'arstechnica',
        title: 'Ars Technica Article',
        canonicalUrl: 'https://arstechnica.com/article-3',
        tags: const ['Security'],
        isSummarizable: true,
        publishedAt: DateTime.now(),
        sourceName: 'Ars Technica',
      );

      final container = ProviderContainer(
        overrides: [
          feedProvider.overrideWith((ref) => _StaticFeedNotifier([articleA, articleB, articleC])),
          preferencesProvider.overrideWith((ref) => _StaticPreferencesNotifier(
                const UserPreference(
                  userId: 'test',
                  followedTags: ['AI', 'Security'],
                  mutedDomains: ['theverge.com'],
                ),
              )),
        ],
      );

      final filtered = container.read(filteredFeedArticlesProvider);

      // Verify that The Verge article is immediately purged
      expect(filtered.length, 2);
      expect(filtered.any((a) => a.id == '2'), isFalse);
      expect(filtered.any((a) => a.id == '1'), isTrue);
      expect(filtered.any((a) => a.id == '3'), isTrue);
    });
  });
}

class _StaticFeedNotifier extends StateNotifier<FeedState> implements FeedNotifier {
  _StaticFeedNotifier(List<ArticleListItem> articles)
      : super(FeedState(articles: articles, isLoadingInitial: false));

  @override
  Future<void> loadInitial() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}

  @override
  void toggleTag(String tag) {}
}

class _StaticPreferencesNotifier extends StateNotifier<UserPreference>
    implements PreferencesNotifier {
  _StaticPreferencesNotifier(super.state);

  @override
  Future<void> toggleFollowedTag(String tag) async {}

  @override
  Future<void> addMutedDomain(String rawDomain) async {}

  @override
  Future<void> removeMutedDomain(String rawDomain) async {}
}
