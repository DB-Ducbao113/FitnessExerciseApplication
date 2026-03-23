import 'package:fitness_exercise_application/features/history/presentation/widgets/daily_workout_list.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

final selectedDateProvider = StateProvider<DateTime>(
  (ref) => DateTimeHelper.localDateOnly(DateTime.now()),
);

const _kBgTop = Color(0xff0a0e1a);
const _kBgBottom = Color(0xff0d1b2a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);
const _kNeonBlue = Color(0xff00bfff);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTimeHelper.localDateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(workoutListProvider);
    final selectedDate = ref.watch(selectedDateProvider);

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
              final grouped = _groupWorkoutsByDate(workouts);
              final selectedWorkouts = _workoutsForDate(selectedDate, workouts)
                ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
              final summary = _DaySummary.fromWorkouts(selectedWorkouts);

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
                    _HistoryHeader(
                      selectedDate: selectedDate,
                      onTodayTap: () {
                        final today = DateTimeHelper.localDateOnly(
                          DateTime.now(),
                        );
                        ref.read(selectedDateProvider.notifier).state = today;
                        setState(() => _focusedDay = today);
                      },
                    ),
                    const SizedBox(height: 20),
                    _GlassCard(
                      child: TableCalendar<WorkoutSession>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2035, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(selectedDate, day),
                        onDaySelected: (selected, focused) {
                          final normalized = DateTimeHelper.localDateOnly(
                            selected,
                          );
                          ref.read(selectedDateProvider.notifier).state =
                              normalized;
                          setState(() => _focusedDay = focused);
                        },
                        eventLoader: (day) {
                          final key = DateTimeHelper.localDateOnly(day);
                          return grouped[key] ?? [];
                        },
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        calendarFormat: CalendarFormat.month,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          leftChevronIcon: Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                          ),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: _kMutedText,
                            fontWeight: FontWeight.w700,
                          ),
                          weekendStyle: TextStyle(
                            color: _kMutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideTextStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          defaultTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          weekendTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          todayDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kNeonBlue.withValues(alpha: 0.24),
                            border: Border.all(
                              color: _kNeonBlue.withValues(alpha: 0.50),
                            ),
                          ),
                          selectedDecoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_kNeonBlue, _kNeonCyan],
                            ),
                          ),
                          markerDecoration: const BoxDecoration(
                            color: _kNeonCyan,
                            shape: BoxShape.circle,
                          ),
                          markersMaxCount: 3,
                          cellMargin: const EdgeInsets.all(5),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (_, _, events) {
                            if (events.isEmpty) return null;
                            return Padding(
                              padding: const EdgeInsets.only(top: 30),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: events.take(3).map((event) {
                                  final workout = event;
                                  return Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _activityColor(
                                        workout.activityType,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _activityColor(
                                            workout.activityType,
                                          ).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SelectedDaySummary(
                      selectedDate: selectedDate,
                      summary: summary,
                    ),
                    const SizedBox(height: 16),
                    DailyWorkoutList(
                      selectedDate: selectedDate,
                      workouts: selectedWorkouts,
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

  Map<DateTime, List<WorkoutSession>> _groupWorkoutsByDate(
    List<WorkoutSession> workouts,
  ) {
    final map = <DateTime, List<WorkoutSession>>{};
    for (final workout in workouts) {
      final date = DateTimeHelper.localDateOnly(workout.startedAt);
      map[date] = [...(map[date] ?? <WorkoutSession>[]), workout];
    }
    return map;
  }

  List<WorkoutSession> _workoutsForDate(
    DateTime date,
    List<WorkoutSession> workouts,
  ) {
    final target = DateTimeHelper.localDateOnly(date);
    return workouts.where((workout) {
      return DateTimeHelper.localDateOnly(workout.startedAt) == target;
    }).toList();
  }
}

class _HistoryHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTodayTap;

  const _HistoryHeader({required this.selectedDate, required this.onTodayTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HISTORY',
                style: TextStyle(
                  color: _kMutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Replay your training',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatHeaderDate(selectedDate),
                style: const TextStyle(
                  color: _kMutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onTodayTap,
          style: TextButton.styleFrom(
            foregroundColor: _kNeonCyan,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: _kCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _kCardBorder),
            ),
          ),
          icon: const Icon(Icons.today_rounded, size: 18),
          label: const Text(
            'Today',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  final DateTime selectedDate;
  final _DaySummary summary;

  const _SelectedDaySummary({
    required this.selectedDate,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayTitle(selectedDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary.workouts == 0
                ? 'No workouts logged for this day.'
                : '${summary.workouts} workouts - ${summary.distanceKm.toStringAsFixed(1)} km - ${summary.calories} kcal',
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (summary.workouts > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryChip(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: '${(summary.durationSec / 60).round()} min',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryChip(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Calories',
                    value: '${summary.calories}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryChip(
                    icon: Icons.directions_walk_rounded,
                    label: 'Steps',
                    value: '${summary.steps}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff101a29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kNeonCyan, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _kMutedText,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
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

class _DaySummary {
  final int workouts;
  final double distanceKm;
  final int durationSec;
  final int calories;
  final int steps;

  const _DaySummary({
    required this.workouts,
    required this.distanceKm,
    required this.durationSec,
    required this.calories,
    required this.steps,
  });

  factory _DaySummary.fromWorkouts(List<WorkoutSession> workouts) {
    return _DaySummary(
      workouts: workouts.length,
      distanceKm: workouts.fold(0.0, (sum, item) => sum + item.distanceKm),
      durationSec: workouts.fold(0, (sum, item) => sum + item.durationSec),
      calories: workouts.fold(
        0,
        (sum, item) => sum + item.caloriesKcal.round(),
      ),
      steps: workouts.fold(0, (sum, item) => sum + item.steps),
    );
  }
}

String _formatHeaderDate(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _dayTitle(DateTime date) {
  final today = DateTimeHelper.localDateOnly(DateTime.now());
  final normalized = DateTimeHelper.localDateOnly(date);
  if (normalized == today) return 'Today';
  if (normalized == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return _formatHeaderDate(normalized);
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
      return _kNeonCyan;
  }
}
