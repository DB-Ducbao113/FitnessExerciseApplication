import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/workout/data/models/workout_session_model.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/core/constants/db_tables.dart';
import 'package:flutter/foundation.dart';

class WorkoutRemoteDataSource {
  final SupabaseClient _supabase;

  WorkoutRemoteDataSource(this._supabase);

  /// Saves the complete session to the cloud database
  Future<void> saveSession(WorkoutSession session) async {
    final model = WorkoutSessionModel.fromEntity(session);
    await _supabase.from(DbTables.workoutSessions).insert(model.toJson());
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
