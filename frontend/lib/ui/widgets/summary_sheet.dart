import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/summary.dart';
import '../../providers/summary_provider.dart';
import '../../services/news_api_service.dart';
import 'skeletons/summary_sheet_skeleton.dart';
import 'tts_player_button.dart';

class SummarySheet extends ConsumerStatefulWidget {
  final String articleId;
  final String articleTitle;
  final bool isSummarizable;

  const SummarySheet({
    super.key,
    required this.articleId,
    required this.articleTitle,
    required this.isSummarizable,
  });

  static Future<void> show({
    required BuildContext context,
    required String articleId,
    required String articleTitle,
    required bool isSummarizable,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SummarySheet(
        articleId: articleId,
        articleTitle: articleTitle,
        isSummarizable: isSummarizable,
      ),
    );
  }

  @override
  ConsumerState<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<SummarySheet> {
  QuestionType _activeAngle = QuestionType.core;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final summaryQuery = SummaryQueryKey(
      articleId: widget.articleId,
      questionType: _activeAngle,
    );
    final summaryAsync = ref.watch(summaryProvider(summaryQuery));

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PULSE WIRE PERSPECTIVE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.articleTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4 Preset Angles Chip Row
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: QuestionType.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final angle = QuestionType.values[index];
                    final isSelected = angle == _activeAngle;

                    return ChoiceChip(
                      label: Text(angle.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _activeAngle = angle);
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : theme.textTheme.bodyMedium?.color,
                      ),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: isDark ? const Color(0xFF1E232A) : const Color(0xFFEBE8E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : theme.colorScheme.outline,
                          width: 0.8,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 4),
              // Angle Subtitle & Audio Readout Action
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _activeAngle.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    summaryAsync.maybeWhen(
                      data: (summary) => TtsPlayerButton(bullets: summary.content),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Content Area
              Expanded(
                child: !widget.isSummarizable
                    ? _buildUnsummarizableState(theme)
                    : summaryAsync.when(
                        loading: () => const SummarySheetSkeleton(),
                        error: (err, _) => _buildErrorState(err, theme),
                        data: (summary) => _buildSummaryContent(summary, theme, scrollController),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnsummarizableState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notes_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text(
              'Content Below Length Threshold',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This article is a brief or announcement stub without enough technical body text to generate reliable multi-angle AI summaries.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, ThemeData theme) {
    String message = 'Unable to generate summary.';
    bool isRateLimit = false;
    bool isOfflineCacheMiss = false;

    if (error is ApiException) {
      if (error.isNotSummarizable) {
        return _buildUnsummarizableState(theme);
      }
      if (error.isRateLimited) {
        isRateLimit = true;
        message = 'Free-tier AI quota rate limit reached. Please wait a moment.';
      } else if (error.message.toLowerCase().contains('offline')) {
        isOfflineCacheMiss = true;
        message = error.message;
      } else {
        message = error.message;
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRateLimit
                  ? Icons.hourglass_empty
                  : (isOfflineCacheMiss ? Icons.cloud_off_rounded : Icons.cloud_off_outlined),
              size: 40,
              color: isRateLimit
                  ? Colors.orange
                  : (isOfflineCacheMiss ? theme.colorScheme.primary : Colors.orange),
            ),
            const SizedBox(height: 12),
            Text(
              isOfflineCacheMiss ? 'Perspective Not Cached' : message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isOfflineCacheMiss
                  ? 'This perspective has not been downloaded for offline reading. Connect to the internet to generate and cache it.'
                  : message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(summaryProvider(SummaryQueryKey(
                  articleId: widget.articleId,
                  questionType: _activeAngle,
                )).notifier).retry();
              },
              child: Text(isOfflineCacheMiss ? 'Check Connection' : 'Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryContent(
    SummaryResponse summary,
    ThemeData theme,
    ScrollController controller,
  ) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        ...summary.content.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final bullet = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outline, width: 0.8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bullet,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),
        // Clean Pulse Wire intelligence metadata
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  summary.cached ? Icons.bolt : Icons.auto_awesome,
                  size: 14,
                  color: summary.cached ? Colors.amber[700] : theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  summary.cached ? 'Instant Read (Cached)' : 'Pulse Wire Intelligence',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              'Verified Summary',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}
