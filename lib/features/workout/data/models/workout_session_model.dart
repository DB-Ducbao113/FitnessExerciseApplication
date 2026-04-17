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
    @JsonKey(
      name: 'lap_splits',
      fromJson: _lapSplitsFromJson,
      toJson: _lapSplitsToJson,
    )
    @Default(<WorkoutLapSplit>[])
    List<WorkoutLapSplit> lapSplits,
    @JsonKey(
      name: 'gps_analysis',
      fromJson: _gpsAnalysisFromJson,
      toJson: _gpsAnalysisToJson,
    )
    @Default(WorkoutGpsAnalysis())
    WorkoutGpsAnalysis gpsAnalysis,
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
      lapSplits: entity.lapSplits,
      gpsAnalysis: entity.gpsAnalysis,
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
      lapSplits: lapSplits,
      gpsAnalysis: gpsAnalysis,
    );
  }
}

List<WorkoutLapSplit> _lapSplitsFromJson(dynamic json) {
  if (json is! List) return const <WorkoutLapSplit>[];
  return json
      .whereType<Map>()
      .map((item) => WorkoutLapSplit.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

List<Map<String, dynamic>> _lapSplitsToJson(List<WorkoutLapSplit> splits) {
  return splits.map((split) => split.toJson()).toList();
}

WorkoutGpsAnalysis _gpsAnalysisFromJson(dynamic json) {
  if (json is! Map) return const WorkoutGpsAnalysis();
  return WorkoutGpsAnalysis.fromJson(Map<String, dynamic>.from(json));
}

Map<String, dynamic> _gpsAnalysisToJson(WorkoutGpsAnalysis analysis) {
  return analysis.toJson();
}
