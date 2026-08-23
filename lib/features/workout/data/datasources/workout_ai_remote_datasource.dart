import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_insight.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote Datasource connecting Flutter App to Supabase Edge Function 'generate-workout-insight'.
class WorkoutAiRemoteDatasource {
  final SupabaseClient _client;

  WorkoutAiRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Invokes Edge Function generate-workout-insight with workoutId and extracted signals.
  Future<WorkoutAiInsight> fetchWorkoutInsight({
    required String workoutId,
    required WorkoutAiSignals signals,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'generate-workout-insight',
        body: {
          'workout_id': workoutId,
          'signals': signals.toJson(),
        },
      );

      if (response.status != 200) {
        throw Exception('Edge function returned status ${response.status}');
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return WorkoutAiInsight.fromJson(data);
      } else if (data is Map) {
        return WorkoutAiInsight.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw const FormatException('Invalid JSON payload returned from Edge Function');
      }
    } catch (e) {
      debugPrint('[WorkoutAiRemoteDatasource] Edge function error: $e');
      rethrow;
    }
  }
}
