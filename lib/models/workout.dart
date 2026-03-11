import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout.freezed.dart';

@freezed
class Workout with _$Workout {
  const factory Workout({
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
  }) = _Workout;
}
