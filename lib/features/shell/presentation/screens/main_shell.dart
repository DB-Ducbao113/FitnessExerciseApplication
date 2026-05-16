import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:flutter/material.dart';

const _kShellBg = Color(0xff0a0e1a);
const _kNavBg = Color(0xee0f1726);
const _kNavBorder = Color(0x2200e5ff);
const _kNavMuted = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);
const _kNeonBlue = Color(0xff00bfff);

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
      backgroundColor: _kShellBg,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _kNavBg,
                border: Border.all(color: _kNavBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: _kNeonCyan.withValues(alpha: 0.08),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  navigationBarTheme: NavigationBarThemeData(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    height: 72,
                    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                      states,
                    ) {
                      final selected = states.contains(WidgetState.selected);
                      return TextStyle(
                        color: selected ? Colors.white : _kNavMuted,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      );
                    }),
                    indicatorColor: Colors.transparent,
                    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
                      states,
                    ) {
                      final selected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        color: selected ? Colors.white : _kNavMuted,
                        size: 22,
                      );
                    }),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  backgroundColor: Colors.transparent,
                  indicatorColor: Colors.transparent,
                  destinations: const [
                    _ShellDestination(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                    ),
                    _ShellDestination(
                      icon: Icons.grid_view_outlined,
                      selectedIcon: Icons.grid_view_rounded,
                      label: 'Activity',
                    ),
                    _ShellDestination(
                      icon: Icons.history_outlined,
                      selectedIcon: Icons.history_rounded,
                      label: 'History',
                    ),
                    _ShellDestination(
                      icon: Icons.bar_chart_outlined,
                      selectedIcon: Icons.bar_chart_rounded,
                      label: 'Analytics',
                    ),
                    _ShellDestination(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person_rounded,
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final selected = NavigationBarTheme.of(
      context,
    ).iconTheme?.resolve({WidgetState.selected});
    final unselected = NavigationBarTheme.of(context).iconTheme?.resolve({});

    return NavigationDestination(
      icon: _NavGlyph(
        icon: icon,
        background: false,
        color: unselected?.color ?? _kNavMuted,
      ),
      selectedIcon: _NavGlyph(
        icon: selectedIcon,
        background: true,
        color: selected?.color ?? Colors.white,
      ),
      label: label,
    );
  }
}

class _NavGlyph extends StatelessWidget {
  final IconData icon;
  final bool background;
  final Color color;

  const _NavGlyph({
    required this.icon,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: background
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [_kNeonBlue, _kNeonCyan]),
              boxShadow: [
                BoxShadow(
                  color: _kNeonCyan.withValues(alpha: 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            )
          : null,
      child: Icon(icon, color: background ? _kShellBg : color),
    );
  }
}
