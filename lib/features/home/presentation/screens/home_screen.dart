import 'dart:math' as math;
import 'dart:io';

import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
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
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Use validDistanceKm when available so home stats align with goal progress.
  // Fall back to distanceKm for indoor/non-GPS workouts that have no GPS analysis.
  double effectiveDistance(WorkoutSession w) {
    return w.gpsAnalysis.validDistanceKm > 0
        ? w.gpsAnalysis.validDistanceKm
        : w.distanceKm;
  }

  return _WeeklyHomeStats(
    startOfWeek: start,
    weeklyDistanceKm: weeklyWorkouts.fold(
      0.0,
      (sum, w) => sum + effectiveDistance(w),
    ),
    weeklyCalories: weeklyWorkouts.fold(0.0, (sum, w) => sum + w.caloriesKcal),
    weeklyWorkoutsDurationSec: weeklyWorkouts.fold(
      0,
      (sum, w) => sum + w.durationSec,
    ),
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

  // Use validDistanceKm when available, consistent with weekly stats and goal progress.
  double effectiveDistance(WorkoutSession w) {
    return w.gpsAnalysis.validDistanceKm > 0
        ? w.gpsAnalysis.validDistanceKm
        : w.distanceKm;
  }

  return _TodayHomeStats(
    workoutCount: todayWorkouts.length,
    distanceKm: todayWorkouts.fold(0.0, (sum, w) => sum + effectiveDistance(w)),
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

int _nextStreakTarget(int days) {
  if (days < 7) return 7;
  if (days < 30) return 30;
  if (days < 90) return 90;
  if (days < 365) return 365;
  return 730;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutListProvider);
    final hasWorkouts = workoutsAsync.valueOrNull?.isNotEmpty ?? false;
    final isEmptyHistory = workoutsAsync.hasValue && !hasWorkouts;
    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      floatingActionButton: hasWorkouts
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton(
                heroTag: 'home_start_workout',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityScreen()),
                ),
                backgroundColor: AetronColors.cyan,
                foregroundColor: AetronColors.space,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(
                    color: AetronColors.cyanSoft,
                    width: 1.2,
                  ),
                ),
                child: const Icon(Icons.add_rounded, size: 36),
              ),
            )
          : null,
      body: isEmptyHistory
          ? const _HomeEmptyExperience()
          : Stack(
              children: [
                RefreshIndicator(
                  color: AetronColors.cyan,
                  backgroundColor: AetronColors.panel,
                  onRefresh: () async {
                    await ref.read(workoutListProvider.notifier).refresh();
                    final userId = ref.read(currentUserIdProvider);
                    if (userId != null) {
                      ref.invalidate(userProfileProvider(userId));
                    }
                    await ref.read(userGoalProvider.notifier).refresh();
                  },
                  child: AetronBackground(
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: const [
                        SliverToBoxAdapter(child: _HomeContent()),
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
    final workoutsAsync = ref.watch(workoutListProvider);
    final hasWorkouts = workoutsAsync.valueOrNull?.isNotEmpty ?? false;
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HomeTopBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOffline) ...[
                  const AetronOfflineBanner(),
                  const SizedBox(height: 16),
                ],
                if (workoutsAsync.hasError)
                  AetronStatePanel(
                    title: 'Dashboard unavailable',
                    message:
                        'Your workout dashboard could not be refreshed right now.',
                    tone: AetronStateTone.error,
                    onRetry: () =>
                        ref.read(workoutListProvider.notifier).refresh(),
                  )
                else if (hasWorkouts) ...const [
                  _EnergyFluxCard(),
                  SizedBox(height: 22),
                  _QuickSummaryCard(),
                ] else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyExperience extends ConsumerWidget {
  const _HomeEmptyExperience();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return RefreshIndicator(
      color: AetronColors.cyan,
      backgroundColor: AetronColors.panel,
      onRefresh: () async {
        await ref.read(workoutListProvider.notifier).refresh();
        final userId = ref.read(currentUserIdProvider);
        if (userId != null) ref.invalidate(userProfileProvider(userId));
        await ref.read(userGoalProvider.notifier).refresh();
      },
      child: AetronBackground(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  const _HomeTopBar(),
                  const Spacer(),
                  AetronProgressRing(
                    value: 0,
                    size: 154,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: AetronColors.cyan,
                          size: 34,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          AppTranslations.get('ready', currentLang),
                          style: AetronText.label,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.get('first_session', currentLang),
                            style: AetronText.section,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppTranslations.get('dashboard_ready_title', currentLang),
                            style: const TextStyle(
                              color: AetronColors.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppTranslations.get('dashboard_ready_sub', currentLang),
                            style: const TextStyle(
                              color: AetronColors.muted,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 17),
                          Row(
                            children: [
                              Expanded(
                                child: _FirstWorkoutMetric(
                                  value: '0',
                                  label: AppTranslations.get('sessions', currentLang),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FirstWorkoutMetric(
                                  value: '0.0',
                                  label: AppTranslations.get('distance', currentLang).toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FirstWorkoutMetric(
                                  value: '0',
                                  label: AppTranslations.get('minutes', currentLang),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          AetronPrimaryButton(
                            label: AppTranslations.get('start_workout', currentLang),
                            icon: Icons.play_arrow_rounded,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ActivityScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _FirstWorkoutMetric extends StatelessWidget {
  const _FirstWorkoutMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AetronColors.cyanSoft,
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AetronText.label.copyWith(fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final avatar = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? avatarImage = avatar.localPath != null
        ? FileImage(File(avatar.localPath!))
        : avatar.remoteUrl != null && avatar.remoteUrl!.isNotEmpty
        ? NetworkImage(avatar.remoteUrl!)
        : null;
    final streak = ref.watch(streakProvider);
    final initials = _initialsFromEmail(user?.email);

    return AetronHeader(
      title: '${_homeGreeting(currentLang)}, ${_homeDisplayName(user)}',
      eyebrow: AppTranslations.get('daily_telemetry', currentLang),
      compact: true,
      titleSize: 22,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AetronStreakPill(
            streak: streak.currentStreak,
            compact: true,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _StreakDetailsSheet(streak: streak),
            ),
          ),
          const SizedBox(width: 10),
          AetronAvatar(
            image: avatarImage,
            label: initials,
            size: 40,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
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
    final currentLang = ref.watch(appLanguageProvider);
    final hero = ref.watch(_weeklyHeroProvider);
    final weekly = ref.watch(_weeklyHomeStatsProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final ratio = hero.target <= 0
        ? 0.0
        : (hero.current / hero.target).clamp(0.0, 1.0).toDouble();
    final percent = (ratio * 100).round();

    return AetronGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GoalScreen())),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return Row(
            children: [
              AetronProgressRing(
                value: ratio,
                size: compact ? 100 : 122,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${weekly.activeDayCount}',
                      style: const TextStyle(
                        color: AetronColors.gold,
                        fontSize: 34,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTranslations.get('days', currentLang),
                      style: AetronText.label.copyWith(
                        color: AetronColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 12 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero.unit == 'kcal'
                          ? AppTranslations.get('calorie_goal', currentLang)
                          : hero.unit == 'sessions'
                          ? AppTranslations.get('workout_goal', currentLang)
                          : AppTranslations.get('distance_goal', currentLang),
                      style: AetronText.section,
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hero.badgeLabel.replaceAll(' / ', '/'),
                        style: const TextStyle(
                          color: AetronColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _GoalStat(
                          label: AppTranslations.get('completion', currentLang),
                          value: '$percent%',
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        _GoalStat(
                          label: currentLang == AppLanguage.vi
                              ? 'Tuần ${hero.weekNumber}'
                              : 'Week ${hero.weekNumber}',
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
            ],
          );
        },
      ),
    );
  }
}

class _GoalStat extends StatelessWidget {
  const _GoalStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), maxLines: 1, style: AetronText.label),
            const SizedBox(height: 5),
            Text(
              value.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AetronColors.cyanSoft,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
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
    final currentLang = ref.watch(appLanguageProvider);
    final today = ref.watch(_todayHomeStatsProvider);
    final weekly = ref.watch(_weeklyHomeStatsProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentLang == AppLanguage.vi
              ? '01. THỐNG KÊ HÀNG NGÀY'
              : '01. DAILY READOUT',
          style: AetronText.section,
        ),
        const SizedBox(height: 14),
        Text(
          currentLang == AppLanguage.vi ? 'Hôm nay' : 'Today',
          style: const TextStyle(
            color: AetronColors.text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AetronMetricTile(
                icon: Icons.fitness_center_rounded,
                value: '${today.workoutCount}',
                label: AppTranslations.get('sessions', currentLang).toLowerCase(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AetronMetricTile(
                icon: Icons.route_rounded,
                value: WorkoutFormatters.formatDistance(
                  today.distanceKm,
                  useMetric: useMetricUnits,
                  decimals: 1,
                ),
                label: AppTranslations.get('distance', currentLang).toLowerCase(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AetronMetricTile(
                icon: Icons.timer_rounded,
                value: WorkoutFormatters.formatDurationFromSeconds(
                  today.durationSec,
                ),
                label: AppTranslations.get('duration', currentLang).toLowerCase(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AetronGlassCard(
          padding: const EdgeInsets.all(16),
          color: AetronColors.panelBright.withValues(alpha: 0.52),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AetronColors.cyan.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AetronColors.cyan.withValues(alpha: 0.44),
                  ),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AetronColors.cyan,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLang == AppLanguage.vi
                          ? 'NỔI BẬT HIỆU SUẤT'
                          : 'PERFORMANCE HIGHLIGHT',
                      style: AetronText.label.copyWith(
                        color: AetronColors.gold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      currentLang == AppLanguage.vi
                          ? 'Chạy phục hồi - Vùng 2'
                          : 'Recovery Run - Zone 2',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AetronColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weekly.workoutCount > 0
                          ? (currentLang == AppLanguage.vi
                              ? 'Đỉnh cao kiên trì: ${weekly.activeDayCount}/7 ngày tập'
                              : 'Consistency peak: ${weekly.activeDayCount}/7 active days')
                          : (currentLang == AppLanguage.vi
                              ? 'Bắt đầu bài tập để mở khóa chỉ số'
                              : 'Start a workout to unlock telemetry'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AetronColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_double_arrow_right_rounded,
                color: AetronColors.cyan,
                size: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              currentLang == AppLanguage.vi ? 'Tuần này' : 'This week',
              style: const TextStyle(
                color: AetronColors.text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              AppTranslations.get('see_all', currentLang).toUpperCase(),
              style: AetronText.label.copyWith(
                color: AetronColors.cyanSoft,
                decoration: TextDecoration.underline,
                decorationColor: AetronColors.cyanSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AetronMetricTile(
                icon: Icons.fitness_center_rounded,
                value: '${weekly.workoutCount}',
                label: AppTranslations.get('sessions', currentLang).toLowerCase(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AetronMetricTile(
                icon: Icons.route_rounded,
                value: WorkoutFormatters.formatDistance(
                  weekly.weeklyDistanceKm,
                  useMetric: useMetricUnits,
                  decimals: 1,
                ),
                label: AppTranslations.get('distance', currentLang).toLowerCase(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AetronMetricTile(
                icon: Icons.event_available_rounded,
                value: '${weekly.activeDayCount}/7',
                label: currentLang == AppLanguage.vi ? 'ngày tập' : 'active days',
              ),
            ),
          ],
        ),
      ],
    );
  }
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

class _StreakDetailsSheet extends ConsumerWidget {
  final StreakData streak;

  const _StreakDetailsSheet({required this.streak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(_weeklyHomeStatsProvider);
    final workouts =
        ref.watch(workoutListProvider).valueOrNull ?? const <WorkoutSession>[];
    final days = streak.currentStreak;
    final targetDays = _nextStreakTarget(days);
    final progress = (days / targetDays).clamp(0.0, 1.0);
    final daysLeft = math.max(0, targetDays - days);
    final statusLabel = days == 0
        ? 'START YOUR STREAK'
        : days >= 7
        ? 'MILESTONE UNLOCKED'
        : 'STREAK ACTIVE';
    final totalMinutes = (weekly.weeklyWorkoutsDurationSec / 60).round();
    final today = DateTimeHelper.localDateOnly(DateTime.now());
    final activeDates = workouts
        .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
        .toSet();

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff0a1424), Color(0xff07111f)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'AETRON',
                        style: TextStyle(
                          color: AetronColors.cyanSoft,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AetronColors.muted,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size.square(220),
                              painter: _StreakRingsPainter(progress: progress),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  statusLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '$days',
                                  style: const TextStyle(
                                    color: AetronColors.cyan,
                                    fontSize: 80,
                                    height: 0.9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'DAYS STREAK',
                                  style: TextStyle(
                                    color: AetronColors.cyanSoft,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                /* Offstage(
                                  offstage: true,
                                  child: Text(
                                  '••••••',
                                  style: TextStyle(
                                    color: AetronColors.cyan.withValues(
                                      alpha: 0.95,
                                    ),
                                    fontSize: 24,
                                    letterSpacing: 3,
                                  ), */
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StreakTargetCard(
                        progress: progress,
                        daysLeft: daysLeft,
                        targetDays: targetDays,
                      ),
                      const SizedBox(height: 12),
                      _StreakWeekStrip(today: today, activeDates: activeDates),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StreakTierCard(
                              icon: Icons.workspace_premium_outlined,
                              value: '90 DAYS',
                              label: 'Mastery Level',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StreakTierCard(
                              icon: Icons.emoji_events_outlined,
                              value: '1 YEAR',
                              label: 'Legendary Tier',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _StreakStatChip(
                            icon: Icons.local_fire_department_rounded,
                            label:
                                '${weekly.weeklyCalories.round()} KCAL TOTAL',
                          ),
                          _StreakStatChip(
                            icon: Icons.schedule_rounded,
                            label: '$totalMinutes MINS',
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => const ActivityScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('CONTINUE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AetronColors.cyan,
                            foregroundColor: AetronColors.space,
                            iconAlignment: IconAlignment.end,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakRingsPainter extends CustomPainter {
  const _StreakRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 7;
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AetronColors.cyan.withValues(alpha: 0.26);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AetronColors.cyan.withValues(alpha: 0.12);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AetronColors.cyan;

    canvas.drawCircle(center, radius, outer);
    canvas.drawCircle(center, radius * 0.78, inner);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * math.pi * 2,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StreakRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StreakTargetCard extends StatelessWidget {
  const _StreakTargetCard({
    required this.progress,
    required this.daysLeft,
    required this.targetDays,
  });

  final double progress;
  final int daysLeft;
  final int targetDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AetronColors.space.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AetronColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'STREAK PROGRESSION',
                style: TextStyle(
                  color: AetronColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              Text(
                '$daysLeft DAYS LEFT',
                style: const TextStyle(
                  color: AetronColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AetronColors.panelBright.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AetronColors.cyan,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _StreakFlameRow(progress: progress),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'TO NEXT TIER: $targetDays DAY ELITE STREAK',
              style: const TextStyle(
                color: AetronColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakFlameRow extends StatelessWidget {
  const _StreakFlameRow({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final activeFlames = (progress * 6).ceil().clamp(0, 6);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var index = 0; index < 6; index++) ...[
          Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: index < activeFlames
                ? AetronColors.cyan
                : AetronColors.panelBright,
          ),
          if (index != 5) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _StreakWeekStrip extends StatelessWidget {
  const _StreakWeekStrip({required this.today, required this.activeDates});

  final DateTime today;
  final Set<DateTime> activeDates;

  @override
  Widget build(BuildContext context) {
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AetronColors.space.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AetronColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('THIS WEEK', style: AetronText.label),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: _StreakDayMarker(
                    label: labels[index],
                    date: startOfWeek.add(Duration(days: index)),
                    today: today,
                    isActive: activeDates.contains(
                      startOfWeek.add(Duration(days: index)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakDayMarker extends StatelessWidget {
  const _StreakDayMarker({
    required this.label,
    required this.date,
    required this.today,
    required this.isActive,
  });

  final String label;
  final DateTime date;
  final DateTime today;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;
    final color = isActive ? AetronColors.cyan : AetronColors.panelBright;
    return Column(
      children: [
        Text(label, style: AetronText.label.copyWith(fontSize: 8)),
        const SizedBox(height: 7),
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.9) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isToday ? AetronColors.gold : color.withValues(alpha: 0.7),
              width: isToday ? 1.5 : 1,
            ),
          ),
          child: isActive
              ? const Icon(
                  Icons.check_rounded,
                  color: AetronColors.space,
                  size: 17,
                )
              : Text(
                  '${date.day}',
                  style: const TextStyle(
                    color: AetronColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ],
    );
  }
}

class _StreakTierCard extends StatelessWidget {
  const _StreakTierCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AetronColors.space.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AetronColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AetronColors.cyanSoft, size: 16),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: AetronColors.muted.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakStatChip extends StatelessWidget {
  const _StreakStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AetronColors.cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AetronColors.cyan, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AetronColors.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyHomeStats {
  final DateTime startOfWeek;
  final double weeklyDistanceKm;
  final double weeklyCalories;
  final int weeklyWorkoutsDurationSec;
  final int workoutCount;
  final int activeDayCount;

  const _WeeklyHomeStats({
    required this.startOfWeek,
    required this.weeklyDistanceKm,
    required this.weeklyCalories,
    required this.weeklyWorkoutsDurationSec,
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

String _homeDisplayName(User? user) {
  final displayName = user?.userMetadata?['display_name'] as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  final username = user?.userMetadata?['username'] as String?;
  if (username != null && username.trim().isNotEmpty) return username.trim();
  return (user?.email ?? 'Athlete').split('@').first;
}

String _homeGreeting(AppLanguage lang) {
  final hour = DateTime.now().hour;
  if (hour < 12) return AppTranslations.get('good_morning', lang);
  if (hour < 18) return AppTranslations.get('good_afternoon', lang);
  return AppTranslations.get('good_evening', lang);
}
