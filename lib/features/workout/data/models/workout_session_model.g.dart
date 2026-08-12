// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkoutSessionModelImpl _$$WorkoutSessionModelImplFromJson(
        Map<String, dynamic> json) =>
    _$WorkoutSessionModelImpl(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      activityType: json['activity_type'] as String? ?? 'running',
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : DateTime.now(),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : DateTime.now(),
      durationSec: (json['duration_sec'] as num?)?.toInt() ?? 0,
      movingTimeSec: (json['moving_time_sec'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      avgSpeedKmh: (json['avg_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      caloriesKcal: (json['calories_kcal'] as num?)?.toDouble() ?? 0.0,
      mode: json['mode'] as String? ?? 'outdoor',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      lapSplits: json['lap_splits'] == null
          ? const <WorkoutLapSplit>[]
          : _lapSplitsFromJson(json['lap_splits']),
      gpsAnalysis: json['gps_analysis'] == null
          ? const WorkoutGpsAnalysis()
          : _gpsAnalysisFromJson(json['gps_analysis']),
      filteredRouteJson: _jsonFieldToString(json['filtered_route_json']),
      matchedRouteJson: _jsonFieldToString(json['matched_route_json']),
      routeMatchStatus: json['route_match_status'] as String? ?? 'pending',
      routeMatchConfidence:
          (json['route_match_confidence'] as num?)?.toDouble(),
      routeDistanceSource:
          json['route_distance_source'] as String? ?? 'filtered',
      matchedDistanceKm: (json['matched_distance_km'] as num?)?.toDouble(),
      routeMatchMetricsJson:
          _jsonMetricsFieldToString(json['route_match_metrics_json']),
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
      'moving_time_sec': instance.movingTimeSec,
      'distance_km': instance.distanceKm,
      'steps': instance.steps,
      'avg_speed_kmh': instance.avgSpeedKmh,
      'calories_kcal': instance.caloriesKcal,
      'mode': instance.mode,
      'created_at': instance.createdAt.toIso8601String(),
      'lap_splits': _lapSplitsToJson(instance.lapSplits),
      'gps_analysis': _gpsAnalysisToJson(instance.gpsAnalysis),
      'filtered_route_json': instance.filteredRouteJson,
      'matched_route_json': instance.matchedRouteJson,
      'route_match_status': instance.routeMatchStatus,
      'route_match_confidence': instance.routeMatchConfidence,
      'route_distance_source': instance.routeDistanceSource,
      'matched_distance_km': instance.matchedDistanceKm,
      'route_match_metrics_json': instance.routeMatchMetricsJson,
    };
