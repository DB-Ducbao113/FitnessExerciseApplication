// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkoutModelImpl _$$WorkoutModelImplFromJson(Map<String, dynamic> json) =>
    _$WorkoutModelImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      activityType: json['activityType'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      durationMin: (json['durationMin'] as num?)?.toDouble(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble(),
      calories: (json['calories'] as num?)?.toInt(),
      mode: json['mode'] as String? ?? 'outdoor',
      stepCount: (json['stepCount'] as num?)?.toInt(),
      strideLength: (json['strideLength'] as num?)?.toDouble(),
      estimatedDistanceMeters: (json['estimatedDistanceMeters'] as num?)
          ?.toDouble(),
      synced: json['synced'] as bool? ?? false,
    );

Map<String, dynamic> _$$WorkoutModelImplToJson(_$WorkoutModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'activityType': instance.activityType,
      'startedAt': instance.startedAt.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'distanceKm': instance.distanceKm,
      'durationMin': instance.durationMin,
      'avgSpeedKmh': instance.avgSpeedKmh,
      'calories': instance.calories,
      'mode': instance.mode,
      'stepCount': instance.stepCount,
      'strideLength': instance.strideLength,
      'estimatedDistanceMeters': instance.estimatedDistanceMeters,
      'synced': instance.synced,
    };
