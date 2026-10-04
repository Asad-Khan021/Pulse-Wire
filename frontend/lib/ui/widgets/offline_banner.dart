import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Animated banner displayed at the top of the feed when operating in offline mode.
class OfflineBanner extends StatelessWidget {
  final DateTime? lastSyncedAt;
  final int pendingActionsCount;
  final VoidCallback? onRefresh;

  const OfflineBanner({
    super.key,
    this.lastSyncedAt,
    this.pendingActionsCount = 0,
    this.onRefresh,
  });

  String _formatLastSync() {
    if (lastSyncedAt == null) return 'Local Cache';
    final diff = DateTime.now().difference(lastSyncedAt!);
    if (diff.inMinutes < 60) {
      return 'Cached ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Cached ${diff.inHours}h ago';
    } else {
      return 'Cached ${DateFormat('MMM d').format(lastSyncedAt!)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bannerBg = isDark ? const Color(0xFF2B2515) : const Color(0xFFFFF7E6);
    final bannerBorder = isDark ? const Color(0xFF6B5318) : const Color(0xFFFFD591);
    final textColor = isDark ? const Color(0xFFFFE58F) : const Color(0xFFD46B08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bannerBg,
        border: Border(
          bottom: BorderSide(color: bannerBorder, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline Mode • ${_formatLastSync()}'
              '${pendingActionsCount > 0 ? " ($pendingActionsCount changes queued)" : ""}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRefresh,
              child: Icon(Icons.refresh, size: 16, color: textColor),
            ),
          ],
        ],
      ),
    );
  }
}
