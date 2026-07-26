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
    return _enqueueJob(
      workoutId: workoutId,
      jobType: kDeterministicFinalizeJobType,
      payload: payload,
      enqueuedEventType: kClientFinishEnqueuedEvent,
      enqueuedMessage: kClientFinishEnqueuedMessage,
      skippedEventType: 'client_finish_enqueue_skipped_existing',
      skippedMessage:
          'Client skipped deterministic processing enqueue because an existing job already covers this workout.',
      debugLabel: 'deterministic finalize',
    );
  }

  Future<String?> enqueueRouteCorrectionJob({
    required String workoutId,
    required Map<String, dynamic> payload,
  }) async {
    return _enqueueJob(
      workoutId: workoutId,
      jobType: kRouteCorrectionJobType,
      payload: payload,
      enqueuedEventType: kClientRouteCorrectionEnqueuedEvent,
      enqueuedMessage: kClientRouteCorrectionEnqueuedMessage,
      skippedEventType: 'client_route_correction_enqueue_skipped_existing',
      skippedMessage:
          'Client skipped route correction enqueue because an existing job already covers this workout.',
      debugLabel: 'route correction',
    );
  }

  Future<String?> _enqueueJob({
    required String workoutId,
    required String jobType,
    required Map<String, dynamic> payload,
    required String enqueuedEventType,
    required String enqueuedMessage,
    required String skippedEventType,
    required String skippedMessage,
    required String debugLabel,
  }) async {
    try {
      final existing = await _findExistingJob(
        workoutId: workoutId,
        jobType: jobType,
      );
      if (existing != null) {
        return _logSkippedExistingJob(
          workoutId: workoutId,
          existing: existing,
          eventType: skippedEventType,
          message: skippedMessage,
          payload: payload,
        );
      }

      final Map<String, dynamic>? response;
      try {
        response = await _supabase
            .from(DbTables.workoutProcessingJobs)
            .insert({
              'workout_id': workoutId,
              'job_type': jobType,
              'status': kQueuedJobStatus,
              'attempt_count': 0,
            })
            .select('id')
            .maybeSingle();
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          final racedExisting = await _findExistingJob(
            workoutId: workoutId,
            jobType: jobType,
          );
          if (racedExisting != null) {
            return _logSkippedExistingJob(
              workoutId: workoutId,
              existing: racedExisting,
              eventType: skippedEventType,
              message: skippedMessage,
              payload: {
                ...payload,
                'reason': 'unique_active_job_race',
              },
            );
          }
        }
        rethrow;
      }

      final jobId = response?['id'] as String?;
      await insertLog(
        workoutId: workoutId,
        jobId: jobId,
        eventType: enqueuedEventType,
        message: enqueuedMessage,
        payload: payload,
      );
      return jobId;
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutProcessingRemoteDataSource] enqueue $debugLabel failed: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '[WorkoutProcessingRemoteDataSource] enqueue $debugLabel unexpected error: $e',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _findExistingJob({
    required String workoutId,
    required String jobType,
  }) async {
    return await _supabase
        .from(DbTables.workoutProcessingJobs)
        .select('id,status')
        .eq('workout_id', workoutId)
        .eq('job_type', jobType)
        .filter('status', 'in', '(queued,running,completed)')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<String?> _logSkippedExistingJob({
    required String workoutId,
    required Map<String, dynamic> existing,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
  }) async {
    final existingJobId = existing['id'] as String?;
    await insertLog(
      workoutId: workoutId,
      jobId: existingJobId,
      eventType: eventType,
      message: message,
      payload: {
        ...payload,
        'existing_job_id': existingJobId,
        'existing_job_status': existing['status'],
      },
    );
    return existingJobId;
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
