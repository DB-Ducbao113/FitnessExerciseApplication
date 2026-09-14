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
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final historyRangeProvider = StateProvider<HistoryRange>(
  (ref) => HistoryRange.all,
);

final historyActivityFilterProvider = StateProvider<String>(
  (ref) => 'all',
);

enum HistoryRange { all, week, month, year }

extension HistoryRangeX on HistoryRange {
  String getLabel(AppLanguage lang) {
    switch (this) {
      case HistoryRange.all:
        return AppTranslations.get('all', lang);
      case HistoryRange.week:
        return AppTranslations.get('week', lang);
      case HistoryRange.month:
        return AppTranslations.get('month', lang);
      case HistoryRange.year:
        return AppTranslations.get('year', lang);
    }
  }
}

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final range = ref.watch(historyRangeProvider);
    final activityFilter = ref.watch(historyActivityFilterProvider);
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

            // Filter by time range and activity type
            final timeFiltered = _filterWorkouts(workouts, range)
              ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

            final filtered = activityFilter == 'all'
                ? timeFiltered
                : timeFiltered
                    .where((w) =>
                        w.activityType.toLowerCase() == activityFilter.toLowerCase())
                    .toList();

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
                  // 1. Header Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentLang == AppLanguage.vi
                                ? 'Dòng thời gian hoạt động'
                                : 'Activity Timeline & Telemetry',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              color: AetronColors.cyanSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Workout Total Counter Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AetronColors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AetronColors.cyan.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on_rounded,
                                color: AetronColors.cyan, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${filtered.length} ${currentLang == AppLanguage.vi ? 'BUỔI' : 'RUNS'}',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AetronColors.cyan,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (isOffline) ...[
                    const SizedBox(height: 12),
                    const AetronOfflineBanner(),
                  ],
                  const SizedBox(height: 14),

                  // 2. Activity Type Filter Pills
                  _ActivityTypeFilterRow(
                    selected: activityFilter,
                    currentLang: currentLang,
                    onSelected: (val) {
                      HapticFeedback.selectionClick();
                      ref.read(historyActivityFilterProvider.notifier).state =
                          val;
                    },
                  ),
                  const SizedBox(height: 10),

                  // 3. Time Range Tabs Segmented Control
                  _RangeTabs(
                    selected: range,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      ref.read(historyRangeProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. Bento Grid Telemetry Overview
                  _HistoryBentoOverview(
                    summary: summary,
                    useMetricUnits: useMetricUnits,
                    currentLang: currentLang,
                  ),
                  const SizedBox(height: 20),

                  // 5. Workout Timeline List grouped by date
                  DailyWorkoutList(
                    workouts: filtered,
                    range: range.getLabel(currentLang),
                  ),
                ],
              ),
            );
          },
          loading: () => const CalendarSkeletonView(),
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

// ─── Activity Type Filter Chips ──────────────────────────────────────────────
class _ActivityTypeFilterRow extends StatelessWidget {
  final String selected;
  final AppLanguage currentLang;
  final ValueChanged<String> onSelected;

  const _ActivityTypeFilterRow({
    required this.selected,
    required this.currentLang,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;
    final filters = [
      {'id': 'all', 'label': isVi ? 'Tất cả' : 'All', 'icon': Icons.apps_rounded, 'color': AetronColors.cyan},
      {'id': 'running', 'label': isVi ? 'Chạy bộ' : 'Running', 'icon': Icons.directions_run_rounded, 'color': AetronColors.cyan},
      {'id': 'walking', 'label': isVi ? 'Đi bộ' : 'Walking', 'icon': Icons.directions_walk_rounded, 'color': AetronColors.mint},
      {'id': 'cycling', 'label': isVi ? 'Đạp xe' : 'Cycling', 'icon': Icons.directions_bike_rounded, 'color': AetronColors.gold},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final id = f['id'] as String;
          final label = f['label'] as String;
          final icon = f['icon'] as IconData;
          final color = f['color'] as Color;
          final isSelected = selected == id;

          return GestureDetector(
            onTap: () => onSelected(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : AetronColors.panelHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : AetronColors.borderSubtle,
                  width: isSelected ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: isSelected ? color : AetronColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected ? color : AetronColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Bento Grid Overview for Selected Period ─────────────────────────────────
class _HistoryBentoOverview extends StatelessWidget {
  final _HistorySummary summary;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const _HistoryBentoOverview({
    required this.summary,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;
    final distanceStr = WorkoutFormatters.formatDistance(
      summary.distanceKm,
      useMetric: useMetricUnits,
      decimals: 1,
    );
    final durationStr = WorkoutFormatters.formatDurationFromSeconds(
      summary.durationSec,
    );
    final unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
    final avgPaceStr = summary.distanceKm > 0 && summary.durationSec > 0
        ? WorkoutFormatters.formatPaceFromDistanceAndDuration(
            distanceKm: summary.distanceKm,
            durationSec: summary.durationSec,
            useMetric: useMetricUnits,
          )
        : '—';

    return Container(
      width: double.infinity,
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
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'TỔNG KẾT GIAI ĐOẠN' : 'PERIOD TELEMETRY MATRIX',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.cyanSoft.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AetronColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${summary.workouts} ${isVi ? 'hoạt động' : 'activities'}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AetronColors.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bento 2x2 Grid
          Row(
            children: [
              // Hero Distance (Left Big Card)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1524),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AetronColors.cyan.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route_rounded,
                              color: AetronColors.cyan, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            (isVi ? 'QUÃNG ĐƯỜNG' : 'DISTANCE').toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AetronColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            distanceStr,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AetronColors.textPrimary,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            unit,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AetronColors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Right Column (Duration & Calories)
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    // Duration Tile
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1524),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AetronColors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_rounded,
                              color: AetronColors.blue, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              durationStr,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AetronColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Calories Tile
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1524),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AetronColors.gold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              color: AetronColors.gold, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${summary.calories} kcal',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AetronColors.gold,
                              ),
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
          const SizedBox(height: 10),

          // Bottom Bar: Average Pace
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B101D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AetronColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded,
                        color: AetronColors.mint, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      isVi ? 'Pace Trung Bình:' : 'Average Pace:',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AetronColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  avgPaceStr,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.mint,
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

// ─── Range Tabs 3D Segmented Selector ──────────────────────────────────────────
class _RangeTabs extends ConsumerWidget {
  const _RangeTabs({required this.selected, required this.onChanged});

  final HistoryRange selected;
  final ValueChanged<HistoryRange> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return AetronSegmented<HistoryRange>(
      values: HistoryRange.values,
      selected: selected,
      labelBuilder: (r) => r.getLabel(currentLang),
      onChanged: onChanged,
    );
  }
}

// ─── 3D Empty History Experience ───────────────────────────────────────────────
class _HistoryEmptyExperience extends ConsumerWidget {
  const _HistoryEmptyExperience({required this.range});

  final HistoryRange range;

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
                  border: Border.all(
                      color: AetronColors.cyan.withValues(alpha: 0.3)),
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
              AppButton(
                label: AppTranslations.get('start_workout', currentLang)
                    .toUpperCase(),
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
      distanceKm: workouts.fold(0.0, (sum, item) {
        final d = item.gpsAnalysis.validDistanceKm > 0
            ? item.gpsAnalysis.validDistanceKm
            : item.distanceKm;
        return sum + d;
      }),
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
  HistoryRange range,
) {
  if (workouts.isEmpty || range == HistoryRange.all) {
    return List<WorkoutSession>.from(workouts);
  }

  final now = DateTime.now();

  List<WorkoutSession> getForWindow(DateTime referenceDate) {
    final refDay = DateTimeHelper.localDateOnly(referenceDate);
    switch (range) {
      case HistoryRange.week:
        final start = refDay.subtract(const Duration(days: 6));
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && !d.isAfter(refDay);
        }).toList();

      case HistoryRange.month:
        final start = refDay.subtract(const Duration(days: 29));
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && !d.isAfter(refDay);
        }).toList();

      case HistoryRange.year:
        final start = DateTime(refDay.year, 1, 1);
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && d.year == refDay.year;
        }).toList();

      case HistoryRange.all:
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
