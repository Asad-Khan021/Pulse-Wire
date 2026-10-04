import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_wire/models/article.dart';
import 'package:pulse_wire/models/summary.dart';
import 'package:pulse_wire/models/user_preference.dart';
import 'package:pulse_wire/services/offline_cache_service.dart';

void main() {
  group('OfflineCacheService Unit Tests', () {
    late OfflineCacheService cacheService;

    setUp(() {
      cacheService = OfflineCacheService();
    });

    test('Article Caching & Tag/Domain Filtering', () async {
      final article1 = ArticleListItem(
        id: 'art-1',
        sourceId: 'techcrunch',
        title: 'Anthropic Unveils New Model',
        canonicalUrl: 'https://techcrunch.com/2026/anthropic-model',
        tags: const ['AI', 'Startups'],
        isSummarizable: true,
        publishedAt: DateTime.parse('2026-09-24T10:00:00Z'),
        sourceName: 'TechCrunch',
      );

      final article2 = ArticleListItem(
        id: 'art-2',
        sourceId: 'theverge',
        title: 'New Hardware Announcements',
        canonicalUrl: 'https://theverge.com/hardware-news',
        tags: const ['Hardware'],
        isSummarizable: true,
        publishedAt: DateTime.parse('2026-09-24T09:00:00Z'),
        sourceName: 'The Verge',
      );

      await cacheService.cacheArticles([article1, article2]);

      // All articles
      final all = cacheService.getCachedArticles();
      expect(all.length, 2);
      expect(all.first.id, 'art-1');

      // Tag filter
      final aiOnly = cacheService.getCachedArticles(tags: ['AI']);
      expect(aiOnly.length, 1);
      expect(aiOnly.first.id, 'art-1');

      // Domain mute filter
      final muted = cacheService.getCachedArticles(excludeDomains: ['theverge.com']);
      expect(muted.length, 1);
      expect(muted.first.id, 'art-1');
    });

    test('Summary Caching & Composite Key Lookup', () async {
      final validSummary = SummaryResponse(
        articleId: 'art-100',
        questionType: QuestionType.core,
        content: const ['Point 1: Major discovery', 'Point 2: Industry implications'],
        cached: false,
        modelUsed: 'Pulse Wire Intelligence',
        promptVersion: 'v1.0',
        generatedAt: DateTime.parse('2026-09-24T12:00:00Z'),
      );

      await cacheService.cacheSummary(validSummary);

      final retrieved = cacheService.getCachedSummary('art-100', QuestionType.core);
      expect(retrieved, isNotNull);
      expect(retrieved!.content.length, 2);
      expect(retrieved.cached, isTrue); // Automatically marked as cached on offline fetch

      // Non-existent perspective returns null
      final risk = cacheService.getCachedSummary('art-100', QuestionType.risk);
      expect(risk, isNull);
    });

    test('Bookmarks Caching and Offline Persistence', () async {
      final article = ArticleListItem(
        id: 'book-1',
        sourceId: 'wired',
        title: 'Deep Learning Advances',
        canonicalUrl: 'https://wired.com/deep-learning',
        tags: const ['AI'],
        isSummarizable: true,
        publishedAt: DateTime.parse('2026-09-24T08:00:00Z'),
        sourceName: 'Wired',
      );

      await cacheService.cacheBookmark(article);
      final bookmarks = cacheService.getCachedBookmarks();
      expect(bookmarks.containsKey('book-1'), isTrue);
      expect(bookmarks['book-1']!.title, 'Deep Learning Advances');

      await cacheService.removeCachedBookmark('book-1');
      final updated = cacheService.getCachedBookmarks();
      expect(updated.containsKey('book-1'), isFalse);
    });

    test('User Preferences Caching', () async {
      const pref = UserPreference(
        userId: 'usr-42',
        followedTags: ['AI', 'Rust'],
        mutedDomains: ['clickbait.net'],
      );

      await cacheService.cachePreferences(pref);
      final retrieved = cacheService.getCachedPreferences();
      expect(retrieved, isNotNull);
      expect(retrieved!.followedTags, contains('Rust'));
      expect(retrieved.mutedDomains, contains('clickbait.net'));
    });

    test('Idempotent Action Queue: Coalescing opposite actions', () async {
      // 1. Queue add_bookmark
      await cacheService.queueAction(
        actionType: 'add_bookmark',
        articleId: 'story-99',
      );
      expect(cacheService.getPendingActions().length, 1);

      // 2. Queue remove_bookmark on same uncommitted story -> Cancels out
      await cacheService.queueAction(
        actionType: 'remove_bookmark',
        articleId: 'story-99',
      );
      expect(cacheService.getPendingActions().length, 0);

      // 3. Queue remove_bookmark first, then add_bookmark -> Coalesces to add_bookmark
      await cacheService.queueAction(
        actionType: 'remove_bookmark',
        articleId: 'story-101',
      );
      expect(cacheService.getPendingActions().first.actionType, 'remove_bookmark');

      await cacheService.queueAction(
        actionType: 'add_bookmark',
        articleId: 'story-101',
      );
      expect(cacheService.getPendingActions().length, 1);
      expect(cacheService.getPendingActions().first.actionType, 'add_bookmark');
    });
  });
}
