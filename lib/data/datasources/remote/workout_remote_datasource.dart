import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/data/models/workout_model.dart';

class WorkoutRemoteDataSource {
  final SupabaseClient _supabase;

  WorkoutRemoteDataSource(this._supabase);

  /// Start workout via Edge Function
  Future<String> startWorkout(String activityType) async {
    final response = await _supabase.functions.invoke(
      'workouts-start',
      body: {'activity_type': activityType},
    );

    if (response.data == null) {
      throw Exception('Failed to start workout');
    }

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    return data['workout_id'] as String;
  }

  /// End workout via Edge Function
  /// Accepts optional manual metrics that will be sent to the backend
  Future<WorkoutModel> endWorkout(
    String workoutId, {
    double? distance,
    double? durationMinutes,
    double? speed,
    int? calories,
    String? mode,
    int? stepCount,
    double? elevationGainMeters,
    double? maxElevation,
  }) async {
    final body = <String, dynamic>{'workout_id': workoutId};

    // Add optional manual metrics if provided
    if (distance != null) body['distance'] = distance;
    if (durationMinutes != null) body['duration_minutes'] = durationMinutes;
    if (speed != null) body['speed'] = speed;
    if (calories != null) body['calories'] = calories;
    if (mode != null) body['mode'] = mode;
    if (stepCount != null) body['step_count'] = stepCount;
    if (elevationGainMeters != null)
      body['elevation_gain_meters'] = elevationGainMeters;
    if (maxElevation != null) body['max_elevation'] = maxElevation;

    final response = await _supabase.functions.invoke(
      'workouts-end',
      body: body,
    );

    if (response.data == null) {
      throw Exception('Failed to end workout');
    }

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    // Fetch the updated workout from database
    final workout = await _supabase
        .from('workouts')
        .select()
        .eq('id', workoutId)
        .single();

    return WorkoutModel.fromJson(workout);
  }

  /// Track GPS via Edge Function
  Future<void> trackGPS(
    String workoutId,
    double latitude,
    double longitude,
  ) async {
    final response = await _supabase.functions.invoke(
      'gps-track',
      body: [
        {'workout_id': workoutId, 'latitude': latitude, 'longitude': longitude},
      ], // Wrap in array for the new batch-supporting function
    );

    if (response.data == null) {
      throw Exception('Failed to track GPS');
    }

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
  }

  /// Batch Track GPS
  Future<void> trackGPSBatch(List<Map<String, dynamic>> points) async {
    if (points.isEmpty) return;

    final response = await _supabase.functions.invoke(
      'gps-track',
      body: points,
    );

    if (response.data == null) {
      throw Exception('Failed to track GPS Batch');
    }

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
  }

  /// Fetch workouts from Supabase
  Future<List<WorkoutModel>> getWorkouts() async {
    final response = await _supabase
        .from('workouts')
        .select()
        .order('started_at', ascending: false);

    return (response as List)
        .map((json) => WorkoutModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch single workout
  Future<WorkoutModel?> getWorkout(String id) async {
    final response = await _supabase
        .from('workouts')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return WorkoutModel.fromJson(response);
  }

  /// Delete workout from Supabase
  Future<void> deleteWorkout(String id) async {
    await _supabase.from('workouts').delete().eq('id', id);
  }
}
