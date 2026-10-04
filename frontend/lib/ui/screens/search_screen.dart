import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/article.dart';
import '../../providers/feed_provider.dart';
import '../widgets/article_card.dart';
import '../widgets/empty_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = 'All';

  final List<String> _quickTags = const [
    'All',
    'AI',
    'Machine Learning',
    'Cybersecurity',
    'Cloud',
    'Startups',
    'Rust',
    'Mobile',
    'DevOps',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final feedState = ref.watch(feedProvider);
    final allArticles = feedState.articles;

    final query = _searchController.text.trim().toLowerCase();

    // Filter articles based on search query and selected quick tag
    final searchResults = allArticles.where((article) {
      final matchesQuery = query.isEmpty ||
          article.title.toLowerCase().contains(query) ||
          article.sourceName.toLowerCase().contains(query) ||
          (article.author?.toLowerCase().contains(query) ?? false) ||
          article.tags.any((t) => t.toLowerCase().contains(query));

      final matchesTag = _selectedTag == 'All' ||
          article.tags.any((t) => t.toLowerCase() == _selectedTag.toLowerCase());

      return matchesQuery && matchesTag;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover & Search'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search stories, topics, or publishers...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? theme.colorScheme.surface
                    : theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Quick Filter Tags Bar
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickTags.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = _quickTags[index];
                final isSelected = _selectedTag == tag;

                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTag = selected ? tag : 'All';
                    });
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: isDark
                      ? theme.colorScheme.surface
                      : Colors.grey.withOpacity(0.08),
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Search results or empty state
          Expanded(
            child: _buildContent(
              theme: theme,
              query: query,
              results: searchResults,
              isLoading: feedState.isLoadingInitial && allArticles.isEmpty,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required ThemeData theme,
    required String query,
    required List<ArticleListItem> results,
    required bool isLoading,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      if (query.isNotEmpty || _selectedTag != 'All') {
        return EmptyStateWidget(
          icon: Icons.search_off_rounded,
          title: 'No Stories Found',
          description:
              'No articles matched "$query" with filter "$_selectedTag". Try different keywords or select "All".',
          actionLabel: 'Clear Search',
          onAction: () {
            _searchController.clear();
            setState(() {
              _selectedTag = 'All';
            });
          },
        );
      }

      return EmptyStateWidget(
        icon: Icons.manage_search_rounded,
        title: 'Explore Pulse Wire',
        description:
            'Search over the latest technology, machine learning, and startup news, or tap a topic chip above to filter.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: results.length + 1,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${results.length} ${results.length == 1 ? 'STORY' : 'STORIES'} FOUND',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (query.isNotEmpty || _selectedTag != 'All')
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _selectedTag = 'All';
                      });
                    },
                    child: Text(
                      'Reset',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        final article = results[index - 1];
        return ArticleCard(article: article);
      },
    );
  }
}
