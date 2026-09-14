import 'package:fitness_exercise_application/core/localization/app_translations.dart';

enum WorkoutTargetType {
  none,
  distance, // in km
  duration, // in minutes
  calories, // in kcal
}

class WorkoutTarget {
  final WorkoutTargetType type;
  final double value; // km, minutes, or kcal

  const WorkoutTarget({
    required this.type,
    this.value = 0.0,
  });

  static const free = WorkoutTarget(type: WorkoutTargetType.none);

  String getDisplayTitle(AppLanguage lang) {
    final isVi = lang == AppLanguage.vi;
    switch (type) {
      case WorkoutTargetType.none:
        return isVi ? 'Chạy tự do' : 'Free Workout';
      case WorkoutTargetType.distance:
        return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} km';
      case WorkoutTargetType.duration:
        return isVi ? '${value.toInt()} phút' : '${value.toInt()} mins';
      case WorkoutTargetType.calories:
        return '${value.toInt()} kcal';
    }
  }

  String getDisplaySubtitle(AppLanguage lang) {
    final isVi = lang == AppLanguage.vi;
    switch (type) {
      case WorkoutTargetType.none:
        return isVi ? 'Không giới hạn cự ly & thời gian' : 'No distance or time limits';
      case WorkoutTargetType.distance:
        return isVi ? 'Mục tiêu cự ly đạt được' : 'Target distance to complete';
      case WorkoutTargetType.duration:
        return isVi ? 'Mục tiêu thời lượng vận động' : 'Target active duration';
      case WorkoutTargetType.calories:
        return isVi ? 'Mục tiêu tiêu thụ năng lượng' : 'Target calories to burn';
    }
  }
}
