import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:latlong2/latlong.dart';

part 'workout_providers.g.dart';

/// Workout List Provider
@riverpod
class WorkoutList extends _$WorkoutList {
  @override
  Future<List<WorkoutSession>> build() async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) throw Exception('No user logged in');

    final repository = ref.watch(workoutRepositoryProvider);
    // Bootstrap/login hydration owns the initial remote sync.
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
  Future<WorkoutSession> quickAddWorkout({
    required String activityType,
    required double durationMinutes,
    double distanceKm = 0.0,
    int steps = 0,
    double? avgSpeedKmh,
    double? caloriesKcal,
    String mode = 'indoor',
  }) async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) throw Exception('No user logged in');

    final resolvedCalories =
        caloriesKcal ??
        await (() async {
          final profile = await ref.read(userProfileProvider(user).future);
          if (profile == null) return 0.0;
          return profile.calculateCalories(
            activityType: activityType,
            distanceKm: distanceKm,
            speedKmh: avgSpeedKmh ?? 0.0,
          );
        })();

    // Quick Add -> Generate UUID -> Save immediately
    final durationSec = (durationMinutes * 60).round();
    final endedAt = DateTime.now().toUtc();
    final session = WorkoutSession(
      id: const Uuid().v4(),
      userId: user,
      activityType: activityType,
      startedAt: endedAt.subtract(Duration(seconds: durationSec)),
      endedAt: endedAt,
      durationSec: durationSec,
      distanceKm: distanceKm,
      steps: steps,
      avgSpeedKmh: avgSpeedKmh ?? 0.0,
      caloriesKcal: resolvedCalories,
      mode: mode,
      createdAt: endedAt,
    );

    await saveSession(session);
    return session;
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

class WorkoutRoutePresentation {
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String source;
  final String matchStatus;
  final double? matchConfidence;

  const WorkoutRoutePresentation({
    required this.routePoints,
    required this.routeSegments,
    required this.source,
    required this.matchStatus,
    this.matchConfidence,
  });
}

final workoutRoutePresentationProvider =
    FutureProvider.family<WorkoutRoutePresentation, String>((ref, id) async {
      final workout = await ref.watch(workoutProvider(id).future);

      if (workout != null) {
        final matchedSegments = _decodeRouteSegments(workout.matchedRouteJson);
        if (matchedSegments.isNotEmpty) {
          return WorkoutRoutePresentation(
            routePoints: matchedSegments.expand((segment) => segment).toList(),
            routeSegments: matchedSegments,
            source: 'matched',
            matchStatus: workout.routeMatchStatus,
            matchConfidence: workout.routeMatchConfidence,
          );
        }

        final filteredSegments = _decodeRouteSegments(
          workout.filteredRouteJson,
        );
        if (filteredSegments.isNotEmpty) {
          return WorkoutRoutePresentation(
            routePoints: filteredSegments.expand((segment) => segment).toList(),
            routeSegments: filteredSegments,
            source: 'filtered',
            matchStatus: workout.routeMatchStatus,
            matchConfidence: workout.routeMatchConfidence,
          );
        }
      }

      final points = await LocalDB.getPointsForSession(id);
      final rawRoute = points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList(growable: false);

      return WorkoutRoutePresentation(
        routePoints: rawRoute,
        routeSegments: rawRoute.isEmpty ? const <List<LatLng>>[] : [rawRoute],
        source: 'raw',
        matchStatus: workout?.routeMatchStatus ?? 'pending',
        matchConfidence: workout?.routeMatchConfidence,
      );
    });

@riverpod
Future<List<LatLng>> workoutRoute(WorkoutRouteRef ref, String id) async {
  final presentation = await ref.watch(
    workoutRoutePresentationProvider(id).future,
  );
  return presentation.routePoints;
}

List<List<LatLng>> _decodeRouteSegments(String raw) {
  if (raw.isEmpty || raw == '[]') return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final segments = <List<LatLng>>[];
    for (final segment in decoded) {
      if (segment is! List) continue;
      final points = <LatLng>[];
      for (final point in segment) {
        if (point is! Map) continue;
        final lat = (point['lat'] as num?)?.toDouble();
        final lng = (point['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        points.add(LatLng(lat, lng));
      }
      if (points.isNotEmpty) {
        segments.add(points);
      }
    }
    return segments;
  } catch (_) {
    return const [];
  }
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
