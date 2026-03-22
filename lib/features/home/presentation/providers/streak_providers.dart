import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreakData {
  final int currentStreak;
  final int longestStreak;

  const StreakData({required this.currentStreak, required this.longestStreak});
}

final streakProvider = Provider<StreakData>((ref) {
  final workouts = ref.watch(workoutListProvider).valueOrNull ?? [];
  if (workouts.isEmpty) {
    return const StreakData(currentStreak: 0, longestStreak: 0);
  }

  final workoutDays =
      workouts
          .map((w) => DateTimeHelper.localDateOnly(w.startedAt))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

  final today = DateTimeHelper.localDateOnly(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  int current = 0;
  if (workoutDays.isNotEmpty &&
      (workoutDays.first == today || workoutDays.first == yesterday)) {
    var check = workoutDays.first;
    for (final day in workoutDays) {
      if (day == check) {
        current++;
        check = check.subtract(const Duration(days: 1));
      } else if (day.isBefore(check)) {
        break;
      }
    }
  }

  int longest = 0;
  int temp = 1;
  final sorted = workoutDays.toList()..sort();
  for (var i = 1; i < sorted.length; i++) {
    final diff = sorted[i].difference(sorted[i - 1]).inDays;
    if (diff == 1) {
      temp++;
      if (temp > longest) longest = temp;
    } else if (diff > 1) {
      temp = 1;
    }
  }
  if (sorted.isNotEmpty && longest == 0) longest = 1;

  return StreakData(currentStreak: current, longestStreak: longest);
});
