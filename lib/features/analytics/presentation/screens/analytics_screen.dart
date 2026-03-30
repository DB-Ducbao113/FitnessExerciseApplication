import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedPeriodProvider = StateProvider<TimePeriod>(
  (ref) => TimePeriod.week,
);

const _kBg = Color(0xFF0B111D);
const _kBgSoft = Color(0xFF121A27);
const _kCard = Color(0xFF242C3A);
const _kCardSoft = Color(0xFF1A212D);
const _kTrack = Color(0xFF343B48);
const _kMutedText = Color(0xFFB7C0CC);
const _kMutedSoft = Color(0xFF7D8DA6);
const _kNeonCyan = Color(0xFF21D9F8);
const _kAmber = Color(0xFFFFB85C);
const _kRed = Color(0xFFE02431);
const _kSlate = Color(0xFF6F7F8F);

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutListProvider);
    final period = ref.watch(selectedPeriodProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: workoutsAsync.when(
          data: (workouts) {
            final filtered = _filterWorkouts(workouts, period);
            final summary = _AnalyticsSummary.fromWorkouts(filtered);
            final records = _PersonalRecords.fromWorkouts(workouts);
            final chart = _chartData(filtered, period);
            final breakdown = _activityBreakdown(filtered);
            final average = chart.isEmpty
                ? 0.0
                : chart.values.fold<double>(0, (sum, v) => sum + v) /
                      chart.length;

            return RefreshIndicator(
              color: _kNeonCyan,
              backgroundColor: _kCardSoft,
              onRefresh: () async {
                await ref.read(workoutListProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                children: [
                  const _AnalyticsTopBar(),
                  const SizedBox(height: 24),
                  _PeriodSwitcher(
                    selectedPeriod: period,
                    onChanged: (value) {
                      ref.read(selectedPeriodProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(height: 22),
                  _OverviewGrid(summary: summary),
                  const SizedBox(height: 26),
                  _GoalProgressSection(
                    progress: ref.watch(goalProgressProvider),
                  ),
                  const SizedBox(height: 26),
                  _WeekTrendCard(
                    chartData: chart,
                    period: period,
                    average: average,
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'PERSONAL RECORDS'),
                  const SizedBox(height: 14),
                  _RecordsList(records: records),
                  const SizedBox(height: 24),
                  _ActivityDistributionCard(
                    breakdown: breakdown,
                    total: filtered.length,
                  ),
                ],
              ),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _kNeonCyan)),
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
    );
  }
}

class _AnalyticsTopBar extends ConsumerWidget {
  const _AnalyticsTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref
        .watch(currentUserProfileProvider)
        .valueOrNull
        ?.avatarUrl;

    return Row(
      children: [
        const Text(
          'ANALYTICS',
          style: TextStyle(
            color: _kNeonCyan,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const Spacer(),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF3A414D),
            borderRadius: BorderRadius.circular(999),
            image: avatarUrl != null && avatarUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFFD7E9F2),
                  size: 22,
                )
              : null,
        ),
      ],
    );
  }
}

class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _kBgSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final period in TimePeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: selectedPeriod == period
                        ? _kNeonCyan
                        : Colors.transparent,
                    boxShadow: selectedPeriod == period
                        ? [
                            BoxShadow(
                              color: _kNeonCyan.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _periodLabel(period),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selectedPeriod == period ? _kBg : _kMutedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.summary});

  final _AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _OverviewItem(
        icon: Icons.fitness_center_rounded,
        label: 'WORKOUTS',
        value: '${summary.totalWorkouts}',
        suffix: '',
        color: _kNeonCyan,
      ),
      _OverviewItem(
        icon: Icons.route_rounded,
        label: 'DISTANCE',
        value: summary.totalDistanceKm.toStringAsFixed(1),
        suffix: ' km',
        color: _kAmber,
      ),
      _OverviewItem(
        icon: Icons.timer_rounded,
        label: 'ACTIVE TIME',
        value: _minutesLabel(summary.totalDurationSec),
        suffix: ' min',
        color: _kNeonCyan,
      ),
      _OverviewItem(
        icon: Icons.local_fire_department_rounded,
        label: 'CALORIES',
        value: '${summary.totalCalories}',
        suffix: ' kcal',
        color: _kRed,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (_, index) => _StatOverviewCard(item: cards[index]),
    );
  }
}

class _StatOverviewCard extends StatelessWidget {
  const _StatOverviewCard({required this.item});

  final _OverviewItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, color: item.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: _kMutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE8EDF5),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                    height: 0.95,
                  ),
                ),
              ),
              if (item.suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    item.suffix.trim(),
                    style: const TextStyle(
                      color: _kMutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _GoalProgressSection extends StatelessWidget {
  const _GoalProgressSection({required this.progress});

  final GoalProgress? progress;

  @override
  Widget build(BuildContext context) {
    if (progress == null) {
      return const _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'GOAL PROGRESS'),
            SizedBox(height: 8),
            Text(
              'Set a goal to see your progress here.',
              style: TextStyle(
                color: _kMutedSoft,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final goal = progress!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'GOAL PROGRESS'),
        const SizedBox(height: 2),
        Text(
          goal.unit == 'km' ? 'MONTHLY DISTANCE' : 'CURRENT GOAL',
          style: const TextStyle(
            color: _kMutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${goal.percent}%',
            style: const TextStyle(
              color: _kNeonCyan,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: goal.ratio,
            minHeight: 15,
            backgroundColor: _kTrack,
            valueColor: const AlwaysStoppedAnimation<Color>(_kNeonCyan),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '${goal.currentLabel} ${goal.unit}'.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${goal.targetLabel} ${goal.unit} TARGET'.toUpperCase(),
              style: const TextStyle(
                color: _kMutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeekTrendCard extends StatelessWidget {
  const _WeekTrendCard({
    required this.chartData,
    required this.period,
    required this.average,
  });

  final Map<String, double> chartData;
  final TimePeriod period;
  final double average;

  @override
  Widget build(BuildContext context) {
    final labels = chartData.keys.toList();
    final values = chartData.values.toList();
    final maxY = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b) + 1;
    final selectedIndex = values.isEmpty
        ? -1
        : values.indexOf(values.reduce((a, b) => a >= b ? a : b));

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_periodLabel(period).toUpperCase()} TREND',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF133444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avg: ${average.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: _kNeonCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 210,
            child: values.every((value) => value == 0)
                ? const Center(
                    child: Text(
                      'No activity in this period',
                      style: TextStyle(color: _kMutedSoft),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(enabled: false),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              final selected = index == selectedIndex;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  labels[index],
                                  style: TextStyle(
                                    color: selected ? _kNeonCyan : _kMutedText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < values.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: values[i],
                                width: 36,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                                gradient: i == selectedIndex
                                    ? LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          _kNeonCyan.withValues(alpha: 0.55),
                                          _kNeonCyan,
                                        ],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          const Color(
                                            0xFF173140,
                                          ).withValues(alpha: 0.55),
                                          const Color(
                                            0xFF1F7D90,
                                          ).withValues(alpha: 0.85),
                                        ],
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

class _RecordsList extends StatelessWidget {
  const _RecordsList({required this.records});

  final _PersonalRecords records;

  @override
  Widget build(BuildContext context) {
    final items = [
      _RecordItem(
        label: 'LONGEST DISTANCE',
        title: 'Marathon Run',
        value: '${records.longestDistance.toStringAsFixed(1)} km',
        date: 'Best record',
        icon: Icons.emoji_events_rounded,
        color: _kAmber,
      ),
      _RecordItem(
        label: 'LONGEST DURATION',
        title: 'Endurance Session',
        value: WorkoutFormatters.formatDurationFromSeconds(
          records.longestDurationSec,
        ),
        date: 'Best record',
        icon: Icons.timer_rounded,
        color: _kNeonCyan,
      ),
      _RecordItem(
        label: 'MOST CALORIES',
        title: 'High Burn Session',
        value: '${records.highestCalories} kcal',
        date: records.topActivity,
        icon: Icons.local_fire_department_rounded,
        color: _kRed,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _RecordCard(item: items[i]),
          if (i != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.item});

  final _RecordItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: _kMutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.value,
                style: TextStyle(
                  color: item.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.date,
                style: const TextStyle(
                  color: _kMutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityDistributionCard extends StatelessWidget {
  const _ActivityDistributionCard({
    required this.breakdown,
    required this.total,
  });

  final Map<String, int> breakdown;
  final int total;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'ACTIVITY DISTRIBUTION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (breakdown.isEmpty)
            const Text(
              'No activity data in this period.',
              style: TextStyle(color: _kMutedSoft),
            )
          else
            ...breakdown.entries.map((entry) {
              final ratio = total == 0 ? 0.0 : entry.value / total;
              final percent = (ratio * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: _activityColor(entry.key),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: _kTrack,
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

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE8EDF5),
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _OverviewItem {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final Color color;

  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });
}

class _RecordItem {
  final String label;
  final String title;
  final String value;
  final String date;
  final IconData icon;
  final Color color;

  const _RecordItem({
    required this.label,
    required this.title,
    required this.value,
    required this.date,
    required this.icon,
    required this.color,
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

String _minutesLabel(int seconds) {
  final minutes = (seconds / 60).floor();
  return '$minutes';
}

Color _activityColor(String activity) {
  switch (activity.toLowerCase()) {
    case 'running':
      return _kNeonCyan;
    case 'cycling':
      return _kAmber;
    case 'walking':
      return Colors.white;
    default:
      return _kSlate;
  }
}
