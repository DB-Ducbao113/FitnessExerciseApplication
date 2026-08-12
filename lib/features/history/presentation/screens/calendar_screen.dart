import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/daily_workout_list.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_state_panel.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final historyRangeProvider = StateProvider<_HistoryRange>(
  (ref) => _HistoryRange.all,
);

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final range = ref.watch(historyRangeProvider);
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;
    final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: workoutsAsync.when(
          data: (workouts) {
            if (workouts.isEmpty) {
              return _HistoryEmptyExperience(range: range);
            }
            final filtered = _filterWorkouts(workouts, range)
              ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
            final summary = _HistorySummary.fromWorkouts(filtered);

            return RefreshIndicator(
              color: AetronColors.cyan,
              backgroundColor: AetronColors.panelHigh,
              onRefresh: () async {
                await ref.read(workoutListProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                children: [
                  // 3D Header Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.get('workout_history', currentLang),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.textPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentLang == AppLanguage.vi
                            ? 'Lịch sử tập luyện đã ghi nhận'
                            : 'Recorded fitness timeline',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: AetronColors.cyanSoft,
                        ),
                      ),
                      if (isOffline) ...[
                        const SizedBox(height: 12),
                        const AetronOfflineBanner(),
                      ],
                      const SizedBox(height: 16),

                      // 3D Range Tabs Segmented Control
                      _RangeTabs(
                        selected: range,
                        onChanged: (value) {
                          ref.read(historyRangeProvider.notifier).state = value;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3D Summary Overview Card
                      _History3DOverview(
                        summary: summary,
                        useMetricUnits: useMetricUnits,
                      ),
                      const SizedBox(height: 20),

                      // 3D Workout Timeline List grouped by date
                      DailyWorkoutList(
                        workouts: filtered,
                        range: range.getLabel(currentLang),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: AetronLoadingPanel(
              label: 'LOADING HISTORY',
              message: 'Retrieving your workout records.',
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AetronStatePanel(
                title: 'History unavailable',
                message: 'Your saved workouts could not be loaded right now.',
                tone: AetronStateTone.error,
                onRetry: () => ref.read(workoutListProvider.notifier).refresh(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 3D Overview Card for Selected Period ───────────────────────────────────
class _History3DOverview extends ConsumerWidget {
  const _History3DOverview({
    required this.summary,
    required this.useMetricUnits,
  });

  final _HistorySummary summary;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final distanceStr = WorkoutFormatters.formatDistance(
      summary.distanceKm,
      useMetric: useMetricUnits,
      decimals: 1,
    );
    final durationStr = WorkoutFormatters.formatDurationFromSeconds(
      summary.durationSec,
    );
    final workoutUnit = currentLang == AppLanguage.vi
        ? 'buổi'
        : (summary.workouts == 1 ? 'workout' : 'workouts');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AetronColors.cyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.12),
            blurRadius: 14,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.get('this_period', currentLang),
            style: TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.cyanSoft.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${summary.workouts} $workoutUnit   •   $distanceStr ${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits)}   •   $durationStr',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (summary.calories > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AetronColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AetronColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${summary.calories} kcal',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: AetronColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Range Tabs 3D Segmented Selector ──────────────────────────────────────────
class _RangeTabs extends ConsumerWidget {
  const _RangeTabs({required this.selected, required this.onChanged});

  final _HistoryRange selected;
  final ValueChanged<_HistoryRange> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final values = _HistoryRange.values;
    final selectedIdx = values.indexOf(selected);

    return AetronSegmentedControl(
      selectedIndex: selectedIdx,
      tabs: values.map((r) => r.getLabel(currentLang)).toList(),
      onTabChanged: (idx) => onChanged(values[idx]),
    );
  }
}

// ─── 3D Empty History Experience ───────────────────────────────────────────────
class _HistoryEmptyExperience extends ConsumerWidget {
  const _HistoryEmptyExperience({required this.range});

  final _HistoryRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return RefreshIndicator(
      color: AetronColors.cyan,
      backgroundColor: AetronColors.panelHigh,
      onRefresh: () => ref.read(workoutListProvider.notifier).refresh(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _RangeTabs(
                selected: range,
                onChanged: (value) {
                  ref.read(historyRangeProvider.notifier).state = value;
                },
              ),
              const Spacer(),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AetronColors.panelHigh,
                  border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: AetronColors.cyan.withValues(alpha: 0.2),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 44,
                  color: AetronColors.cyan,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppTranslations.get('no_workouts_yet', currentLang),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppTranslations.get('empty_history_desc', currentLang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: AetronColors.textSecondary,
                ),
              ),
              const Spacer(),
              Aetron3DPrimaryButton(
                label: AppTranslations.get('start_workout', currentLang).toUpperCase(),
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HistoryRange { all, week, month, year }

extension on _HistoryRange {
  String getLabel(AppLanguage lang) {
    switch (this) {
      case _HistoryRange.all:
        return AppTranslations.get('all', lang);
      case _HistoryRange.week:
        return AppTranslations.get('week', lang);
      case _HistoryRange.month:
        return AppTranslations.get('month', lang);
      case _HistoryRange.year:
        return AppTranslations.get('year', lang);
    }
  }
}

class _HistorySummary {
  final int workouts;
  final double distanceKm;
  final int calories;
  final int durationSec;

  const _HistorySummary({
    required this.workouts,
    required this.distanceKm,
    required this.calories,
    required this.durationSec,
  });

  factory _HistorySummary.fromWorkouts(List<WorkoutSession> workouts) {
    return _HistorySummary(
      workouts: workouts.length,
      distanceKm: workouts.fold(0.0, (sum, item) => sum + item.distanceKm),
      durationSec: workouts.fold(0, (sum, item) => sum + item.durationSec),
      calories: workouts.fold(
        0,
        (sum, item) => sum + item.caloriesKcal.round(),
      ),
    );
  }
}

List<WorkoutSession> _filterWorkouts(
  List<WorkoutSession> workouts,
  _HistoryRange range,
) {
  if (workouts.isEmpty || range == _HistoryRange.all) {
    return List<WorkoutSession>.from(workouts);
  }

  final now = DateTime.now();

  List<WorkoutSession> getForWindow(DateTime referenceDate) {
    final refDay = DateTimeHelper.localDateOnly(referenceDate);
    switch (range) {
      case _HistoryRange.week:
        final start = refDay.subtract(const Duration(days: 6));
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && !d.isAfter(refDay);
        }).toList();

      case _HistoryRange.month:
        final start = refDay.subtract(const Duration(days: 29));
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && !d.isAfter(refDay);
        }).toList();

      case _HistoryRange.year:
        final start = DateTime(refDay.year, 1, 1);
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && d.year == refDay.year;
        }).toList();

      case _HistoryRange.all:
        return List<WorkoutSession>.from(workouts);
    }
  }

  final currentFiltered = getForWindow(now);
  if (currentFiltered.isNotEmpty) {
    return currentFiltered;
  }

  final latestWorkoutDate = workouts.first.startedAt;
  return getForWindow(latestWorkoutDate);
}
