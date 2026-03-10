import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/data/local/local_db.dart';
import 'package:fitness_exercise_application/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/domain/repositories/workout_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:fitness_exercise_application/domain/entities/workout_session.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutRemoteDataSource _remoteDataSource;
  final SupabaseClient _supabase;

  WorkoutRepositoryImpl(this._remoteDataSource, this._supabase);

  @override
  Future<void> saveSessionRemote(WorkoutSession session) async {
    await _remoteDataSource.saveSession(session);
  }

  @override
  Future<void> cacheSessionLocal(WorkoutSession session) async {
    final localWorkout = LocalWorkout.fromEntity(session);
    localWorkout.isSynced = true;
    await LocalDB.saveSession(localWorkout);
  }

  @override
  Future<List<WorkoutSession>> fetchSessionsRemote(String userId) async {
    final remoteWorkouts = await _remoteDataSource.getSessionsByUser(userId);
    return remoteWorkouts;
  }

  @override
  Future<List<WorkoutSession>> getSessionsLocal(String userId) async {
    final localWorkouts = await LocalDB.getSessionsByUser(userId);
    return localWorkouts.map((w) => w.toEntity()).toList();
  }

  @override
  Future<void> replaceLocalCache(
    String userId,
    List<WorkoutSession> sessions,
  ) async {
    // 1. Wipe current local cache explicitly for the user
    await LocalDB.clearAllForUser(userId);
    // 2. Hydrate from the provided sessions
    await LocalDB.syncRemoteSessions(sessions);
  }

  @override
  Future<List<WorkoutSession>> getSessionsByType(String activityType) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final localWorkouts = await LocalDB.getSessionsByUserByType(
      userId,
      activityType,
    );
    return localWorkouts.map((w) => w.toEntity()).toList();
  }

  @override
  Future<WorkoutSession?> getSessionById(String sessionId) async {
    final w = await LocalDB.getSessionById(sessionId);
    return w?.toEntity();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    // Delete local first for immediate UI feedback
    final w = await LocalDB.getSessionById(sessionId);
    if (w != null) {
      await LocalDB.deleteWorkout(w.id);
    }

    // Try deleting remote
    if (await InternetConnectionChecker().hasConnection) {
      try {
        await _remoteDataSource.deleteSession(sessionId);
      } catch (e) {
        debugPrint('[WorkoutRepository] Failed to delete remote session: $e');
      }
    }
  }

  @override
  Future<void> deleteAllSessions(String userId) async {
    // Clear local cache completely
    await LocalDB.clearAllForUser(userId);

    // Try deleting remote
    if (await InternetConnectionChecker().hasConnection) {
      try {
        await _remoteDataSource.deleteAllSessions(userId);
      } catch (e) {
        debugPrint(
          '[WorkoutRepository] Failed to delete all remote sessions: $e',
        );
      }
    }
  }

  @override
  Future<void> syncPendingData() async {
    if (!await InternetConnectionChecker().hasConnection) return;

    try {
      final unsyncedWorkouts = await LocalDB.getUnsyncedWorkouts();
      for (final workout in unsyncedWorkouts) {
        try {
          await _remoteDataSource.saveSession(workout.toEntity());
          workout.isSynced = true;
          await LocalDB.saveSession(workout);
        } catch (e) {
          debugPrint(
            '[WorkoutRepository] Failed to sync pending session ${workout.sessionId}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[Sync] syncPendingData error: $e');
    }
  }

  @override
  Future<void> syncFromCloud() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (!await InternetConnectionChecker().hasConnection) return;

    try {
      final remoteWorkouts = await fetchSessionsRemote(userId);
      await replaceLocalCache(userId, remoteWorkouts);
    } catch (e) {
      debugPrint('[Sync] syncFromCloud error: $e');
    }
  }
}
