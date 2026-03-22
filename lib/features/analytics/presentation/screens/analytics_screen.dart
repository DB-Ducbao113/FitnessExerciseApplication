import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedPeriodProvider = StateProvider<TimePeriod>(
  (ref) => TimePeriod.week,
);

const _kBgTop = Color(0xff0a0e1a);
const _kBgBottom = Color(0xff0d1b2a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);
const _kNeonBlue = Color(0xff00bfff);
const _kNeonPurple = Color(0xff6a5cff);

enum TimePeriod { week, month, year }

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutListProvider);
    final period = ref.watch(selectedPeriodProvider);

    return Scaffold(
      backgroundColor: _kBgTop,
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
              final filtered = _filterWorkouts(workouts, period);
              final summary = _AnalyticsSummary.fromWorkouts(filtered);
              final records = _PersonalRecords.fromWorkouts(workouts);
              final chart = _chartData(filtered, period);
              final breakdown = _activityBreakdown(filtered);

              return RefreshIndicator(
                color: _kNeonCyan,
                backgroundColor: _kCardBg,
                onRefresh: () async {
                  await ref.read(workoutListProvider.notifier).refresh();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    const _AnalyticsHeader(),
                    const SizedBox(height: 18),
                    _PeriodSelector(
                      selectedPeriod: period,
                      onChanged: (value) {
                        ref.read(selectedPeriodProvider.notifier).state = value;
                      },
                    ),
                    const SizedBox(height: 18),
                    _OverviewGrid(summary: summary),
                    const SizedBox(height: 16),
                    _GoalBanner(progress: ref.watch(goalProgressProvider)),
                    const SizedBox(height: 16),
                    _TrendCard(chartData: chart, period: period),
                    const SizedBox(height: 16),
                    _RecordsCard(records: records),
                    const SizedBox(height: 16),
                    _BreakdownCard(
                      breakdown: breakdown,
                      total: filtered.length,
                    ),
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
                  'Could not load analytics.\n$error',
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

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANALYTICS',
          style: TextStyle(
            color: _kMutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Progress',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Trends and records.',
          style: TextStyle(
            color: _kMutedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onChanged;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          for (final period in TimePeriod.values) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: selectedPeriod == period
                        ? const LinearGradient(colors: [_kNeonBlue, _kNeonCyan])
                        : null,
                    color: selectedPeriod == period
                        ? null
                        : Colors.white.withValues(alpha: 0.03),
                  ),
                  child: Text(
                    _periodLabel(period),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selectedPeriod == period ? _kBgTop : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            if (period != TimePeriod.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final _AnalyticsSummary summary;

  const _OverviewGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _OverviewItem(
        icon: Icons.fitness_center_rounded,
        label: 'Workouts',
        value: '${summary.totalWorkouts}',
      ),
      _OverviewItem(
        icon: Icons.straighten_rounded,
        label: 'Distance',
        value: '${summary.totalDistanceKm.toStringAsFixed(1)} km',
      ),
      _OverviewItem(
        icon: Icons.timer_outlined,
        label: 'Active Time',
        value: WorkoutFormatters.formatDurationFromSeconds(
          summary.totalDurationSec,
        ),
      ),
      _OverviewItem(
        icon: Icons.local_fire_department_rounded,
        label: 'Calories',
        value: '${summary.totalCalories} kcal',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (_, index) => _OverviewCard(item: cards[index]),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final _OverviewItem item;

  const _OverviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xff101a29),
            ),
            child: Icon(item.icon, color: _kNeonCyan, size: 20),
          ),
          const Spacer(),
          Text(
            item.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalBanner extends StatelessWidget {
  final GoalProgress? progress;

  const _GoalBanner({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress == null) {
      return _GlassCard(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal progress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Set a goal to see your weekly progress here.',
              style: TextStyle(
                color: _kMutedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final goal = progress!;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Goal progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${goal.percent}%',
                style: const TextStyle(
                  color: _kNeonCyan,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal.ratio,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(_kNeonCyan),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${goal.currentLabel} / ${goal.targetLabel} ${goal.unit}',
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final Map<String, double> chartData;
  final TimePeriod period;

  const _TrendCard({required this.chartData, required this.period});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_periodLabel(period)} trend',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Workout count across the selected period.',
            style: TextStyle(
              color: _kMutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: chartData.values.every((value) => value == 0)
                ? const Center(
                    child: Text(
                      'No activity in this period',
                      style: TextStyle(color: _kMutedText),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          chartData.values.reduce((a, b) => a > b ? a : b) + 1,
                      barTouchData: BarTouchData(enabled: false),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) {
                          return FlLine(
                            color: Colors.white.withValues(alpha: 0.08),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, _) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: _kMutedText,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final labels = chartData.keys.toList();
                              final index = value.toInt();
                              if (index < 0 || index >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  labels[index],
                                  style: const TextStyle(
                                    color: _kMutedText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < chartData.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: chartData.values.elementAt(i),
                                width: 16,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [_kNeonBlue, _kNeonCyan],
                                ),
                              ),
                            ],
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

class _RecordsCard extends StatelessWidget {
  final _PersonalRecords records;

  const _RecordsCard({required this.records});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal records',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _RecordRow(
            label: 'Longest distance',
            value: '${records.longestDistance.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 10),
          _RecordRow(
            label: 'Longest duration',
            value: WorkoutFormatters.formatDurationFromSeconds(
              records.longestDurationSec,
            ),
          ),
          const SizedBox(height: 10),
          _RecordRow(
            label: 'Most calories',
            value: '${records.highestCalories} kcal',
          ),
          const SizedBox(height: 10),
          _RecordRow(label: 'Top activity', value: records.topActivity),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final String label;
  final String value;

  const _RecordRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff101a29),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            label,
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
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final Map<String, int> breakdown;
  final int total;

  const _BreakdownCard({required this.breakdown, required this.total});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity breakdown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (breakdown.isEmpty)
            const Text(
              'No activity data in this period.',
              style: TextStyle(color: _kMutedText),
            )
          else
            ...breakdown.entries.map((entry) {
              final ratio = total == 0 ? 0.0 : entry.value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _activityIcon(entry.key),
                          color: _activityColor(entry.key),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            color: _kMutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _activityColor(entry.key),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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

class _OverviewItem {
  final IconData icon;
  final String label;
  final String value;

  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _AnalyticsSummary {
  final int totalWorkouts;
  final double totalDistanceKm;
  final int totalDurationSec;
  final int totalCalories;
  final int totalSteps;

  const _AnalyticsSummary({
    required this.totalWorkouts,
    required this.totalDistanceKm,
    required this.totalDurationSec,
    required this.totalCalories,
    required this.totalSteps,
  });

  factory _AnalyticsSummary.fromWorkouts(List<WorkoutSession> workouts) {
    return _AnalyticsSummary(
      totalWorkouts: workouts.length,
      totalDistanceKm: workouts.fold(0.0, (sum, item) => sum + item.distanceKm),
      totalDurationSec: workouts.fold(0, (sum, item) => sum + item.durationSec),
      totalCalories: workouts.fold(
        0,
        (sum, item) => sum + item.caloriesKcal.round(),
      ),
      totalSteps: workouts.fold(0, (sum, item) => sum + item.steps),
    );
  }
}

class _PersonalRecords {
  final double longestDistance;
  final int longestDurationSec;
  final int highestCalories;
  final String topActivity;

  const _PersonalRecords({
    required this.longestDistance,
    required this.longestDurationSec,
    required this.highestCalories,
    required this.topActivity,
  });

  factory _PersonalRecords.fromWorkouts(List<WorkoutSession> workouts) {
    if (workouts.isEmpty) {
      return const _PersonalRecords(
        longestDistance: 0,
        longestDurationSec: 0,
        highestCalories: 0,
        topActivity: 'No data',
      );
    }

    final counts = <String, int>{};
    for (final workout in workouts) {
      counts.update(
        workout.activityType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return _PersonalRecords(
      longestDistance: workouts
          .map((item) => item.distanceKm)
          .reduce((a, b) => a > b ? a : b),
      longestDurationSec: workouts
          .map((item) => item.durationSec)
          .reduce((a, b) => a > b ? a : b),
      highestCalories: workouts
          .map((item) => item.caloriesKcal.round())
          .reduce((a, b) => a > b ? a : b),
      topActivity: WorkoutFormatters.formatActivityType(top),
    );
  }
}

List<WorkoutSession> _filterWorkouts(
  List<WorkoutSession> workouts,
  TimePeriod period,
) {
  final now = DateTime.now();
  switch (period) {
    case TimePeriod.week:
      final start = DateTimeHelper.localDateOnly(
        now,
      ).subtract(Duration(days: DateTimeHelper.localDateOnly(now).weekday - 1));
      return workouts.where((workout) {
        return !DateTimeHelper.localDateOnly(workout.startedAt).isBefore(start);
      }).toList();
    case TimePeriod.month:
      final start = DateTime(now.year, now.month, 1);
      return workouts.where((workout) {
        return !DateTimeHelper.localDateOnly(workout.startedAt).isBefore(start);
      }).toList();
    case TimePeriod.year:
      final start = DateTime(now.year, 1, 1);
      return workouts.where((workout) {
        return !DateTimeHelper.localDateOnly(workout.startedAt).isBefore(start);
      }).toList();
  }
}

Map<String, double> _chartData(
  List<WorkoutSession> workouts,
  TimePeriod period,
) {
  final data = <String, double>{};
  final now = DateTimeHelper.localDateOnly(DateTime.now());

  switch (period) {
    case TimePeriod.week:
      for (var i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: now.weekday - 1 - i));
        data[_weekdayLabel(day)] = 0;
      }
      for (final workout in workouts) {
        final key = _weekdayLabel(
          DateTimeHelper.localDateOnly(workout.startedAt),
        );
        if (data.containsKey(key)) data[key] = data[key]! + 1;
      }
      break;
    case TimePeriod.month:
      for (var week = 1; week <= 5; week++) {
        data['W$week'] = 0;
      }
      for (final workout in workouts) {
        final date = DateTimeHelper.localDateOnly(workout.startedAt);
        final index = ((date.day - 1) ~/ 7) + 1;
        final key = 'W${index.clamp(1, 5)}';
        data[key] = (data[key] ?? 0) + 1;
      }
      break;
    case TimePeriod.year:
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      for (var i = 0; i < 12; i++) {
        data[months[i]] = 0;
      }
      for (final workout in workouts) {
        final date = DateTimeHelper.localDateOnly(workout.startedAt);
        final key = months[date.month - 1];
        data[key] = (data[key] ?? 0) + 1;
      }
      break;
  }

  return data;
}

Map<String, int> _activityBreakdown(List<WorkoutSession> workouts) {
  final map = <String, int>{};
  for (final workout in workouts) {
    final key = WorkoutFormatters.formatActivityType(workout.activityType);
    map.update(key, (value) => value + 1, ifAbsent: () => 1);
  }
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final entry in entries) entry.key: entry.value};
}

String _periodLabel(TimePeriod period) {
  switch (period) {
    case TimePeriod.week:
      return 'Week';
    case TimePeriod.month:
      return 'Month';
    case TimePeriod.year:
      return 'Year';
  }
}

String _weekdayLabel(DateTime day) {
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return labels[day.weekday - 1];
}

Color _activityColor(String activity) {
  switch (activity.toLowerCase()) {
    case 'running':
      return const Color(0xffFF6B6B);
    case 'cycling':
      return const Color(0xff4ECDC4);
    case 'walking':
      return const Color(0xff95E1D3);
    case 'swimming':
      return const Color(0xff3498DB);
    case 'weights':
      return const Color(0xff9B59B6);
    case 'yoga':
      return const Color(0xffF39C12);
    default:
      return _kNeonPurple;
  }
}

IconData _activityIcon(String activity) {
  switch (activity.toLowerCase()) {
    case 'running':
      return Icons.directions_run;
    case 'cycling':
      return Icons.directions_bike;
    case 'walking':
      return Icons.directions_walk;
    case 'swimming':
      return Icons.pool;
    case 'weights':
      return Icons.fitness_center;
    case 'yoga':
      return Icons.self_improvement;
    default:
      return Icons.bolt_rounded;
  }
}
