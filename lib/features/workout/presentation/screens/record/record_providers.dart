import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/services/ios_live_activity_service.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

// Constants

const String kOutdoorMode = 'outdoor';
const String kIndoorMode = 'indoor';
const String kAutoTrackingMode = 'auto'; // temporary mode before lock

bool _requiresGpsTracking(String activityType) {
  switch (activityType.toLowerCase()) {
    case 'running':
    case 'walking':
    case 'cycling':
      return true;
    default:
      return false;
  }
}

// Stride

String? _normalizeGender(String? gender) {
  final normalized = gender?.trim().toLowerCase();
  if (normalized == 'female') return 'female';
  if (normalized == 'male') return 'male';
  return null;
}

double _defaultStrideLength(String activityType, String? gender) {
  final isRunning = activityType.toLowerCase().contains('run');
  final normalizedGender = _normalizeGender(gender);
  if (isRunning) {
    return normalizedGender == 'female' ? 0.85 : 0.93;
  }
  return normalizedGender == 'female' ? 0.68 : 0.73;
}

double computeStrideLength({
  required String activityType,
  double? heightCm,
  String? gender,
}) {
  if (heightCm == null || heightCm <= 0) {
    return _defaultStrideLength(activityType, gender);
  }
  final isRunning = activityType.toLowerCase().contains('run');
  final normalizedGender = _normalizeGender(gender);
  final factor = isRunning
      ? (normalizedGender == 'female' ? 0.62 : 0.67)
      : (normalizedGender == 'female' ? 0.40 : 0.43);
  final raw = heightCm * factor / 100;
  return raw.clamp(0.50, 1.50);
}

// State

enum RecordingState { idle, initializing, active, paused, stopping, finished, error }

class WorkoutSessionState {
  final RecordingState status;
  final String? sessionId;
  final String activityType;

  final String trackingMode;
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

  final LatLng? initialPosition;
  final LatLng? currentLatLng;
  final bool followUser;
  final bool isAutoPaused;
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
    this.initialPosition,
    this.currentLatLng,
    this.followUser = true,
    this.isAutoPaused = false,
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
    LatLng? initialPosition,
    LatLng? currentLatLng,
    bool? followUser,
    bool? isAutoPaused,
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
      initialPosition: initialPosition ?? this.initialPosition,
      currentLatLng: currentLatLng ?? this.currentLatLng,
      followUser: followUser ?? this.followUser,
      isAutoPaused: isAutoPaused ?? this.isAutoPaused,
      pausedAutoStopRemainingSeconds:
          pausedAutoStopRemainingSeconds ?? this.pausedAutoStopRemainingSeconds,
      recenterRequestId: recenterRequestId ?? this.recenterRequestId,
      errorMessage: errorMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

// Providers

final workoutSessionProvider =
    StateNotifierProvider.autoDispose<
      WorkoutSessionNotifier,
      WorkoutSessionState
    >((ref) => WorkoutSessionNotifier(ref));

// Notifier

class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  final Ref _ref;

  // Subscriptions
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<int>? _stepSub;
  StreamSubscription<ClassifierEvent>? _classifierSub;

  // Timers
  Timer? _uiTicker;
  Timer? _indoorDistanceTimer;
  Timer? _calorieTimer;
  Timer? _pauseAutoStopTimer;

  final Stopwatch _stopwatch = Stopwatch();
  EnvironmentClassifier? _classifier;

  final _speedSamples = Queue<double>();
  final _routeSampleBuffer = Queue<_RouteSample>();
  static const int _speedWindowSize = 12;
  static const int _routeSampleWindowSize = 5;

  double _weightKg = 60.0;
  double? _heightCm;
  String? _gender;
  DateTime? _lastAcceptedPositionTime;
  DateTime? _lastStepTime;
  // Raw GPS anchor used for distance accumulation only.
  LatLng? _distanceAnchorPoint;
  int _lastSplitElapsedSec = 0;
  double _lastSplitDistanceMeters = 0;
  int _nextLapIndex = 1;
  bool _shouldResetGpsAnchorOnResume = false;
  bool _isStopping = false;
  static const Duration _kPauseAutoStopDelay = Duration(minutes: 2);
  static const Duration _kIndoorWatchdogTick = Duration(seconds: 2);
  static const Duration _kIndoorStepGrace = Duration(seconds: 4);
  static const Duration _kIndoorStallAutoPause = Duration(seconds: 8);
  static const Duration _kRecoveredGpsWindow = Duration(seconds: 3);

  WorkoutSessionNotifier(this._ref)
    : super(
        WorkoutSessionState(
          status: RecordingState.idle,
          activityType: 'Running',
          trackingMode: kAutoTrackingMode,
        ),
      );

  // Profile

  void setUserProfile({double? weightKg, double? heightCm, String? gender}) {
    if (weightKg != null && weightKg > 0) _weightKg = weightKg;
    if (heightCm != null && heightCm > 0) _heightCm = heightCm;
    final normalizedGender = _normalizeGender(gender);
    if (normalizedGender != null) _gender = normalizedGender;

    if ((_heightCm ?? 0) > 0) {
      final stride = computeStrideLength(
        activityType: state.activityType,
        heightCm: _heightCm,
        gender: _gender,
      );
      state = state.copyWith(strideLengthMeters: stride);
    }
  }

  // Public API

  void startWorkout(String activityType) {
    final sessionId = const Uuid().v4();
    final stride = computeStrideLength(
      activityType: activityType,
      heightCm: _heightCm,
      gender: _gender,
    );
    _speedSamples.clear();
    _routeSampleBuffer.clear();
    _lastAcceptedPositionTime = null;
    _lastStepTime = null;
    _distanceAnchorPoint = null;
    _lastSplitElapsedSec = 0;
    _lastSplitDistanceMeters = 0;
    _nextLapIndex = 1;
    _shouldResetGpsAnchorOnResume = false;
    _isStopping = false;

    state = WorkoutSessionState(
      status: RecordingState.initializing,
      sessionId: sessionId,
      activityType: activityType,
      trackingMode: _requiresGpsTracking(activityType)
          ? kOutdoorMode
          : kIndoorMode,
      modeDecisionLocked: _requiresGpsTracking(activityType),
      strideLengthMeters: stride,
      startedAt: DateTime.now(),
      pausedAutoStopRemainingSeconds: 0,
    );
    debugPrint(
      '[Workout] startWorkout $activityType — stride=${stride.toStringAsFixed(2)}m',
    );

    _initServicesInBackground(activityType);
  }

  void onUserDraggedMap() {
    if (!state.followUser) return;
    state = state.copyWith(followUser: false);
  }

  bool requestRecenter() {
    if (state.currentLatLng == null) return false;
    state = state.copyWith(
      followUser: true,
      recenterRequestId: state.recenterRequestId + 1,
    );
    return true;
  }

  Future<void> _initServicesInBackground(String activityType) async {
    if (_requiresGpsTracking(activityType)) {
      _classifierSub?.cancel();
      _classifier?.dispose();
      _classifier = null;
      _classifierSub = null;
      if (mounted) {
        state = state.copyWith(
          trackingMode: kOutdoorMode,
          modeDecisionLocked: true,
        );
      }
      _startGpsBackground(activityType);
    } else if (mounted) {
      _classifier?.dispose();
      _classifier = null;
      _classifierSub?.cancel();
      _classifierSub = null;
      state = state.copyWith(
        trackingMode: kIndoorMode,
        modeDecisionLocked: true,
      );
      _refreshIndoorWatchdog();
    }
    _startStepCounterBackground();

    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    _startCalorieTimer();
    _refreshIndoorWatchdog();

    if (mounted) {
      state = state.copyWith(
        status: RecordingState.active,
        durationSeconds: 0,
        movingTimeSeconds: 0,
        distanceMeters: 0,
        speedKmh: 0,
        stepCount: 0,
        caloriesBurned: 0,
        lapSplits: const [],
        isAutoPaused: false,
      );
      debugPrint('[Workout] status=active, sensors starting in background');
      _syncLiveActivityState();
    }
  }

  // GPS

  Future<void> _startGpsBackground(String activityType) async {
    debugPrint('[Workout] GPS startup begin at ${DateTime.now()}');
    final locationService = _ref.read(locationTrackingServiceProvider);

    final lastKnown = await locationService.getLastKnownPosition();
    if (lastKnown != null && mounted) {
      final latLng = LatLng(lastKnown.latitude, lastKnown.longitude);
      state = state.copyWith(initialPosition: latLng, currentLatLng: latLng);
    }

    try {
      await locationService.startTracking(activityType);
      _locationSub?.cancel();
      _locationSub = locationService.positionStream.listen(_onPosition);
      debugPrint('[Workout] GPS position subscription started');
    } catch (e) {
      debugPrint('[Workout] GPS error: $e');
      if (mounted) {
        state = state.copyWith(
          trackingMode: kIndoorMode,
          modeDecisionLocked: true,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
        _refreshIndoorWatchdog();
        _startCalorieTimer();
      }
    }
  }

  // Steps

  Future<void> _startStepCounterBackground() async {
    debugPrint('[Workout] pedometer startup begin at ${DateTime.now()}');
    try {
      final stepService = _ref.read(stepTrackingServiceProvider);
      await stepService.startTracking();
      _stepSub?.cancel();
      _stepSub = stepService.stepStream.listen(_onStep);
      debugPrint('[Workout] pedometer subscription active');
    } catch (e) {
      debugPrint('[Workout] pedometer error: $e');
      if (mounted) {
        state = state.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  // Session control

  Future<void> pauseWorkout() async {
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _stepSub?.pause();
    state = state.copyWith(
      status: RecordingState.paused,
      speedKmh: 0,
      isAutoPaused: false,
      pausedAutoStopRemainingSeconds: _kPauseAutoStopDelay.inSeconds,
    );
    _syncLiveActivityState();
    _startPauseAutoStopCountdown();
  }

  Future<void> resumeWorkout() async {
    _cancelPauseAutoStopCountdown();
    _stopwatch.start();
    _stepSub?.resume();
    _speedSamples.clear();
    _shouldResetGpsAnchorOnResume = true;
    _startTicker();
    _startCalorieTimer();
    state = state.copyWith(
      status: RecordingState.active,
      speedKmh: 0,
      isAutoPaused: false,
      pausedAutoStopRemainingSeconds: 0,
    );
    _refreshIndoorWatchdog();
    _syncLiveActivityState();
  }

  Future<void> stopWorkout() async {
    if (_isStopping) {
      debugPrint('[Workout] stopWorkout ignored — stop already in progress');
      return;
    }
    _isStopping = true;

    try {
    _cancelPauseAutoStopCountdown();
    state = state.copyWith(
      status: RecordingState.stopping,
      speedKmh: 0,
      isAutoPaused: false,
      pausedAutoStopRemainingSeconds: 0,
    );
    final locationService = _ref.read(locationTrackingServiceProvider);

    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _uiTicker = null;
    _indoorDistanceTimer = null;
    _calorieTimer = null;

    locationService.stopTracking();
    _locationSub?.cancel();
    _locationSub = null;

    _ref.read(stepTrackingServiceProvider).stopTracking();
    _stepSub?.cancel();
    _stepSub = null;

    _classifierSub?.cancel();
    _classifierSub = null;
    _classifier?.dispose();
    _classifier = null;

    // Final snapshot
    final finalCalories = _computeCalories();
    final finalDurationSec = state.durationSeconds;
    final finalMovingSec = state.movingTimeSeconds;
    final finalDistKm = state.distanceMeters / 1000.0;
    final finalAvgSpeedKmh = finalMovingSec > 0
        ? finalDistKm / (finalMovingSec / 3600.0)
        : 0.0;

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception("Cannot save workout: No active user");

    // Prefer sensor steps, otherwise estimate from stride.
    int finalSteps = state.stepCount;
    if (finalSteps <= 0 && state.trackingMode != kIndoorMode) {
      final strideToUse = state.strideLengthMeters > 0
          ? state.strideLengthMeters
          : _defaultStrideLength(state.activityType, _gender);
      finalSteps = math.max(0, (state.distanceMeters / strideToUse).round());
    }

    final sessionId = state.sessionId ?? const Uuid().v4();
    final session = WorkoutSession(
      id: sessionId,
      userId: userId,
      activityType: state.activityType,
      startedAt:
          state.startedAt?.toUtc() ??
          DateTime.now().toUtc().subtract(Duration(seconds: finalDurationSec)),
      endedAt: DateTime.now().toUtc(),
      durationSec: finalDurationSec,
      distanceKm: finalDistKm,
      steps: finalSteps,
      avgSpeedKmh: finalAvgSpeedKmh,
      caloriesKcal: finalCalories.toDouble(),
      mode: state.trackingMode,
      createdAt: DateTime.now().toUtc(),
      lapSplits: state.lapSplits,
    );

    if (mounted) {
      final endedState = state.copyWith(
        status: RecordingState.finished,
        caloriesBurned: finalCalories,
        avgSpeedKmh: finalAvgSpeedKmh,
        sessionId: sessionId,
        pausedAutoStopRemainingSeconds: 0,
      );
      state = endedState;
      await _endLiveActivity(endedState);
    }

    await _ref.read(workoutListProvider.notifier).saveSession(session);
    } finally {
      _isStopping = false;
    }
  }

  // Calories

  int _computeCalories({double? distanceMeters, double? speedKmh}) {
    final distKm = (distanceMeters ?? state.distanceMeters) / 1000.0;
    if (distKm <= 0) return 0;

    final profile = UserProfile(
      id: 'active-session',
      userId: _ref.read(currentUserIdProvider) ?? 'active-session',
      weightKg: _weightKg,
      heightM: ((_heightCm ?? 170) / 100).clamp(0.5, 2.5),
      age: 0,
      gender: _gender ?? 'male',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    return profile
        .calculateCalories(
          activityType: state.activityType,
          distanceKm: distKm,
          speedKmh: speedKmh ?? state.speedKmh,
        )
        .round();
  }

  void _startCalorieTimer() {
    _calorieTimer?.cancel();
    _calorieTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (state.status != RecordingState.active) return;
      final kcal = _computeCalories();
      state = state.copyWith(caloriesBurned: kcal);
      debugPrint(
        '[Calories] ${kcal}kcal — dist=${(state.distanceMeters / 1000).toStringAsFixed(2)}km weight=${_weightKg}kg',
      );
    });
  }

  void _syncLiveActivityState() {
    final liveActivity = _ref.read(iosLiveActivityServiceProvider);
    unawaited(
      liveActivity.syncWorkout(
        activityType: state.activityType,
        trackingMode: state.trackingMode,
        status: state.status.name,
        durationSeconds: state.durationSeconds,
        distanceMeters: state.distanceMeters,
        avgSpeedKmh: state.avgSpeedKmh,
        caloriesBurned: state.caloriesBurned,
      ),
    );
  }

  Future<void> _endLiveActivity(WorkoutSessionState finalState) {
    final liveActivity = _ref.read(iosLiveActivityServiceProvider);
    return liveActivity.endWorkout(
      activityType: finalState.activityType,
      trackingMode: finalState.trackingMode,
      durationSeconds: finalState.durationSeconds,
      distanceMeters: finalState.distanceMeters,
      avgSpeedKmh: finalState.avgSpeedKmh,
      caloriesBurned: finalState.caloriesBurned,
    );
  }

  void _startPauseAutoStopCountdown() {
    _cancelPauseAutoStopCountdown();
    final deadline = DateTime.now().add(_kPauseAutoStopDelay);
    _pauseAutoStopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.status != RecordingState.paused) {
        timer.cancel();
        return;
      }

      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(pausedAutoStopRemainingSeconds: 0);
        debugPrint('[Workout] pause timeout reached, auto-finishing workout');
        unawaited(stopWorkout());
        return;
      }

      state = state.copyWith(pausedAutoStopRemainingSeconds: remaining);
    });
  }

  void _cancelPauseAutoStopCountdown() {
    _pauseAutoStopTimer?.cancel();
    _pauseAutoStopTimer = null;
  }

  // Mode changes

  // ignore: unused_element
  void _onEnvironmentChanged(ClassifierEvent event) {
    if (!mounted) return;
    if (state.status != RecordingState.active) return;

    final newMode = event.environment == TrackingEnvironment.outdoor
        ? kOutdoorMode
        : kIndoorMode;

    if (state.trackingMode == newMode && state.modeDecisionLocked) return;
    if (newMode == kOutdoorMode) {
      _shouldResetGpsAnchorOnResume = true;
      _speedSamples.clear();
    }
    state = state.copyWith(
      trackingMode: newMode,
      modeDecisionLocked: true,
      isAutoPaused: false,
    );

    _refreshIndoorWatchdog();
    _startCalorieTimer();
    debugPrint('[Workout] trackingMode -> $newMode (${event.reason})');
  }

  // GPS updates

  void _onPosition(Position position) {
    final livePoint = LatLng(position.latitude, position.longitude);
    final sensorSpeedKmh = position.speed > 0
        ? position.speed.clamp(0.0, 50.0) * 3.6
        : 0.0;

    debugPrint(
      '[GPS] lat=${position.latitude}, lng=${position.longitude}, acc=${position.accuracy}, speed=${position.speed} | mode=${state.trackingMode}',
    );

    if (state.status == RecordingState.paused) {
      _distanceAnchorPoint = livePoint;
      _lastAcceptedPositionTime = position.timestamp;
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: 0,
        isAutoPaused: false,
      );
      debugPrint('[GPS] paused live update only');
      return;
    }

    if (state.status != RecordingState.active) return;

    _classifier?.addPosition(position);

    // Indoor mode updates marker and speed only.
    if (state.trackingMode == kIndoorMode) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: _computeSmoothedSpeed(),
      );
      return;
    }
    // While auto-detecting, keep the marker live but do not record GPS route yet.
    if (state.trackingMode == kAutoTrackingMode && !state.modeDecisionLocked) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: _computeSmoothedSpeed(),
      );
      return;
    }

    final minSegmentMeters = kDebugLocationMode
        ? 0.25
        : _getMinSegmentMeters(state.activityType);
    final maxAccuracy = kDebugLocationMode
        ? 100.0
        : _getMaxRouteAccuracy(state.activityType);
    final previewAccuracy = kDebugLocationMode
        ? 100.0
        : _getPreviewAccuracy(state.activityType);

    if (position.accuracy <= previewAccuracy) {
      state = state.copyWith(currentLatLng: livePoint);
    }

    // Seed the route with the first accepted point.
    if (state.routePoints.isEmpty) {
      if (position.accuracy > maxAccuracy) {
        debugPrint(
          '[GPS-SKIP] waiting_for_better_first_fix acc=${position.accuracy.toStringAsFixed(1)}m',
        );
        return;
      }
      _lastAcceptedPositionTime = position.timestamp;
      _distanceAnchorPoint = livePoint;
      _pushRouteSample(livePoint, position.accuracy, position.timestamp);
      state = state.copyWith(
        initialPosition: state.initialPosition ?? livePoint,
        currentLatLng: livePoint,
        routePoints: [livePoint],
        speedKmh: 0,
      );
      debugPrint('[GPS-ACCEPT] first route point seeded');
      return;
    }

    if (_shouldResetGpsAnchorOnResume) {
      _shouldResetGpsAnchorOnResume = false;
      _distanceAnchorPoint = livePoint;
      _lastAcceptedPositionTime = position.timestamp;
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: 0,
        isAutoPaused: false,
      );
      debugPrint('[GPS] resume anchor reset');
      return;
    }

    // Filter noisy GPS segments.
    final lastPt = state.routePoints.last;
    final rawDistanceAnchor = _distanceAnchorPoint ?? lastPt;
    _pushRouteSample(livePoint, position.accuracy, position.timestamp);
    var routeCandidate = _stabilizeRoutePoint(
      lastPt,
      livePoint,
      position.accuracy,
    );
    routeCandidate = _smoothRouteCandidate(
      activityType: state.activityType,
      lastPoint: lastPt,
      candidate: routeCandidate,
    );
    routeCandidate = _alignCandidateToRecentHeading(
      activityType: state.activityType,
      routePoints: state.routePoints,
      candidate: routeCandidate,
    );
    final rawSegmentMeters = Geolocator.distanceBetween(
      rawDistanceAnchor.latitude,
      rawDistanceAnchor.longitude,
      livePoint.latitude,
      livePoint.longitude,
    );
    final routeSegmentMeters = Geolocator.distanceBetween(
      lastPt.latitude,
      lastPt.longitude,
      routeCandidate.latitude,
      routeCandidate.longitude,
    );
    final segmentMeters = rawSegmentMeters;

    if (segmentMeters < minSegmentMeters) {
      // Ignore tiny segments.
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: state.speedKmh,
      );
      debugPrint(
        '[GPS-SKIP] segment=${segmentMeters.toStringAsFixed(2)}m < $minSegmentMeters',
      );
      return;
    }

    if (position.accuracy > maxAccuracy) {
      // Ignore low-accuracy samples.
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: state.speedKmh,
      );
      debugPrint(
        '[GPS-SKIP] accuracy=${position.accuracy.toStringAsFixed(2)}m > $maxAccuracy',
      );
      return;
    }

    final maxSpeedMs = _getMaxSpeedMs(state.activityType);
    if (position.speed > 0 && position.speed > maxSpeedMs) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: state.speedKmh,
      );
      debugPrint(
        '[GPS-SKIP] gps_speed=${position.speed.toStringAsFixed(2)}m/s > ${maxSpeedMs.toStringAsFixed(2)}m/s',
      );
      return;
    }

    final previousAcceptedTime = _lastAcceptedPositionTime;
    if (previousAcceptedTime != null) {
      final timeDeltaSec =
          position.timestamp.difference(previousAcceptedTime).inMilliseconds /
          1000.0;
      if (timeDeltaSec > 0) {
        final impliedSpeed = segmentMeters / timeDeltaSec;
        if (impliedSpeed > maxSpeedMs * 1.2) {
          state = state.copyWith(
            currentLatLng: livePoint,
            speedKmh: state.speedKmh,
          );
          debugPrint(
            '[GPS-SKIP] implied_speed=${impliedSpeed.toStringAsFixed(2)}m/s',
          );
          return;
        }
      }
    }

    final canUseBearingFilter =
        state.activityType.toLowerCase() == 'cycling' &&
        state.routePoints.length >= 2 &&
        routeSegmentMeters > 22;
    if (canUseBearingFilter) {
      final previousBearing = _computeBearing(
        state.routePoints[state.routePoints.length - 2],
        lastPt,
      );
      final currentBearing = _computeBearing(lastPt, routeCandidate);
      final bearingDelta = _bearingDelta(previousBearing, currentBearing);
      final maxBearingDelta = 150.0;
      final shouldRejectTurn =
          bearingDelta > maxBearingDelta && rawSegmentMeters < 18;
      if (shouldRejectTurn) {
        state = state.copyWith(
          currentLatLng: livePoint,
          speedKmh: state.speedKmh,
        );
        debugPrint(
          '[GPS-SKIP] bearing_delta=${bearingDelta.toStringAsFixed(1)}°',
        );
        return;
      }
    }

    final timeDeltaSec = previousAcceptedTime == null
        ? 0.0
        : position.timestamp.difference(previousAcceptedTime).inMilliseconds /
              1000.0;
    final segmentSpeedKmh = timeDeltaSec > 0
        ? (segmentMeters / timeDeltaSec) * 3.6
        : sensorSpeedKmh;
    final candidateSpeedKmh = segmentSpeedKmh > 0
        ? segmentSpeedKmh
        : sensorSpeedKmh;
    if (candidateSpeedKmh > 0) {
      _addSpeedSample(candidateSpeedKmh);
    }
    final smoothedKmh = _computeSmoothedSpeed();

    final updatedRoute = List<LatLng>.from(state.routePoints)
      ..add(routeCandidate);
    final newDistanceM = state.distanceMeters + segmentMeters;
    final newCalories = _computeCalories(
      distanceMeters: newDistanceM,
      speedKmh: smoothedKmh,
    );
    _lastAcceptedPositionTime = position.timestamp;
    _distanceAnchorPoint = livePoint;
    _setAutoPauseState(false);

    state = state.copyWith(
      currentLatLng: livePoint,
      routePoints: updatedRoute,
      distanceMeters: newDistanceM,
      speedKmh: smoothedKmh,
      lapSplits: _captureLapSplits(newDistanceM),
      caloriesBurned: newCalories,
      isAutoPaused: false,
    );

    debugPrint(
      '[GPS-ACCEPT] segment=${segmentMeters.toStringAsFixed(2)}m raw=${rawSegmentMeters.toStringAsFixed(2)}m route=${routeSegmentMeters.toStringAsFixed(2)}m total=${newDistanceM.toStringAsFixed(2)}m routePoints=${updatedRoute.length}',
    );
  }

  // Step updates
  void _onStep(int sessionSteps) {
    if (state.status != RecordingState.active) return;

    final delta = sessionSteps - state.stepCount;
    if (delta <= 0) return;

    _classifier?.addStepDelta(delta);
    state = state.copyWith(stepCount: sessionSteps);

    if (state.trackingMode == kOutdoorMode) {
      final secondsSinceGps = _lastAcceptedPositionTime == null
          ? 999
          : DateTime.now().difference(_lastAcceptedPositionTime!).inSeconds;
      if (sessionSteps >= 8 && secondsSinceGps >= 12) {
        state = state.copyWith(
          trackingMode: kIndoorMode,
          modeDecisionLocked: true,
        );
        _refreshIndoorWatchdog();
        debugPrint('[Workout] outdoor fallback -> indoor from step tracking');
      }
    }

    if (state.trackingMode == kIndoorMode) {
      _updateIndoorDistanceFromSteps(delta);
    }
  }

  // Indoor distance

  void _updateIndoorDistanceFromSteps(int newSteps) {
    final addedDistM = newSteps * state.strideLengthMeters;
    final now = DateTime.now();

    if (_lastStepTime != null) {
      final secSinceLastStep =
          now.difference(_lastStepTime!).inMilliseconds / 1000.0;
      if (secSinceLastStep > 0) {
        final instantSpeedKmh = (addedDistM / secSinceLastStep) * 3.6;
        _addSpeedSample(instantSpeedKmh);
      }
    }

    _lastStepTime = now;
    _setAutoPauseState(false);

    final newDistanceM = state.distanceMeters + addedDistM;
    final newSpeedKmh = _computeSmoothedSpeed();
    final newCalories = _computeCalories(
      distanceMeters: newDistanceM,
      speedKmh: newSpeedKmh,
    );

    state = state.copyWith(
      distanceMeters: newDistanceM,
      speedKmh: newSpeedKmh,
      lapSplits: _captureLapSplits(newDistanceM),
      caloriesBurned: newCalories,
      isAutoPaused: false,
    );
  }

  void _refreshIndoorWatchdog() {
    _indoorDistanceTimer?.cancel();
    _indoorDistanceTimer = null;

    if (state.status != RecordingState.active || state.trackingMode != kIndoorMode) {
      return;
    }

    _indoorDistanceTimer = Timer.periodic(_kIndoorWatchdogTick, (_) {
      if (!mounted) return;
      if (state.status != RecordingState.active || state.trackingMode != kIndoorMode) {
        _indoorDistanceTimer?.cancel();
        _indoorDistanceTimer = null;
        return;
      }

      final now = DateTime.now();
      final secondsSinceStep = _lastStepTime == null
          ? 999
          : now.difference(_lastStepTime!).inSeconds;
      final secondsSinceGps = _lastAcceptedPositionTime == null
          ? 999
          : now.difference(_lastAcceptedPositionTime!).inSeconds;

      if (secondsSinceStep <= _kIndoorStepGrace.inSeconds) {
        return;
      }

      if (secondsSinceGps <= _kRecoveredGpsWindow.inSeconds) {
        _shouldResetGpsAnchorOnResume = true;
        _speedSamples.clear();
        state = state.copyWith(
          trackingMode: kOutdoorMode,
          modeDecisionLocked: true,
          isAutoPaused: false,
          speedKmh: 0,
        );
        _refreshIndoorWatchdog();
        debugPrint(
          '[Workout] indoor watchdog -> outdoor '
          '(gps recovered, step stall ${secondsSinceStep}s)',
        );
        return;
      }

      if (secondsSinceStep >= _kIndoorStallAutoPause.inSeconds) {
        state = state.copyWith(speedKmh: 0, isAutoPaused: true);
        debugPrint(
          '[Workout] indoor watchdog stall '
          '(steps=${secondsSinceStep}s gps=${secondsSinceGps}s)',
        );
      }
    });
  }

  // UI ticker

  void _startTicker() {
    _setAutoPauseState(false);
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final elapsedSec = _stopwatch.elapsed.inSeconds;
      var liveSpeedKmh = state.speedKmh;
      var movingTimeSec = state.movingTimeSeconds;
      var isAutoPaused = state.isAutoPaused;

      if (state.trackingMode == kIndoorMode &&
          _lastStepTime != null &&
          DateTime.now().difference(_lastStepTime!).inSeconds >= 3) {
        liveSpeedKmh = 0;
        isAutoPaused = true;
        _setAutoPauseState(true);
      }

      if (state.trackingMode != kIndoorMode &&
          _lastAcceptedPositionTime != null &&
          DateTime.now().difference(_lastAcceptedPositionTime!).inSeconds >=
              5) {
        liveSpeedKmh = 0;
        isAutoPaused = true;
      }

      if (_isMoving(liveSpeedKmh, state.activityType)) {
        movingTimeSec += 1;
        isAutoPaused = false;
        _setAutoPauseState(false);
      }

      final distKm = state.distanceMeters / 1000.0;
      final elapsedHours = elapsedSec / 3600.0;
      final avg = elapsedHours > 0 && distKm > 0.001
          ? (distKm / elapsedHours)
          : 0.0;

      state = state.copyWith(
        durationSeconds: elapsedSec,
        movingTimeSeconds: movingTimeSec,
        speedKmh: liveSpeedKmh,
        avgSpeedKmh: avg,
        isAutoPaused: isAutoPaused,
      );
      _syncLiveActivityState();
    });
  }

  double _computeSmoothedSpeed() {
    if (_speedSamples.isEmpty) return 0;
    final samples = _speedSamples.toList();
    double weightedSum = 0;
    double weightSum = 0;
    for (var i = 0; i < samples.length; i++) {
      final weight = (i + 1).toDouble();
      weightedSum += samples[i] * weight;
      weightSum += weight;
    }
    return weightSum > 0 ? weightedSum / weightSum : 0;
  }

  void _addSpeedSample(double speedKmh) {
    _speedSamples.addLast(speedKmh.clamp(0.0, 60.0));
    if (_speedSamples.length > _speedWindowSize) {
      _speedSamples.removeFirst();
    }
  }

  bool _isMoving(double speedKmh, String activityType) {
    return speedKmh >= _getMinMovingSpeedKmh(activityType);
  }

  double _getMinMovingSpeedKmh(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 0.10;
      case 'cycling':
        return 0.4;
      case 'running':
      default:
        return 0.20;
    }
  }

  double _getMaxSpeedMs(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 3.5;
      case 'cycling':
        return 20.0;
      case 'running':
        return 12.0;
      default:
        return 15.0;
    }
  }

  double _getMinSegmentMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 0.8;
      case 'cycling':
        return 2.0;
      case 'running':
        return 0.5;
      default:
        return 0.4;
    }
  }

  double _getMaxRouteAccuracy(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 25.0;
      case 'running':
        return 35.0;
      case 'walking':
        return 35.0;
      default:
        return 35.0;
    }
  }

  double _getPreviewAccuracy(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 25.0;
      case 'running':
        return 35.0;
      case 'walking':
        return 35.0;
      default:
        return 35.0;
    }
  }

  double _computeBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLng = (to.longitude - from.longitude) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  double _bearingDelta(double a, double b) {
    final delta = (a - b).abs();
    return delta > 180 ? 360 - delta : delta;
  }

  LatLng _stabilizeRoutePoint(
    LatLng lastPoint,
    LatLng candidate,
    double accuracyMeters,
  ) {
    if (kDebugLocationMode) return candidate;

    final weight = accuracyMeters <= 8
        ? 1.0
        : accuracyMeters <= 15
        ? 0.9
        : accuracyMeters <= 25
        ? 0.82
        : accuracyMeters <= 35
        ? 0.72
        : 0.58;

    return LatLng(
      lastPoint.latitude + (candidate.latitude - lastPoint.latitude) * weight,
      lastPoint.longitude +
          (candidate.longitude - lastPoint.longitude) * weight,
    );
  }

  void _pushRouteSample(
    LatLng point,
    double accuracyMeters,
    DateTime timestamp,
  ) {
    _routeSampleBuffer.addLast(
      _RouteSample(
        point: point,
        accuracyMeters: accuracyMeters,
        timestamp: timestamp,
      ),
    );
    while (_routeSampleBuffer.length > _routeSampleWindowSize) {
      _routeSampleBuffer.removeFirst();
    }
  }

  LatLng _smoothRouteCandidate({
    required String activityType,
    required LatLng lastPoint,
    required LatLng candidate,
  }) {
    if (_routeSampleBuffer.length < 3) return candidate;

    final samples = _routeSampleBuffer.toList();
    double latSum = 0;
    double lngSum = 0;
    double weightSum = 0;

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final recencyWeight = 1.0 + (i / samples.length);
      final accuracyWeight = 1.0 / math.max(4.0, sample.accuracyMeters);
      final weight = recencyWeight * accuracyWeight;
      latSum += sample.point.latitude * weight;
      lngSum += sample.point.longitude * weight;
      weightSum += weight;
    }

    if (weightSum <= 0) return candidate;

    final averaged = LatLng(latSum / weightSum, lngSum / weightSum);
    final blend = switch (activityType.toLowerCase()) {
      'cycling' => 0.22,
      'running' => 0.18,
      'walking' => 0.15,
      _ => 0.18,
    };

    return LatLng(
      candidate.latitude + (averaged.latitude - candidate.latitude) * blend,
      candidate.longitude + (averaged.longitude - candidate.longitude) * blend,
    );
  }

  LatLng _alignCandidateToRecentHeading({
    required String activityType,
    required List<LatLng> routePoints,
    required LatLng candidate,
  }) {
    if (routePoints.length < 2) return candidate;
    if (activityType.toLowerCase() != 'cycling') return candidate;

    final lastPoint = routePoints[routePoints.length - 1];
    final previousPoint = routePoints[routePoints.length - 2];
    final baseSegmentMeters = Geolocator.distanceBetween(
      previousPoint.latitude,
      previousPoint.longitude,
      lastPoint.latitude,
      lastPoint.longitude,
    );
    if (baseSegmentMeters < 6) return candidate;

    final meanLatRad =
        ((lastPoint.latitude + previousPoint.latitude) / 2.0) * math.pi / 180.0;
    final metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(meanLatRad);
    if (metersPerDegLng.abs() < 1e-6) return candidate;

    final dirX =
        (lastPoint.longitude - previousPoint.longitude) * metersPerDegLng;
    final dirY =
        (lastPoint.latitude - previousPoint.latitude) * metersPerDegLat;
    final dirLen = math.sqrt(dirX * dirX + dirY * dirY);
    if (dirLen < 1e-6) return candidate;

    final unitX = dirX / dirLen;
    final unitY = dirY / dirLen;

    final candX = (candidate.longitude - lastPoint.longitude) * metersPerDegLng;
    final candY = (candidate.latitude - lastPoint.latitude) * metersPerDegLat;
    final forwardMeters = candX * unitX + candY * unitY;
    final lateralMeters = candX * (-unitY) + candY * unitX;

    final maxLateralMeters = switch (activityType.toLowerCase()) {
      'cycling' => 10.0,
      'running' => 12.0,
      'walking' => 14.0,
      _ => 12.0,
    };
    final adjustedLateral = lateralMeters.clamp(
      -maxLateralMeters,
      maxLateralMeters,
    );
    final adjustedForward = forwardMeters < 0 ? 0.0 : forwardMeters;

    final adjustedX = unitX * adjustedForward + (-unitY) * adjustedLateral;
    final adjustedY = unitY * adjustedForward + unitX * adjustedLateral;

    return LatLng(
      lastPoint.latitude + (adjustedY / metersPerDegLat),
      lastPoint.longitude + (adjustedX / metersPerDegLng),
    );
  }

  List<WorkoutLapSplit> _captureLapSplits(double totalDistanceMeters) {
    var splits = state.lapSplits;
    while (totalDistanceMeters >= _nextLapIndex * 1000.0) {
      final lapDistanceMeters =
          (_nextLapIndex * 1000.0) - _lastSplitDistanceMeters;
      final elapsedSec = _stopwatch.elapsed.inSeconds;
      final lapDurationSec = math.max(1, elapsedSec - _lastSplitElapsedSec);
      final lapDistanceKm = lapDistanceMeters / 1000.0;
      final lapPace = lapDistanceKm > 0
          ? lapDurationSec / 60.0 / lapDistanceKm
          : 0.0;

      splits = [
        ...splits,
        WorkoutLapSplit(
          index: _nextLapIndex,
          distanceKm: lapDistanceKm,
          durationSeconds: lapDurationSec,
          paceMinPerKm: lapPace,
        ),
      ];
      _lastSplitElapsedSec = elapsedSec;
      _lastSplitDistanceMeters = _nextLapIndex * 1000.0;
      _nextLapIndex += 1;
    }
    return splits;
  }

  void _setAutoPauseState(bool isPaused) {
    if (state.status == RecordingState.active && !_stopwatch.isRunning) {
      _stopwatch.start();
    }
  }

  // Cleanup

  @override
  void dispose() {
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _pauseAutoStopTimer?.cancel();
    _locationSub?.cancel();
    _stepSub?.cancel();
    _classifierSub?.cancel();
    _classifier?.dispose();
    super.dispose();
  }
}

class _RouteSample {
  final LatLng point;
  final double accuracyMeters;
  final DateTime timestamp;

  const _RouteSample({
    required this.point,
    required this.accuracyMeters,
    required this.timestamp,
  });
}
