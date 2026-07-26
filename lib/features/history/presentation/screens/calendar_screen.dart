import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/daily_workout_list.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final historyRangeProvider = StateProvider<_HistoryRange>(
  (ref) => _HistoryRange.all,
);

const _kPanel = Color(0xFF102033);
const _kNeonCyan = Color(0xFF19E2FF);

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final range = ref.watch(historyRangeProvider);
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: AetronBackground(
        withGrid: false,
        child: workoutsAsync.when(
          data: (workouts) {
            if (workouts.isEmpty) {
              return _HistoryEmptyExperience(range: range);
            }
            final filtered = _filterWorkouts(workouts, range)
              ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
            final summary = _HistorySummary.fromWorkouts(filtered);

            return RefreshIndicator(
              color: _kNeonCyan,
              backgroundColor: _kPanel,
              onRefresh: () async {
                await ref.read(workoutListProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
                children: [
                  const _BrandHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.get('calendar', currentLang).toUpperCase(),
                          style: const TextStyle(
                            color: AetronColors.text,
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (isOffline) ...[
                          const SizedBox(height: 14),
                          const AetronOfflineBanner(),
                        ],
                        const SizedBox(height: 20),
                        _RangeTabs(
                          selected: range,
                          onChanged: (value) {
                            ref.read(historyRangeProvider.notifier).state =
                                value;
                          },
                        ),
                        const SizedBox(height: 20),
                        _HistoryOverview(
                          summary: summary,
                          useMetricUnits: useMetricUnits,
                        ),
                        const SizedBox(height: 20),
                        DailyWorkoutList(
                          workouts: filtered,
                          range: range.getLabel(currentLang),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: AetronLoadingPanel(
              label: 'LOADING HISTORY',
              message: 'Indexing recorded sessions.',
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AetronStatePanel(
                title: 'History unavailable',
                message: 'Your workout history could not be loaded right now.',
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


class _HistoryEmptyExperience extends ConsumerWidget {
  const _HistoryEmptyExperience({required this.range});

  final _HistoryRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return RefreshIndicator(
      color: _kNeonCyan,
      backgroundColor: _kPanel,
      onRefresh: () => ref.read(workoutListProvider.notifier).refresh(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.78,
            child: CustomPaint(painter: _FullHistorySignalPainter()),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AetronColors.voidBlack.withValues(alpha: 0.32),
                  Colors.transparent,
                  AetronColors.voidBlack.withValues(alpha: 0.94),
                ],
              ),
            ),
          ),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    const _BrandHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      child: _RangeTabs(
                        selected: range,
                        onChanged: (value) {
                          ref.read(historyRangeProvider.notifier).state = value;
                        },
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.route_rounded,
                      color: _kNeonCyan,
                      size: 34,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppTranslations.get('route_timeline_standby', currentLang),
                      style: AetronText.section,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppTranslations.get('no_activity_recorded', currentLang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        AppTranslations.get('no_activity_sub', currentLang),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AetronColors.cyanSoft,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: AetronPrimaryButton(
                          label: AppTranslations.get('record_activity', currentLang),
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ActivityScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FullHistorySignalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _kNeonCyan.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 34.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final route = Path()
      ..moveTo(size.width * .04, size.height * .78)
      ..cubicTo(
        size.width * .24,
        size.height * .34,
        size.width * .52,
        size.height * .86,
        size.width * .70,
        size.height * .48,
      )
      ..cubicTo(
        size.width * .84,
        size.height * .19,
        size.width * .94,
        size.height * .30,
        size.width * .90,
        size.height * .66,
      );
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
      ..color = _kNeonCyan.withValues(alpha: .16);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _kNeonCyan.withValues(alpha: .62);
    canvas.drawPath(route, glow);
    canvas.drawPath(route, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandHeader extends ConsumerWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return AetronHeader(
      title: AppTranslations.get('nav_history', currentLang),
      compact: true,
      titleSize: 22,
    );
  }
}

class _HistoryOverview extends ConsumerWidget {
  const _HistoryOverview({
    required this.summary,
    required this.useMetricUnits,
  });

  final _HistorySummary summary;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final distance = WorkoutFormatters.formatDistance(
      summary.distanceKm,
      useMetric: useMetricUnits,
      decimals: 1,
    );
    final duration = WorkoutFormatters.formatDurationFromSeconds(
      summary.durationSec,
    );
    final workoutLabel = currentLang == AppLanguage.vi ? 'buổi tập' : 'workouts';

    return AetronGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      radius: 18,
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AetronColors.cyan, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${summary.workouts} $workoutLabel / $distance / $duration',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AetronColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FittedBox(
            child: Text(
              '${summary.calories} KCAL',
              style: AetronText.label.copyWith(
                color: AetronColors.text,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeTabs extends ConsumerWidget {
  const _RangeTabs({required this.selected, required this.onChanged});

  final _HistoryRange selected;
  final ValueChanged<_HistoryRange> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return AetronSegmented<_HistoryRange>(
      values: _HistoryRange.values,
      selected: selected,
      labelBuilder: (value) => value.getLabel(currentLang),
      onChanged: onChanged,
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
  if (range == _HistoryRange.all) return List<WorkoutSession>.from(workouts);

  final now = DateTimeHelper.localDateOnly(DateTime.now());
  late final DateTime start;

  switch (range) {
    case _HistoryRange.week:
      start = now.subtract(Duration(days: now.weekday - 1));
      break;
    case _HistoryRange.month:
      start = DateTime(now.year, now.month, 1);
      break;
    case _HistoryRange.year:
      start = DateTime(now.year, 1, 1);
      break;
    case _HistoryRange.all:
      start = DateTime(2000);
      break;
  }

  return workouts.where((workout) {
    return !DateTimeHelper.localDateOnly(workout.startedAt).isBefore(start);
  }).toList();
}
