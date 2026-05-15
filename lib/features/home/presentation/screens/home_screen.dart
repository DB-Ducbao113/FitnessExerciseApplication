import 'dart:math' as math;
import 'dart:io';

import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kBgTop = Color(0xff0a0e1a);
const _kBgBottom = Color(0xff0d1b2a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);

final _weeklyHomeStatsProvider = Provider<_WeeklyHomeStats>((ref) {
  final workouts =
      ref.watch(workoutListProvider).valueOrNull ?? <WorkoutSession>[];
  final start = _startOfWeek(DateTime.now());
  final end = start.add(const Duration(days: 6));

  final weeklyWorkouts = workouts.where((workout) {
    final date = DateTimeHelper.localDateOnly(workout.startedAt);
    return !date.isBefore(start) && !date.isAfter(end);
  }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final activeDates = weeklyWorkouts
      .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
      .toSet();

  return _WeeklyHomeStats(
    startOfWeek: start,
    weeklyDistanceKm: weeklyWorkouts.fold(0.0, (sum, w) => sum + w.distanceKm),
    weeklyCalories: weeklyWorkouts.fold(0.0, (sum, w) => sum + w.caloriesKcal),
    workoutCount: weeklyWorkouts.length,
    activeDayCount: activeDates.length,
  );
});

final _todayHomeStatsProvider = Provider<_TodayHomeStats>((ref) {
  final workouts =
      ref.watch(workoutListProvider).valueOrNull ?? <WorkoutSession>[];
  final today = DateTimeHelper.localDateOnly(DateTime.now());
  final todayWorkouts = workouts.where((workout) {
    return DateTimeHelper.localDateOnly(workout.startedAt) == today;
  });

  return _TodayHomeStats(
    workoutCount: todayWorkouts.length,
    distanceKm: todayWorkouts.fold(0.0, (sum, w) => sum + w.distanceKm),
    durationSec: todayWorkouts.fold(0, (sum, w) => sum + w.durationSec),
  );
});

final _weeklyHeroProvider = Provider<_WeeklyHeroData>((ref) {
  final weekly = ref.watch(_weeklyHomeStatsProvider);
  final goal = ref.watch(userGoalProvider).valueOrNull;
  final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

  double current;
  double target;
  String unit;
  String badgeLabel;
  String helperLabel;

  if (goal != null) {
    switch (goal.goalType) {
      case GoalType.distance:
        current = weekly.weeklyDistanceKm;
        unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
        break;
      case GoalType.workouts:
        current = weekly.workoutCount.toDouble();
        unit = 'sessions';
        break;
      case GoalType.calories:
        current = weekly.weeklyCalories;
        unit = 'kcal';
        break;
    }
    target = goal.period == GoalPeriod.weekly
        ? goal.targetValue
        : _monthlyTargetToWeeklyTarget(goal.targetValue, weekly.startOfWeek);
    target = target <= 0 ? 1 : target;
    badgeLabel =
        '${_formatMetric(current, unit)} / ${_formatMetric(target, unit)} ${unit.toUpperCase()}';
    helperLabel = goal.period == GoalPeriod.weekly
        ? 'Linked to your weekly goal'
        : 'Based on your monthly goal';
  } else {
    current = weekly.weeklyCalories;
    target = math.max(4200.0, current <= 0 ? 4200.0 : current * 1.35);
    unit = 'kcal';
    badgeLabel =
        '${_formatMetric(current, unit)} / ${_formatMetric(target, unit)} KCAL';
    helperLabel = 'Tap to set your goal';
  }

  return _WeeklyHeroData(
    weekNumber: _weekNumber(weekly.startOfWeek),
    current: current,
    target: target,
    unit: unit,
    badgeLabel: badgeLabel,
    helperLabel: helperLabel,
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBgTop,
      body: Stack(
        children: [
          RefreshIndicator(
            color: _kNeonCyan,
            backgroundColor: _kCardBg,
            onRefresh: () async {
              await ref.read(workoutListProvider.notifier).refresh();
              final userId = ref.read(currentUserIdProvider);
              if (userId != null) {
                ref.invalidate(userProfileProvider(userId));
              }
              await ref.read(userGoalProvider.notifier).refresh();
            },
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kBgTop, _kBgBottom],
                ),
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 32),
                      child: const _HomeContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeTopBar(),
        SizedBox(height: 18),
        _EnergyFluxCard(),
        SizedBox(height: 16),
        _QuickSummaryCard(),
      ],
    );
  }
}

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatar = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? avatarImage = avatar.localPath != null
        ? FileImage(File(avatar.localPath!))
        : avatar.remoteUrl != null && avatar.remoteUrl!.isNotEmpty
        ? NetworkImage(avatar.remoteUrl!)
        : null;
    final streak = ref.watch(streakProvider);
    final initials = _initialsFromEmail(user?.email);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _kCardBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.035),
            _kNeonCyan.withValues(alpha: 0.015),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FITNESS DASHBOARD',
                      style: TextStyle(
                        color: _kMutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xfff4fdff),
                          Color(0xff9cefff),
                          Color(0xff00d8ff),
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'AETRON',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kCardBorder),
                ),
                child: _StreakPill(streak: streak),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: _kNeonCyan.withValues(alpha: 0.32),
                      width: 1.4,
                    ),
                    image: avatarImage != null
                        ? DecorationImage(image: avatarImage, fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: avatarImage == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnergyFluxCard extends ConsumerWidget {
  const _EnergyFluxCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(_weeklyHeroProvider);
    final weekly = ref.watch(_weeklyHomeStatsProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final ratio = hero.target <= 0
        ? 0.0
        : (hero.current / hero.target).clamp(0.0, 1.0).toDouble();
    final percent = (ratio * 100).round();

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GoalScreen())),
      child: _GlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kNeonCyan.withValues(alpha: 0.10),
                    border: Border.all(
                      color: _kNeonCyan.withValues(alpha: 0.30),
                    ),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: _kNeonCyan,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GOAL PROGRESS',
                        style: TextStyle(
                          color: _kNeonCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hero.badgeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hero.helperLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kMutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(_kNeonCyan),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniGoalSignal(
                  label: 'Active days',
                  value: '${weekly.activeDayCount}/7',
                ),
                const SizedBox(width: 10),
                _MiniGoalSignal(
                  label: 'Week ${hero.weekNumber}',
                  value: WorkoutFormatters.formatDistance(
                    weekly.weeklyDistanceKm,
                    useMetric: useMetricUnits,
                    decimals: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSummaryCard extends ConsumerWidget {
  const _QuickSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(_todayHomeStatsProvider);
    final weekly = ref.watch(_weeklyHomeStatsProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK SUMMARY',
            style: TextStyle(
              color: _kNeonCyan,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 14),
          _QuickSummaryRow(
            title: 'Today',
            items: [
              _QuickSummaryItem(
                icon: Icons.fitness_center_rounded,
                value: '${today.workoutCount}',
                label: 'sessions',
              ),
              _QuickSummaryItem(
                icon: Icons.route_rounded,
                value: WorkoutFormatters.formatDistance(
                  today.distanceKm,
                  useMetric: useMetricUnits,
                  decimals: 1,
                ),
                label: 'distance',
              ),
              _QuickSummaryItem(
                icon: Icons.timer_rounded,
                value: WorkoutFormatters.formatDurationFromSeconds(
                  today.durationSec,
                ),
                label: 'time',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),
          _QuickSummaryRow(
            title: 'This week',
            items: [
              _QuickSummaryItem(
                icon: Icons.fitness_center_rounded,
                value: '${weekly.workoutCount}',
                label: 'sessions',
              ),
              _QuickSummaryItem(
                icon: Icons.route_rounded,
                value: WorkoutFormatters.formatDistance(
                  weekly.weeklyDistanceKm,
                  useMetric: useMetricUnits,
                  decimals: 1,
                ),
                label: 'distance',
              ),
              _QuickSummaryItem(
                icon: Icons.event_available_rounded,
                value: '${weekly.activeDayCount}/7',
                label: 'active days',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickSummaryRow extends StatelessWidget {
  const _QuickSummaryRow({required this.title, required this.items});

  final String title;
  final List<_QuickSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _QuickSummaryTile(item: items[i])),
              if (i != items.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickSummaryTile extends StatelessWidget {
  const _QuickSummaryTile({required this.item});

  final _QuickSummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: _kNeonCyan, size: 18),
          const SizedBox(height: 10),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGoalSignal extends StatelessWidget {
  const _MiniGoalSignal({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kCardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kMutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSummaryItem {
  const _QuickSummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

class _TodayHomeStats {
  final int workoutCount;
  final double distanceKm;
  final int durationSec;

  const _TodayHomeStats({
    required this.workoutCount,
    required this.distanceKm,
    required this.durationSec,
  });
}

class _StreakPill extends StatelessWidget {
  final StreakData streak;

  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _StreakDetailsSheet(streak: streak),
      ),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xff3a2717),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xffffb800), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffffb800).withValues(alpha: 0.16),
              blurRadius: 18,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xffffc21a), size: 17),
            const SizedBox(width: 5),
            Text(
              '${streak.currentStreak}D',
              style: const TextStyle(
                color: Color(0xffffc21a),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakDetailsSheet extends StatelessWidget {
  final StreakData streak;

  const _StreakDetailsSheet({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xff0f1726),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Streak',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _StreakInfoRow(
            title: 'Current streak',
            value: '${streak.currentStreak} days',
          ),
          const SizedBox(height: 12),
          _StreakInfoRow(
            title: 'Best streak',
            value: '${streak.longestStreak} days',
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep at least one workout logged each day to extend the streak.',
            style: TextStyle(color: _kMutedText, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StreakInfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _StreakInfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: _kNeonCyan.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _WeeklyHomeStats {
  final DateTime startOfWeek;
  final double weeklyDistanceKm;
  final double weeklyCalories;
  final int workoutCount;
  final int activeDayCount;

  const _WeeklyHomeStats({
    required this.startOfWeek,
    required this.weeklyDistanceKm,
    required this.weeklyCalories,
    required this.workoutCount,
    required this.activeDayCount,
  });
}

class _WeeklyHeroData {
  final int weekNumber;
  final double current;
  final double target;
  final String unit;
  final String badgeLabel;
  final String helperLabel;

  const _WeeklyHeroData({
    required this.weekNumber,
    required this.current,
    required this.target,
    required this.unit,
    required this.badgeLabel,
    required this.helperLabel,
  });
}

DateTime _startOfWeek(DateTime date) {
  final local = DateTimeHelper.localDateOnly(date);
  return local.subtract(Duration(days: local.weekday - 1));
}

int _weekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeekStart = firstThursday.subtract(
    Duration(days: firstThursday.weekday - 1),
  );
  return ((thursday.difference(firstWeekStart).inDays) / 7).floor() + 1;
}

String _formatMetric(double value, String unit) {
  switch (unit) {
    case 'km':
    case 'mi':
      return value.toStringAsFixed(1);
    case 'sessions':
      return value.round().toString();
    case 'kcal':
      return value.round().toString();
    default:
      return value.round().toString();
  }
}

double _monthlyTargetToWeeklyTarget(
  double monthlyTarget,
  DateTime startOfWeek,
) {
  final monthStart = DateTime(startOfWeek.year, startOfWeek.month, 1);
  final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
  final daysInMonth = nextMonth.difference(monthStart).inDays;
  return monthlyTarget / (daysInMonth / 7.0);
}

String _initialsFromEmail(String? email) {
  final source = (email ?? 'User').split('@').first.trim();
  if (source.isEmpty) return 'U';
  final parts = source
      .split(RegExp(r'[._\-\s]+'))
      .where((element) => element.isNotEmpty)
      .toList();
  if (parts.length == 1) {
    return parts.first
        .substring(0, math.min(2, parts.first.length))
        .toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
