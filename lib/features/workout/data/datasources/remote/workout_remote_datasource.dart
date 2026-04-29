import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/workout/data/models/workout_session_model.dart';
import 'package:fitness_exercise_application/features/workout/domain/constants/workout_processing_contract.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/core/constants/db_tables.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class WorkoutRemoteDataSource {
  final SupabaseClient _supabase;

  WorkoutRemoteDataSource(this._supabase);

  Future<void> createSessionShell({
    required String id,
    required String userId,
    required String activityType,
    required String mode,
    required DateTime startedAt,
    required DateTime createdAt,
  }) async {
    await _supabase.from(DbTables.workoutSessions).upsert({
      'id': id,
      'user_id': userId,
      'activity_type': activityType,
      'mode': mode,
      'started_at': startedAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'moving_time_sec': 0,
      'processing_status': kClientRecordingStatus,
      'metrics_version': kClientMetricsVersion,
    });
  }

  /// Saves the complete session to the cloud database
  Future<void> saveSession(WorkoutSession session) async {
    final model = WorkoutSessionModel.fromEntity(session);
    final payload = model.toJson()
      ..remove('gps_analysis')
      ..remove('filtered_route_json')
      ..remove('matched_route_json')
      ..remove('route_match_status')
      ..remove('route_match_confidence')
      ..remove('route_distance_source')
      ..remove('matched_distance_km')
      ..remove('route_match_metrics_json');
    await _supabase.from(DbTables.workoutSessions).upsert({
      ...payload,
      'processing_status': kClientProcessingStatus,
      'metrics_version': kClientMetricsVersion,
    });
  }

  Future<void> saveLiveRouteSnapshot({
    required String sessionId,
    required List<List<LatLng>> routeSegments,
    required bool shouldRequestRouteCorrection,
    required double? lastGpsGapDurationSec,
    required bool isGpsSignalWeak,
  }) async {
    final filteredRouteJson = routeSegments
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) => segment
              .map((point) => {'lat': point.latitude, 'lng': point.longitude})
              .toList(growable: false),
        )
        .toList(growable: false);

    final routePointCount = filteredRouteJson.fold<int>(
      0,
      (sum, segment) => sum + segment.length,
    );

    await _supabase
        .from(DbTables.workoutSessions)
        .update({
          'filtered_route_json': filteredRouteJson,
          'route_match_status': shouldRequestRouteCorrection
              ? 'pending'
              : 'not_requested',
          'route_distance_source': 'filtered',
          'route_match_metrics_json': {
            'live_snapshot': true,
            'route_segment_count': filteredRouteJson.length,
            'route_point_count': routePointCount,
            'last_gps_gap_duration_sec': lastGpsGapDurationSec,
            'is_gps_signal_weak': isGpsSignalWeak,
            'snapshot_synced_at': DateTime.now().toUtc().toIso8601String(),
          },
        })
        .eq('id', sessionId);
  }

  /// Fetch workouts from Supabase for a specific user
  Future<List<WorkoutSession>> getSessionsByUser(String userId) async {
    try {
      final response = await _supabase
          .from(DbTables.workoutSessions)
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false);

      return (response as List)
          .map(
            (json) => WorkoutSessionModel.fromJson(
              json as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList();
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getSessionsByUser error: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getSessionsByUser unexpected error: $e',
      );
      return [];
    }
  }

  /// Fetch single workout
  Future<WorkoutSession?> getSessionById(String id) async {
    try {
      final response = await _supabase
          .from(DbTables.workoutSessions)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return WorkoutSessionModel.fromJson(response).toEntity();
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getSessionById error: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getSessionById unexpected error: $e',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRouteMatchPayload(String id) async {
    try {
      final response = await _supabase
          .from(DbTables.workoutSessions)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      final payload = Map<String, dynamic>.from(response);
      final hasAnyRouteMatchField =
          payload.containsKey('matched_route_json') ||
          payload.containsKey('route_match_status') ||
          payload.containsKey('route_match_confidence') ||
          payload.containsKey('route_distance_source') ||
          payload.containsKey('matched_distance_km') ||
          payload.containsKey('route_match_metrics_json');
      return hasAnyRouteMatchField ? payload : null;
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getRouteMatchPayload error: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getRouteMatchPayload unexpected error: $e',
      );
      return null;
    }
  }

  /// Delete workout from Supabase
  Future<void> deleteSession(String id) async {
    try {
      await _supabase.from(DbTables.workoutSessions).delete().eq('id', id);
    } catch (e) {
      debugPrint('[WorkoutRemoteDataSource] deleteSession error: $e');
      rethrow;
    }
  }

  /// Delete all workouts for a user from Supabase
  Future<void> deleteAllSessions(String userId) async {
    try {
      await _supabase
          .from(DbTables.workoutSessions)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[WorkoutRemoteDataSource] deleteAllSessions error: $e');
      rethrow;
    }
  }
}
