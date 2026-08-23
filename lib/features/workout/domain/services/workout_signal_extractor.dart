import 'dart:math' as math;
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_signals.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

/// Deterministic signal extraction service for AI Post-Workout Insights.
/// Implements mathematical formulas for Pace Fatigue Slope, Pace CV, Rest Ratio,
/// GPS Reliability, and Baseline Z-Scores.
class WorkoutSignalExtractor {
  const WorkoutSignalExtractor();

  /// Extract all weak signals from a workout session and optional 30-day baseline sessions.
  WorkoutAiSignals extractSignals({
    required WorkoutSession workout,
    List<WorkoutSession> last30DaysWorkouts = const [],
    double? userGoalTargetDistanceKm,
  }) {
    final fatigueSlope = computePaceFatigueSlope(workout.lapSplits);
    final paceCv = computePaceConsistencyCv(workout.lapSplits);
    final restRatio = computeRestRatio(
      restDurationSec: workout.gpsAnalysis.restDurationSec,
      totalDurationSec: workout.durationSec,
    );
    final gpsReliability = computeGpsReliabilityScore(workout);

    final paceZScore = computeBaselinePaceZScore(workout, last30DaysWorkouts);
    final distanceZScore = computeBaselineDistanceZScore(workout, last30DaysWorkouts);
    final goalAlign = evaluateGoalAlignment(workout, userGoalTargetDistanceKm);
    final volume7d = computeRecent7DayVolumeKm(last30DaysWorkouts);

    return WorkoutAiSignals(
      paceFatigueSlope: fatigueSlope,
      paceConsistencyCv: paceCv,
      restRatio: restRatio,
      gpsReliabilityScore: gpsReliability,
      baselinePaceZScore: paceZScore,
      baselineDistanceZScore: distanceZScore,
      goalAlignment: goalAlign,
      recent7dVolumeKm: volume7d,
    );
  }

  /// Calculates Pace Fatigue Slope using Ordinary Least Squares (OLS) Linear Regression
  /// y = slope * x + intercept, where x is lap index (1, 2, ... n) and y is paceMinPerKm.
  /// Slope > 0 means athlete is slowing down (fatigue).
  /// Slope < 0 means athlete is speeding up (negative split).
  double computePaceFatigueSlope(List<WorkoutLapSplit> splits) {
    if (splits.length < 2) return 0.0;

    final n = splits.length;
    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumXX = 0.0;

    for (int i = 0; i < n; i++) {
      final x = (i + 1).toDouble();
      final y = splits[i].paceMinPerKm;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }

    final denominator = (n * sumXX) - (sumX * sumX);
    if (denominator.abs() < 1e-9) return 0.0;

    final slope = ((n * sumXY) - (sumX * sumY)) / denominator;
    // Round to 4 decimal places
    return (slope * 10000).roundToDouble() / 10000;
  }

  /// Calculates Pace Coefficient of Variation (CV = stddev / mean).
  /// Measures pace consistency across laps. CV < 0.10 indicates highly steady pacing.
  double computePaceConsistencyCv(List<WorkoutLapSplit> splits) {
    if (splits.isEmpty) return 0.0;

    final paces = splits.map((s) => s.paceMinPerKm).where((p) => p > 0).toList();
    if (paces.isEmpty) return 0.0;

    final mean = paces.reduce((a, b) => a + b) / paces.length;
    if (mean <= 0.0) return 0.0;

    double varianceSum = 0.0;
    for (final p in paces) {
      varianceSum += (p - mean) * (p - mean);
    }
    final variance = varianceSum / paces.length;
    final stdDev = math.sqrt(variance);

    final cv = stdDev / mean;
    return (cv * 10000).roundToDouble() / 10000;
  }

  /// Calculates Rest Time Ratio = restDurationSec / totalDurationSec
  double computeRestRatio({
    required int restDurationSec,
    required int totalDurationSec,
  }) {
    if (totalDurationSec <= 0) return 0.0;
    final ratio = restDurationSec / totalDurationSec;
    return math.min(1.0, math.max(0.0, (ratio * 10000).roundToDouble() / 10000));
  }

  /// Calculates GPS Reliability Score based on valid distance vs display distance ratio
  /// and valid points percentage.
  double computeGpsReliabilityScore(WorkoutSession workout) {
    if (workout.distanceKm <= 0) return 1.0;

    final validDist = workout.gpsAnalysis.validDistanceKm;
    final displayDist = workout.distanceKm;

    if (validDist <= 0) return 0.95; // Default fallback if no detailed GPS breakdown

    final distRatio = math.min(validDist, displayDist) / math.max(validDist, displayDist);
    return (distRatio * 100).roundToDouble() / 100;
  }

  /// Calculates Baseline Pace Z-score Z = (currentPace - meanPace) / stdDevPace
  /// Negative Z-score means faster than average; Positive means slower.
  double computeBaselinePaceZScore(
    WorkoutSession current,
    List<WorkoutSession> history,
  ) {
    final sameActivity = history
        .where((w) => w.activityType.toLowerCase() == current.activityType.toLowerCase())
        .where((w) => w.distanceKm > 0 && w.durationSec > 0)
        .toList();

    if (sameActivity.length < 3) return 0.0;

    final currentPace = (current.durationSec / 60.0) / current.distanceKm;
    final historyPaces = sameActivity
        .map((w) => (w.durationSec / 60.0) / w.distanceKm)
        .toList();

    final mean = historyPaces.reduce((a, b) => a + b) / historyPaces.length;
    double varSum = 0.0;
    for (final p in historyPaces) {
      varSum += (p - mean) * (p - mean);
    }
    final stdDev = math.sqrt(varSum / historyPaces.length);

    if (stdDev < 0.01) return 0.0;
    final zScore = (currentPace - mean) / stdDev;
    return (zScore * 100).roundToDouble() / 100;
  }

  /// Calculates Baseline Distance Z-score
  double computeBaselineDistanceZScore(
    WorkoutSession current,
    List<WorkoutSession> history,
  ) {
    final sameActivity = history
        .where((w) => w.activityType.toLowerCase() == current.activityType.toLowerCase())
        .where((w) => w.distanceKm > 0)
        .toList();

    if (sameActivity.length < 3) return 0.0;

    final historyDistances = sameActivity.map((w) => w.distanceKm).toList();
    final mean = historyDistances.reduce((a, b) => a + b) / historyDistances.length;
    double varSum = 0.0;
    for (final d in historyDistances) {
      varSum += (d - mean) * (d - mean);
    }
    final stdDev = math.sqrt(varSum / historyDistances.length);

    if (stdDev < 0.01) return 0.0;
    final zScore = (current.distanceKm - mean) / stdDev;
    return (zScore * 100).roundToDouble() / 100;
  }

  /// Evaluates goal alignment relative to target distance
  String evaluateGoalAlignment(WorkoutSession workout, double? targetDistanceKm) {
    if (targetDistanceKm == null || targetDistanceKm <= 0) return 'none';

    final ratio = workout.distanceKm / targetDistanceKm;
    if (ratio >= 1.0) return 'exceeded';
    if (ratio >= 0.8) return 'on_track';
    return 'behind';
  }

  /// Calculates total volume in recent 7 days
  double computeRecent7DayVolumeKm(List<WorkoutSession> history) {
    if (history.isEmpty) return 0.0;

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    double volume = 0.0;
    for (final w in history) {
      if (w.startedAt.isAfter(sevenDaysAgo)) {
        volume += w.distanceKm;
      }
    }
    return (volume * 100).roundToDouble() / 100;
  }
}
