// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_wire/main.dart';
import 'package:pulse_wire/models/user_preference.dart';
import 'package:pulse_wire/providers/connectivity_provider.dart';
import 'package:pulse_wire/providers/feed_provider.dart';
import 'package:pulse_wire/providers/preferences_provider.dart';

class MockConnectivityNotifier extends StateNotifier<bool> implements ConnectivityNotifier {
  MockConnectivityNotifier() : super(true);

  @override
  Future<void> checkNow() async {}
}

class MockPreferencesNotifier extends StateNotifier<UserPreference> implements PreferencesNotifier {
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

void main() {
  testWidgets('Pulse Wire app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => MockConnectivityNotifier()),
          preferencesProvider.overrideWith((ref) => MockPreferencesNotifier()),
          feedProvider.overrideWith((ref) => MockFeedNotifier()),
        ],
        child: const PulseWireApp(),
      ),
    );

    // Verify that the Pulse Wire title is displayed in AppBar.
    expect(find.text('PULSE WIRE'), findsOneWidget);
  });
}
