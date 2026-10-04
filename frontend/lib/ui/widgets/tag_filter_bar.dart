import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/feed_provider.dart';

class TagFilterBar extends ConsumerWidget {
  const TagFilterBar({super.key});

  static const List<String> availableTags = [
    'All',
    'AI',
    'Machine Learning',
    'Cybersecurity',
    'Cloud',
    'DevOps',
    'Hardware',
    'Startups',
    'Open Source',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedProvider);
    final selectedTags = feedState.selectedTags;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: availableTags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = availableTags[index];
          final isSelected = tag == 'All'
              ? selectedTags.isEmpty
              : selectedTags.contains(tag);

          return FilterChip(
            label: Text(tag),
            selected: isSelected,
            onSelected: (_) {
              ref.read(feedProvider.notifier).toggleTag(tag);
            },
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : theme.textTheme.bodyMedium?.color,
            ),
            backgroundColor: isDark ? const Color(0xFF1E232A) : const Color(0xFFEBE8E2),
            selectedColor: theme.colorScheme.primary,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : theme.colorScheme.outline,
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          );
        },
      ),
    );
  }
}
