import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/daily_workout_list.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final historyRangeProvider = StateProvider<_HistoryRange>(
  (ref) => _HistoryRange.all,
);

const _kBgTop = Color(0xFF0A1320);
const _kBgBottom = Color(0xFF08111B);
const _kPanel = Color(0xFF102033);
const _kPanelSoft = Color(0xFF12263C);
const _kPanelBorder = Color(0x2200E5FF);
const _kMutedText = Color(0xFF8A96A9);
const _kMutedSoft = Color(0xFF627286);
const _kNeonCyan = Color(0xFF19E2FF);
const _kAmber = Color(0xFFFFB85C);

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutListProvider);
    final range = ref.watch(historyRangeProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: _kBgBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: SafeArea(
          child: workoutsAsync.when(
            data: (workouts) {
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
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 14),
                    _HistoryOverview(
                      summary: summary,
                      useMetricUnits: useMetricUnits,
                    ),
                    const SizedBox(height: 12),
                    _RangeTabs(
                      selected: range,
                      onChanged: (value) {
                        ref.read(historyRangeProvider.notifier).state = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    DailyWorkoutList(workouts: filtered, range: range.label),
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: _kNeonCyan),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load history.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends ConsumerWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13263B),
        border: Border(
          bottom: BorderSide(color: _kNeonCyan.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'HISTORY',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2A18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kAmber.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFFD364),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  '${streak.currentStreak}',
                  style: TextStyle(
                    color: Color(0xFFFFD364),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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

class _HistoryOverview extends StatelessWidget {
  const _HistoryOverview({required this.summary, required this.useMetricUnits});

  final _HistorySummary summary;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _OverviewItem(
        label: 'TOTAL DISTANCE',
        value:
            (useMetricUnits
                    ? summary.distanceKm
                    : WorkoutFormatters.kmToMi(summary.distanceKm))
                .toStringAsFixed(1),
        color: _kNeonCyan,
        icon: Icons.place_outlined,
      ),
      _OverviewItem(
        label: 'CALORIES',
        value: '${summary.calories}',
        color: _kAmber,
        icon: Icons.local_fire_department_rounded,
      ),
      _OverviewItem(
        label: 'SESSIONS',
        value: '${summary.workouts}',
        color: const Color(0xFF39F2B8),
        icon: Icons.fitness_center_rounded,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: _OverviewCard(item: cards[i])),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.item});

  final _OverviewItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _kPanelSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, color: item.color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: _kMutedSoft,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.selected, required this.onChanged});

  final _HistoryRange selected;
  final ValueChanged<_HistoryRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF14304A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final value in _HistoryRange.values) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == value ? _kNeonCyan : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    value.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected == value ? _kBgBottom : _kMutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            if (value != _HistoryRange.values.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

enum _HistoryRange { all, week, month, year }

extension on _HistoryRange {
  String get label {
    switch (this) {
      case _HistoryRange.all:
        return 'All';
      case _HistoryRange.week:
        return 'Week';
      case _HistoryRange.month:
        return 'Month';
      case _HistoryRange.year:
        return 'Year';
    }
  }
}

class _OverviewItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _OverviewItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _HistorySummary {
  final int workouts;
  final double distanceKm;
  final int calories;

  const _HistorySummary({
    required this.workouts,
    required this.distanceKm,
    required this.calories,
  });

  factory _HistorySummary.fromWorkouts(List<WorkoutSession> workouts) {
    return _HistorySummary(
      workouts: workouts.length,
      distanceKm: workouts.fold(0.0, (sum, item) => sum + item.distanceKm),
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
