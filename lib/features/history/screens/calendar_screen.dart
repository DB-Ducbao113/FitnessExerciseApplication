import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fitness_exercise_application/models/workout_session.dart';
import 'package:fitness_exercise_application/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/history/screens/widgets/daily_workout_list.dart';
import 'package:fitness_exercise_application/utils/date_time_helper.dart';

// State provider for selected date
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(workoutListProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: const Color(0xff18b0e8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              final today = DateTime.now();
              ref.read(selectedDateProvider.notifier).state = today;
              setState(() {
                _focusedDay = today;
              });
            },
            tooltip: 'Today',
          ),
        ],
      ),
      body: workoutsAsync.when(
        data: (workouts) {
          // Group workouts by date
          final workoutsByDate = _groupWorkoutsByDate(workouts);

          // Get workouts for selected date
          final selectedWorkouts = _getWorkoutsForDate(selectedDate, workouts);

          return Column(
            children: [
              // Calendar
              Card(
                margin: const EdgeInsets.all(16),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                  onDaySelected: (selected, focused) {
                    ref.read(selectedDateProvider.notifier).state = selected;
                    setState(() {
                      _focusedDay = focused;
                    });
                  },
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: const Color(0xff18b0e8).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Color(0xff18b0e8),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Color(0xffFF6B6B),
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                  ),
                  eventLoader: (day) {
                    final dateKey = DateTime(day.year, day.month, day.day);
                    return workoutsByDate[dateKey] ?? [];
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return null;

                      final workoutsForDay = events.cast<WorkoutSession>();
                      final colors = workoutsForDay
                          .take(3)
                          .map((w) => _getActivityColor(w.activityType))
                          .toList();

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: colors.map((color) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),

              // Daily Workout List
              Expanded(
                child: SingleChildScrollView(
                  child: DailyWorkoutList(
                    selectedDate: selectedDate,
                    workouts: selectedWorkouts,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading calendar: $error')),
      ),
    );
  }

  Map<DateTime, List<WorkoutSession>> _groupWorkoutsByDate(
    List<WorkoutSession> workouts,
  ) {
    final map = <DateTime, List<WorkoutSession>>{};
    for (final workout in workouts) {
      final date = DateTimeHelper.localDateOnly(workout.startedAt);
      map[date] = [...(map[date] ?? []), workout];
    }
    return map;
  }

  List<WorkoutSession> _getWorkoutsForDate(
    DateTime date,
    List<WorkoutSession> allWorkouts,
  ) {
    final targetDate = DateTimeHelper.localDateOnly(date);
    return allWorkouts.where((w) {
      final workoutDate = DateTimeHelper.localDateOnly(w.startedAt);
      return workoutDate == targetDate;
    }).toList();
  }

  Color _getActivityColor(String activity) {
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
        return const Color(0xff18b0e8);
    }
  }
}
