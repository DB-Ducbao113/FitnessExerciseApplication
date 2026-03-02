import 'dart:async';
import 'dart:collection';
import 'package:fitness_exercise_application/core/services/location_service.dart';
import 'package:fitness_exercise_application/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/data/services/environment_detector.dart';
import 'package:fitness_exercise_application/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/presentation/providers/providers.dart';
import 'package:fitness_exercise_application/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/data/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/data/services/step_tracking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const String kOutdoorMode = 'outdoor';
const String kIndoorMode = 'indoor';
const String kAutoTrackingMode = 'auto'; // detecting phase

// ─── State ────────────────────────────────────────────────────────────────────

enum RecordingState { idle, initializing, active, paused, error }

class WorkoutSessionState {
  final RecordingState status;
  final int? workoutId;
  final String activityType;

  /// 'auto' = detecting, 'outdoor', 'indoor'
  final String trackingMode;

  final int durationSeconds;
  final double distanceMeters;
  final double speedKmh; // smoothed km/h
  final int stepCount;
  final double strideLengthMeters;
  final int caloriesBurned;
  final List<LatLng> routePoints;

  /// Non-null when status == error
  final String? errorMessage;

  WorkoutSessionState({
    required this.status,
    this.workoutId,
    required this.activityType,
    required this.trackingMode,
    this.durationSeconds = 0,
    this.distanceMeters = 0,
    this.speedKmh = 0,
    this.stepCount = 0,
    this.strideLengthMeters = 0.75,
    this.caloriesBurned = 0,
    this.routePoints = const [],
    this.errorMessage,
  });

  WorkoutSessionState copyWith({
    RecordingState? status,
    int? workoutId,
    String? activityType,
    String? trackingMode,
    int? durationSeconds,
    double? distanceMeters,
    double? speedKmh,
    int? stepCount,
    double? strideLengthMeters,
    int? caloriesBurned,
    List<LatLng>? routePoints,
    String? errorMessage,
  }) {
    return WorkoutSessionState(
      status: status ?? this.status,
      workoutId: workoutId ?? this.workoutId,
      activityType: activityType ?? this.activityType,
      trackingMode: trackingMode ?? this.trackingMode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      speedKmh: speedKmh ?? this.speedKmh,
      stepCount: stepCount ?? this.stepCount,
      strideLengthMeters: strideLengthMeters ?? this.strideLengthMeters,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      routePoints: routePoints ?? this.routePoints,
      errorMessage: errorMessage,
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

  // Subscriptions
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<int>? _stepSub;
  StreamSubscription<ClassifierEvent>? _classifierSub;

  // Timers
  Timer? _uiTicker;
  Timer? _indoorDistanceTimer; // fires every 5s — avoids per-step rebuild

  final Stopwatch _stopwatch = Stopwatch();
  WorkoutRepository? _repository;
  EnvironmentClassifier? _classifier;

  // Speed smoothing: 5-sample moving average in km/h
  final _speedSamples = Queue<double>();
  static const int _speedWindowSize = 5;

  // Indoor step accounting
  int _lastStepCountForDistance = 0;

  WorkoutSessionNotifier(this._ref)
    : super(
        WorkoutSessionState(
          status: RecordingState.idle,
          activityType: 'Running',
          trackingMode: kAutoTrackingMode,
        ),
      );

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Starts a workout session.
  ///
  /// DESIGN: sets state to [RecordingState.initializing] SYNCHRONOUSLY and
  /// returns immediately. All heavy sensor startup runs in the background so
  /// the UI can render the record screen without any delay.
  void startWorkout(String activityType) {
    // ── Step 1: Update UI immediately (synchronous) ────────────────────────
    state = WorkoutSessionState(
      status: RecordingState.initializing,
      activityType: activityType,
      trackingMode: kAutoTrackingMode,
      routePoints: const [],
    );
    debugPrint(
      '[Workout] startWorkout: UI set to initializing at ${DateTime.now()}',
    );

    // ── Step 2: Start all heavy work in background ─────────────────────────
    _initServicesInBackground(activityType);
  }

  Future<void> _initServicesInBackground(String activityType) async {
    _repository = _ref.read(workoutRepositoryProvider);

    // Fresh classifier per session
    _classifier?.dispose();
    _classifier = EnvironmentClassifier();
    _classifierSub?.cancel();
    _classifierSub = _classifier!.stateStream.listen(_onEnvironmentChanged);

    // ── Start GPS (may take time, that's OK — classifier feeds as data arrives)
    _startGpsBackground(activityType);

    // ── Start pedometer (runs in parallel with GPS)
    _startStepCounterBackground();

    // ── Persist workout record to DB (runs in parallel)
    _createWorkoutRecord(activityType);

    // ── Start the UI ticker (timer shows 00:00 counting up)
    _stopwatch.reset();
    _startTicker();

    // ── Mark active immediately so controls render
    if (mounted) {
      state = state.copyWith(
        status: RecordingState.active,
        durationSeconds: 0,
        distanceMeters: 0,
        speedKmh: 0,
        stepCount: 0,
        caloriesBurned: 0,
      );
      debugPrint('[Workout] UI is now active — sensors starting in background');
    }
  }

  Future<void> _startGpsBackground(String activityType) async {
    debugPrint('[Workout] GPS startup begin at ${DateTime.now()}');
    try {
      final locationService = _ref.read(locationTrackingServiceProvider);
      await locationService.startTracking(activityType);
      _locationSub?.cancel();
      _locationSub = locationService.positionStream.listen(_onPosition);
      debugPrint('[Workout] GPS subscription active');
    } catch (e) {
      debugPrint('[Workout] GPS error: $e');
      if (mounted) {
        // Surface GPS error in top bar badge only — don't crash the session
        state = state.copyWith(
          trackingMode: kIndoorMode, // fall back to indoor / step tracking
        );
        _onGpsError(e.toString());
      }
    }
  }

  Future<void> _startStepCounterBackground() async {
    debugPrint('[Workout] pedometer startup begin at ${DateTime.now()}');
    try {
      final stepService = _ref.read(stepTrackingServiceProvider);
      await stepService.startTracking();
      _stepSub?.cancel();
      _stepSub = stepService.stepStream.listen(_onStep);
      debugPrint('[Workout] pedometer subscription active');
    } catch (e) {
      debugPrint('[Workout] pedometer error: $e — steps will remain 0');
      // Steps stay 0; app continues normally
    }
  }

  Future<void> _createWorkoutRecord(String activityType) async {
    try {
      final workoutId = await _repository!.startWorkout(activityType);
      if (mounted) state = state.copyWith(workoutId: workoutId);
      debugPrint('[Workout] DB record created: workoutId=$workoutId');
    } catch (e) {
      debugPrint('[Workout] DB record creation failed: $e (non-fatal)');
      // Non-fatal: session continues, save will be attempted on Stop
    }
  }

  void _onGpsError(String code) {
    // Show a one-time error dialog by storing the code in state.
    // RecordScreen reads errorMessage and shows the dialog.
    if (!mounted) return;
    state = state.copyWith(errorMessage: code);
  }

  // ─── Pause / Resume / Stop ─────────────────────────────────────────────────

  Future<void> pauseWorkout() async {
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _locationSub?.pause();
    _stepSub?.pause();
    state = state.copyWith(status: RecordingState.paused);
    await _repository?.pauseWorkout(state.workoutId!);
  }

  Future<void> resumeWorkout() async {
    _locationSub?.resume();
    _stepSub?.resume();
    _startTicker();
    if (state.trackingMode == kIndoorMode) _startIndoorDistanceTimer();
    state = state.copyWith(status: RecordingState.active);
    await _repository?.resumeWorkout(state.workoutId!);
  }

  Future<void> stopWorkout() async {
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _uiTicker = null;
    _indoorDistanceTimer = null;

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

    if (state.workoutId != null) {
      await _ref
          .read(workoutListProvider.notifier)
          .finishWorkout(
            workoutId: state.workoutId.toString(),
            activityType: state.activityType,
            durationSeconds: _stopwatch.elapsed.inSeconds,
            distance: state.distanceMeters / 1000.0,
          );
    }

    state = state.copyWith(status: RecordingState.idle);
  }

  // ─── Calorie estimate stub ─────────────────────────────────────────────────

  /// TODO: calibrate with MET tables per activity type and user weight.
  double estimateCalories({
    required double distanceKm,
    required int durationSec,
    double weightKg = 70.0,
  }) {
    // Scaffold: ~60 kcal/km
    return distanceKm * 60.0;
  }

  // ─── Environment transitions ───────────────────────────────────────────────

  void _onEnvironmentChanged(ClassifierEvent event) {
    if (!mounted) return;
    if (state.status != RecordingState.active) return;

    final newMode = event.environment == TrackingEnvironment.outdoor
        ? kOutdoorMode
        : kIndoorMode;

    debugPrint('[Workout] environment → $newMode (${event.reason})');

    if (state.trackingMode == newMode) return;

    _indoorDistanceTimer?.cancel();

    if (newMode == kIndoorMode) {
      _lastStepCountForDistance = state.stepCount;
      _startIndoorDistanceTimer();
      state = state.copyWith(
        trackingMode: newMode,
        routePoints: const [], // clear GPS route
      );
    } else {
      state = state.copyWith(
        trackingMode: newMode,
        routePoints: const [], // fresh start for outdoor route
      );
    }
  }

  // ─── GPS position handler ──────────────────────────────────────────────────

  void _onPosition(Position position) {
    if (state.status != RecordingState.active) return;

    // Feed classifier (always)
    _classifier?.addPosition(position);

    // Speed smoothing (km/h)
    final rawKmh = position.speed.clamp(0.0, 50.0) * 3.6;
    _speedSamples.addLast(rawKmh);
    if (_speedSamples.length > _speedWindowSize) _speedSamples.removeFirst();
    final smoothedKmh =
        _speedSamples.reduce((a, b) => a + b) / _speedSamples.length;

    if (state.trackingMode != kOutdoorMode) {
      // Still update speed indicator even in indoor mode
      state = state.copyWith(speedKmh: smoothedKmh);
      return;
    }

    // ── Outdoor: append to route ────────────────────────────────────────────
    final point = LatLng(position.latitude, position.longitude);
    double addedDistance = 0;
    const distCalc = Distance();

    if (state.routePoints.isNotEmpty) {
      final lastPt = state.routePoints.last;
      addedDistance = distCalc.as(LengthUnit.Meter, lastPt, point);

      // Min 5 m and accuracy ≤ 25 m
      if (addedDistance < 5.0 || position.accuracy > 25.0) {
        state = state.copyWith(speedKmh: smoothedKmh);
        return;
      }
    }

    final updatedRoute = List<LatLng>.from(state.routePoints)..add(point);
    final newDistanceM = state.distanceMeters + addedDistance;

    // Persist GPS point
    final gpsPoint = LocalGPSPoint()
      ..timestamp = position.timestamp
      ..latitude = position.latitude
      ..longitude = position.longitude
      ..altitude = position.altitude
      ..speed = position.speed
      ..accuracy = position.accuracy
      ..heading = position.heading;
    _repository?.trackPoint(state.workoutId!, gpsPoint);

    state = state.copyWith(
      routePoints: updatedRoute,
      distanceMeters: newDistanceM,
      speedKmh: smoothedKmh,
    );
  }

  // ─── Step handler ──────────────────────────────────────────────────────────

  void _onStep(int sessionSteps) {
    if (state.status != RecordingState.active) return;

    final delta = sessionSteps - state.stepCount;
    if (delta <= 0) return;

    _classifier?.addStepDelta(delta);

    // Only update state (no indoor distance calc here — that's on the 5s timer)
    state = state.copyWith(stepCount: sessionSteps);
  }

  // ─── Indoor distance (every 5 s) ──────────────────────────────────────────

  void _startIndoorDistanceTimer() {
    _indoorDistanceTimer?.cancel();
    _indoorDistanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (state.status != RecordingState.active) return;
      if (state.trackingMode != kIndoorMode) return;
      _updateIndoorDistance();
    });
  }

  void _updateIndoorDistance() {
    final stepsDelta = state.stepCount - _lastStepCountForDistance;
    if (stepsDelta <= 0) return;

    final addedDistM = stepsDelta * state.strideLengthMeters;
    _lastStepCountForDistance = state.stepCount;

    // Indoor speed from step rate over 5s window
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

  // ─── UI ticker ────────────────────────────────────────────────────────────

  void _startTicker() {
    _stopwatch.start();
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        state = state.copyWith(durationSeconds: _stopwatch.elapsed.inSeconds);
      }
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _locationSub?.cancel();
    _stepSub?.cancel();
    _classifierSub?.cancel();
    _classifier?.dispose();
    super.dispose();
  }
}
