import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fitness_exercise_application/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/presentation/screens/stats/widgets/stat_card.dart';
import 'package:fitness_exercise_application/presentation/screens/stats/widgets/time_period_selector.dart';
import 'package:fitness_exercise_application/presentation/screens/stats/widgets/activity_breakdown.dart';
import 'package:fitness_exercise_application/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/core/utils/workout_formatters.dart';

// State provider for selected time period
final selectedPeriodProvider = StateProvider<TimePeriod>(
  (ref) => TimePeriod.week,
);

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutListProvider);
    final selectedPeriod = ref.watch(selectedPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: const Color(0xff18b0e8),
        foregroundColor: Colors.white,
      ),
      body: workoutsAsync.when(
        data: (workouts) {
          if (workouts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No workout data yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start tracking workouts to see statistics',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Filter workouts by selected period
          final filteredWorkouts = _filterWorkoutsByPeriod(
            workouts,
            selectedPeriod,
          );

          // Calculate statistics
          final totalWorkouts = filteredWorkouts.length;
          final totalDistance = filteredWorkouts.fold<double>(
            0,
            (sum, w) => sum + w.distanceKm,
          );
          // Sum in seconds for precision: durationMin * 60 avoids accumulating
          // float rounding errors from fractional minutes.
          final totalDurationSec = filteredWorkouts.fold<int>(
            0,
            (sum, w) => sum + w.durationSec,
          );
          final totalCalories = filteredWorkouts.fold<int>(
            0,
            (sum, w) => sum + w.caloriesKcal.round(),
          );
          final totalSteps = filteredWorkouts.fold<int>(
            0,
            (sum, w) => sum + w.steps,
          );
          // Overall avg speed: totalDistance / totalTime (weight-correct formula).
          // This is more accurate than averaging per-session speeds.
          final overallAvgSpeedKmh = totalDurationSec > 0
              ? totalDistance / (totalDurationSec / 3600.0)
              : 0.0;

          // Activity breakdown
          final activityCounts = <String, int>{};
          for (final workout in filteredWorkouts) {
            final activity = workout.activityType;
            activityCounts[activity] = (activityCounts[activity] ?? 0) + 1;
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(workoutListProvider.notifier).refresh();
            },
            child: ListView(
              children: [
                // Time Period Selector
                TimePeriodSelector(
                  selectedPeriod: selectedPeriod,
                  onPeriodChanged: (period) {
                    ref.read(selectedPeriodProvider.notifier).state = period;
                  },
                ),

                // Summary Statistics
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.fitness_center,
                          label: 'Workouts',
                          value: '$totalWorkouts',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          icon: Icons.straighten,
                          label: 'Distance',
                          value: '${totalDistance.toStringAsFixed(1)} km',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.timer,
                          label: 'Duration',
                          value: WorkoutFormatters.formatDurationFromSeconds(
                            totalDurationSec,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          icon: Icons.local_fire_department,
                          label: 'Calories',
                          value: WorkoutFormatters.formatCalories(
                            totalCalories,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Row 3: Overall avg speed + Steps
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.speed,
                          label: 'Avg Speed',
                          value:
                              '${overallAvgSpeedKmh.toStringAsFixed(1)} km/h',
                          color: const Color(0xff4ECDC4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          icon: Icons.directions_walk,
                          label: 'Steps',
                          value: totalSteps > 999
                              ? '${(totalSteps / 1000).toStringAsFixed(1)}k'
                              : '$totalSteps',
                          color: const Color(0xff9B59B6),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Workout Chart
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Workout Trend',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: _WorkoutChart(
                            workouts: filteredWorkouts,
                            period: selectedPeriod,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Activity Breakdown
                ActivityBreakdown(activityCounts: activityCounts),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading stats: $error')),
      ),
    );
  }

  List<WorkoutSession> _filterWorkoutsByPeriod(
    List<WorkoutSession> workouts,
    TimePeriod period,
  ) {
    final now = DateTime.now();
    DateTime cutoffDate;

    switch (period) {
      case TimePeriod.week:
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case TimePeriod.month:
        cutoffDate = now.subtract(const Duration(days: 30));
        break;
      case TimePeriod.year:
        cutoffDate = now.subtract(const Duration(days: 365));
        break;
    }

    return workouts.where((w) => w.startedAt.isAfter(cutoffDate)).toList();
  }
}

class _WorkoutChart extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final TimePeriod period;

  const _WorkoutChart({required this.workouts, required this.period});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return Center(
        child: Text(
          'No data for this period',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final chartData = _prepareChartData();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartData.values.reduce((a, b) => a > b ? a : b) + 2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final labels = chartData.keys.toList();
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: chartData.entries.map((entry) {
          final index = chartData.keys.toList().indexOf(entry.key);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                color: const Color(0xff18b0e8),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Map<String, int> _prepareChartData() {
    final data = <String, int>{};

    switch (period) {
      case TimePeriod.week:
        // Last 7 days
        for (int i = 6; i >= 0; i--) {
          final date = DateTime.now().subtract(Duration(days: i));
          final label = [
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ][date.weekday - 1];
          data[label] = 0;
        }
        for (final workout in workouts) {
          final label = [
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ][workout.startedAt.weekday - 1];
          data[label] = (data[label] ?? 0) + 1;
        }
        break;

      case TimePeriod.month:
        // Last 4 weeks
        for (int i = 3; i >= 0; i--) {
          data['W${4 - i}'] = 0;
        }
        for (final workout in workouts) {
          final weeksAgo =
              DateTime.now().difference(workout.startedAt).inDays ~/ 7;
          if (weeksAgo < 4) {
            final label = 'W${4 - weeksAgo}';
            data[label] = (data[label] ?? 0) + 1;
          }
        }
        break;

      case TimePeriod.year:
        // Last 12 months
        final months = [
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
        for (int i = 11; i >= 0; i--) {
          final date = DateTime.now().subtract(Duration(days: i * 30));
          data[months[date.month - 1]] = 0;
        }
        for (final workout in workouts) {
          final label = months[workout.startedAt.month - 1];
          data[label] = (data[label] ?? 0) + 1;
        }
        break;
    }

    return data;
  }
}
