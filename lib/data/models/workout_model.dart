import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fitness_exercise_application/domain/entities/workout.dart';

part 'workout_model.freezed.dart';
part 'workout_model.g.dart';

@freezed
class WorkoutModel with _$WorkoutModel {
  const WorkoutModel._();

  const factory WorkoutModel({
    required String id,
    required String userId,
    required String activityType,
    required DateTime startedAt,
    DateTime? endedAt,
    double? distanceKm,
    double? durationMin,
    double? avgSpeedKmh,
    int? calories,
    @Default('outdoor') String mode,
    int? stepCount,
    double? strideLength,
    double? estimatedDistanceMeters,
    @Default(false) bool synced,
  }) = _WorkoutModel;

  factory WorkoutModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutModelFromJson(json);

  /// Convert to domain entity
  Workout toEntity() => Workout(
    id: id,
    userId: userId,
    activityType: activityType,
    startedAt: startedAt,
    endedAt: endedAt,
    distanceKm: distanceKm,
    durationMin: durationMin,
    avgSpeedKmh: avgSpeedKmh,
    calories: calories,
    mode: mode,
    stepCount: stepCount,
    strideLength: strideLength,
    estimatedDistanceMeters: estimatedDistanceMeters,
  );

  /// Create from domain entity
  factory WorkoutModel.fromEntity(Workout workout, {bool synced = false}) =>
      WorkoutModel(
        id: workout.id,
        userId: workout.userId,
        activityType: workout.activityType,
        startedAt: workout.startedAt,
        endedAt: workout.endedAt,
        distanceKm: workout.distanceKm,
        durationMin: workout.durationMin,
        avgSpeedKmh: workout.avgSpeedKmh,
        calories: workout.calories,
        mode: workout.mode,
        stepCount: workout.stepCount,
        strideLength: workout.strideLength,
        estimatedDistanceMeters: workout.estimatedDistanceMeters,
        synced: synced,
      );

  /// Convert to SQLite map
  Map<String, dynamic> toSQLite() => {
    'id': id,
    'user_id': userId,
    'activity_type': activityType,
    'started_at': startedAt.millisecondsSinceEpoch,
    'ended_at': endedAt?.millisecondsSinceEpoch,
    'distance_km': distanceKm,
    'duration_min': durationMin,
    'avg_speed_kmh': avgSpeedKmh,
    'calories': calories,
    'mode': mode,
    'step_count': stepCount,
    'stride_length': strideLength,
    'estimated_distance_meters': estimatedDistanceMeters,
    'synced': synced ? 1 : 0,
  };

  /// Create from SQLite map
  factory WorkoutModel.fromSQLite(Map<String, dynamic> map) => WorkoutModel(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    activityType: map['activity_type'] as String,
    startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
    endedAt: map['ended_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int)
        : null,
    distanceKm: map['distance_km'] as double?,
    durationMin: map['duration_min'] as double?,
    avgSpeedKmh: map['avg_speed_kmh'] as double?,
    calories: map['calories'] as int?,
    mode: (map['mode'] as String?) ?? 'outdoor',
    stepCount: map['step_count'] as int?,
    strideLength: map['stride_length'] as double?,
    estimatedDistanceMeters: map['estimated_distance_meters'] as double?,
    synced: map['synced'] == 1,
  );
}
