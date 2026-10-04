import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_wire/services/news_api_service.dart';

void main() {
  group('NewsApiCategorizer & Section Routing Tests', () {
    test('routes Machine Learning articles into Machine Learning and AI sections', () {
      const title = 'PyTorch 2.5 Accelerates Deep Learning and Neural Network Training';
      const desc = 'New tensor compiler speeds up transformer model weights and reinforcement learning.';

      final categories = NewsApiCategorizer.assignCategories(title, desc);
      final primary = NewsApiCategorizer.assignCategory(title, desc);

      expect(categories, contains('Machine Learning'));
      expect(categories, contains('AI'));
      expect(primary, anyOf('Machine Learning', 'AI'));
    });

    test('routes AI and LLM articles into AI section', () {
      const title = 'OpenAI Unveils Advanced Voice Features in ChatGPT Plus';
      const desc = 'The generative AI company expands agentic multimodal capabilities.';

      final categories = NewsApiCategorizer.assignCategories(title, desc);
      final primary = NewsApiCategorizer.assignCategory(title, desc);

      expect(categories, contains('AI'));
      expect(primary, 'AI');
    });

    test('routes Cybersecurity articles into Cybersecurity section', () {
      const title = 'Critical Zero-Day Vulnerability Exposed in Enterprise VPN';
      const desc = 'Security researchers identify malware and ransomware targeting corporate servers.';

      final categories = NewsApiCategorizer.assignCategories(title, desc);
      final primary = NewsApiCategorizer.assignCategory(title, desc);

      expect(categories, contains('Cybersecurity'));
      expect(primary, 'Cybersecurity');
    });

    test('routes Cloud and Infrastructure articles into Cloud section', () {
      const title = 'AWS Announces New Kubernetes Cluster Features';
      const desc = 'DevOps teams can now automate multi-region Docker deployments.';

      final categories = NewsApiCategorizer.assignCategories(title, desc);
      expect(categories, contains('Cloud'));
    });

    test('routes Hardware articles into Hardware section', () {
      const title = 'Nvidia Blackwell GPU Production Reaches Scale';
      const desc = 'Semiconductor and chip manufacturing updates from TSMC.';

      final categories = NewsApiCategorizer.assignCategories(title, desc);
      expect(categories, contains('Hardware'));
    });

    test('falls back to General Tech for unclassified stories', () {
      const title = 'Tech Conference Announces Dates for Next Year';
      const desc = 'Registration opens next month in San Francisco.';

      final categories = NewsApiCategorizer.assignCategories(title, desc);
      expect(categories, ['General Tech']);
      expect(NewsApiCategorizer.assignCategory(title, desc), 'General Tech');
    });
  });
}
