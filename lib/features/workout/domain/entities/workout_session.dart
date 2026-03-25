import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_session.freezed.dart';

class WorkoutLapSplit {
  final int index;
  final double distanceKm;
  final int durationSeconds;
  final double paceMinPerKm;

  const WorkoutLapSplit({
    required this.index,
    required this.distanceKm,
    required this.durationSeconds,
    required this.paceMinPerKm,
  });

  factory WorkoutLapSplit.fromJson(Map<String, dynamic> json) {
    return WorkoutLapSplit(
      index: json['index'] as int? ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      paceMinPerKm: (json['paceMinPerKm'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'paceMinPerKm': paceMinPerKm,
  };
}

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
    @Default(<WorkoutLapSplit>[]) List<WorkoutLapSplit> lapSplits,
  }) = _WorkoutSession;
}
