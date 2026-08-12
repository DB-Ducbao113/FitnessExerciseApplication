import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/route_match_quality_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutRemoteDataSource _remoteDataSource;
  final RawTrackingRemoteDataSource _rawTrackingRemoteDataSource;
  final WorkoutProcessingRemoteDataSource _processingRemoteDataSource;
  final SupabaseClient _supabase;
  final RouteMatchQualityService _routeMatchQualityService =
      const RouteMatchQualityService();

  WorkoutRepositoryImpl(
    this._remoteDataSource,
    this._rawTrackingRemoteDataSource,
    this._processingRemoteDataSource,
    this._supabase,
  );

  @override
  Future<void> saveSessionRemote(WorkoutSession session) async {
    await _remoteDataSource.saveSession(session);
  }

  @override
  Future<void> cacheSessionLocal(
    WorkoutSession session, {
    bool isSynced = false,
  }) async {
    final localWorkout = LocalWorkout.fromEntity(session, isSynced: isSynced);
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

    // Try deleting remote (gracefully handles offline)
    try {
      await _remoteDataSource.deleteSession(sessionId);
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to delete remote session: $e');
    }
  }

  @override
  Future<void> deleteAllSessions(String userId) async {
    // Clear local cache completely
    await LocalDB.clearAllForUser(userId);

    // Try deleting remote (gracefully handles offline)
    try {
      await _remoteDataSource.deleteAllSessions(userId);
    } catch (e) {
      debugPrint(
        '[WorkoutRepository] Failed to delete all remote sessions: $e',
      );
    }
  }

  @override
  Future<void> syncPendingData() async {

    try {
      final unsyncedWorkouts = await LocalDB.getUnsyncedWorkouts();
      for (final workout in unsyncedWorkouts) {
        try {
          final session = workout.toEntity();
          await _remoteDataSource.saveSession(session);
          await _syncRawTrackingForSession(workout.sessionId);
          await _enqueueDeterministicProcessing(session);
          await _enqueueRouteCorrectionIfNeeded(session);
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

  Future<void> _syncRawTrackingForSession(String sessionId) async {
    final unsyncedGpsPoints = await LocalDB.getUnsyncedGpsPointsForSession(
      sessionId,
    );
    if (unsyncedGpsPoints.isNotEmpty) {
      await _rawTrackingRemoteDataSource.saveRawGpsPoints(
        unsyncedGpsPoints.map(LocalDB.rawGpsPointToPayload).toList(),
      );
      await LocalDB.markGpsPointsAsSynced(
        unsyncedGpsPoints.map((point) => point.id).toList(),
      );
    }

    final unsyncedStepIntervals =
        await LocalDB.getUnsyncedStepIntervalsForSession(sessionId);
    if (unsyncedStepIntervals.isNotEmpty) {
      await _rawTrackingRemoteDataSource.saveRawStepIntervals(
        unsyncedStepIntervals.map((interval) => interval.toPayload()).toList(),
      );
      await LocalDB.markStepIntervalsAsSynced(
        unsyncedStepIntervals.map((interval) => interval.id).toList(),
      );
    }
  }

  Future<void> _enqueueDeterministicProcessing(WorkoutSession session) async {
    await _processingRemoteDataSource.enqueueDeterministicJob(
      workoutId: session.id,
      payload: {
        'session_id': session.id,
        'activity_type': session.activityType,
        'mode': session.mode,
        'duration_sec': session.durationSec,
        'moving_time_sec': session.movingTimeSec,
        'distance_km': session.distanceKm,
        'steps': session.steps,
        'avg_speed_kmh': session.avgSpeedKmh,
        'calories_kcal': session.caloriesKcal,
        'source': 'offline_sync',
      },
    );
  }

  Future<void> _enqueueRouteCorrectionIfNeeded(WorkoutSession session) async {
    final routeSummary = _summarizeRouteSegments(session.filteredRouteJson);
    if (routeSummary.pointCount < 10 || routeSummary.segmentCount == 0) return;

    try {
      await _processingRemoteDataSource.enqueueRouteCorrectionJob(
        workoutId: session.id,
        payload: {
          'session_id': session.id,
          'activity_type': session.activityType,
          'mode': session.mode,
          'started_at': session.startedAt.toUtc().toIso8601String(),
          'ended_at': session.endedAt.toUtc().toIso8601String(),
          'duration_sec': session.durationSec,
          'moving_time_sec': session.movingTimeSec,
          'distance_km_filtered': session.distanceKm,
          'gps_gap_count': session.gpsAnalysis.gpsGapCount,
          'gps_gap_duration_sec': session.gpsAnalysis.gpsGapDurationSec,
          'filtered_route_json': session.filteredRouteJson,
          'route_match_status': session.routeMatchStatus,
          'route_distance_source': session.routeDistanceSource,
          'route_segment_count': routeSummary.segmentCount,
          'route_point_count': routeSummary.pointCount,
          'source': 'offline_sync',
        },
      );
    } catch (e) {
      debugPrint(
        '[WorkoutRepository] Failed to enqueue route correction for ${session.id}: $e',
      );
    }
  }

  _RouteSegmentSummary _summarizeRouteSegments(String routeJson) {
    try {
      final decoded = jsonDecode(routeJson);
      if (decoded is! List) {
        return const _RouteSegmentSummary(segmentCount: 0, pointCount: 0);
      }

      var segmentCount = 0;
      var pointCount = 0;
      for (final segment in decoded) {
        if (segment is! List || segment.isEmpty) continue;
        segmentCount += 1;
        pointCount += segment.length;
      }

      return _RouteSegmentSummary(
        segmentCount: segmentCount,
        pointCount: pointCount,
      );
    } catch (_) {
      return const _RouteSegmentSummary(segmentCount: 0, pointCount: 0);
    }
  }

  @override
  Future<bool> syncRouteMatchResult(String sessionId) async {

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

    try {
      await syncPendingData();
      final remoteWorkouts = await fetchSessionsRemote(userId);
      await LocalDB.syncRemoteSessions(remoteWorkouts);
    } catch (e) {
      debugPrint('[Sync] syncFromCloud error: $e');
    }
  }
}

class _RouteSegmentSummary {
  final int segmentCount;
  final int pointCount;

  const _RouteSegmentSummary({
    required this.segmentCount,
    required this.pointCount,
  });
}
