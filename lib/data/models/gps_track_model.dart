import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fitness_exercise_application/domain/entities/gps_track.dart';

part 'gps_track_model.freezed.dart';
part 'gps_track_model.g.dart';

@freezed
class GPSTrackModel with _$GPSTrackModel {
  const GPSTrackModel._();

  const factory GPSTrackModel({
    int? id,
    required String workoutId,
    required double latitude,
    required double longitude,
    required DateTime recordedAt,
    @Default(false) bool synced,
  }) = _GPSTrackModel;

  factory GPSTrackModel.fromJson(Map<String, dynamic> json) =>
      _$GPSTrackModelFromJson(json);

  /// Convert to domain entity
  GPSTrack toEntity() => GPSTrack(
    id: id,
    workoutId: workoutId,
    latitude: latitude,
    longitude: longitude,
    recordedAt: recordedAt,
  );

  /// Create from domain entity
  factory GPSTrackModel.fromEntity(GPSTrack track, {bool synced = false}) =>
      GPSTrackModel(
        id: track.id,
        workoutId: track.workoutId,
        latitude: track.latitude,
        longitude: track.longitude,
        recordedAt: track.recordedAt,
        synced: synced,
      );

  /// Convert to SQLite map
  Map<String, dynamic> toSQLite() => {
    if (id != null) 'id': id,
    'workout_id': workoutId,
    'latitude': latitude,
    'longitude': longitude,
    'recorded_at': recordedAt.millisecondsSinceEpoch,
    'synced': synced ? 1 : 0,
  };

  /// Create from SQLite map
  factory GPSTrackModel.fromSQLite(Map<String, dynamic> map) => GPSTrackModel(
    id: map['id'] as int?,
    workoutId: map['workout_id'] as String,
    latitude: map['latitude'] as double,
    longitude: map['longitude'] as double,
    recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recorded_at'] as int),
    synced: map['synced'] == 1,
  );
}
