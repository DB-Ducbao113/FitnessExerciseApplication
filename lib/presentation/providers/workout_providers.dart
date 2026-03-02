import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_exercise_application/domain/entities/workout.dart';
import 'package:fitness_exercise_application/presentation/providers/providers.dart';
import 'package:fitness_exercise_application/presentation/providers/user_profile_providers.dart';

part 'workout_providers.g.dart';

/// Workout List Provider
@riverpod
class WorkoutList extends _$WorkoutList {
  @override
  Future<List<Workout>> build() async {
    final repository = ref.watch(workoutRepositoryProvider);
    return await repository.getWorkouts();
  }

  /// Refresh workout list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(workoutRepositoryProvider);
      return await repository.getWorkouts();
    });
  }

  /// Start a new workout
  Future<String?> startWorkout(String activityType) async {
    try {
      final repository = ref.read(workoutRepositoryProvider);
      final workoutId = await repository.startWorkout(activityType);

      // Refresh list
      ref.invalidateSelf();

      return workoutId.toString();
    } catch (e) {
      return null;
    }
  }

  /// End a workout
  Future<bool> endWorkout(String workoutId) async {
    try {
      final repository = ref.read(workoutRepositoryProvider);
      final intId = int.tryParse(workoutId);
      if (intId != null) {
        await repository.endWorkout(intId);
        ref.invalidateSelf();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Delete a workout
  Future<void> deleteWorkout(String workoutId) async {
    final repository = ref.read(workoutRepositoryProvider);
    await repository.deleteWorkout(workoutId);
    ref.invalidateSelf();
  }

  /// Finish a workout with metrics
  Future<void> finishWorkout({
    required String workoutId,
    required String activityType,
    required int durationSeconds,
    double? distance,
    int? calories,
  }) async {
    // Get user profile for calorie calc if not provided
    int finalCalories = calories ?? 0;

    if (calories == null) {
      final user = ref.read(currentUserIdProvider);
      if (user == null) throw Exception('No user logged in');

      final profile = await ref.read(userProfileProvider(user).future);
      if (profile == null) throw Exception('No user profile found');

      // Calculate metrics
      final durationMin = durationSeconds / 60.0;
      final calculatedCalories = profile.calculateCalories(
        activityType: activityType,
        durationMinutes: durationMin,
      );
      finalCalories = calculatedCalories.round();
    }

    final durationMin = durationSeconds / 60.0;
    double? speed;
    if (distance != null && durationMin > 0) {
      speed = distance / (durationMin / 60.0); // km/h
    }

    // Update repository
    final repository = ref.read(workoutRepositoryProvider);
    final intId = int.tryParse(workoutId);
    if (intId != null) {
      await repository.endWorkout(
        intId,
        distance: distance,
        durationMinutes: durationMin,
        speed: speed,
        calories: finalCalories,
      );
    }

    ref.invalidateSelf();
  }

  /// Quick Add Workout
  Future<void> quickAddWorkout({
    required String activityType,
    required double durationMinutes,
  }) async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) throw Exception('No user logged in');

    final profile = await ref.read(userProfileProvider(user).future);
    if (profile == null) throw Exception('No user profile found');

    final calories = profile.calculateCalories(
      activityType: activityType,
      durationMinutes: durationMinutes,
    );

    final repository = ref.read(workoutRepositoryProvider);
    final workoutId = await repository.startWorkout(activityType);

    await repository.endWorkout(
      workoutId,
      distance: null,
      durationMinutes: durationMinutes,
      calories: calories.round(),
    );

    ref.invalidateSelf();
  }
}

/// Active Workout Provider
@riverpod
class ActiveWorkout extends _$ActiveWorkout {
  @override
  String? build() {
    return null;
  }

  void setActive(String workoutId) {
    state = workoutId;
  }

  void clearActive() {
    state = null;
  }
}

/// Single Workout Provider
@riverpod
Future<Workout?> workout(WorkoutRef ref, String id) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getWorkout(id);
}

// --- Timer Logic ---

class TimerState {
  final int seconds;
  final bool isRunning;

  TimerState({required this.seconds, required this.isRunning});

  TimerState copyWith({int? seconds, bool? isRunning}) {
    return TimerState(
      seconds: seconds ?? this.seconds,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _timer;

  TimerNotifier() : super(TimerState(seconds: 0, isRunning: true)) {
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(seconds: state.seconds + 1);
    });
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  void resume() {
    state = state.copyWith(isRunning: true);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final timerProvider =
    StateNotifierProvider.autoDispose<TimerNotifier, TimerState>((ref) {
      return TimerNotifier();
    });
