import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // Configurable base URL with runtime support
  static String? _overrideBaseUrl;

  /// Sets an explicit base URL at runtime.
  static void setBaseUrl(String url) {
    _overrideBaseUrl = url;
  }

  /// Resolves the optimal default base URL based on the runtime platform.
  static String get defaultBaseUrl {
    if (_overrideBaseUrl != null && _overrideBaseUrl!.isNotEmpty) {
      return _overrideBaseUrl!;
    }
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (!kIsWeb) {
      if (Platform.isAndroid) {
        // Android emulator loopback alias to host machine
        return 'http://10.0.2.2:8000/api/v1';
      }
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  // Pre-configured hosts for quick swapping & fallback attempts
  static const String localhostBaseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String wifiLanBaseUrl = 'http://192.168.100.21:8000/api/v1';

  // NewsAPI Configuration
  static const String newsApiKey = String.fromEnvironment(
    'NEWS_API_KEY',
    defaultValue: '5a0882eac8064e06a7376d73e3d2fa73',
  );

  // Core Feed & Article endpoints
  static const String feed = '/feed';
  static String articleDetail(String id) => '/feed/$id';
  static String articleSummary(String id) => '/articles/$id/summary';
  static String articleSignals(String id) => '/articles/$id/signals';
  static const String newsApiFeed = '/feed/newsapi';
  static const String syncNewsApi = '/feed/sync-newsapi';

  // User Scoped endpoints
  static const String bookmarks = '/bookmarks';
  static String removeBookmark(String articleId) => '/bookmarks/$articleId';
  static const String preferences = '/me/preferences';

  // Request Timeouts
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 8);
}
