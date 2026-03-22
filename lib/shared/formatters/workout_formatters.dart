// Utility functions for formatting workout data consistently across the app.

class WorkoutFormatters {
  /// Format calories with "kcal" suffix
  /// Example: 280 -> "280 kcal"
  static String formatCalories(int calories) {
    return '$calories kcal';
  }

  /// Format duration in minutes to readable format
  /// Examples:
  /// - 30 -> "30 min"
  /// - 90 -> "1h 30min"
  /// - 120 -> "2h"
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

  /// Format duration from seconds to readable format
  /// Example: 1800 -> "30 min"
  static String formatDurationFromSeconds(int durationSeconds) {
    final minutes = (durationSeconds / 60).round();
    return formatDuration(minutes);
  }

  /// Format distance with "km" suffix
  /// Example: 5.2 -> "5.2 km"
  static String formatDistance(double distanceKm) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Format activity type to display format
  /// Example: "running" -> "Running"
  static String formatActivityType(String activityType) {
    if (activityType.isEmpty) return activityType;
    return activityType[0].toUpperCase() + activityType.substring(1);
  }
}
