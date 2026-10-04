import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/navigation_provider.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'bookmarks_screen.dart';
import 'feed_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  final Set<int> _visitedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    _visitedTabs.add(currentIndex);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: [
              const FeedScreen(),
              _visitedTabs.contains(1)
                  ? const SearchScreen()
                  : const SizedBox.shrink(),
              _visitedTabs.contains(2)
                  ? const BookmarksScreen()
                  : const SizedBox.shrink(),
              _visitedTabs.contains(3)
                  ? const SettingsScreen()
                  : const SizedBox.shrink(),
            ],
          ),
          const CustomBottomNavBar(),
        ],
      ),
    );
  }
}
