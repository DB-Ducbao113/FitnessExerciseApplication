import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
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
    _isar = await Isar.open([
      LocalWorkoutSchema,
      LocalGPSPointSchema,
    ], directory: dir.path, inspector: false);
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

      // Delete GPS points associated with these workouts
      for (final w in workouts) {
        await isar.localGPSPoints
            .filter()
            .localWorkoutIdEqualTo(w.id)
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
          final newWorkout = LocalWorkout.fromEntity(remote);
          await isar.localWorkouts.put(newWorkout);
        } else {
          // If it exists locally, ensure it matches the cloud source of truth
          existing.userId = remote.userId;
          existing.activityType = remote.activityType;
          existing.startedAt = remote.startedAt;
          existing.endedAt = remote.endedAt;
          existing.durationSec = remote.durationSec;
          existing.distanceKm = remote.distanceKm;
          existing.steps = remote.steps;
          existing.avgSpeedKmh = remote.avgSpeedKmh;
          existing.caloriesKcal = remote.caloriesKcal;
          existing.mode = remote.mode;
          existing.createdAt = remote.createdAt;
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

  static Future<List<LocalGPSPoint>> getPointsForWorkout(int workoutId) async {
    await init();
    final isar = instance;
    return await isar.localGPSPoints
        .filter()
        .localWorkoutIdEqualTo(workoutId)
        .sortByTimestamp()
        .findAll();
  }

  static Future<List<LocalGPSPoint>> getUnsyncedPoints(int workoutId) async {
    await init();
    final isar = instance;
    return await isar.localGPSPoints
        .filter()
        .localWorkoutIdEqualTo(workoutId)
        .isSyncedEqualTo(false)
        .sortByTimestamp()
        .findAll();
  }

  static Future<void> markPointsAsSynced(List<int> pointIds) async {
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
}
