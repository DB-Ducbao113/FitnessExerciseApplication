import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

part 'workout_session_model.freezed.dart';
part 'workout_session_model.g.dart';

@freezed
class WorkoutSessionModel with _$WorkoutSessionModel {
  const WorkoutSessionModel._();

  const factory WorkoutSessionModel({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'activity_type') required String activityType,
    @JsonKey(name: 'started_at') required DateTime startedAt,
    @JsonKey(name: 'ended_at') required DateTime endedAt,
    @JsonKey(name: 'duration_sec') required int durationSec,
    @JsonKey(name: 'distance_km') required double distanceKm,
    required int steps,
    @JsonKey(name: 'avg_speed_kmh') required double avgSpeedKmh,
    @JsonKey(name: 'calories_kcal') required double caloriesKcal,
    required String mode,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _WorkoutSessionModel;

  factory WorkoutSessionModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSessionModelFromJson(json);

  factory WorkoutSessionModel.fromEntity(WorkoutSession entity) {
    return WorkoutSessionModel(
      id: entity.id,
      userId: entity.userId,
      activityType: entity.activityType,
      startedAt: entity.startedAt,
      endedAt: entity.endedAt,
      durationSec: entity.durationSec,
      distanceKm: entity.distanceKm,
      steps: entity.steps,
      avgSpeedKmh: entity.avgSpeedKmh,
      caloriesKcal: entity.caloriesKcal,
      mode: entity.mode,
      createdAt: entity.createdAt,
    );
  }

  WorkoutSession toEntity() {
    return WorkoutSession(
      id: id,
      userId: userId,
      activityType: activityType,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSec: durationSec,
      distanceKm: distanceKm,
      steps: steps,
      avgSpeedKmh: avgSpeedKmh,
      caloriesKcal: caloriesKcal,
      mode: mode,
      createdAt: createdAt,
    );
  }
}
