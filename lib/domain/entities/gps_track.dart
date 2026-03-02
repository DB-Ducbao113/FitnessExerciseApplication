import 'package:freezed_annotation/freezed_annotation.dart';

part 'gps_track.freezed.dart';

@freezed
class GPSTrack with _$GPSTrack {
  const factory GPSTrack({
    required int? id,
    required String workoutId,
    required double latitude,
    required double longitude,
    required DateTime recordedAt,
  }) = _GPSTrack;
}
