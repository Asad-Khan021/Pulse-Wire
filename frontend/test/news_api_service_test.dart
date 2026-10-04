import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_wire/core/constants/api_constants.dart';
import 'package:pulse_wire/models/summary.dart';
import 'package:pulse_wire/services/news_api_service.dart';

void main() {
  group('NewsApiService Live & Fallback Tests', () {
    test('fetches live tech news feed from NewsAPI successfully', () async {
      final service = NewsApiService();
      final result = await service.fetchTechNewsFeed(pageSize: 5);

      expect(result['status'], 'success');
      expect(result['articles'], isA<List>());
      final articles = result['articles'] as List<dynamic>;
      expect(articles.isNotEmpty, true);

      final first = articles.first as Map<String, dynamic>;
      expect(first['title'], isNotEmpty);
      expect(first['category'], isNotEmpty);
      expect(first['categories'], isA<List>());
    });

    test('getFeed falls back to direct NewsAPI when backend baseUrl is unreachable', () async {
      // Point to an invalid local port to simulate Connection Refused
      final service = NewsApiService(baseUrl: 'http://127.0.0.1:59999/api/v1');
      final feedResponse = await service.getFeed(limit: 5);

      expect(feedResponse.items.isNotEmpty, true);
      final item = feedResponse.items.first;
      expect(item.title, isNotEmpty);
      expect(item.tags, isNotEmpty);
      expect(item.sourceName, isNotEmpty);

      // Verify article detail fallback works from in-memory cache
      final detail = await service.getArticleDetail(item.id);
      expect(detail.id, item.id);
      expect(detail.title, item.title);

      // Verify summary fallback works from in-memory cache
      final summary = await service.getSummary(item.id, QuestionType.core);
      expect(summary.articleId, item.id);
      expect(summary.content.isNotEmpty, true);
    });

    test('getFeed filters by Machine Learning and AI tags', () async {
      final service = NewsApiService(baseUrl: 'http://127.0.0.1:59999/api/v1');
      final feedResponse = await service.getFeed(limit: 20, tags: ['AI']);

      for (final item in feedResponse.items) {
        expect(item.tags.contains('AI'), true);
      }
    });

    test('cleanHtmlToPlainText cleans HTML, strips scripts and extracts full article paragraphs', () {
      const sampleHtml = '''
      <!DOCTYPE html>
      <html>
        <head><script>alert("tracker");</script><style>.ad{display:none}</style></head>
        <body>
          <nav><a href="/">Home</a><a href="/news">Tech</a></nav>
          <header><h1>Tech Daily Header</h1></header>
          <article class="article-body">
            <h2>Next-Gen Quantum Computing Architecture Revealed</h2>
            <p>Engineers have announced an innovative topological qubit framework operating stably at ambient room temperatures.</p>
            <div class="advertisement">Sponsored: Click here to buy gadgets.</div>
            <p>The breakthrough dramatically reduces quantum decoherence error rates by three orders of magnitude, paving the path to commercial fault tolerance.</p>
            <p>Industry leaders expect early pilot systems to be integrated into leading cloud data centers by the end of next year.</p>
          </article>
          <footer>Copyright 2026 Tech Daily. All rights reserved.</footer>
        </body>
      </html>
      ''';

      final cleaned = NewsApiService.cleanHtmlToPlainText(sampleHtml);
      expect(cleaned.contains('alert'), isFalse);
      expect(cleaned.contains('.ad'), isFalse);
      expect(cleaned.contains('Next-Gen Quantum Computing Architecture Revealed'), isTrue);
      expect(cleaned.contains('topological qubit framework'), isTrue);
      expect(cleaned.contains('quantum decoherence error rates'), isTrue);
      expect(cleaned.contains('cloud data centers'), isTrue);
      expect(cleaned.contains('Copyright'), isFalse);

      // Verify paragraphs are separated by double newlines
      final paragraphs = cleaned.split('\n\n');
      expect(paragraphs.length, greaterThanOrEqualTo(3));
    });

    test('ApiConstants provides dynamic and platform-aware base URLs', () {
      expect(ApiConstants.newsApiKey, isNotEmpty);
      expect(ApiConstants.defaultBaseUrl, isNotEmpty);

      ApiConstants.setBaseUrl('http://192.168.100.21:8000/api/v1');
      expect(ApiConstants.defaultBaseUrl, 'http://192.168.100.21:8000/api/v1');

      // Reset
      ApiConstants.setBaseUrl('');
    });
  });
}
