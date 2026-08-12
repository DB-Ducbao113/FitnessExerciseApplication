import 'dart:ui';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mainTabControllerProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _screens = [
    HomeScreen(),
    ActivityScreen(),
    CalendarScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mainTabControllerProvider.notifier).state = widget.initialIndex;
      });
    }
  }

  void _onTabSelected(int index) {
    if (ref.read(mainTabControllerProvider) != index) {
      HapticFeedback.selectionClick();
      ref.read(mainTabControllerProvider.notifier).state = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainTabControllerProvider);

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: _AetronDock(
        currentIndex: currentIndex,
        onChanged: _onTabSelected,
      ),
    );
  }
}

class _AetronDock extends ConsumerWidget {
  const _AetronDock({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'nav_home'),
    (Icons.directions_run_outlined, Icons.directions_run_rounded, 'nav_activity'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'nav_history'),
    (Icons.analytics_outlined, Icons.analytics_rounded, 'nav_analytics'),
    (Icons.person_outline, Icons.person_rounded, 'nav_profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom > 0 ? bottom : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: AetronColors.space.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AetronColors.cyan.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.60),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AetronColors.cyan.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _DockItem(
                      icon: _items[i].$1,
                      selectedIcon: _items[i].$2,
                      label: AppTranslations.get(_items[i].$3, currentLang),
                      selected: i == currentIndex,
                      onTap: () => onChanged(i),
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

class _DockItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 52 : 38,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AetronColors.cyan.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: selected
                    ? Border.all(color: AetronColors.cyan.withValues(alpha: 0.4), width: 1)
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AetronColors.cyan.withValues(alpha: 0.25),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected ? AetronColors.cyanSoft : AetronColors.muted,
                size: selected ? 21 : 19,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AetronColors.cyanSoft : AetronColors.muted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

