import 'dart:math' as math;

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
const _kNeonBlue = Color(0xff00bfff);

final _weeklyHomeStatsProvider = Provider<_WeeklyHomeStats>((ref) {
  final workouts =
      ref.watch(workoutListProvider).valueOrNull ?? <WorkoutSession>[];
  final start = _startOfWeek(DateTime.now());
  final days = List<DateTime>.generate(
    7,
    (index) => start.add(Duration(days: index)),
  );

  final weeklyWorkouts = workouts.where((workout) {
    final date = DateTimeHelper.localDateOnly(workout.startedAt);
    return !date.isBefore(start) && !date.isAfter(days.last);
  }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final activeDates = weeklyWorkouts
      .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
      .toSet();

  final caloriesByDay = <DateTime, double>{for (final day in days) day: 0};

  for (final workout in weeklyWorkouts) {
    final date = DateTimeHelper.localDateOnly(workout.startedAt);
    caloriesByDay.update(
      date,
      (value) => value + workout.caloriesKcal,
      ifAbsent: () => workout.caloriesKcal,
    );
  }

  return _WeeklyHomeStats(
    startOfWeek: start,
    days: days,
    weeklyDistanceKm: weeklyWorkouts.fold(0.0, (sum, w) => sum + w.distanceKm),
    weeklyCalories: weeklyWorkouts.fold(0.0, (sum, w) => sum + w.caloriesKcal),
    weeklyDurationSec: weeklyWorkouts.fold(0, (sum, w) => sum + w.durationSec),
    workoutCount: weeklyWorkouts.length,
    activeDayCount: activeDates.length,
    caloriesByDay: caloriesByDay,
    activeDates: activeDates,
    lastWorkout: workouts.isEmpty
        ? null
        : (workouts.toList()
                ..sort((a, b) => b.startedAt.compareTo(a.startedAt)))
              .first,
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
        SizedBox(height: 24),
        _EnergyFluxCard(),
        SizedBox(height: 20),
        _NeoStatsGrid(),
        SizedBox(height: 20),
        _SectionTitle(title: 'Weekly Pulse'),
        SizedBox(height: 12),
        _WeeklyPulseCard(),
      ],
    );
  }
}

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = ref
        .watch(currentUserProfileProvider)
        .valueOrNull
        ?.avatarUrl;
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
                    image: avatarUrl != null && avatarUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: avatarUrl == null || avatarUrl.isEmpty
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
    final ratio = hero.target <= 0
        ? 0.0
        : (hero.current / hero.target).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GoalScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 336,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 246,
                        height: 246,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _kNeonCyan.withValues(alpha: 0.24),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: CustomPaint(
                        size: const Size.square(288),
                        painter: _EnergyFluxPainter(progress: ratio),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 8,
                    right: 8,
                    bottom: 16,
                    child: CustomPaint(painter: _EnergyAccentPainter()),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 68,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'CORE LOAD',
                          style: TextStyle(
                            color: _kMutedText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: weekly.weeklyCalories.round().toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: ' KCAL',
                                style: TextStyle(
                                  color: _kMutedText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeoStatsGrid extends ConsumerWidget {
  const _NeoStatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(_weeklyHomeStatsProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final items = [
      _NeoStatItem(
        icon: Icons.place_outlined,
        label: 'DISTANCE',
        value:
            (useMetricUnits
                    ? weekly.weeklyDistanceKm
                    : WorkoutFormatters.kmToMi(weekly.weeklyDistanceKm))
                .toStringAsFixed(1),
        unit: WorkoutFormatters.distanceUnitLabel(
          useMetric: useMetricUnits,
        ).toUpperCase(),
      ),
      _NeoStatItem(
        icon: Icons.schedule_rounded,
        label: 'TIME',
        value: (weekly.weeklyDurationSec / 60).floor().toString(),
        unit: 'MIN',
      ),
      _NeoStatItem(
        icon: Icons.speed_rounded,
        label: 'PACE',
        value: _speedLabel(
          weekly.weeklyDistanceKm,
          weekly.weeklyDurationSec,
          useMetricUnits: useMetricUnits,
        ),
        unit: useMetricUnits ? 'KM/H' : 'MPH',
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: _NeoStatCard(item: items[i])),
          if (i != items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _WeeklyPulseCard extends ConsumerWidget {
  const _WeeklyPulseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(_weeklyHomeStatsProvider);
    final maxCalories = weekly.caloriesByDay.values.fold<double>(0, math.max);

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY PULSE',
                      style: TextStyle(
                        color: _kNeonCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '7D ANALYTICS',
                      style: TextStyle(
                        color: _kMutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${weekly.weeklyCalories.round()} KCAL',
                style: const TextStyle(
                  color: _kMutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 156,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weekly.days.length; i++) ...[
                  Expanded(
                    child: _PulseBar(
                      label: _weekdayLabel(weekly.days[i]),
                      value: weekly.caloriesByDay[weekly.days[i]] ?? 0,
                      maxValue: maxCalories,
                      isToday:
                          DateTimeHelper.localDateOnly(weekly.days[i]) ==
                          DateTimeHelper.localDateOnly(DateTime.now()),
                    ),
                  ),
                  if (i != weekly.days.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _NeoStatItem {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _NeoStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });
}

class _NeoStatCard extends StatelessWidget {
  final _NeoStatItem item;

  const _NeoStatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kNeonCyan.withValues(alpha: 0.08), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 16, color: _kNeonCyan.withValues(alpha: 0.78)),
          const SizedBox(height: 10),
          Text(
            item.label,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: item.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.unit.isNotEmpty)
                  TextSpan(
                    text: ' ${item.unit}',
                    style: const TextStyle(
                      color: _kMutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final bool isToday;

  const _PulseBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const reservedHeight = 38.0;
              final usableHeight = math.max(
                28.0,
                constraints.maxHeight - reservedHeight,
              );
              final barHeight = 24.0 + (usableHeight - 24.0) * normalized;

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: isToday || value > 0 ? 1 : 0,
                    child: Text(
                      value.round().toString(),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: isToday ? _kNeonCyan : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    height: barHeight,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      color: value <= 0
                          ? Colors.white.withValues(alpha: 0.10)
                          : null,
                      gradient: value <= 0
                          ? null
                          : LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isToday
                                  ? [_kNeonBlue, _kNeonCyan]
                                  : [
                                      _kNeonBlue.withValues(alpha: 0.45),
                                      _kNeonCyan.withValues(alpha: 0.75),
                                    ],
                            ),
                      boxShadow: value <= 0
                          ? null
                          : [
                              BoxShadow(
                                color: (isToday ? _kNeonCyan : _kNeonBlue)
                                    .withValues(alpha: 0.24),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 14,
          child: Text(
            label,
            style: TextStyle(
              color: isToday ? _kNeonCyan : _kMutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EnergyFluxPainter extends CustomPainter {
  final double progress;

  const _EnergyFluxPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xff1e3a4a);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [_kNeonCyan, _kNeonBlue],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [_kNeonCyan, _kNeonBlue],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(rect);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _kNeonCyan.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    if (progress > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyFluxPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _EnergyAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kNeonCyan.withValues(alpha: 0.28)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height * 0.34),
      Offset(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EnergyAccentPainter oldDelegate) => false;
}

class _WeeklyHomeStats {
  final DateTime startOfWeek;
  final List<DateTime> days;
  final double weeklyDistanceKm;
  final double weeklyCalories;
  final int weeklyDurationSec;
  final int workoutCount;
  final int activeDayCount;
  final Map<DateTime, double> caloriesByDay;
  final Set<DateTime> activeDates;
  final WorkoutSession? lastWorkout;

  const _WeeklyHomeStats({
    required this.startOfWeek,
    required this.days,
    required this.weeklyDistanceKm,
    required this.weeklyCalories,
    required this.weeklyDurationSec,
    required this.workoutCount,
    required this.activeDayCount,
    required this.caloriesByDay,
    required this.activeDates,
    required this.lastWorkout,
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

String _weekdayLabel(DateTime date) {
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return labels[date.weekday - 1];
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

String _speedLabel(
  double distanceKm,
  int durationSec, {
  required bool useMetricUnits,
}) {
  if (distanceKm <= 0 || durationSec <= 0) return '--';
  final speed = distanceKm / (durationSec / 3600);
  final displaySpeed = useMetricUnits ? speed : speed * 0.6213711922;
  return displaySpeed.toStringAsFixed(displaySpeed >= 10 ? 0 : 1);
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
