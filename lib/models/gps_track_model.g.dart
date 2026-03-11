// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gps_track_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GPSTrackModelImpl _$$GPSTrackModelImplFromJson(Map<String, dynamic> json) =>
    _$GPSTrackModelImpl(
      id: (json['id'] as num?)?.toInt(),
      workoutId: json['workoutId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      synced: json['synced'] as bool? ?? false,
    );

Map<String, dynamic> _$$GPSTrackModelImplToJson(_$GPSTrackModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workoutId': instance.workoutId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'recordedAt': instance.recordedAt.toIso8601String(),
      'synced': instance.synced,
    };
