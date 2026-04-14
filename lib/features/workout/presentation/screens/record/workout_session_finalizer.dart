import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';

class WorkoutSessionFinalization {
  final String sessionId;
  final int caloriesBurned;
  final double avgSpeedKmh;
  final WorkoutSession session;

  const WorkoutSessionFinalization({
    required this.sessionId,
    required this.caloriesBurned,
    required this.avgSpeedKmh,
    required this.session,
  });
}

class WorkoutSessionFinalizer {
  const WorkoutSessionFinalizer();

  WorkoutSessionFinalization finalize({
    required WorkoutSessionState state,
    required String userId,
    required DateTime finishedAt,
    required int caloriesBurned,
    required double fallbackStrideLengthMeters,
  }) {
    final durationSec = state.durationSeconds;
    final distanceKm = WorkoutMetricsCalculator.distanceMetersToKm(
      state.distanceMeters,
    );
    final avgSpeedKmh = WorkoutMetricsCalculator.computeAverageSpeedKmh(
      distanceKm: distanceKm,
      durationSec: durationSec,
    );

    var finalSteps = state.stepCount;
    if (finalSteps <= 0 && state.recordingSource != 'step_fallback') {
      final strideToUse = state.strideLengthMeters > 0
          ? state.strideLengthMeters
          : fallbackStrideLengthMeters;
      finalSteps = math.max(0, (state.distanceMeters / strideToUse).round());
    }

    final sessionId = state.sessionId ?? finishedAt.microsecondsSinceEpoch.toString();
    final session = WorkoutSession(
      id: sessionId,
      userId: userId,
      activityType: state.activityType,
      startedAt:
          state.startedAt?.toUtc() ??
          finishedAt.toUtc().subtract(Duration(seconds: durationSec)),
      endedAt: finishedAt.toUtc(),
      durationSec: durationSec,
      distanceKm: distanceKm,
      steps: finalSteps,
      avgSpeedKmh: avgSpeedKmh,
      caloriesKcal: caloriesBurned.toDouble(),
      mode: state.trackingMode,
      createdAt: finishedAt.toUtc(),
      lapSplits: state.lapSplits,
    );

    return WorkoutSessionFinalization(
      sessionId: sessionId,
      caloriesBurned: caloriesBurned,
      avgSpeedKmh: avgSpeedKmh,
      session: session,
    );
  }
}
