import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/preferences_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showAddMutedDomainDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Mute Publisher Domain'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. example.com',
            labelText: 'Domain Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final domain = textController.text.trim();
              if (domain.isNotEmpty) {
                ref.read(preferencesProvider.notifier).addMutedDomain(domain);
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Mute Domain'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesProvider);
    final currentThemeMode = ref.watch(themeProvider);

    const allTags = [
      'AI',
      'Machine Learning',
      'Cybersecurity',
      'Cloud',
      'DevOps',
      'Security',
      'Startups',
      'Hardware',
      'Open Source',
      'Mobile',
      'Databases',
      'Rust',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences & Settings'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 96),
        children: [
          // Section: Appearance
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        currentThemeMode == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Dark Theme',
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Switch(
                    value: currentThemeMode == ThemeMode.dark,
                    onChanged: (val) {
                      ref.read(themeProvider.notifier).setTheme(
                            val ? ThemeMode.dark : ThemeMode.light,
                          );
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Section: Followed Topics
          Text(
            'FOLLOWED TOPICS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stories matching followed tags are prioritized in your feed.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTags.map((tag) {
              final isFollowed = preferences.followedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isFollowed,
                onSelected: (_) {
                  ref.read(preferencesProvider.notifier).toggleFollowedTag(tag);
                },
                selectedColor: theme.colorScheme.primary.withOpacity(0.18),
                checkmarkColor: theme.colorScheme.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Section: Muted Domains
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MUTED DOMAINS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.0,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Domain'),
                onPressed: () => _showAddMutedDomainDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (preferences.mutedDomains.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No muted domains. All active publisher feeds are displayed.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: preferences.mutedDomains.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final domain = preferences.mutedDomains[index];
                  return ListTile(
                    title: Text(domain),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        ref.read(preferencesProvider.notifier).removeMutedDomain(domain);
                      },
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 32),

          // Section: About & Infrastructure
          Center(
            child: Column(
              children: [
                Text(
                  'PULSE WIRE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0 • AI-Powered Technology Intelligence',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
