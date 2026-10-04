import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bookmarks_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/navigation_provider.dart';
import '../widgets/article_card.dart';
import '../widgets/empty_state.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookmarksState = ref.watch(bookmarksProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final articles = bookmarksState.list;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Stories'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        actions: [
          if (bookmarksState.pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber[700]!, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_problem_rounded, size: 14, color: Colors.amber[800]),
                      const SizedBox(width: 4),
                      Text(
                        '${bookmarksState.pendingSyncCount} Queued',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primary.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(Icons.offline_pin_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode • Bookmarks are saved locally in Hive and will sync automatically when back online.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: articles.isEmpty
                ? NoBookmarksEmptyState(
                    onExplore: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        ref.read(navigationIndexProvider.notifier).setIndex(0);
                      }
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 96),
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      return Dismissible(
                        key: Key(article.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          ref.read(bookmarksProvider.notifier).removeBookmark(article.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed "${article.title}" from bookmarks'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  ref.read(bookmarksProvider.notifier).toggleBookmark(article);
                                },
                              ),
                            ),
                          );
                        },
                        child: ArticleCard(article: article),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
