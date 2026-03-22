import 'dart:async';
import 'dart:collection';
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

// ─── Constants ────────────────────────────────────────────────────────────────

// kDebugLocationMode is defined in core/config/debug_config.dart

const String kOutdoorMode = 'outdoor';
const String kIndoorMode = 'indoor';
const String kAutoTrackingMode = 'auto'; // detecting phase

// ─── Calorie coefficients (k-factor per km, by activity + speed) ─────────────

double _calorieK(String activityType, double speedKmh) {
  final isRunning = activityType.toLowerCase().contains('run');
  double k = isRunning ? 1.05 : 0.92; // running / walking base
  if (speedKmh > 10) k += 0.05; // fast run
  if (speedKmh > 15) k += 0.05; // sprint
  return k;
}

// ─── Stride length from activityType ───────────────

double _defaultStrideLength(String activityType) {
  final isRunning = activityType.toLowerCase().contains('run');
  return isRunning ? 0.90 : 0.75;
}

double computeStrideLength({required String activityType, double? heightCm}) {
  if (heightCm == null || heightCm <= 0) {
    return _defaultStrideLength(activityType);
  }
  final isRunning = activityType.toLowerCase().contains('run');
  final raw = isRunning ? heightCm * 0.65 / 100 : heightCm * 0.415 / 100;
  return raw.clamp(0.50, 1.50); // sanity bounds in meters
}

// ─── State ────────────────────────────────────────────────────────────────────

enum RecordingState { idle, initializing, active, paused, error }

class WorkoutSessionState {
  final RecordingState status;
  final String? sessionId; // The UUID generated at the END
  final String activityType;

  final String trackingMode;
  final bool modeDecisionLocked;

  final int durationSeconds;
  final double distanceMeters;
  final double speedKmh;
  final double avgSpeedKmh;
  final int stepCount;
  final double strideLengthMeters;
  final int caloriesBurned;
  final List<LatLng> routePoints;

  final LatLng? initialPosition;
  final LatLng? currentLatLng;
  final bool followUser;
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
    this.distanceMeters = 0,
    this.speedKmh = 0,
    this.avgSpeedKmh = 0,
    this.stepCount = 0,
    this.strideLengthMeters = 0.75,
    this.caloriesBurned = 0,
    this.routePoints = const [],
    this.initialPosition,
    this.currentLatLng,
    this.followUser = true,
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
    double? distanceMeters,
    double? speedKmh,
    double? avgSpeedKmh,
    int? stepCount,
    double? strideLengthMeters,
    int? caloriesBurned,
    List<LatLng>? routePoints,
    LatLng? initialPosition,
    LatLng? currentLatLng,
    bool? followUser,
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
      distanceMeters: distanceMeters ?? this.distanceMeters,
      speedKmh: speedKmh ?? this.speedKmh,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      stepCount: stepCount ?? this.stepCount,
      strideLengthMeters: strideLengthMeters ?? this.strideLengthMeters,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      routePoints: routePoints ?? this.routePoints,
      initialPosition: initialPosition ?? this.initialPosition,
      currentLatLng: currentLatLng ?? this.currentLatLng,
      followUser: followUser ?? this.followUser,
      recenterRequestId: recenterRequestId ?? this.recenterRequestId,
      errorMessage: errorMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final locationServiceProvider = Provider((ref) => LocationService());

final workoutSessionProvider =
    StateNotifierProvider.autoDispose<
      WorkoutSessionNotifier,
      WorkoutSessionState
    >((ref) => WorkoutSessionNotifier(ref));

// ─── Notifier ─────────────────────────────────────────────────────────────────

class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  final Ref _ref;

  // Stream subscriptions
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
  static const int _speedWindowSize = 5;

  int _lastStepCountForDistance = 0;

  double _weightKg = 60.0;

  WorkoutSessionNotifier(this._ref)
    : super(
        WorkoutSessionState(
          status: RecordingState.idle,
          activityType: 'Running',
          trackingMode: kAutoTrackingMode,
        ),
      );

  // ─── Profile ──────────────────────────────────────────────────────────────

  void setUserProfile({double? weightKg, double? heightCm}) {
    if (weightKg != null && weightKg > 0) _weightKg = weightKg;
    if (heightCm != null && heightCm > 0) {
      final stride = computeStrideLength(
        activityType: state.activityType,
        heightCm: heightCm,
      );
      state = state.copyWith(strideLengthMeters: stride);
    }
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  void startWorkout(String activityType) {
    final stride = computeStrideLength(activityType: activityType);

    state = WorkoutSessionState(
      status: RecordingState.initializing,
      activityType: activityType,
      trackingMode: kAutoTrackingMode,
      modeDecisionLocked: false,
      strideLengthMeters: stride,
      startedAt: DateTime.now(), // Capture exact start time
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

    _startGpsBackground(activityType);
    _startStepCounterBackground();

    // NOTE: Removed `_createWorkoutRecord`. The session is only saved upon stop.

    _stopwatch.reset();
    _startTicker();
    _startIndoorDistanceTimer();
    _startCalorieTimer();

    if (mounted) {
      state = state.copyWith(
        status: RecordingState.active,
        durationSeconds: 0,
        distanceMeters: 0,
        speedKmh: 0,
        stepCount: 0,
        caloriesBurned: 0,
      );
      debugPrint('[Workout] status=active, sensors starting in background');
    }
  }

  // ─── GPS startup ──────────────────────────────────────────────────────────

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
        _lastStepCountForDistance = state.stepCount;
        _startIndoorDistanceTimer();
        _startCalorieTimer();
      }
    }
  }

  // ─── Pedometer startup ────────────────────────────────────────────────────

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

  // ─── Pause / Resume / Stop ────────────────────────────────────────────────

  Future<void> pauseWorkout() async {
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _locationSub?.pause();
    _stepSub?.pause();
    state = state.copyWith(status: RecordingState.paused);
  }

  Future<void> resumeWorkout() async {
    _locationSub?.resume();
    _stepSub?.resume();
    _startTicker();
    _startCalorieTimer();
    if (state.trackingMode == kIndoorMode) _startIndoorDistanceTimer();
    state = state.copyWith(status: RecordingState.active);
  }

  Future<void> stopWorkout() async {
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

    // ── STEP 1: Final Metrics Snap ────────────────
    final finalCalories = _computeCalories();
    final finalDurationSec = state.durationSeconds;
    final finalDistKm = state.distanceMeters / 1000.0;
    final finalAvgSpeedKmh = finalDurationSec > 0
        ? finalDistKm / (finalDurationSec / 3600.0)
        : 0.0;

    // ── STEP 2: Construct WorkoutSession with UUID ─────────────────────
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception("Cannot save workout: No active user");

    // Calculate final steps based on tracking mode
    int finalSteps = state.stepCount;
    if (state.trackingMode != kIndoorMode) {
      // Outdoor: estimate steps from GPS distance (1 step ~ 0.75m)
      finalSteps = (state.distanceMeters / 0.75).round();
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
    );

    if (mounted) {
      state = state.copyWith(
        caloriesBurned: finalCalories,
        avgSpeedKmh: finalAvgSpeedKmh,
        sessionId: sessionId,
      );
    }

    // ── STEP 3: Push to Persistence Layer ──────────────────────────────
    await _ref.read(workoutListProvider.notifier).saveSession(session);

    state = state.copyWith(status: RecordingState.idle);
  }

  // ─── Calorie calculation ──────────────────────────────────────────────────

  int _computeCalories() {
    final distKm = state.distanceMeters / 1000.0;
    if (distKm <= 0) return 0;
    final k = _calorieK(state.activityType, state.speedKmh);
    return (_weightKg * distKm * k).round();
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

  // ─── Environment transitions ──────────────────────────────────────────────

  void _onEnvironmentChanged(ClassifierEvent event) {
    if (!mounted) return;
    if (state.status != RecordingState.active) return;

    final newMode = event.environment == TrackingEnvironment.outdoor
        ? kOutdoorMode
        : kIndoorMode;

    if (state.trackingMode == newMode && state.modeDecisionLocked) return;

    _indoorDistanceTimer?.cancel();

    if (newMode == kIndoorMode) {
      _lastStepCountForDistance = state.stepCount;
      _startIndoorDistanceTimer();
      state = state.copyWith(trackingMode: newMode, modeDecisionLocked: true);
    } else {
      state = state.copyWith(trackingMode: newMode, modeDecisionLocked: true);
    }

    _startCalorieTimer();
  }

  // ─── GPS position handler ─────────────────────────────────────────────────

  void _onPosition(Position position) {
    if (state.status != RecordingState.active) return;

    _classifier?.addPosition(position);

    final rawKmh = position.speed.clamp(0.0, 50.0) * 3.6;
    _speedSamples.addLast(rawKmh);
    if (_speedSamples.length > _speedWindowSize) _speedSamples.removeFirst();
    final smoothedKmh =
        _speedSamples.reduce((a, b) => a + b) / _speedSamples.length;

    final livePoint = LatLng(position.latitude, position.longitude);

    debugPrint(
      '[GPS] lat=${position.latitude}, lng=${position.longitude}, acc=${position.accuracy}, speed=${position.speed} | mode=${state.trackingMode}',
    );

    // Indoor mode: update marker position and speed but skip route/distance.
    if (state.trackingMode == kIndoorMode) {
      state = state.copyWith(currentLatLng: livePoint, speedKmh: smoothedKmh);
      return;
    }
    // Keep GPS rendering active during auto-detection so the start flag and
    // current position appear immediately instead of waiting for classifier
    // convergence.
    final effectivelyOutdoor = state.trackingMode != kIndoorMode;
    if (!effectivelyOutdoor) {
      state = state.copyWith(currentLatLng: livePoint, speedKmh: smoothedKmh);
      return;
    }

    // ── First point: seed the route and return. ───────────────────────────────
    if (state.routePoints.isEmpty) {
      state = state.copyWith(
        initialPosition: state.initialPosition ?? livePoint,
        currentLatLng: livePoint,
        routePoints: [livePoint],
        speedKmh: smoothedKmh,
      );
      debugPrint('[GPS-ACCEPT] first route point seeded');
      return;
    }

    // ── Subsequent points: apply light jitter filter. ─────────────────────────
    final lastPt = state.routePoints.last;
    final segmentMeters = Geolocator.distanceBetween(
      lastPt.latitude,
      lastPt.longitude,
      livePoint.latitude,
      livePoint.longitude,
    );

    final minSegmentMeters = kDebugLocationMode ? 1.0 : 3.0;
    final maxAccuracy = kDebugLocationMode ? 100.0 : 30.0;

    if (segmentMeters < minSegmentMeters) {
      // Position too close: still update marker but don't add segment.
      state = state.copyWith(currentLatLng: livePoint, speedKmh: smoothedKmh);
      debugPrint(
        '[GPS-SKIP] segment=${segmentMeters.toStringAsFixed(2)}m < $minSegmentMeters',
      );
      return;
    }

    if (position.accuracy > maxAccuracy) {
      // Accuracy too poor: still update marker but skip the route point.
      state = state.copyWith(currentLatLng: livePoint, speedKmh: smoothedKmh);
      debugPrint(
        '[GPS-SKIP] accuracy=${position.accuracy.toStringAsFixed(2)}m > $maxAccuracy',
      );
      return;
    }

    final updatedRoute = List<LatLng>.from(state.routePoints)..add(livePoint);
    final newDistanceM = state.distanceMeters + segmentMeters;

    state = state.copyWith(
      currentLatLng: livePoint,
      routePoints: updatedRoute,
      distanceMeters: newDistanceM,
      speedKmh: smoothedKmh,
    );

    debugPrint(
      '[GPS-ACCEPT] segment=${segmentMeters.toStringAsFixed(2)}m, total=${newDistanceM.toStringAsFixed(2)}m, routePoints=${updatedRoute.length}',
    );
  }

  // ─── Step handler ─────────────────────────────────────────────────────────
  void _onStep(int sessionSteps) {
    if (state.status != RecordingState.active) return;

    final delta = sessionSteps - state.stepCount;
    if (delta <= 0) return;

    _classifier?.addStepDelta(delta);
    state = state.copyWith(stepCount: sessionSteps);
  }

  // ─── Indoor distance (every 5s) ───────────────────────────────────────────

  void _startIndoorDistanceTimer() {
    _indoorDistanceTimer?.cancel();
    _indoorDistanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (state.status != RecordingState.active) return;
      if (state.trackingMode == kOutdoorMode) return;
      _updateIndoorDistance();
    });
  }

  void _updateIndoorDistance() {
    final stepsDelta = state.stepCount - _lastStepCountForDistance;
    if (stepsDelta <= 0) return;

    final addedDistM = stepsDelta * state.strideLengthMeters;
    _lastStepCountForDistance = state.stepCount;

    final speedFromStepsKmh = (addedDistM / 5.0) * 3.6;
    _speedSamples.addLast(speedFromStepsKmh);
    if (_speedSamples.length > _speedWindowSize) _speedSamples.removeFirst();
    final smoothedKmh =
        _speedSamples.reduce((a, b) => a + b) / _speedSamples.length;

    state = state.copyWith(
      distanceMeters: state.distanceMeters + addedDistM,
      speedKmh: smoothedKmh,
    );
  }

  // ─── UI ticker (1s) ───────────────────────────────────────────────────────

  void _startTicker() {
    _stopwatch.start();
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final elapsedSec = _stopwatch.elapsed.inSeconds;

      final distKm = state.distanceMeters / 1000.0;
      final elapsedHours = elapsedSec / 3600.0;
      final avg = elapsedHours > 0 ? (distKm / elapsedHours) : 0.0;

      state = state.copyWith(durationSeconds: elapsedSec, avgSpeedKmh: avg);
    });
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
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
