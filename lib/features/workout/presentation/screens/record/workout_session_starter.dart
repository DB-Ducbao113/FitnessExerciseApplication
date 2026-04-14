import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';

class WorkoutSessionStartPlan {
  final String sessionId;
  final String activityType;
  final bool requiresGps;
  final double strideLengthMeters;
  final DateTime startedAt;
  final String trackingMode;
  final String environmentHint;
  final String recordingSource;
  final bool modeDecisionLocked;

  const WorkoutSessionStartPlan({
    required this.sessionId,
    required this.activityType,
    required this.requiresGps,
    required this.strideLengthMeters,
    required this.startedAt,
    required this.trackingMode,
    required this.environmentHint,
    required this.recordingSource,
    required this.modeDecisionLocked,
  });
}

class WorkoutSessionStarter {
  const WorkoutSessionStarter();

  WorkoutSessionStartPlan createPlan({
    required String sessionId,
    required String activityType,
    required bool requiresGps,
    required double strideLengthMeters,
    required DateTime startedAt,
    required String outdoorMode,
    required String indoorMode,
    required String recordingSource,
  }) {
    return WorkoutSessionStartPlan(
      sessionId: sessionId,
      activityType: activityType,
      requiresGps: requiresGps,
      strideLengthMeters: strideLengthMeters,
      startedAt: startedAt,
      trackingMode: requiresGps ? outdoorMode : indoorMode,
      environmentHint: requiresGps ? 'detecting' : 'indoor',
      recordingSource: recordingSource,
      modeDecisionLocked: requiresGps,
    );
  }

  WorkoutSessionState applyGpsBootstrap(WorkoutSessionState current) {
    return current.copyWith(
      trackingMode: 'outdoor',
      environmentHint: 'detecting',
      recordingSource: 'gps',
      gpsFallbackActive: false,
      modeDecisionLocked: true,
    );
  }

  WorkoutSessionState applyIndoorBootstrap(WorkoutSessionState current) {
    return current.copyWith(
      trackingMode: 'indoor',
      environmentHint: 'indoor',
      recordingSource: 'step_fallback',
      gpsFallbackActive: true,
      modeDecisionLocked: true,
    );
  }
}
