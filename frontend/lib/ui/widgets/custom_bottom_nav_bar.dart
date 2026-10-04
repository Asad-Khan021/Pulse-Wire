import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/navigation_provider.dart';

class CustomBottomNavBar extends ConsumerWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Theme-specific styles
    // Dark mode: Dark background, orange accents, orange active indicator
    // Light mode: Light background, high-contrast accents, matching active indicator
    final barBg = isDark ? const Color(0xFF181C24) : AppTheme.lightSurface;
    final borderColor = isDark
        ? AppTheme.darkBorder.withOpacity(0.85)
        : AppTheme.lightBorder;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.5)
        : const Color(0xFF1A1A1A).withOpacity(0.1);

    final activeColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final activeIndicatorBg = isDark
        ? AppTheme.darkAccent.withOpacity(0.18)
        : AppTheme.lightAccent.withOpacity(0.12);
    final activeIndicatorBorder = isDark
        ? AppTheme.darkAccent.withOpacity(0.4)
        : AppTheme.lightAccent.withOpacity(0.3);

    final inactiveColor =
        isDark ? AppTheme.darkInkSecondary : AppTheme.lightInkSecondary;

    final navItems = const [
      _NavItemData(
        label: 'Home',
        icon: Icons.newspaper_outlined,
        activeIcon: Icons.newspaper_rounded,
      ),
      _NavItemData(
        label: 'Search',
        icon: Icons.search_outlined,
        activeIcon: Icons.search_rounded,
      ),
      _NavItemData(
        label: 'Saved',
        icon: Icons.bookmark_border_rounded,
        activeIcon: Icons.bookmark_rounded,
      ),
      _NavItemData(
        label: 'Settings',
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune_rounded,
      ),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          margin: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: math.max(12.0, bottomInset > 0 ? bottomInset * 0.6 : 12.0),
          ),
          decoration: BoxDecoration(
            color: barBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = currentIndex == index;

                return Expanded(
                  child: _NavBarItem(
                    label: item.label,
                    icon: item.icon,
                    activeIcon: item.activeIcon,
                    isSelected: isSelected,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    indicatorBg: activeIndicatorBg,
                    indicatorBorder: activeIndicatorBorder,
                    onTap: () {
                      ref
                          .read(navigationIndexProvider.notifier)
                          .setIndex(index);
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _NavBarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final Color indicatorBg;
  final Color indicatorBorder;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.indicatorBg,
    required this.indicatorBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: activeColor.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? indicatorBg : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? indicatorBorder : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 22,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.2,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
