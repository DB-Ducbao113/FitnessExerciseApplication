// Shared workout formatters.

class WorkoutFormatters {
  /// Format calories.
  static String formatCalories(int calories) {
    return '$calories kcal';
  }

  /// Format duration from minutes.
  static String formatDuration(int durationMinutes) {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }

    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}min';
  }

  /// Format duration from seconds.
  static String formatDurationFromSeconds(int durationSeconds) {
    final minutes = (durationSeconds / 60).round();
    return formatDuration(minutes);
  }

  /// Format distance.
  static String formatDistance(double distanceKm) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Format activity label.
  static String formatActivityType(String activityType) {
    if (activityType.isEmpty) return activityType;
    return activityType[0].toUpperCase() + activityType.substring(1);
  }
}
