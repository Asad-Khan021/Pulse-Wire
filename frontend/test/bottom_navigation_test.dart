import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_wire/core/theme/app_theme.dart';
import 'package:pulse_wire/main.dart';
import 'package:pulse_wire/models/article.dart';
import 'package:pulse_wire/models/user_preference.dart';
import 'package:pulse_wire/providers/bookmarks_provider.dart';
import 'package:pulse_wire/providers/connectivity_provider.dart';
import 'package:pulse_wire/providers/feed_provider.dart';
import 'package:pulse_wire/providers/preferences_provider.dart';
import 'package:pulse_wire/providers/theme_provider.dart';
import 'package:pulse_wire/ui/widgets/custom_bottom_nav_bar.dart';

class MockConnectivityNotifier extends StateNotifier<bool>
    implements ConnectivityNotifier {
  MockConnectivityNotifier() : super(true);

  @override
  Future<void> checkNow() async {}
}

class MockPreferencesNotifier extends StateNotifier<UserPreference>
    implements PreferencesNotifier {
  MockPreferencesNotifier()
      : super(const UserPreference(
          userId: 'test_user',
          followedTags: ['AI', 'Cloud'],
          mutedDomains: [],
        ));

  @override
  Future<void> toggleFollowedTag(String tag) async {}

  @override
  Future<void> addMutedDomain(String rawDomain) async {}

  @override
  Future<void> removeMutedDomain(String rawDomain) async {}
}

class MockFeedNotifier extends StateNotifier<FeedState> implements FeedNotifier {
  MockFeedNotifier() : super(const FeedState());

  @override
  Future<void> loadInitial() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}

  @override
  void toggleTag(String tag) {}
}

class MockBookmarksNotifier extends StateNotifier<BookmarksState>
    implements BookmarksNotifier {
  MockBookmarksNotifier() : super(const BookmarksState());

  @override
  Future<void> toggleBookmark(ArticleListItem article) async {}

  @override
  Future<void> removeBookmark(String articleId) async {}
}

void main() {
  Widget buildTestApp({ThemeMode themeMode = ThemeMode.dark}) {
    return ProviderScope(
      overrides: [
        isOnlineProvider.overrideWith((ref) => MockConnectivityNotifier()),
        preferencesProvider.overrideWith((ref) => MockPreferencesNotifier()),
        feedProvider.overrideWith((ref) => MockFeedNotifier()),
        bookmarksProvider.overrideWith((ref) => MockBookmarksNotifier()),
        themeProvider.overrideWith((ref) => ThemeModeNotifier()..setTheme(themeMode)),
      ],
      child: const PulseWireApp(),
    );
  }

  testWidgets('Bottom navigation bar displays all 4 tabs and switches between screens',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Verify CustomBottomNavBar is present
    expect(find.byType(CustomBottomNavBar), findsOneWidget);

    // Verify all 4 tab labels exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Home screen is initially displayed
    expect(find.text('PULSE WIRE'), findsOneWidget);

    // Verify Top AppBar does NOT have Save (Bookmarks) or Setting (Tune) action buttons
    final feedAppBar = find.byType(AppBar);
    expect(
      find.descendant(of: feedAppBar, matching: find.byType(IconButton)),
      findsNothing,
    );

    // Tap 'Search' tab
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Discover & Search'), findsOneWidget);
    expect(find.text('Explore Pulse Wire'), findsOneWidget);

    // Tap 'Saved' tab
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Stories'), findsOneWidget);

    // Tap 'Settings' tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Preferences & Settings'), findsOneWidget);

    // Tap 'Home' tab to return
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('PULSE WIRE'), findsOneWidget);
  });

  testWidgets('Bottom navigation bar adapts styling for dark mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    final navBarFinder = find.byType(CustomBottomNavBar);
    expect(navBarFinder, findsOneWidget);

    final BuildContext context = tester.element(navBarFinder);
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppTheme.darkAccent);
  });

  testWidgets('Bottom navigation bar adapts styling for light mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(themeMode: ThemeMode.light));
    await tester.pumpAndSettle();

    final navBarFinder = find.byType(CustomBottomNavBar);
    expect(navBarFinder, findsOneWidget);

    final BuildContext context = tester.element(navBarFinder);
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppTheme.lightAccent);
  });
}
