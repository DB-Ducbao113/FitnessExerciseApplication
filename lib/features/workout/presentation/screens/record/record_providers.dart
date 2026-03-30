import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/services/location_service.dart';
import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
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

// Calories

double _calorieK(String activityType, double speedKmh) {
  final isRunning = activityType.toLowerCase().contains('run');
  double k = isRunning ? 1.05 : 0.92;
  if (speedKmh > 10) k += 0.05;
  if (speedKmh > 15) k += 0.05;
  return k;
}

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

enum RecordingState { idle, initializing, active, paused, error }

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
      recenterRequestId: recenterRequestId ?? this.recenterRequestId,
      errorMessage: errorMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

// Providers

final locationServiceProvider = Provider((ref) => LocationService());

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

  final Stopwatch _stopwatch = Stopwatch();
  EnvironmentClassifier? _classifier;

  final _speedSamples = Queue<double>();
  static const int _speedWindowSize = 12;

  double _weightKg = 60.0;
  double? _heightCm;
  String? _gender;
  DateTime? _lastAcceptedPositionTime;
  DateTime? _lastStepTime;
  int _lowSpeedGpsSamples = 0;
  bool _stopwatchAutoPaused = false;
  int _lastSplitElapsedSec = 0;
  double _lastSplitDistanceMeters = 0;
  int _nextLapIndex = 1;

  static const int _autoPauseSampleThreshold = 3;

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
    final stride = computeStrideLength(
      activityType: activityType,
      heightCm: _heightCm,
      gender: _gender,
    );
    _speedSamples.clear();
    _lastAcceptedPositionTime = null;
    _lastStepTime = null;
    _lowSpeedGpsSamples = 0;
    _stopwatchAutoPaused = false;
    _lastSplitElapsedSec = 0;
    _lastSplitDistanceMeters = 0;
    _nextLapIndex = 1;

    state = WorkoutSessionState(
      status: RecordingState.initializing,
      activityType: activityType,
      trackingMode: kAutoTrackingMode,
      modeDecisionLocked: false,
      strideLengthMeters: stride,
      startedAt: DateTime.now(),
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
    _classifier?.dispose();
    _classifier = EnvironmentClassifier();
    _classifierSub?.cancel();
    _classifierSub = _classifier!.stateStream.listen(_onEnvironmentChanged);

    if (_requiresGpsTracking(activityType)) {
      _startGpsBackground(activityType);
    } else if (mounted) {
      state = state.copyWith(
        trackingMode: kIndoorMode,
        modeDecisionLocked: true,
      );
    }
    _startStepCounterBackground();

    _stopwatch.reset();
    _startTicker();
    _startCalorieTimer();

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
      debugPrint('[Workout] pedometer error: $e — steps remain 0');
    }
  }

  // Session control

  Future<void> pauseWorkout() async {
    _stopwatchAutoPaused = false;
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _locationSub?.pause();
    _stepSub?.pause();
    state = state.copyWith(status: RecordingState.paused);
  }

  Future<void> resumeWorkout() async {
    _stopwatchAutoPaused = false;
    _locationSub?.resume();
    _stepSub?.resume();
    _startTicker();
    _startCalorieTimer();
    state = state.copyWith(status: RecordingState.active);
  }

  Future<void> stopWorkout() async {
    _stopwatchAutoPaused = false;
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _uiTicker = null;
    _indoorDistanceTimer = null;
    _calorieTimer = null;

    _ref.read(locationTrackingServiceProvider).stopTracking();
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

    final sessionId = const Uuid().v4();
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
      state = state.copyWith(
        caloriesBurned: finalCalories,
        avgSpeedKmh: finalAvgSpeedKmh,
        sessionId: sessionId,
      );
    }

    await _ref.read(workoutListProvider.notifier).saveSession(session);

    state = state.copyWith(status: RecordingState.idle);
  }

  // Calories

  int _computeCalories() {
    final distKm = state.distanceMeters / 1000.0;
    if (distKm <= 0) return 0;

    final genderFactor = _gender == 'female' ? 0.95 : 1.0;
    final k = _calorieK(state.activityType, state.speedKmh);
    return (_weightKg * distKm * k * genderFactor).round();
  }

  void _startCalorieTimer() {
    _calorieTimer?.cancel();
    _calorieTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (state.status != RecordingState.active) return;
      final kcal = _computeCalories();
      state = state.copyWith(caloriesBurned: kcal);
      debugPrint(
        '[Calories] ${kcal}kcal — dist=${(state.distanceMeters / 1000).toStringAsFixed(2)}km weight=${_weightKg}kg',
      );
    });
  }

  // Mode changes

  void _onEnvironmentChanged(ClassifierEvent event) {
    if (!mounted) return;
    if (state.status != RecordingState.active) return;

    final newMode = event.environment == TrackingEnvironment.outdoor
        ? kOutdoorMode
        : kIndoorMode;

    if (state.trackingMode == newMode && state.modeDecisionLocked) return;

    if (newMode == kIndoorMode) {
      state = state.copyWith(trackingMode: newMode, modeDecisionLocked: true);
    } else {
      state = state.copyWith(trackingMode: newMode, modeDecisionLocked: true);
    }

    _startCalorieTimer();
  }

  // GPS updates

  void _onPosition(Position position) {
    if (state.status != RecordingState.active) return;

    _classifier?.addPosition(position);

    final livePoint = LatLng(position.latitude, position.longitude);
    final sensorSpeedKmh = position.speed > 0
        ? position.speed.clamp(0.0, 50.0) * 3.6
        : 0.0;

    debugPrint(
      '[GPS] lat=${position.latitude}, lng=${position.longitude}, acc=${position.accuracy}, speed=${position.speed} | mode=${state.trackingMode}',
    );

    // Indoor mode updates marker and speed only.
    if (state.trackingMode == kIndoorMode) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: _computeSmoothedSpeed(),
      );
      return;
    }
    // Keep rendering GPS while detection is still undecided.
    final effectivelyOutdoor = state.trackingMode != kIndoorMode;
    if (!effectivelyOutdoor) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: _computeSmoothedSpeed(),
      );
      return;
    }

    // Seed the route with the first accepted point.
    if (state.routePoints.isEmpty) {
      _lastAcceptedPositionTime = position.timestamp;
      state = state.copyWith(
        initialPosition: state.initialPosition ?? livePoint,
        currentLatLng: livePoint,
        routePoints: [livePoint],
        speedKmh: 0,
      );
      debugPrint('[GPS-ACCEPT] first route point seeded');
      return;
    }

    // Filter noisy GPS segments.
    final lastPt = state.routePoints.last;
    final segmentMeters = Geolocator.distanceBetween(
      lastPt.latitude,
      lastPt.longitude,
      livePoint.latitude,
      livePoint.longitude,
    );

    final minSegmentMeters = kDebugLocationMode
        ? 0.25
        : _getMinSegmentMeters(state.activityType);
    final maxAccuracy = kDebugLocationMode ? 100.0 : 30.0;

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

    if (state.routePoints.length >= 2 && segmentMeters > 20) {
      final previousBearing = _computeBearing(
        state.routePoints[state.routePoints.length - 2],
        lastPt,
      );
      final currentBearing = _computeBearing(lastPt, livePoint);
      final bearingDelta = _bearingDelta(previousBearing, currentBearing);
      if (bearingDelta > 120) {
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

    if (_shouldAutoPause(smoothedKmh)) {
      _lowSpeedGpsSamples++;
      if (_lowSpeedGpsSamples >= _autoPauseSampleThreshold) {
        _setAutoPauseState(true);
        state = state.copyWith(
          currentLatLng: livePoint,
          speedKmh: 0,
          isAutoPaused: true,
        );
        debugPrint(
          '[GPS-SKIP] auto_paused speed=${smoothedKmh.toStringAsFixed(2)}km/h',
        );
        return;
      }
    } else {
      _lowSpeedGpsSamples = 0;
    }

    final updatedRoute = List<LatLng>.from(state.routePoints)..add(livePoint);
    final newDistanceM = state.distanceMeters + segmentMeters;
    _lastAcceptedPositionTime = position.timestamp;
    _setAutoPauseState(false);

    state = state.copyWith(
      currentLatLng: livePoint,
      routePoints: updatedRoute,
      distanceMeters: newDistanceM,
      speedKmh: smoothedKmh,
      lapSplits: _captureLapSplits(newDistanceM),
      isAutoPaused: false,
    );

    debugPrint(
      '[GPS-ACCEPT] segment=${segmentMeters.toStringAsFixed(2)}m, total=${newDistanceM.toStringAsFixed(2)}m, routePoints=${updatedRoute.length}',
    );
  }

  // Step updates
  void _onStep(int sessionSteps) {
    if (state.status != RecordingState.active) return;

    final delta = sessionSteps - state.stepCount;
    if (delta <= 0) return;

    _classifier?.addStepDelta(delta);
    state = state.copyWith(stepCount: sessionSteps);
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

    state = state.copyWith(
      distanceMeters: state.distanceMeters + addedDistM,
      speedKmh: _computeSmoothedSpeed(),
      lapSplits: _captureLapSplits(state.distanceMeters + addedDistM),
      isAutoPaused: false,
    );
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

      if (_isMoving(liveSpeedKmh, state.activityType)) {
        movingTimeSec += 1;
        isAutoPaused = false;
        _setAutoPauseState(false);
      }

      final distKm = state.distanceMeters / 1000.0;
      final movingHours = movingTimeSec / 3600.0;
      final avg = movingHours > 0 && distKm > 0.01
          ? (distKm / movingHours)
          : 0.0;

      state = state.copyWith(
        durationSeconds: elapsedSec,
        movingTimeSeconds: movingTimeSec,
        speedKmh: liveSpeedKmh,
        avgSpeedKmh: avg,
        isAutoPaused: isAutoPaused,
      );
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

  bool _shouldAutoPause(double speedKmh) =>
      !_isMoving(speedKmh, state.activityType);

  bool _isMoving(double speedKmh, String activityType) {
    return speedKmh >= _getMinMovingSpeedKmh(activityType);
  }

  double _getMinMovingSpeedKmh(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 0.5;
      case 'cycling':
        return 2.0;
      case 'running':
      default:
        return 1.0;
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
        return 2.0;
      case 'cycling':
        return 8.0;
      case 'running':
        return 4.0;
      default:
        return 3.0;
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
    if (isPaused) {
      if (!_stopwatchAutoPaused) {
        _stopwatch.stop();
        _stopwatchAutoPaused = true;
      }
      return;
    }

    if (_stopwatchAutoPaused || !_stopwatch.isRunning) {
      _stopwatch.start();
      _stopwatchAutoPaused = false;
    }
  }

  // Cleanup

  @override
  void dispose() {
    _stopwatchAutoPaused = false;
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _locationSub?.cancel();
    _stepSub?.cancel();
    _classifierSub?.cancel();
    _classifier?.dispose();
    super.dispose();
  }
}
