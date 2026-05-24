import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

class RecordedWorkoutAssessment {
  final bool shouldInvalidateResult;
  final String? reason;
  final WorkoutValidityFlag validityFlag;

  const RecordedWorkoutAssessment({
    required this.shouldInvalidateResult,
    required this.reason,
    required this.validityFlag,
  });
}

RecordedWorkoutAssessment assessRecordedWorkout({
  required WorkoutGpsAnalysis gpsAnalysis,
}) {
  return RecordedWorkoutAssessment(
    shouldInvalidateResult:
        gpsAnalysis.validityFlag == WorkoutValidityFlag.unverified,
    reason: gpsAnalysis.flaggedSegments.isEmpty
        ? null
        : gpsAnalysis.flaggedSegments.first.reason,
    validityFlag: gpsAnalysis.validityFlag,
  );
}

RecordedWorkoutAssessment assessWorkoutSession(WorkoutSession workout) {
  return assessRecordedWorkout(gpsAnalysis: workout.gpsAnalysis);
}

String activityConsistencyWarningText(
  RecordedWorkoutAssessment assessment,
) {
  switch (assessment.validityFlag) {
    case WorkoutValidityFlag.verified:
      return 'Verified GPS workout.';
    case WorkoutValidityFlag.partial:
      return 'Some route segments were flagged and excluded from goal distance.';
    case WorkoutValidityFlag.unverified:
      return 'Too many abnormal GPS segments were detected. This workout is not counted toward goals.';
  }
}

String workoutValidityLabel(WorkoutValidityFlag flag) {
  switch (flag) {
    case WorkoutValidityFlag.verified:
      return 'Verified';
    case WorkoutValidityFlag.partial:
      return 'Partial';
    case WorkoutValidityFlag.unverified:
      return 'Unverified';
  }
}

String workoutSegmentReasonLabel(String? reason) {
  switch (reason) {
    case 'pace_too_fast':
      return 'Pace too fast';
    case 'pace_too_slow':
      return 'Pace too slow';
    case 'low_gps_accuracy':
      return 'Low GPS accuracy';
    case 'valid':
    case null:
      return 'Valid';
    default:
      return reason.replaceAll('_', ' ');
  }
}
