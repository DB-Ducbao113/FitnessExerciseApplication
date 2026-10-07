import 'package:fitness_exercise_application/core/localization/app_translations.dart';
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
  RecordedWorkoutAssessment assessment, [
  AppLanguage? lang,
]) {
  final isVi = lang == AppLanguage.vi;
  switch (assessment.validityFlag) {
    case WorkoutValidityFlag.verified:
      return isVi
          ? 'Buổi tập GPS đã xác minh.'
          : 'Verified GPS workout.';
    case WorkoutValidityFlag.partial:
      return isVi
          ? 'Một số đoạn lộ trình bị gắn cờ và loại khỏi cự ly mục tiêu.'
          : 'Some route segments were flagged and excluded from goal distance.';
    case WorkoutValidityFlag.unverified:
      return isVi
          ? 'Phát hiện quá nhiều đoạn GPS bất thường. Buổi tập này không tính vào mục tiêu.'
          : 'Too many abnormal GPS segments were detected. This workout is not counted toward goals.';
  }
}

String workoutValidityLabel(WorkoutValidityFlag flag, [AppLanguage? lang]) {
  if (lang == AppLanguage.vi) {
    switch (flag) {
      case WorkoutValidityFlag.verified:
        return 'Đã xác minh';
      case WorkoutValidityFlag.partial:
        return 'Một phần';
      case WorkoutValidityFlag.unverified:
        return 'Chưa xác minh';
    }
  }
  switch (flag) {
    case WorkoutValidityFlag.verified:
      return 'Verified';
    case WorkoutValidityFlag.partial:
      return 'Partial';
    case WorkoutValidityFlag.unverified:
      return 'Unverified';
  }
}

String workoutSegmentReasonLabel(String? reason, [AppLanguage? lang]) {
  final isVi = lang == AppLanguage.vi;
  switch (reason) {
    case 'pace_too_fast':
      return isVi ? 'Tốc độ quá nhanh' : 'Pace too fast';
    case 'pace_too_slow':
      return isVi ? 'Tốc độ quá chậm' : 'Pace too slow';
    case 'low_gps_accuracy':
      return isVi ? 'Độ chính xác GPS thấp' : 'Low GPS accuracy';
    case 'valid':
    case null:
      return isVi ? 'Hợp lệ' : 'Valid';
    default:
      return reason.replaceAll('_', ' ');
  }
}
