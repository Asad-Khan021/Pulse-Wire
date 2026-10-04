import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_preference.dart';
import '../services/news_api_service.dart';
import '../services/offline_cache_service.dart';
import 'connectivity_provider.dart';
import 'feed_provider.dart';

class PreferencesNotifier extends StateNotifier<UserPreference> {
  final NewsApiService _apiService;
  final OfflineCacheService _cacheService;
  final Ref _ref;

  PreferencesNotifier(this._apiService, this._cacheService, this._ref)
      : super(const UserPreference(
          userId: '',
          followedTags: ['AI', 'Machine Learning', 'Cybersecurity', 'Cloud'],
          mutedDomains: [],
        )) {
    _initPreferences();
  }

  /// Initial load: retrieves Hive snapshot immediately, then checks backend if online.
  Future<void> _initPreferences() async {
    // 1. Instant local restore from Hive
    final cached = _cacheService.getCachedPreferences();
    if (cached != null) {
      state = cached;
    }

    // 2. Fetch server preferences if online
    final isOnline = _ref.read(isOnlineProvider);
    if (isOnline) {
      try {
        final serverPref = await _apiService.getPreferences();
        state = serverPref;
        await _cacheService.cachePreferences(serverPref);
      } catch (e) {
        debugPrint('[PreferencesNotifier] Offline fallback for preferences: $e');
      }
    }
  }

  /// Toggles a followed tag with optimistic local update and background synchronization.
  Future<void> toggleFollowedTag(String tag) async {
    final list = List<String>.from(state.followedTags);
    if (list.contains(tag)) {
      list.remove(tag);
    } else {
      list.add(tag);
    }
    final updated = state.copyWith(followedTags: list);
    state = updated;
    await _cacheService.cachePreferences(updated);

    _syncToBackend(updated);
  }

  /// Adds a muted domain and immediately purges matching stories across the feed.
  Future<void> addMutedDomain(String rawDomain) async {
    final clean = _normalizeDomain(rawDomain);
    if (clean.isEmpty || state.mutedDomains.contains(clean)) return;

    final list = List<String>.from(state.mutedDomains)..add(clean);
    final updated = state.copyWith(mutedDomains: list);
    state = updated;
    await _cacheService.cachePreferences(updated);

    // Synchronize to backend if online
    _syncToBackend(updated);
  }

  /// Removes a domain from the user's muted list.
  Future<void> removeMutedDomain(String rawDomain) async {
    final clean = _normalizeDomain(rawDomain);
    final list = List<String>.from(state.mutedDomains)..remove(clean);
    final updated = state.copyWith(mutedDomains: list);
    state = updated;
    await _cacheService.cachePreferences(updated);

    // Synchronize to backend if online
    _syncToBackend(updated);
  }

  /// Helper to sanitize user-typed domains (e.g. "https://www.theverge.com/tech" -> "theverge.com")
  String _normalizeDomain(String domain) {
    var cleaned = domain.trim().toLowerCase();
    cleaned = cleaned.replaceFirst(RegExp(r'^https?:\/\/'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^www\.'), '');
    final slashIndex = cleaned.indexOf('/');
    if (slashIndex != -1) {
      cleaned = cleaned.substring(0, slashIndex);
    }
    return cleaned;
  }

  /// Asynchronously syncs preference state to backend without blocking local UI.
  Future<void> _syncToBackend(UserPreference preference) async {
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) return;

    try {
      await _apiService.updatePreferences(preference);
      debugPrint('[PreferencesNotifier] Preferences synced to backend successfully.');
    } catch (e) {
      debugPrint('[PreferencesNotifier] Failed to sync preferences to backend: $e');
    }
  }
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, UserPreference>((ref) {
  final api = ref.watch(apiServiceProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return PreferencesNotifier(api, cache, ref);
});
