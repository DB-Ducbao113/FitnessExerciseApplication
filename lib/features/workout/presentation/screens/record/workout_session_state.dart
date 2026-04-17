import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:latlong2/latlong.dart';

enum RecordingState {
  idle,
  initializing,
  active,
  paused,
  stopping,
  finished,
  error,
}

class GpsGapSegment {
  final LatLng start;
  final LatLng end;
  final double durationSec;

  const GpsGapSegment({
    required this.start,
    required this.end,
    required this.durationSec,
  });
}

class WorkoutSessionState {
  final RecordingState status;
  final String? sessionId;
  final String activityType;

  final String trackingMode;
  final String environmentHint;
  final String recordingSource;
  final bool gpsFallbackActive;
  final bool modeDecisionLocked;

  final int durationSeconds;
  final int movingTimeSeconds;
  final double distanceMeters;
  final double speedKmh;
  final double avgSpeedKmh;
  final int stepCount;
  final double strideLengthMeters;
  final int caloriesBurned;
  final List<LatLng> routePoints;
  final List<WorkoutLapSplit> lapSplits;
  final WorkoutGpsAnalysis gpsAnalysis;

  final LatLng? initialPosition;
  final LatLng? currentLatLng;
  final bool isIndoorSyntheticRoute;
  final double indoorSyntheticHeadingDeg;
  final LatLng? gpsGapMarker;
  final List<GpsGapSegment> gpsGapSegments;
  final bool followUser;
  final bool isAutoPaused;
  final bool isGpsSignalWeak;
  final double lastGpsGapDurationSec;
  final int pausedAutoStopRemainingSeconds;
  final int recenterRequestId;
  final String? errorMessage;
  final DateTime? startedAt;

  double get paceMinPerKm {
    if (avgSpeedKmh < 0.3) return 0;
    return 60.0 / avgSpeedKmh;
  }

  WorkoutSessionState({
    required this.status,
    this.sessionId,
    required this.activityType,
    required this.trackingMode,
    this.environmentHint = 'detecting',
    this.recordingSource = 'gps',
    this.gpsFallbackActive = false,
    this.modeDecisionLocked = false,
    this.durationSeconds = 0,
    this.movingTimeSeconds = 0,
    this.distanceMeters = 0,
    this.speedKmh = 0,
    this.avgSpeedKmh = 0,
    this.stepCount = 0,
    this.strideLengthMeters = 0.75,
    this.caloriesBurned = 0,
    this.routePoints = const [],
    this.lapSplits = const [],
    this.gpsAnalysis = const WorkoutGpsAnalysis(),
    this.initialPosition,
    this.currentLatLng,
    this.isIndoorSyntheticRoute = false,
    this.indoorSyntheticHeadingDeg = 0,
    this.gpsGapMarker,
    this.gpsGapSegments = const [],
    this.followUser = true,
    this.isAutoPaused = false,
    this.isGpsSignalWeak = false,
    this.lastGpsGapDurationSec = 0,
    this.pausedAutoStopRemainingSeconds = 0,
    this.recenterRequestId = 0,
    this.errorMessage,
    this.startedAt,
  });

  WorkoutSessionState copyWith({
    RecordingState? status,
    String? sessionId,
    String? activityType,
    String? trackingMode,
    String? environmentHint,
    String? recordingSource,
    bool? gpsFallbackActive,
    bool? modeDecisionLocked,
    int? durationSeconds,
    int? movingTimeSeconds,
    double? distanceMeters,
    double? speedKmh,
    double? avgSpeedKmh,
    int? stepCount,
    double? strideLengthMeters,
    int? caloriesBurned,
    List<LatLng>? routePoints,
    List<WorkoutLapSplit>? lapSplits,
    WorkoutGpsAnalysis? gpsAnalysis,
    LatLng? initialPosition,
    LatLng? currentLatLng,
    bool? isIndoorSyntheticRoute,
    double? indoorSyntheticHeadingDeg,
    LatLng? gpsGapMarker,
    List<GpsGapSegment>? gpsGapSegments,
    bool? followUser,
    bool? isAutoPaused,
    bool? isGpsSignalWeak,
    double? lastGpsGapDurationSec,
    int? pausedAutoStopRemainingSeconds,
    int? recenterRequestId,
    String? errorMessage,
    DateTime? startedAt,
  }) {
    return WorkoutSessionState(
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      activityType: activityType ?? this.activityType,
      trackingMode: trackingMode ?? this.trackingMode,
      environmentHint: environmentHint ?? this.environmentHint,
      recordingSource: recordingSource ?? this.recordingSource,
      gpsFallbackActive: gpsFallbackActive ?? this.gpsFallbackActive,
      modeDecisionLocked: modeDecisionLocked ?? this.modeDecisionLocked,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      movingTimeSeconds: movingTimeSeconds ?? this.movingTimeSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      speedKmh: speedKmh ?? this.speedKmh,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      stepCount: stepCount ?? this.stepCount,
      strideLengthMeters: strideLengthMeters ?? this.strideLengthMeters,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      routePoints: routePoints ?? this.routePoints,
      lapSplits: lapSplits ?? this.lapSplits,
      gpsAnalysis: gpsAnalysis ?? this.gpsAnalysis,
      initialPosition: initialPosition ?? this.initialPosition,
      currentLatLng: currentLatLng ?? this.currentLatLng,
      isIndoorSyntheticRoute:
          isIndoorSyntheticRoute ?? this.isIndoorSyntheticRoute,
      indoorSyntheticHeadingDeg:
          indoorSyntheticHeadingDeg ?? this.indoorSyntheticHeadingDeg,
      gpsGapMarker: gpsGapMarker ?? this.gpsGapMarker,
      gpsGapSegments: gpsGapSegments ?? this.gpsGapSegments,
      followUser: followUser ?? this.followUser,
      isAutoPaused: isAutoPaused ?? this.isAutoPaused,
      isGpsSignalWeak: isGpsSignalWeak ?? this.isGpsSignalWeak,
      lastGpsGapDurationSec:
          lastGpsGapDurationSec ?? this.lastGpsGapDurationSec,
      pausedAutoStopRemainingSeconds:
          pausedAutoStopRemainingSeconds ?? this.pausedAutoStopRemainingSeconds,
      recenterRequestId: recenterRequestId ?? this.recenterRequestId,
      errorMessage: errorMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}
