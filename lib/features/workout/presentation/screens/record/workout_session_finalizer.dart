import 'dart:convert';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class WorkoutSessionFinalization {
  final String sessionId;
  final int caloriesBurned;
  final double avgSpeedKmh;
  final WorkoutGpsAnalysis gpsAnalysis;
  final WorkoutSession session;

  const WorkoutSessionFinalization({
    required this.sessionId,
    required this.caloriesBurned,
    required this.avgSpeedKmh,
    required this.gpsAnalysis,
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
    required WorkoutTrackingEngine trackingEngine,
    required List<Position> rawGpsPositions,
    required List<List<LatLng>> filteredRouteSegments,
  }) {
    final gpsAnalysis = trackingEngine.analyzeGpsWorkout(
      GpsWorkoutAnalysisInput(
        rawPositions: rawGpsPositions,
        activityType: state.activityType,
        totalDurationSec: state.durationSeconds,
        fallbackDistanceMeters: state.distanceMeters,
      ),
    );
    final durationSec = state.durationSeconds;
    final distanceKm = gpsAnalysis.totalDistanceKm > 0
        ? gpsAnalysis.totalDistanceKm
        : WorkoutMetricsCalculator.distanceMetersToKm(state.distanceMeters);
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

    final sessionId =
        state.sessionId ?? finishedAt.microsecondsSinceEpoch.toString();
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
      gpsAnalysis: gpsAnalysis,
      filteredRouteJson: _encodeRouteSegments(filteredRouteSegments),
      matchedRouteJson: '[]',
      routeMatchStatus: 'pending',
      routeDistanceSource: 'filtered',
      routeMatchMetricsJson: '{}',
    );

    return WorkoutSessionFinalization(
      sessionId: sessionId,
      caloriesBurned: caloriesBurned,
      avgSpeedKmh: avgSpeedKmh,
      gpsAnalysis: gpsAnalysis,
      session: session,
    );
  }
}

String _encodeRouteSegments(List<List<LatLng>> segments) {
  final jsonSegments = segments
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) => segment
            .map((point) => {'lat': point.latitude, 'lng': point.longitude})
            .toList(growable: false),
      )
      .toList(growable: false);
  return jsonEncode(jsonSegments);
}
