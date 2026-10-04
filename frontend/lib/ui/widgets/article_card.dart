import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/article.dart';
import '../../providers/bookmarks_provider.dart';
import '../screens/article_detail_screen.dart';
import 'summary_sheet.dart';

class ArticleCard extends ConsumerWidget {
  final ArticleListItem article;

  const ArticleCard({
    super.key,
    required this.article,
  });

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookmarksState = ref.watch(bookmarksProvider);
    final isBookmarked = bookmarksState.isBookmarked(article.id);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArticleDetailScreen(articleId: article.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metadata Row: Source, Time, HN Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      article.sourceName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•  ${_formatRelativeTime(article.publishedAt)}',
                    style: theme.textTheme.labelSmall,
                  ),
                  const Spacer(),
                  if (article.hnPoints != null && article.hnPoints! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_upward, size: 12, color: Colors.deepOrange),
                          const SizedBox(width: 2),
                          Text(
                            '${article.hnPoints}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title and Optional Thumbnail
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (article.imageUrl != null && article.imageUrl!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: article.imageUrl!,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 76,
                          height: 76,
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // Bottom Row: Tags & Actions (Bookmark & Summarize)
              Row(
                children: [
                  // Tags Preview
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: article.tags.take(2).map((t) {
                        return Text(
                          '#$t',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Bookmark Button
                  IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      size: 22,
                      color: isBookmarked ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
                    ),
                    onPressed: () {
                      ref.read(bookmarksProvider.notifier).toggleBookmark(article);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),

                  // Summarize Pill Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Summarize'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
