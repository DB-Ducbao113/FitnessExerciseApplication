import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';

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
    if (durationSeconds <= 0) return '0s';

    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      if (seconds == 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h ${minutes}m ${seconds}s';
    }

    if (minutes > 0) {
      if (seconds == 0) {
        return '${minutes}m';
      }
      return '${minutes}m ${seconds}s';
    }

    return '${seconds}s';
  }

  /// Format elapsed duration in clock style for workout screens.
  static String formatElapsedClock(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format distance.
  static String formatDistance(double distanceKm) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Compute average speed from persisted distance and duration.
  static double computeAverageSpeedKmh({
    required double distanceKm,
    required int durationSec,
  }) {
    return WorkoutMetricsCalculator.computeAverageSpeedKmh(
      distanceKm: distanceKm,
      durationSec: durationSec,
    );
  }

  /// Format pace from speed in km/h.
  static String formatPaceFromSpeedKmh(double speedKmh) {
    if (speedKmh < 0.1) return '--';
    final totalSeconds = (3600 / speedKmh).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  /// Format pace directly from persisted distance and duration.
  static String formatPaceFromDistanceAndDuration({
    required double distanceKm,
    required int durationSec,
  }) {
    final speedKmh = computeAverageSpeedKmh(
      distanceKm: distanceKm,
      durationSec: durationSec,
    );
    return formatPaceFromSpeedKmh(speedKmh);
  }

  /// Format speed directly from persisted distance and duration.
  static String formatSpeedFromDistanceAndDuration({
    required double distanceKm,
    required int durationSec,
  }) {
    final speed = computeAverageSpeedKmh(
      distanceKm: distanceKm,
      durationSec: durationSec,
    );
    if (speed <= 0) return '--';
    return speed.toStringAsFixed(speed >= 10 ? 0 : 1);
  }

  /// Format activity label.
  static String formatActivityType(String activityType) {
    if (activityType.isEmpty) return activityType;
    return activityType[0].toUpperCase() + activityType.substring(1);
  }
}
