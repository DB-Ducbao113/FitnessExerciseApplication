import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/core/constants/db_tables.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';

// Remote helpers
final _supabase = Supabase.instance.client;

Future<UserGoal?> _fetchGoal(String userId) async {
  final row = await _supabase
      .from(DbTables.userGoals)
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  if (row == null) return null;
  return UserGoal.fromMap(row);
}

Future<void> _upsertGoal(UserGoal goal) async {
  final data = <String, dynamic>{...goal.toMap()};
  // Only send id for updates.
  if (goal.id.isNotEmpty) {
    data['id'] = goal.id;
  }
  await _supabase.from(DbTables.userGoals).upsert(data, onConflict: 'user_id');
}

// Goal state
final userGoalProvider =
    StateNotifierProvider<UserGoalNotifier, AsyncValue<UserGoal?>>(
      (ref) => UserGoalNotifier(),
    );

class UserGoalNotifier extends StateNotifier<AsyncValue<UserGoal?>> {
  UserGoalNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      state = AsyncValue.data(await _fetchGoal(userId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  /// Save or update the goal.
  Future<void> saveGoal(UserGoal goal) async {
    try {
      await _upsertGoal(goal);
      state = AsyncValue.data(goal);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteGoal() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from(DbTables.userGoals).delete().eq('user_id', userId);
    state = const AsyncValue.data(null);
  }
}

// Goal progress
class GoalProgress {
  final double current;
  final double target;
  final String unit;

  const GoalProgress({
    required this.current,
    required this.target,
    required this.unit,
  });

  double get ratio => target > 0 ? (current / target).clamp(0.0, 1.0) : 0;
  int get percent => (ratio * 100).round();
  bool get isAchieved => current >= target;

  String get currentLabel {
    if (unit == 'km') return current.toStringAsFixed(1);
    return current.toInt().toString();
  }

  String get targetLabel {
    if (unit == 'km') return target.toStringAsFixed(0);
    return target.toInt().toString();
  }
}

/// Computes goal progress from cached workouts.
final goalProgressProvider = Provider<GoalProgress?>((ref) {
  final goalAsync = ref.watch(userGoalProvider);
  final workoutsAsync = ref.watch(workoutListProvider);

  final goal = goalAsync.valueOrNull;
  final workouts = workoutsAsync.valueOrNull;

  if (goal == null || workouts == null) return null;

  // Period start
  final now = DateTimeHelper.localDateOnly(DateTime.now());
  final periodStart = goal.period == GoalPeriod.weekly
      ? now.subtract(Duration(days: now.weekday - 1))
      : DateTime(now.year, now.month, 1);

  final relevant = workouts
      .where(
        (w) => !DateTimeHelper.localDateOnly(w.startedAt).isBefore(periodStart),
      )
      .toList();

  double current;
  switch (goal.goalType) {
    case GoalType.distance:
      current = relevant.fold(0.0, (s, w) => s + w.distanceKm);
      break;
    case GoalType.workouts:
      current = relevant.length.toDouble();
      break;
    case GoalType.calories:
      current = relevant.fold(0.0, (s, w) => s + w.caloriesKcal);
      break;
  }

  return GoalProgress(
    current: current,
    target: goal.targetValue,
    unit: goal.unit,
  );
});
