import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

part 'workout_providers.g.dart';

/// Workout List Provider
@riverpod
class WorkoutList extends _$WorkoutList {
  @override
  Future<List<WorkoutSession>> build() async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) throw Exception('No user logged in');

    final repository = ref.watch(workoutRepositoryProvider);
    // 1. Pull down any remote changes (syncId collision fixes, cross-device sync)
    // We let the bootstrap handle immediate fetch, or we can keep syncFromCloud here.
    await repository.syncFromCloud();
    // 2. Load from local DB
    return await repository.getSessionsLocal(user);
  }

  /// Refresh workout list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(currentUserIdProvider);
      if (user == null) throw Exception('No user logged in');

      final repository = ref.read(workoutRepositoryProvider);
      await repository.syncFromCloud();
      return await repository.getSessionsLocal(user);
    });
  }

  /// Delete a workout
  Future<void> deleteWorkout(String workoutId) async {
    final repository = ref.read(workoutRepositoryProvider);
    await repository.deleteSession(workoutId);
    ref.invalidateSelf();
  }

  /// Delete all workouts
  Future<void> deleteAllWorkouts() async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) return;

    final repository = ref.read(workoutRepositoryProvider);
    await repository.deleteAllSessions(user);
    ref.invalidateSelf();
  }

  /// Save a completed workout session verbatim
  Future<void> saveSession(WorkoutSession session) async {
    final repository = ref.read(workoutRepositoryProvider);
    try {
      if (await InternetConnectionChecker().hasConnection) {
        await repository.saveSessionRemote(session);
      }
    } catch (_) {
      // Offline fallback
    }
    await repository.cacheSessionLocal(session);
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

    // Quick Add -> Generate UUID -> Save immediately
    final session = WorkoutSession(
      id: const Uuid().v4(),
      userId: user,
      activityType: activityType,
      startedAt: DateTime.now().subtract(
        Duration(minutes: durationMinutes.round()),
      ),
      endedAt: DateTime.now(),
      durationSec: (durationMinutes * 60).round(),
      distanceKm: 0.0,
      steps: 0,
      avgSpeedKmh: 0.0,
      caloriesKcal: calories,
      mode: 'indoor', // Default for quick add
      createdAt: DateTime.now(),
    );

    await saveSession(session);
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
Future<WorkoutSession?> workout(WorkoutRef ref, String id) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getSessionById(id);
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

class TodayStats {
  final double distanceKm;
  final int durationSec;
  final int caloriesKcal;
  final int steps;
  final int workoutCount;

  const TodayStats({
    required this.distanceKm,
    required this.durationSec,
    required this.caloriesKcal,
    required this.steps,
    required this.workoutCount,
  });

  static const empty = TodayStats(
    distanceKm: 0,
    durationSec: 0,
    caloriesKcal: 0,
    steps: 0,
    workoutCount: 0,
  );
}

final todayStatsProvider = Provider<TodayStats>((ref) {
  final workouts = ref.watch(workoutListProvider).valueOrNull ?? [];
  final today = DateTimeHelper.localDateOnly(DateTime.now());

  final todayWorkouts = workouts
      .where((w) => DateTimeHelper.localDateOnly(w.startedAt) == today)
      .toList();

  if (todayWorkouts.isEmpty) return TodayStats.empty;

  return TodayStats(
    distanceKm: todayWorkouts.fold(0.0, (s, w) => s + w.distanceKm),
    durationSec: todayWorkouts.fold(0, (s, w) => s + w.durationSec),
    caloriesKcal: todayWorkouts.fold(0, (s, w) => s + w.caloriesKcal.round()),
    steps: todayWorkouts.fold(0, (s, w) => s + w.steps),
    workoutCount: todayWorkouts.length,
  );
});
