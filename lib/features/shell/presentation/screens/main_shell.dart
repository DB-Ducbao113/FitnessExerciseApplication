import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

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
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _AetronDock(
        currentIndex: _currentIndex,
        onChanged: (i) => setState(() => _currentIndex = i),
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
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'nav_activity'),
    (Icons.history_outlined, Icons.history_rounded, 'nav_history'),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'nav_analytics'),
    (Icons.person_outline, Icons.person_rounded, 'nav_profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom > 0 ? 0 : 8),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 12, 14, 12 + bottom),
        decoration: BoxDecoration(
          color: AetronColors.space.withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.62)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.40),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Row(
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
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: selected ? 68 : 48,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AetronColors.cyan.withValues(alpha: 0.23)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AetronColors.cyan.withValues(alpha: 0.22),
                          blurRadius: 22,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected ? AetronColors.cyanSoft : AetronColors.muted,
                size: 28,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AetronColors.cyanSoft : AetronColors.muted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
