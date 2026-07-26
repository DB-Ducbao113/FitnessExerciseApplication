import 'dart:convert';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_step_interval.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class LocalDB {
  static Isar? _isar;
  static Future<void>? _initFuture;

  static Future<void> init() async {
    if (_isar != null) return;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _open();
    try {
      await _initFuture!;
    } finally {
      _initFuture = null;
    }
  }

  static Future<void> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [LocalWorkoutSchema, LocalGPSPointSchema, LocalStepIntervalSchema],
      directory: dir.path,
      inspector: false,
    );
  }

  static Isar get instance {
    final isar = _isar;
    if (isar == null) {
      throw StateError('LocalDB has not been initialized');
    }
    return isar;
  }

  // New Workout Methods

  /// Insert locally. Used when finishing a session.
  static Future<void> saveSession(LocalWorkout workout) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      await isar.localWorkouts.put(workout);
    });
  }

  /// Get all sessions for a user, sorted descending. UI uses this.
  static Future<List<LocalWorkout>> getSessionsByUser(String userId) async {
    await init();
    final isar = instance;
    return await isar.localWorkouts
        .filter()
        .userIdEqualTo(userId)
        .sortByStartedAtDesc()
        .findAll();
  }

  /// Filtered by activity type.
  static Future<List<LocalWorkout>> getSessionsByUserByType(
    String userId,
    String activityType,
  ) async {
    await init();
    final isar = instance;
    return await isar.localWorkouts
        .filter()
        .userIdEqualTo(userId)
        .activityTypeEqualTo(activityType, caseSensitive: false)
        .sortByStartedAtDesc()
        .findAll();
  }

  static Future<LocalWorkout?> getSessionById(String sessionId) async {
    await init();
    final isar = instance;
    return await isar.localWorkouts
        .filter()
        .sessionIdEqualTo(sessionId)
        .findFirst();
  }

  static Future<void> deleteWorkout(int id) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      final workout = await isar.localWorkouts.get(id);
      if (workout != null) {
        await isar.localGPSPoints
            .filter()
            .sessionIdEqualTo(workout.sessionId)
            .deleteAll();
        await isar.localStepIntervals
            .filter()
            .sessionIdEqualTo(workout.sessionId)
            .deleteAll();
      }
      await isar.localWorkouts.delete(id);
    });
  }

  static Future<List<LocalWorkout>> getUnsyncedWorkouts() async {
    await init();
    final isar = instance;
    return await isar.localWorkouts.filter().isSyncedEqualTo(false).findAll();
  }

  /// Wipe all local cache for a specific user (used on logout).
  static Future<void> clearAllForUser(String userId) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      final workouts = await isar.localWorkouts
          .filter()
          .userIdEqualTo(userId)
          .findAll();

      // Delete GPS points associated with these workouts by sessionId.
      for (final w in workouts) {
        await isar.localGPSPoints
            .filter()
            .sessionIdEqualTo(w.sessionId)
            .deleteAll();
        await isar.localStepIntervals
            .filter()
            .sessionIdEqualTo(w.sessionId)
            .deleteAll();
      }

      // Delete the workouts themselves
      await isar.localWorkouts.filter().userIdEqualTo(userId).deleteAll();
    });
  }

  /// Hydrate local DB from cloud models to implement sync across devices.
  static Future<void> syncRemoteSessions(List<WorkoutSession> remotes) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      for (final remote in remotes) {
        var existing = await isar.localWorkouts
            .filter()
            .sessionIdEqualTo(remote.id)
            .findFirst();

        if (existing == null) {
          // If it doesn't exist locally, add it to the cache
          final newWorkout = LocalWorkout.fromEntity(remote, isSynced: true);
          await isar.localWorkouts.put(newWorkout);
        } else {
          // If it exists locally, ensure it matches the cloud source of truth
          existing.userId = remote.userId;
          existing.activityType = remote.activityType;
          existing.startedAt = remote.startedAt;
          existing.endedAt = remote.endedAt;
          existing.durationSec = remote.durationSec;
          existing.movingTimeSec = remote.movingTimeSec;
          existing.distanceKm = remote.distanceKm;
          existing.steps = remote.steps;
          existing.avgSpeedKmh = remote.avgSpeedKmh;
          existing.caloriesKcal = remote.caloriesKcal;
          existing.mode = remote.mode;
          existing.createdAt = remote.createdAt;
          existing.lapSplitsJson = jsonEncode(
            remote.lapSplits.map((split) => split.toJson()).toList(),
          );
          final shouldPreserveLocalAnalysis =
              remote.gpsAnalysis.totalDistanceKm <= 0 &&
              remote.gpsAnalysis.validDistanceKm <= 0 &&
              existing.gpsAnalysisJson.isNotEmpty &&
              existing.gpsAnalysisJson != '{}';
          final shouldPreserveFilteredRoute =
              (remote.filteredRouteJson.isEmpty ||
                  remote.filteredRouteJson == '[]') &&
              existing.filteredRouteJson.isNotEmpty &&
              existing.filteredRouteJson != '[]';
          final shouldPreserveMatchedRoute =
              (remote.matchedRouteJson.isEmpty ||
                  remote.matchedRouteJson == '[]') &&
              existing.matchedRouteJson.isNotEmpty &&
              existing.matchedRouteJson != '[]';
          if (!shouldPreserveLocalAnalysis) {
            existing.gpsAnalysisJson = jsonEncode(remote.gpsAnalysis.toJson());
          }
          if (!shouldPreserveFilteredRoute) {
            existing.filteredRouteJson = remote.filteredRouteJson;
          }
          if (!shouldPreserveMatchedRoute) {
            existing.matchedRouteJson = remote.matchedRouteJson;
          }
          existing.routeMatchStatus = remote.routeMatchStatus.isNotEmpty
              ? remote.routeMatchStatus
              : existing.routeMatchStatus;
          existing.routeMatchConfidence =
              remote.routeMatchConfidence ?? existing.routeMatchConfidence;
          existing.routeDistanceSource = remote.routeDistanceSource.isNotEmpty
              ? remote.routeDistanceSource
              : existing.routeDistanceSource;
          existing.matchedDistanceKm =
              remote.matchedDistanceKm ?? existing.matchedDistanceKm;
          existing.routeMatchMetricsJson =
              (remote.routeMatchMetricsJson.isNotEmpty &&
                  remote.routeMatchMetricsJson != '{}')
              ? remote.routeMatchMetricsJson
              : existing.routeMatchMetricsJson;
          existing.isSynced = true;

          await isar.localWorkouts.put(existing);
        }
      }
    });
  }

  // GPS Point Methods
  static Future<void> savePoints(List<LocalGPSPoint> points) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      await isar.localGPSPoints.putAll(points);
    });
  }

  static Future<void> saveRawGpsPoint(LocalGPSPoint point) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      await isar.localGPSPoints.put(point);
    });
  }

  /// Get all GPS points for a workout by its local Isar integer ID.
  /// Prefer [getPointsForSession] (uses sessionId index).
  static Future<List<LocalGPSPoint>> getPointsForWorkout(int workoutId) async {
    await init();
    final isar = instance;
    // Resolve sessionId first so we can use the indexed query path.
    final workout = await isar.localWorkouts.get(workoutId);
    if (workout == null) return const [];
    return await isar.localGPSPoints
        .filter()
        .sessionIdEqualTo(workout.sessionId)
        .sortByTimestamp()
        .findAll();
  }

  /// Get unsynced GPS points for a session by its local Isar integer ID.
  static Future<List<LocalGPSPoint>> getUnsyncedPoints(int workoutId) async {
    await init();
    final isar = instance;
    final workout = await isar.localWorkouts.get(workoutId);
    if (workout == null) return const [];
    return await isar.localGPSPoints
        .filter()
        .sessionIdEqualTo(workout.sessionId)
        .isSyncedEqualTo(false)
        .sortByTimestamp()
        .findAll();
  }

  static Future<List<LocalGPSPoint>> getUnsyncedGpsPointsForSession(
    String sessionId,
  ) async {
    await init();
    final isar = instance;
    return await isar.localGPSPoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .isSyncedEqualTo(false)
        .sortByTimestamp()
        .findAll();
  }

  static Future<List<LocalGPSPoint>> getPointsForSession(
    String sessionId,
  ) async {
    await init();
    final isar = instance;
    return await isar.localGPSPoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByTimestamp()
        .findAll();
  }

  static Future<void> markPointsAsSynced(List<int> pointIds) async {
    await markGpsPointsAsSynced(pointIds);
  }

  static Future<void> markGpsPointsAsSynced(List<int> pointIds) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      for (final id in pointIds) {
        final point = await isar.localGPSPoints.get(id);
        if (point != null) {
          point.isSynced = true;
          await isar.localGPSPoints.put(point);
        }
      }
    });
  }

  static RawGpsPointPayload rawGpsPointToPayload(LocalGPSPoint point) {
    return RawGpsPointPayload(
      workoutId: point.sessionId,
      timestamp: point.timestamp,
      latitude: point.latitude,
      longitude: point.longitude,
      altitude: point.altitude,
      speed: point.speed,
      accuracy: point.accuracy,
      heading: point.heading,
      deviceSource: point.deviceSource,
    );
  }

  static Future<void> saveRawStepInterval(LocalStepInterval interval) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      await isar.localStepIntervals.put(interval);
    });
  }

  static Future<List<LocalStepInterval>> getUnsyncedStepIntervalsForSession(
    String sessionId,
  ) async {
    await init();
    final isar = instance;
    return await isar.localStepIntervals
        .filter()
        .sessionIdEqualTo(sessionId)
        .isSyncedEqualTo(false)
        .sortByIntervalStart()
        .findAll();
  }

  static Future<void> markStepIntervalsAsSynced(List<int> intervalIds) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      for (final id in intervalIds) {
        final interval = await isar.localStepIntervals.get(id);
        if (interval != null) {
          interval.isSynced = true;
          await isar.localStepIntervals.put(interval);
        }
      }
    });
  }

  static Future<void> updateRouteMatchResult(RouteMatchResult result) async {
    await init();
    final isar = instance;
    await isar.writeTxn(() async {
      final workout = await isar.localWorkouts
          .filter()
          .sessionIdEqualTo(result.sessionId)
          .findFirst();
      if (workout == null) return;

      workout.matchedRouteJson = result.matchedRouteJson;
      workout.routeMatchStatus = result.routeMatchStatus;
      workout.routeMatchConfidence = result.routeMatchConfidence;
      workout.routeDistanceSource = result.routeDistanceSource;
      workout.matchedDistanceKm = result.matchedDistanceKm;
      workout.routeMatchMetricsJson = result.routeMatchMetricsJson;

      await isar.localWorkouts.put(workout);
    });
  }
}
