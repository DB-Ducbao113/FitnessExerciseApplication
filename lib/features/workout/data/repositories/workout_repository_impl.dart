import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/route_match_quality_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutRemoteDataSource _remoteDataSource;
  final SupabaseClient _supabase;
  final RouteMatchQualityService _routeMatchQualityService =
      const RouteMatchQualityService();

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
  Future<bool> syncRouteMatchResult(String sessionId) async {
    if (!await InternetConnectionChecker().hasConnection) return false;

    try {
      final payload = await _remoteDataSource.getRouteMatchPayload(sessionId);
      if (payload == null) return false;

      final rawResult = RouteMatchResult(
        sessionId: sessionId,
        matchedRouteJson: payload['matched_route_json'] as String? ?? '[]',
        routeMatchStatus: payload['route_match_status'] as String? ?? 'pending',
        routeMatchConfidence: (payload['route_match_confidence'] as num?)
            ?.toDouble(),
        routeDistanceSource:
            payload['route_distance_source'] as String? ?? 'filtered',
        matchedDistanceKm: (payload['matched_distance_km'] as num?)?.toDouble(),
        routeMatchMetricsJson:
            payload['route_match_metrics_json'] as String? ?? '{}',
      );

      final normalized = _routeMatchQualityService.normalize(rawResult);
      await LocalDB.updateRouteMatchResult(normalized);
      return true;
    } catch (e) {
      debugPrint('[WorkoutRepository] syncRouteMatchResult error: $e');
      return false;
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
