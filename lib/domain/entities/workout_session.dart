import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_session.freezed.dart';

@freezed
class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required String userId,
    required String activityType,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSec,
    required double distanceKm,
    required int steps,
    required double avgSpeedKmh,
    required double caloriesKcal,
    required String mode,
    required DateTime createdAt,
  }) = _WorkoutSession;
}
