import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/offline_cache_service.dart';
import 'ui/screens/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineCacheService.init();
  runApp(
    const ProviderScope(
      child: PulseWireApp(),
    ),
  );
}

class PulseWireApp extends ConsumerWidget {
  const PulseWireApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Pulse Wire',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainShellScreen(),
    );
  }
}
