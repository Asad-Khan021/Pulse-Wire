import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/news_api_service.dart';
import '../services/offline_cache_service.dart';
import 'feed_provider.dart';

/// Provider for the singleton instance of OfflineCacheService.
final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService();
});

/// Raw stream of connectivity results from connectivity_plus (v6/v7).
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Evaluates whether the device currently has active network connectivity.
final isOnlineProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  final cacheService = ref.watch(offlineCacheServiceProvider);
  final apiService = ref.watch(apiServiceProvider);
  return ConnectivityNotifier(cacheService, apiService);
});

class ConnectivityNotifier extends StateNotifier<bool> {
  final OfflineCacheService _cacheService;
  final NewsApiService _apiService;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _initialized = false;

  ConnectivityNotifier(this._cacheService, this._apiService) : super(true) {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasConnection = _isAnyConnected(results);
      state = hasConnection;
      _initialized = true;

      // Subscribe to live network state transitions
      _subscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    } catch (e) {
      debugPrint('[ConnectivityNotifier] Initial connectivity check error: $e');
      state = true; // Assume online on check failure to allow network attempts
    }
  }

  bool _isAnyConnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) async {
    final nowOnline = _isAnyConnected(results);
    final wasOffline = !state;

    state = nowOnline;

    // Automatic Reconnection Flow: Offline -> Online transition
    if (wasOffline && nowOnline && _initialized) {
      debugPrint('[ConnectivityNotifier] Network restored! Initiating background synchronization...');
      try {
        // Trigger sequential flush of idempotent write queue
        final flushedCount = await _cacheService.flushPendingActions(_apiService);
        if (flushedCount > 0) {
          debugPrint('[ConnectivityNotifier] Flushed $flushedCount pending actions upon reconnect.');
        }
      } catch (e) {
        debugPrint('[ConnectivityNotifier] Error during reconnect flush: $e');
      }
    }
  }

  /// Manually trigger a connectivity recheck and flush
  Future<void> checkNow() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _handleConnectivityChange(results);
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
