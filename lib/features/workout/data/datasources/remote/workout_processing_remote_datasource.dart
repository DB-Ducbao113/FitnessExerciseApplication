import 'package:fitness_exercise_application/core/constants/db_tables.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/constants/workout_processing_contract.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final workoutProcessingRemoteDataSourceProvider =
    Provider<WorkoutProcessingRemoteDataSource>((ref) {
      final supabase = ref.watch(supabaseClientProvider);
      return WorkoutProcessingRemoteDataSource(supabase);
    });

class WorkoutProcessingRemoteDataSource {
  final SupabaseClient _supabase;

  WorkoutProcessingRemoteDataSource(this._supabase);

  Future<String?> enqueueDeterministicJob({
    required String workoutId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _supabase
          .from(DbTables.workoutProcessingJobs)
          .insert({
            'workout_id': workoutId,
            'job_type': kDeterministicFinalizeJobType,
            'status': kQueuedJobStatus,
            'attempt_count': 0,
          })
          .select('id')
          .maybeSingle();

      final jobId = response?['id'] as String?;
      await insertLog(
        workoutId: workoutId,
        jobId: jobId,
        eventType: kClientFinishEnqueuedEvent,
        message: kClientFinishEnqueuedMessage,
        payload: payload,
      );
      return jobId;
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutProcessingRemoteDataSource] enqueue job failed: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '[WorkoutProcessingRemoteDataSource] enqueue job unexpected error: $e',
      );
      rethrow;
    }
  }

  Future<String?> enqueueRouteCorrectionJob({
    required String workoutId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _supabase
          .from(DbTables.workoutProcessingJobs)
          .insert({
            'workout_id': workoutId,
            'job_type': kRouteCorrectionJobType,
            'status': kQueuedJobStatus,
            'attempt_count': 0,
          })
          .select('id')
          .maybeSingle();

      final jobId = response?['id'] as String?;
      await insertLog(
        workoutId: workoutId,
        jobId: jobId,
        eventType: kClientRouteCorrectionEnqueuedEvent,
        message: kClientRouteCorrectionEnqueuedMessage,
        payload: payload,
      );
      return jobId;
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutProcessingRemoteDataSource] enqueue route correction failed: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '[WorkoutProcessingRemoteDataSource] enqueue route correction unexpected error: $e',
      );
      rethrow;
    }
  }

  Future<void> insertLog({
    required String workoutId,
    String? jobId,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
    String logLevel = 'info',
  }) async {
    try {
      await _supabase.from(DbTables.workoutProcessingLogs).insert({
        'workout_id': workoutId,
        'job_id': jobId,
        'log_level': logLevel,
        'event_type': eventType,
        'message': message,
        'payload': payload,
      });
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutProcessingRemoteDataSource] insert log failed: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '[WorkoutProcessingRemoteDataSource] insert log unexpected error: $e',
      );
      rethrow;
    }
  }
}
