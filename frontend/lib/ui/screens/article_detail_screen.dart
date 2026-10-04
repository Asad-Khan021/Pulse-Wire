import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/article.dart';
import '../../providers/feed_provider.dart';
import '../widgets/summary_sheet.dart';

final articleDetailProvider =
    FutureProvider.family<ArticleDetail, String>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  return api.getArticleDetail(id);
});

class ArticleDetailScreen extends ConsumerWidget {
  final String articleId;

  const ArticleDetailScreen({
    super.key,
    required this.articleId,
  });

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(articleDetailProvider(articleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Detail'),
        actions: [
          detailAsync.maybeWhen(
            data: (article) => IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Open Original',
              onPressed: () => _launchUrl(article.canonicalUrl),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load article detail.\n$err',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        data: (article) => _buildDetailContent(context, article, theme),
      ),
      bottomNavigationBar: detailAsync.maybeWhen(
        data: (article) => _buildBottomBar(context, article, theme),
        orElse: () => null,
      ),
    );
  }

  Widget _buildDetailContent(
    BuildContext context,
    ArticleDetail article,
    ThemeData theme,
  ) {
    final wordCount = (article.cleanedContent ?? '').split(RegExp(r'\s+')).length;
    final readingTime = (wordCount / 180).ceil();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Source & Time row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                article.source.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              DateFormat('MMMM d, yyyy').format(article.publishedAt),
              style: theme.textTheme.labelSmall,
            ),
            const Spacer(),
            Text(
              '$readingTime min read',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Headline
        Text(
          article.title,
          style: theme.textTheme.headlineLarge?.copyWith(height: 1.3),
        ),
        const SizedBox(height: 10),

        // Author (if present)
        if (article.author != null && article.author!.isNotEmpty)
          Text(
            'By ${article.author}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(height: 16),

        // Community Signals (HN / Reddit metrics)
        _buildCommunitySignals(article, theme),
        const SizedBox(height: 20),

        // Optional Hero Image
        if (article.imageUrl != null && article.imageUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: article.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Cleaned Detailed Article Content
        _buildDetailedStoryText(context, article, theme),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDetailedStoryText(
    BuildContext context,
    ArticleDetail article,
    ThemeData theme,
  ) {
    final content = article.cleanedContent?.trim() ?? '';
    if (content.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.6)),
        ),
        child: Column(
          children: [
            Icon(Icons.menu_book_outlined, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Full Story Available at Source',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'The complete coverage is hosted directly on the publisher website.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Read Full Article'),
              onPressed: () => _launchUrl(article.canonicalUrl),
            ),
          ],
        ),
      );
    }

    // Split into paragraphs
    var paragraphs = content
        .split(RegExp(r'\n\s*\n|\r\n\r\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.length <= 1 && content.contains('\n')) {
      paragraphs = content
          .split('\n')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E232A) : const Color(0xFFF1EFEB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.article_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'FULL STORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${content.split(RegExp(r'\s+')).length} words',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        // Paragraphs of detailed text
        ...paragraphs.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;

          // Check if paragraph looks like a section header (short, no period, or starting with #)
          final isHeader = (p.startsWith('#') ||
              (p.length < 75 && !p.endsWith('.') && !p.endsWith('"') && !p.endsWith('”') && idx > 0));

          if (isHeader) {
            final headerText = p.replaceFirst(RegExp(r'^#+\s*'), '');
            return Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 10),
              child: Text(
                headerText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                  height: 1.3,
                ),
              ),
            );
          }

          // Check if paragraph looks like a quote
          final isQuote = (p.startsWith('"') || p.startsWith('“') || p.startsWith('‘') || p.startsWith('>'));
          if (isQuote) {
            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.only(left: 14, top: 6, bottom: 6),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: theme.colorScheme.primary, width: 3.5),
                ),
              ),
              child: Text(
                p,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: 16.5,
                  height: 1.7,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.95),
                ),
              ),
            );
          }

          // First paragraph: lead style
          if (idx == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                p,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  height: 1.7,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
            );
          }

          // Normal body paragraph
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              p,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16.5,
                height: 1.75,
                letterSpacing: 0.15,
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        // End of story card with source link
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'SOURCE ATTRIBUTION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Original publication by ${article.source.name}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                article.canonicalUrl,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommunitySignals(ArticleDetail article, ThemeData theme) {
    final hasHn = article.hnPoints != null && article.hnPoints! > 0;
    final hasReddit = article.redditCommentCount != null && article.redditCommentCount! > 0;

    if (!hasHn && !hasReddit) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 16, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Text(
            'Community Discussion:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(width: 12),
          if (hasHn)
            InkWell(
              onTap: article.hnDiscussionUrl != null
                  ? () => _launchUrl(article.hnDiscussionUrl!)
                  : null,
              child: Row(
                children: [
                  const Text('HN: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  Text('${article.hnPoints} pts (${article.hnCommentCount ?? 0} comments)',
                      style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                ],
              ),
            ),
          if (hasHn && hasReddit) const SizedBox(width: 12),
          if (hasReddit)
            InkWell(
              onTap: article.redditThreadUrl != null
                  ? () => _launchUrl(article.redditThreadUrl!)
                  : null,
              child: Text(
                'Reddit (${article.redditCommentCount} comments)',
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent, decoration: TextDecoration.underline),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ArticleDetail article,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.colorScheme.outline, width: 0.8)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.launch, size: 16),
                label: const Text('Read Full Source'),
                onPressed: () => _launchUrl(article.canonicalUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Pulse Summary'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  SummarySheet.show(
                    context: context,
                    articleId: article.id,
                    articleTitle: article.title,
                    isSummarizable: article.isSummarizable,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
