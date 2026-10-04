import 'package:flutter/material.dart';

/// Configurable empty and error state component built for responsive layouts.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Widget? customHeader;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.customHeader,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 0 ? constraints.maxHeight : 300,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (customHeader != null)
                      customHeader!
                    else
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: (iconColor ?? theme.colorScheme.primary).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 36,
                          color: iconColor ?? theme.colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: onAction,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(actionLabel!),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Offline Cache Miss Empty State: Shown when user is offline and no local articles are cached.
class NoOfflineCacheEmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const NoOfflineCacheEmptyState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.wifi_off_rounded,
      title: 'No Cached Content Available',
      description:
          'Pulse Wire could not find local offline snapshots for this view. Connect to Wi-Fi or cellular data to download live technology intelligence.',
      actionLabel: 'Check Connection & Retry',
      onAction: onRetry,
    );
  }
}

/// Empty state when user has not bookmarked any stories yet.
class NoBookmarksEmptyState extends StatelessWidget {
  final VoidCallback? onExplore;

  const NoBookmarksEmptyState({super.key, this.onExplore});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.bookmarks_outlined,
      title: 'No Bookmarks Saved Yet',
      description:
          'Tap the bookmark ribbon on any story in your feed to save it for offline reading and quick reference.',
      actionLabel: onExplore != null ? 'Explore Feed' : null,
      onAction: onExplore,
    );
  }
}

/// Retry-capable Error Boundary for Feed loading failures.
class FeedErrorStateWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const FeedErrorStateWidget({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRateLimit = errorMessage.toLowerCase().contains('rate') ||
        errorMessage.toLowerCase().contains('quota');

    return EmptyStateWidget(
      icon: isRateLimit ? Icons.hourglass_top_rounded : Icons.cloud_off_rounded,
      iconColor: isRateLimit ? Colors.amber[700] : theme.colorScheme.error,
      title: isRateLimit ? 'Traffic Throttle Active' : 'Unable to Load Live Feed',
      description: errorMessage,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
