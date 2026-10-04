import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/feed_provider.dart';
import '../widgets/article_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeletons/article_card_skeleton.dart';
import '../widgets/tag_filter_bar.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedState = ref.watch(feedProvider);
    final filteredArticles = ref.watch(filteredFeedArticlesProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase();

    final showOfflineBanner = !isOnline || feedState.isOffline;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              todayFormatted,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: theme.colorScheme.primary,
              ),
            ),
            const Text(
              'PULSE WIRE',
              style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: TagFilterBar(),
        ),
      ),
      body: Column(
        children: [
          // Dynamic Offline Status Banner
          if (showOfflineBanner)
            OfflineBanner(
              lastSyncedAt: feedState.lastSyncedAt,
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
              color: theme.colorScheme.primary,
              child: _buildFeedBody(feedState, filteredArticles, isOnline, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedBody(
    FeedState state,
    List<dynamic> articles,
    bool isOnline,
    ThemeData theme,
  ) {
    // 1. Shimmer Loading State using ArticleCardSkeletonList
    if (state.isLoadingInitial) {
      return const ArticleCardSkeletonList(itemCount: 4);
    }

    // 2. Offline Empty Cache State
    if ((state.isOffline || !isOnline) && articles.isEmpty) {
      return NoOfflineCacheEmptyState(
        onRetry: () => ref.read(feedProvider.notifier).loadInitial(),
      );
    }

    // 3. Error State with Retry Boundary
    if (state.errorMessage != null && articles.isEmpty) {
      return FeedErrorStateWidget(
        errorMessage: state.errorMessage!,
        onRetry: () => ref.read(feedProvider.notifier).loadInitial(),
      );
    }

    // 4. Empty Filter Results
    if (articles.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.newspaper_outlined,
        title: 'No Stories in this View',
        description: 'Try adjusting your topic tags or check your muted domain list in Settings.',
        actionLabel: state.selectedTags.isNotEmpty ? 'Reset Filters' : 'Refresh Feed',
        onAction: () {
          if (state.selectedTags.isNotEmpty) {
            ref.read(feedProvider.notifier).toggleTag('All');
          } else {
            ref.read(feedProvider.notifier).refresh();
          }
        },
      );
    }

    // 5. Active Articles Feed (Online live stream or Hive-cached snapshot)
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 96),
      itemCount: articles.length + (state.hasMore && isOnline ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == articles.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          );
        }

        return ArticleCard(article: articles[index]);
      },
    );
  }
}
