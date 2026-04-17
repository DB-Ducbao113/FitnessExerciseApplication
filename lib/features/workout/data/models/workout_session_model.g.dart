// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkoutSessionModelImpl _$$WorkoutSessionModelImplFromJson(
        Map<String, dynamic> json) =>
    _$WorkoutSessionModelImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      activityType: json['activity_type'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: DateTime.parse(json['ended_at'] as String),
      durationSec: (json['duration_sec'] as num).toInt(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      steps: (json['steps'] as num).toInt(),
      avgSpeedKmh: (json['avg_speed_kmh'] as num).toDouble(),
      caloriesKcal: (json['calories_kcal'] as num).toDouble(),
      mode: json['mode'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lapSplits: json['lap_splits'] == null
          ? const <WorkoutLapSplit>[]
          : _lapSplitsFromJson(json['lap_splits']),
      gpsAnalysis: json['gps_analysis'] == null
          ? const WorkoutGpsAnalysis()
          : _gpsAnalysisFromJson(json['gps_analysis']),
    );

Map<String, dynamic> _$$WorkoutSessionModelImplToJson(
        _$WorkoutSessionModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'activity_type': instance.activityType,
      'started_at': instance.startedAt.toIso8601String(),
      'ended_at': instance.endedAt.toIso8601String(),
      'duration_sec': instance.durationSec,
      'distance_km': instance.distanceKm,
      'steps': instance.steps,
      'avg_speed_kmh': instance.avgSpeedKmh,
      'calories_kcal': instance.caloriesKcal,
      'mode': instance.mode,
      'created_at': instance.createdAt.toIso8601String(),
      'lap_splits': _lapSplitsToJson(instance.lapSplits),
      'gps_analysis': _gpsAnalysisToJson(instance.gpsAnalysis),
    };
