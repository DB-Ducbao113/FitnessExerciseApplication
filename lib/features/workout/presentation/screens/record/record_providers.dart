import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/constants/workout_processing_contract.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/services/ios_live_activity_service.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_environment_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_sensor_bootstrapper.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_sensor_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_lifecycle.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_starter.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
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

String _defaultRecordingSource(String activityType) {
  return _requiresGpsTracking(activityType) ? 'gps' : 'step_fallback';
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

// Providers

final workoutSessionProvider =
    StateNotifierProvider.autoDispose<
      WorkoutSessionNotifier,
      WorkoutSessionState
    >((ref) => WorkoutSessionNotifier(ref));

// Notifier

class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  final Ref _ref;
  final WorkoutRecordingCoordinator _recordingCoordinator;
  final WorkoutTrackingEngine _trackingEngine = const WorkoutTrackingEngine();
  final GpsSmoothingService _gpsSmoothingService = const GpsSmoothingService();
  final WorkoutSessionFinalizer _sessionFinalizer =
      const WorkoutSessionFinalizer();
  final WorkoutSessionLifecycle _sessionLifecycle =
      const WorkoutSessionLifecycle();
  final WorkoutSensorBootstrapper _sensorBootstrapper =
      const WorkoutSensorBootstrapper();
  final WorkoutSensorController _sensorController =
      const WorkoutSensorController();
  final WorkoutEnvironmentController _environmentController =
      WorkoutEnvironmentController();
  final WorkoutSessionStarter _sessionStarter = const WorkoutSessionStarter();

  // Subscriptions
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<int>? _stepSub;

  // Timers
  Timer? _uiTicker;
  Timer? _indoorDistanceTimer;
  Timer? _calorieTimer;
  Timer? _pauseAutoStopTimer;
  Timer? _gpsHealthTimer;

  final Stopwatch _stopwatch = Stopwatch();

  final _speedSamples = Queue<double>();
  static const int _speedWindowSize = 12;

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
  bool _isRecoveringGpsStream = false;
  DateTime? _lastGpsEventTime;
  final List<Position> _rawGpsPositions = [];
  static const Duration _kPauseAutoStopDelay = Duration(minutes: 2);
  static const Duration _kIndoorWatchdogTick = Duration(seconds: 2);
  static const Duration _kIndoorStepGrace = Duration(seconds: 4);
  static const Duration _kIndoorStallAutoPause = Duration(seconds: 8);
  static const Duration _kRecoveredGpsWindow = Duration(seconds: 3);
  static const Duration _kGpsHealthCheckTick = Duration(seconds: 5);
  static const Duration _kGpsStreamStaleThreshold = Duration(seconds: 5);
  static const int _kMaxGpsDebugEntries = 80;

  WorkoutSessionNotifier(this._ref)
    : _recordingCoordinator = _ref.read(workoutRecordingCoordinatorProvider),
      super(
        WorkoutSessionState(
          status: RecordingState.idle,
          activityType: 'Running',
          trackingMode: kAutoTrackingMode,
          environmentHint: 'detecting',
          recordingSource: 'gps',
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

  void startWorkout(String activityType, {Position? startupGpsLock}) {
    final sessionId = const Uuid().v4();
    final stride = computeStrideLength(
      activityType: activityType,
      heightCm: _heightCm,
      gender: _gender,
    );
    final startPlan = _sessionStarter.createPlan(
      sessionId: sessionId,
      activityType: activityType,
      requiresGps: _requiresGpsTracking(activityType),
      strideLengthMeters: stride,
      startedAt: DateTime.now(),
      outdoorMode: kOutdoorMode,
      indoorMode: kIndoorMode,
      recordingSource: _defaultRecordingSource(activityType),
    );
    _resetRuntimeTrackingState();
    final startupLockPoint = startupGpsLock == null
        ? null
        : LatLng(startupGpsLock.latitude, startupGpsLock.longitude);

    state = _sessionLifecycle.createInitializingState(
      sessionId: startPlan.sessionId,
      activityType: startPlan.activityType,
      trackingMode: startPlan.trackingMode,
      environmentHint: startPlan.environmentHint,
      recordingSource: startPlan.recordingSource,
      modeDecisionLocked: startPlan.modeDecisionLocked,
      strideLengthMeters: startPlan.strideLengthMeters,
      startedAt: startPlan.startedAt,
    );
    if (startupLockPoint != null) {
      _distanceAnchorPoint = startupLockPoint;
      _lastAcceptedPositionTime = startupGpsLock?.timestamp;
      state = state.copyWith(
        initialPosition: startupLockPoint,
        currentLatLng: startupLockPoint,
        smoothedCurrentLatLng: startupLockPoint,
        filteredRoutePoints: [startupLockPoint],
        smoothedRoutePoints: [startupLockPoint],
        routePoints: [startupLockPoint],
        routeSegments: [
          [startupLockPoint],
        ],
        smoothedRouteSegments: [
          [startupLockPoint],
        ],
        gpsConfidence: GpsConfidence.high,
      );
    }
    debugPrint(
      '[Workout] startWorkout $activityType — stride=${stride.toStringAsFixed(2)}m startupLock=${startupLockPoint != null}',
    );

    _initServicesInBackground(startPlan);
    unawaited(
      _recordingCoordinator.createRemoteWorkoutShell(
        sessionId: startPlan.sessionId,
        startedAt: startPlan.startedAt,
        activityType: startPlan.activityType,
        mode: startPlan.trackingMode,
      ),
    );
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

  Future<void> _initServicesInBackground(
    WorkoutSessionStartPlan startPlan,
  ) async {
    if (startPlan.requiresGps) {
      await _environmentController.start(
        activityType: startPlan.activityType,
        onEvent: _onEnvironmentChanged,
      );
      if (mounted) {
        state = _sessionStarter.applyGpsBootstrap(state);
      }
      _startGpsBackground(startPlan.activityType);
    } else if (mounted) {
      await _environmentController.stop();
      final locationService = _ref.read(locationTrackingServiceProvider);
      final lastKnown = await _sensorController.getLastKnownPosition(
        locationService,
      );
      final seededState = lastKnown == null
          ? state
          : _sensorBootstrapper.applyLastKnownPosition(
              current: state,
              latitude: lastKnown.latitude,
              longitude: lastKnown.longitude,
            );
      state = _sessionStarter.applyIndoorBootstrap(seededState);
      _refreshIndoorWatchdog();
    }
    _startStepCounterBackground();

    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    _startCalorieTimer();
    _refreshIndoorWatchdog();

    if (mounted) {
      state = _sessionLifecycle.activate(
        current: state,
        recordingSource: startPlan.recordingSource,
      );
      debugPrint('[Workout] status=active, sensors starting in background');
      _syncLiveActivityState();
    }
  }

  // GPS

  Future<void> _startGpsBackground(String activityType) async {
    debugPrint('[Workout] GPS startup begin at ${DateTime.now()}');
    final locationService = _ref.read(locationTrackingServiceProvider);

    final lastKnown = await _sensorController.getLastKnownPosition(
      locationService,
    );
    if (lastKnown != null &&
        mounted &&
        state.initialPosition == null &&
        state.routePoints.isEmpty) {
      state = _sensorBootstrapper.applyLastKnownPosition(
        current: state,
        latitude: lastKnown.latitude,
        longitude: lastKnown.longitude,
      );
    }

    try {
      await _locationSub?.cancel();
      _locationSub = await _sensorController.startGpsTracking(
        locationService: locationService,
        activityType: activityType,
        onPosition: _onPosition,
        onError: (error, stackTrace) {
          debugPrint('[Workout] GPS stream error: $error');
          _logGpsHealthEvent(
            eventType: kGpsStreamErrorEvent,
            message: kGpsStreamErrorMessage,
            reason: 'stream_error',
            logLevel: 'error',
            error: error,
          );
          unawaited(_recoverGpsStream(activityType, reason: 'stream_error'));
        },
        onDone: () {
          debugPrint('[Workout] GPS stream done unexpectedly');
          _logGpsHealthEvent(
            eventType: kGpsStreamDoneEvent,
            message: kGpsStreamDoneMessage,
            reason: 'stream_done',
            logLevel: 'warning',
          );
          unawaited(_recoverGpsStream(activityType, reason: 'stream_done'));
        },
      );
      _lastGpsEventTime = DateTime.now();
      _startGpsHealthWatchdog(activityType);
      debugPrint('[Workout] GPS position subscription started');
    } catch (e) {
      debugPrint('[Workout] GPS error: $e');
      if (mounted) {
        state = _sensorBootstrapper.applyGpsStartupFailure(
          state,
          e.toString().replaceAll('Exception: ', ''),
        );
        _refreshIndoorWatchdog();
        _startCalorieTimer();
      }
    }
  }

  void _startGpsHealthWatchdog(String activityType) {
    _gpsHealthTimer?.cancel();
    _gpsHealthTimer = Timer.periodic(_kGpsHealthCheckTick, (_) {
      if (!mounted || state.status != RecordingState.active) return;
      if (!_requiresGpsTracking(state.activityType)) return;

      final lastGpsEventTime = _lastGpsEventTime;
      if (lastGpsEventTime == null) return;
      final silence = DateTime.now().difference(lastGpsEventTime);
      if (silence < _kGpsStreamStaleThreshold) return;

      if (!state.isGpsSignalWeak) {
        final fallbackGapMarker =
            state.currentLatLng ??
            (state.routePoints.isNotEmpty ? state.routePoints.last : null);
        state = state.copyWith(
          isGpsSignalWeak: true,
          gpsGapMarker: fallbackGapMarker,
        );
      }

      debugPrint(
        '[Workout] GPS watchdog detected stalled stream after ${silence.inSeconds}s',
      );
      _logGpsHealthEvent(
        eventType: kGpsStreamStalledEvent,
        message: kGpsStreamStalledMessage,
        reason: 'stale_stream',
        logLevel: 'warning',
        silence: silence,
      );
      unawaited(_recoverGpsStream(activityType, reason: 'stale_stream'));
    });
  }

  Future<void> _recoverGpsStream(
    String activityType, {
    required String reason,
  }) async {
    if (_isRecoveringGpsStream || _isStopping || !mounted) return;
    if (state.status != RecordingState.active) return;
    _isRecoveringGpsStream = true;
    final locationService = _ref.read(locationTrackingServiceProvider);

    try {
      debugPrint('[Workout] attempting GPS recovery reason=$reason');
      _logGpsHealthEvent(
        eventType: kGpsRecoveryStartedEvent,
        message: kGpsRecoveryStartedMessage,
        reason: reason,
      );

      final rescuePosition = await locationService
          .getCurrentPositionWithTimeout(
            fallback: await locationService.getLastKnownPosition(),
            timeout: const Duration(seconds: 4),
          );
      if (rescuePosition != null && mounted) {
        _lastGpsEventTime = DateTime.now();
        _onPosition(rescuePosition);
      }

      await _locationSub?.cancel();
      _locationSub = await _sensorController.startGpsTracking(
        locationService: locationService,
        activityType: activityType,
        onPosition: _onPosition,
        onError: (error, stackTrace) {
          debugPrint('[Workout] GPS stream error during recovery: $error');
          _logGpsHealthEvent(
            eventType: kGpsStreamErrorEvent,
            message: kGpsStreamErrorMessage,
            reason: 'stream_error_during_recovery',
            logLevel: 'error',
            error: error,
          );
          unawaited(_recoverGpsStream(activityType, reason: 'stream_error'));
        },
        onDone: () {
          debugPrint('[Workout] GPS stream done during recovery');
          _logGpsHealthEvent(
            eventType: kGpsStreamDoneEvent,
            message: kGpsStreamDoneMessage,
            reason: 'stream_done_during_recovery',
            logLevel: 'warning',
          );
          unawaited(_recoverGpsStream(activityType, reason: 'stream_done'));
        },
      );
      _lastGpsEventTime = DateTime.now();
      debugPrint('[Workout] GPS recovery succeeded');
      _logGpsHealthEvent(
        eventType: kGpsRecoverySucceededEvent,
        message: kGpsRecoverySucceededMessage,
        reason: reason,
        payloadOverrides: {
          'recovery_used_rescue_position': rescuePosition != null,
        },
      );
    } catch (e) {
      debugPrint('[Workout] GPS recovery failed: $e');
      _logGpsHealthEvent(
        eventType: kGpsRecoveryFailedEvent,
        message: kGpsRecoveryFailedMessage,
        reason: reason,
        logLevel: 'error',
        error: e,
      );
    } finally {
      _isRecoveringGpsStream = false;
    }
  }

  // Steps

  Future<void> _startStepCounterBackground() async {
    debugPrint('[Workout] pedometer startup begin at ${DateTime.now()}');
    try {
      final stepService = _ref.read(stepTrackingServiceProvider);
      await _stepSub?.cancel();
      _stepSub = await _sensorController.startStepTracking(
        stepService: stepService,
        onStep: _onStep,
      );
      debugPrint('[Workout] pedometer subscription active');
    } catch (e) {
      debugPrint('[Workout] pedometer error: $e');
      if (mounted) {
        state = _sensorBootstrapper.applyStepStartupFailure(
          state,
          e.toString().replaceAll('Exception: ', ''),
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
    state = _sessionLifecycle.pause(
      current: state,
      pauseAutoStopRemainingSeconds: _kPauseAutoStopDelay.inSeconds,
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
    state = _sessionLifecycle.resume(state);
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
      state = _sessionLifecycle.stopping(state);
      await _shutdownTrackingInfrastructure();

      final finishedAt = DateTime.now();
      final finalCalories = _computeCalories(
        distanceMeters: state.distanceMeters,
        durationSec: state.durationSeconds,
      );

      final userId = _ref.read(currentUserIdProvider);
      if (userId == null) {
        throw Exception("Cannot save workout: No active user");
      }

      final finalization = _sessionFinalizer.finalize(
        state: state,
        userId: userId,
        finishedAt: finishedAt,
        caloriesBurned: finalCalories,
        fallbackStrideLengthMeters: _defaultStrideLength(
          state.activityType,
          _gender,
        ),
        trackingEngine: _trackingEngine,
        rawGpsPositions: List<Position>.unmodifiable(_rawGpsPositions),
        filteredRouteSegments: List<List<LatLng>>.unmodifiable(
          state.routeSegments
              .where((segment) => segment.isNotEmpty)
              .map((segment) => List<LatLng>.unmodifiable(segment)),
        ),
      );

      if (mounted) {
        final endedState = _sessionLifecycle.finish(
          current: state,
          caloriesBurned: finalization.caloriesBurned,
          avgSpeedKmh: finalization.avgSpeedKmh,
          sessionId: finalization.sessionId,
          gpsAnalysis: finalization.gpsAnalysis,
        );
        state = endedState;
        await _endLiveActivity(endedState);
      }

      await _ref
          .read(workoutListProvider.notifier)
          .saveSession(finalization.session);
      _recordingCoordinator.markRemoteWorkoutShellReady();
      await _recordingCoordinator.flushPendingRawTracking(
        workoutId: finalization.sessionId,
        force: true,
      );
      _recordingCoordinator.queueLiveRouteSnapshot(
        workoutId: finalization.sessionId,
        routeSegments: state.routeSegments,
        lastGpsGapDurationSec: state.lastGpsGapDurationSec,
        isGpsSignalWeak: state.isGpsSignalWeak,
      );
      await _recordingCoordinator.syncLiveRouteSnapshot(force: true);
      await _recordingCoordinator.enqueueProcessingForSession(
        finalization.session,
      );
      await _recordingCoordinator.enqueueRouteCorrectionForSession(
        finalization.session,
      );
    } finally {
      _isStopping = false;
    }
  }

  Future<void> _shutdownTrackingInfrastructure() async {
    final locationService = _ref.read(locationTrackingServiceProvider);
    final stepService = _ref.read(stepTrackingServiceProvider);

    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _gpsHealthTimer?.cancel();
    _uiTicker = null;
    _indoorDistanceTimer = null;
    _calorieTimer = null;
    _gpsHealthTimer = null;

    await _sensorController.stopGpsTracking(
      locationService: locationService,
      subscription: _locationSub,
    );
    _locationSub = null;

    await _sensorController.stopStepTracking(
      stepService: stepService,
      subscription: _stepSub,
    );
    _stepSub = null;

    await _environmentController.stop();
  }

  void _resetRuntimeTrackingState() {
    _speedSamples.clear();
    _lastAcceptedPositionTime = null;
    _lastStepTime = null;
    _lastGpsEventTime = null;
    _distanceAnchorPoint = null;
    _recordingCoordinator.reset();
    _rawGpsPositions.clear();
    _lastSplitElapsedSec = 0;
    _lastSplitDistanceMeters = 0;
    _nextLapIndex = 1;
    _shouldResetGpsAnchorOnResume = false;
    _isStopping = false;
  }

  // Calories

  int _computeCalories({double? distanceMeters, int? durationSec}) {
    final profile = UserProfile(
      id: 'active-session',
      userId: _ref.read(currentUserIdProvider) ?? 'active-session',
      weightKg: _weightKg,
      heightCm: (_heightCm ?? 170).clamp(50.0, 250.0),
      legacyAge: 0,
      gender: _gender ?? 'male',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    return WorkoutMetricsCalculator.computeCaloriesKcal(
      profile: profile,
      activityType: state.activityType,
      distanceMeters: distanceMeters ?? state.distanceMeters,
      durationSec: durationSec ?? state.durationSeconds,
    );
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
    final nextHint = switch (event.environment) {
      TrackingEnvironment.outdoor => 'outdoor',
      TrackingEnvironment.indoor => 'indoor',
      TrackingEnvironment.detecting => 'detecting',
    };

    if (_requiresGpsTracking(state.activityType)) {
      state = state.copyWith(environmentHint: nextHint);
      debugPrint(
        '[Workout][ENV] hint=$nextHint fallbackSuggested=${event.fallbackSuggested} '
        'confidence=${event.confidence.toStringAsFixed(2)} reason=${event.reason}',
      );
      return;
    }

    final newMode = event.environment == TrackingEnvironment.outdoor
        ? kOutdoorMode
        : event.environment == TrackingEnvironment.indoor
        ? kIndoorMode
        : state.trackingMode;
    state = state.copyWith(
      trackingMode: newMode,
      environmentHint: nextHint,
      recordingSource: newMode == kOutdoorMode ? 'gps' : 'step_fallback',
      gpsFallbackActive: newMode == kIndoorMode,
      modeDecisionLocked: true,
      isAutoPaused: false,
    );
    _refreshIndoorWatchdog();
    debugPrint(
      '[Workout][ENV] mode=$newMode recordingSource=${state.recordingSource} '
      'confidence=${event.confidence.toStringAsFixed(2)} reason=${event.reason}',
    );
  }

  // GPS updates

  void _onPosition(Position position) {
    final isGpsPrimary = _requiresGpsTracking(state.activityType);
    final livePoint = LatLng(position.latitude, position.longitude);
    _lastGpsEventTime = DateTime.now();
    final rawGpsDeviceSource =
        state.isGpsSignalWeak || _shouldResetGpsAnchorOnResume
        ? 'geolocator_position_stream_recovery'
        : 'geolocator_position_stream';

    debugPrint(
      '[Workout][GPS] lat=${position.latitude}, lng=${position.longitude}, '
      'acc=${position.accuracy}, speed=${position.speed} '
      '| mode=${state.trackingMode} env=${state.environmentHint} '
      'source=${state.recordingSource} fallback=${state.gpsFallbackActive}',
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

    if (state.status != RecordingState.active) {
      debugPrint('[Workout][GPS] ignore reason=status_${state.status.name}');
      return;
    }

    _recordingCoordinator.bufferRawGpsPoint(
      position,
      workoutId: state.sessionId,
      deviceSource: rawGpsDeviceSource,
    );
    _rawGpsPositions.add(position);
    _environmentController.addPosition(position);

    if (!isGpsPrimary && state.trackingMode == kIndoorMode) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: _computeSmoothedSpeed(),
      );
      debugPrint('[Workout][GPS] indoor-only activity marker update');
      return;
    }

    if (state.trackingMode == kAutoTrackingMode && !state.modeDecisionLocked) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: _computeSmoothedSpeed(),
      );
      debugPrint('[Workout][GPS] ignore reason=auto_detecting_without_lock');
      return;
    }

    final decision = _trackingEngine.evaluateGpsUpdate(
      position: position,
      activityType: state.activityType,
      routePoints: state.routePoints,
      currentLatLng: state.currentLatLng,
      distanceAnchorPoint: _distanceAnchorPoint,
      lastAcceptedPositionTime: _lastAcceptedPositionTime,
      shouldResetAnchorOnResume: _shouldResetGpsAnchorOnResume,
      debugLocationMode: kDebugLocationMode,
    );
    state = state.copyWith(currentLatLng: decision.previewPoint);
    _recordGpsDecision(
      position: position,
      decision: decision,
      detail: decision.skipReason ?? 'accepted',
    );

    if (decision.type == TrackingGpsDecisionType.skip) {
      debugPrint('[GPS-SKIP] ${decision.skipReason}');
      return;
    }

    if (decision.type == TrackingGpsDecisionType.seedRoute) {
      _lastAcceptedPositionTime = position.timestamp;
      _distanceAnchorPoint = decision.livePoint;
      state = state.copyWith(
        initialPosition: state.initialPosition ?? decision.livePoint,
        currentLatLng: decision.livePoint,
        smoothedCurrentLatLng: decision.livePoint,
        trackingMode: kOutdoorMode,
        environmentHint: 'outdoor',
        recordingSource: 'gps',
        gpsFallbackActive: false,
        filteredRoutePoints: [decision.livePoint],
        smoothedRoutePoints: [decision.livePoint],
        routePoints: [decision.livePoint],
        routeSegments: [
          [decision.livePoint],
        ],
        smoothedRouteSegments: [
          [decision.livePoint],
        ],
        isIndoorSyntheticRoute: false,
        gpsConfidence: GpsConfidence.high,
        isStationaryByGps: false,
        speedKmh: 0,
      );
      debugPrint(
        '[Workout][GPS-ACCEPT] first route point seeded; gps pipeline active',
      );
      _recordingCoordinator.queueLiveRouteSnapshot(
        workoutId: state.sessionId,
        routeSegments: state.routeSegments,
        lastGpsGapDurationSec: state.lastGpsGapDurationSec,
        isGpsSignalWeak: state.isGpsSignalWeak,
      );
      return;
    }

    if (decision.type == TrackingGpsDecisionType.resetAnchor) {
      _shouldResetGpsAnchorOnResume = false;
      _distanceAnchorPoint = decision.livePoint;
      _lastAcceptedPositionTime = position.timestamp;
      state = state.copyWith(
        currentLatLng: decision.livePoint,
        smoothedCurrentLatLng: decision.livePoint,
        speedKmh: 0,
        isAutoPaused: false,
      );
      debugPrint('[GPS] resume anchor reset');
      _recordingCoordinator.queueLiveRouteSnapshot(
        workoutId: state.sessionId,
        routeSegments: state.routeSegments,
        lastGpsGapDurationSec: state.lastGpsGapDurationSec,
        isGpsSignalWeak: state.isGpsSignalWeak,
      );
      return;
    }

    _applyAcceptedGpsSegment(
      position: position,
      livePoint: decision.livePoint,
      segmentMeters: decision.segmentMeters,
      rawSegmentMeters: decision.rawSegmentMeters,
      routeSegmentMeters: decision.routeSegmentMeters,
      candidateSpeedKmh: decision.candidateSpeedKmh,
      routeCandidate: decision.livePoint,
      shouldAddDistance: decision.shouldAddDistance,
      gpsGapDurationSec: decision.gpsGapDurationSec,
    );
  }

  // Step updates
  void _onStep(int sessionSteps) {
    if (state.status != RecordingState.active) return;

    final stepDecision = _trackingEngine.evaluateStepUpdate(
      sessionSteps: sessionSteps,
      currentStepCount: state.stepCount,
      requiresGpsTracking: _requiresGpsTracking(state.activityType),
      gpsFallbackActive: state.gpsFallbackActive,
      recordingSource: state.recordingSource,
      lastAcceptedPositionTime: _lastAcceptedPositionTime,
      now: DateTime.now(),
    );
    final delta = stepDecision.delta;
    if (delta <= 0) return;

    _recordingCoordinator.bufferRawStepInterval(
      delta,
      startedAt: state.startedAt,
      workoutId: state.sessionId,
    );
    _environmentController.addStepDelta(delta);
    state = state.copyWith(stepCount: sessionSteps);

    if (stepDecision.shouldActivateGpsFallback) {
      state = state.copyWith(
        trackingMode: kIndoorMode,
        recordingSource: 'step_fallback',
        gpsFallbackActive: true,
        modeDecisionLocked: true,
      );
      _refreshIndoorWatchdog();
      debugPrint('[Workout][FALLBACK] gps weak -> step_fallback active');
    }

    if (!_requiresGpsTracking(state.activityType) || state.gpsFallbackActive) {
      _updateIndoorDistanceFromSteps(delta);
    }
  }

  // Indoor distance

  void _updateIndoorDistanceFromSteps(int newSteps) {
    final now = DateTime.now();
    final contribution = _trackingEngine.computeIndoorStepContribution(
      stepDelta: newSteps,
      strideLengthMeters: state.strideLengthMeters,
      now: now,
      lastStepTime: _lastStepTime,
    );

    if (contribution.instantSpeedKmh != null) {
      _addSpeedSample(contribution.instantSpeedKmh!);
    }

    _lastStepTime = now;
    _setAutoPauseState(false);

    final newDistanceM =
        state.distanceMeters + contribution.addedDistanceMeters;
    final newSpeedKmh = _computeSmoothedSpeed();
    final newCalories = _computeCalories(
      distanceMeters: newDistanceM,
      durationSec: state.durationSeconds,
    );

    state = state.copyWith(
      distanceMeters: newDistanceM,
      speedKmh: newSpeedKmh,
      lapSplits: _captureLapSplits(newDistanceM),
      caloriesBurned: newCalories,
      isAutoPaused: false,
    );
    _appendIndoorSyntheticRoute(
      addedDistanceMeters: contribution.addedDistanceMeters,
      recordedAt: now,
    );
  }

  void _appendIndoorSyntheticRoute({
    required double addedDistanceMeters,
    required DateTime recordedAt,
  }) {
    if (!mounted || addedDistanceMeters <= 0) return;

    final anchor = state.initialPosition ?? state.currentLatLng;
    if (anchor == null) return;

    final updatedRoute = List<LatLng>.from(state.routePoints);
    final updatedFilteredRoute = List<LatLng>.from(state.filteredRoutePoints);
    final updatedRouteSegments = state.routeSegments
        .map((segment) => List<LatLng>.from(segment))
        .toList();
    if (updatedRoute.isEmpty) {
      updatedRoute.add(anchor);
      updatedFilteredRoute.add(anchor);
      updatedRouteSegments.add([anchor]);
      state = state.copyWith(
        smoothedCurrentLatLng: anchor,
        smoothedRoutePoints: [anchor],
        smoothedRouteSegments: [
          [anchor],
        ],
        gpsConfidence: GpsConfidence.high,
        isStationaryByGps: false,
      );
      unawaited(
        _persistSyntheticRoutePoint(
          anchor,
          recordedAt,
          headingDeg: state.indoorSyntheticHeadingDeg,
        ),
      );
    }

    final baseHeading = state.indoorSyntheticHeadingDeg == 0
        ? 20.0
        : state.indoorSyntheticHeadingDeg;
    final displayMeters = (addedDistanceMeters * 0.18).clamp(0.8, 4.5);
    final cadenceTurn = 18.0 + ((state.stepCount % 9) * 2.5);
    final waveTurn = math.sin(state.stepCount / 6) * 9.0;
    final nextHeading = (baseHeading + cadenceTurn + waveTurn) % 360.0;
    final previousPoint = updatedRoute.last;
    final projectedPoint = _offsetLatLng(
      previousPoint,
      distanceMeters: displayMeters,
      headingDeg: nextHeading,
    );
    final constrainedPoint = _constrainSyntheticPoint(
      anchor: anchor,
      candidate: projectedPoint,
      fallback: previousPoint,
    );

    if (_distanceBetween(previousPoint, constrainedPoint) < 0.6) {
      state = state.copyWith(
        currentLatLng: constrainedPoint,
        smoothedCurrentLatLng: constrainedPoint,
        initialPosition: state.initialPosition ?? anchor,
        isIndoorSyntheticRoute: true,
        indoorSyntheticHeadingDeg: (nextHeading + 28.0) % 360.0,
      );
      return;
    }

    updatedRoute.add(constrainedPoint);
    updatedFilteredRoute.add(constrainedPoint);
    if (updatedRouteSegments.isEmpty) {
      updatedRouteSegments.add([constrainedPoint]);
    } else {
      updatedRouteSegments.last.add(constrainedPoint);
    }
    state = state.copyWith(
      filteredRoutePoints: updatedFilteredRoute,
      smoothedRoutePoints: updatedFilteredRoute,
      routePoints: updatedRoute,
      routeSegments: updatedRouteSegments,
      smoothedRouteSegments: updatedRouteSegments,
      currentLatLng: constrainedPoint,
      smoothedCurrentLatLng: constrainedPoint,
      initialPosition: state.initialPosition ?? anchor,
      isIndoorSyntheticRoute: true,
      indoorSyntheticHeadingDeg: nextHeading,
      gpsConfidence: GpsConfidence.high,
      isStationaryByGps: false,
    );
    unawaited(
      _persistSyntheticRoutePoint(
        constrainedPoint,
        recordedAt,
        headingDeg: nextHeading,
      ),
    );
  }

  LatLng _offsetLatLng(
    LatLng origin, {
    required double distanceMeters,
    required double headingDeg,
  }) {
    const metersPerDegreeLat = 111320.0;
    final headingRad = headingDeg * math.pi / 180.0;
    final latDelta = math.cos(headingRad) * distanceMeters / metersPerDegreeLat;
    final lngScale = math.max(
      0.2,
      math.cos(origin.latitude * math.pi / 180.0).abs(),
    );
    final lngDelta =
        math.sin(headingRad) * distanceMeters / (metersPerDegreeLat * lngScale);
    return LatLng(origin.latitude + latDelta, origin.longitude + lngDelta);
  }

  LatLng _constrainSyntheticPoint({
    required LatLng anchor,
    required LatLng candidate,
    required LatLng fallback,
  }) {
    final anchorDistance = _distanceBetween(anchor, candidate);
    if (anchorDistance <= 55) return candidate;

    final fallbackHeading = _bearingDegrees(anchor, fallback);
    final returnHeading = (fallbackHeading + 42.0) % 360.0;
    return _offsetLatLng(
      fallback,
      distanceMeters: 2.6,
      headingDeg: returnHeading,
    );
  }

  double _distanceBetween(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  double _bearingDegrees(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180.0;
    final lat2 = end.latitude * math.pi / 180.0;
    final lngDelta = (end.longitude - start.longitude) * math.pi / 180.0;
    final y = math.sin(lngDelta) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(lngDelta);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  Future<void> _persistSyntheticRoutePoint(
    LatLng point,
    DateTime timestamp, {
    required double headingDeg,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final localPoint = LocalGPSPoint()
      ..sessionId = sessionId
      ..localWorkoutId = 0
      ..timestamp = timestamp
      ..latitude = point.latitude
      ..longitude = point.longitude
      ..accuracy = 0
      ..speed = 0
      ..heading = headingDeg
      ..confidence = 'synthetic'
      ..isSynced = true;
    await LocalDB.saveRawGpsPoint(localPoint);
  }

  void _applyAcceptedGpsSegment({
    required Position position,
    required LatLng livePoint,
    required double segmentMeters,
    required double rawSegmentMeters,
    required double routeSegmentMeters,
    required double candidateSpeedKmh,
    required LatLng routeCandidate,
    required bool shouldAddDistance,
    required double gpsGapDurationSec,
  }) {
    if (shouldAddDistance && candidateSpeedKmh > 0) {
      _addSpeedSample(candidateSpeedKmh);
    }
    final smoothedKmh = _computeSmoothedSpeed();

    final updatedFilteredRoute = List<LatLng>.from(state.filteredRoutePoints)
      ..add(routeCandidate);
    final updatedSmoothedRoutePoints = List<LatLng>.from(
      state.smoothedRoutePoints,
    );
    final updatedRoute = List<LatLng>.from(state.routePoints)
      ..add(routeCandidate);
    final updatedRouteSegments = state.routeSegments
        .map((segment) => List<LatLng>.from(segment))
        .toList();
    final updatedSmoothedRouteSegments = state.smoothedRouteSegments
        .map((segment) => List<LatLng>.from(segment))
        .toList();
    final updatedGapSegments = List<GpsGapSegment>.from(state.gpsGapSegments);
    final lastRoutePoint = state.filteredRoutePoints.isNotEmpty
        ? state.filteredRoutePoints.last
        : null;
    final timeDeltaSec = gpsGapDurationSec > 0
        ? gpsGapDurationSec
        : (_lastAcceptedPositionTime == null
              ? 0.0
              : position.timestamp
                        .difference(_lastAcceptedPositionTime!)
                        .inMilliseconds /
                    1000.0);
    final smoothingUpdate = _gpsSmoothingService.smoothAcceptedPoint(
      activityType: state.activityType,
      acceptedPoint: routeCandidate,
      previousAcceptedPoint: lastRoutePoint,
      previousSmoothedPoint: state.smoothedCurrentLatLng,
      lastSmoothedRoutePoint: updatedSmoothedRoutePoints.isNotEmpty
          ? updatedSmoothedRoutePoints.last
          : null,
      accuracyMeters: position.accuracy,
      speedMs: position.speed,
      timeDeltaSec: timeDeltaSec,
      gpsGapDurationSec: gpsGapDurationSec,
    );
    if (gpsGapDurationSec > 5.0 && lastRoutePoint != null) {
      updatedGapSegments.add(
        GpsGapSegment(
          start: lastRoutePoint,
          end: routeCandidate,
          durationSec: gpsGapDurationSec,
        ),
      );
      updatedRouteSegments.add([routeCandidate]);
      updatedSmoothedRouteSegments.add([smoothingUpdate.smoothedPoint]);
    } else if (updatedRouteSegments.isEmpty) {
      updatedRouteSegments.add([routeCandidate]);
      updatedSmoothedRouteSegments.add([smoothingUpdate.smoothedPoint]);
    } else {
      updatedRouteSegments.last.add(routeCandidate);
      if (updatedSmoothedRouteSegments.isEmpty) {
        updatedSmoothedRouteSegments.add([smoothingUpdate.smoothedPoint]);
      } else if (smoothingUpdate.shouldAppendRoutePoint) {
        updatedSmoothedRouteSegments.last.add(smoothingUpdate.smoothedPoint);
      }
    }
    if (updatedSmoothedRoutePoints.isEmpty ||
        smoothingUpdate.shouldAppendRoutePoint ||
        gpsGapDurationSec > 5.0) {
      updatedSmoothedRoutePoints.add(smoothingUpdate.smoothedPoint);
    }
    final distanceDelta = shouldAddDistance ? segmentMeters : 0.0;
    final newDistanceM = state.distanceMeters + distanceDelta;
    final newCalories = _computeCalories(
      distanceMeters: newDistanceM,
      durationSec: state.durationSeconds,
    );
    _lastAcceptedPositionTime = position.timestamp;
    _distanceAnchorPoint = livePoint;
    _setAutoPauseState(false);

    state = state.copyWith(
      trackingMode: kOutdoorMode,
      environmentHint: 'outdoor',
      recordingSource: 'gps',
      gpsFallbackActive: false,
      currentLatLng: livePoint,
      smoothedCurrentLatLng: smoothingUpdate.smoothedPoint,
      gpsGapMarker: gpsGapDurationSec > 5.0
          ? routeCandidate
          : state.gpsGapMarker,
      gpsGapSegments: updatedGapSegments,
      filteredRoutePoints: updatedFilteredRoute,
      smoothedRoutePoints: updatedSmoothedRoutePoints,
      routePoints: updatedRoute,
      routeSegments: updatedRouteSegments,
      smoothedRouteSegments: updatedSmoothedRouteSegments,
      isIndoorSyntheticRoute: false,
      gpsConfidence: smoothingUpdate.confidence,
      isStationaryByGps: smoothingUpdate.isStationary,
      distanceMeters: newDistanceM,
      speedKmh: shouldAddDistance ? smoothedKmh : 0,
      lapSplits: _captureLapSplits(newDistanceM),
      caloriesBurned: newCalories,
      isAutoPaused: false,
      isGpsSignalWeak: false,
      lastGpsGapDurationSec: gpsGapDurationSec,
    );

    debugPrint(
      '[Workout][GPS-ACCEPT] segment=${segmentMeters.toStringAsFixed(2)}m '
      'raw=${rawSegmentMeters.toStringAsFixed(2)}m '
      'route=${routeSegmentMeters.toStringAsFixed(2)}m '
      'total=${newDistanceM.toStringAsFixed(2)}m routePoints=${updatedRoute.length} '
      'source=gps addDistance=$shouldAddDistance gap=${gpsGapDurationSec.toStringAsFixed(1)}s',
    );
    _recordingCoordinator.queueLiveRouteSnapshot(
      workoutId: state.sessionId,
      routeSegments: state.routeSegments,
      lastGpsGapDurationSec: gpsGapDurationSec,
      isGpsSignalWeak: state.isGpsSignalWeak,
    );
  }

  void _recordGpsDecision({
    required Position position,
    required TrackingGpsDecision decision,
    required String detail,
  }) {
    final previousAcceptedTime = _lastAcceptedPositionTime;
    final timeDeltaSec = previousAcceptedTime == null
        ? 0.0
        : position.timestamp.difference(previousAcceptedTime).inMilliseconds /
              1000.0;
    final debugEntry = GpsValidationDebugEntry.fromPosition(
      position: position,
      outcome: decision.outcome,
      reason: decision.reason,
      segmentMeters: decision.segmentMeters,
      routeSegmentMeters: decision.routeSegmentMeters,
      timeDeltaSec: timeDeltaSec,
      detail: detail,
    );
    final updatedEntries = List<GpsValidationDebugEntry>.from(
      state.gpsDebugEntries,
    )..add(debugEntry);
    if (updatedEntries.length > _kMaxGpsDebugEntries) {
      updatedEntries.removeRange(
        0,
        updatedEntries.length - _kMaxGpsDebugEntries,
      );
    }
    state = state.copyWith(gpsDebugEntries: updatedEntries);
    debugPrint(
      '[GPS-VALIDATION] outcome=${decision.outcome.name} reason=${decision.reason.name} '
      'lat=${position.latitude.toStringAsFixed(6)} lng=${position.longitude.toStringAsFixed(6)} '
      'acc=${position.accuracy.toStringAsFixed(1)} speed=${position.speed.toStringAsFixed(2)} '
      'segment=${decision.segmentMeters.toStringAsFixed(2)} route=${decision.routeSegmentMeters.toStringAsFixed(2)} '
      'detail=$detail',
    );
  }

  void _refreshIndoorWatchdog() {
    _indoorDistanceTimer?.cancel();
    _indoorDistanceTimer = null;

    final isIndoorFallbackActive = !_requiresGpsTracking(state.activityType)
        ? state.trackingMode == kIndoorMode
        : state.gpsFallbackActive;
    if (state.status != RecordingState.active || !isIndoorFallbackActive) {
      return;
    }

    _indoorDistanceTimer = Timer.periodic(_kIndoorWatchdogTick, (_) {
      if (!mounted) return;
      final stillIndoorFallbackActive =
          !_requiresGpsTracking(state.activityType)
          ? state.trackingMode == kIndoorMode
          : state.gpsFallbackActive;
      if (state.status != RecordingState.active || !stillIndoorFallbackActive) {
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
          recordingSource: 'gps',
          gpsFallbackActive: false,
          modeDecisionLocked: true,
          isAutoPaused: false,
          speedKmh: 0,
        );
        _refreshIndoorWatchdog();
        debugPrint(
          '[Workout][FALLBACK] gps recovered after fallback '
          '(step stall ${secondsSinceStep}s)',
        );
        return;
      }

      if (secondsSinceStep >= _kIndoorStallAutoPause.inSeconds) {
        state = state.copyWith(speedKmh: 0, isAutoPaused: true);
        debugPrint(
          '[Workout][FALLBACK] indoor watchdog stall '
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

      if (state.recordingSource == 'step_fallback' &&
          _lastStepTime != null &&
          DateTime.now().difference(_lastStepTime!).inSeconds >= 3) {
        liveSpeedKmh = 0;
        isAutoPaused = true;
        _setAutoPauseState(true);
      }

      if (state.recordingSource == 'gps' &&
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

  void _logGpsHealthEvent({
    required String eventType,
    required String message,
    required String reason,
    String logLevel = 'info',
    Object? error,
    Duration? silence,
    Map<String, dynamic>? payloadOverrides,
  }) {
    final workoutId = state.sessionId;
    if (workoutId == null || workoutId.isEmpty) return;

    final lastGpsAgeSeconds = _lastGpsEventTime == null
        ? null
        : DateTime.now().difference(_lastGpsEventTime!).inSeconds;

    final payload = <String, dynamic>{
      'reason': reason,
      'activity_type': state.activityType,
      'tracking_mode': state.trackingMode,
      'recording_source': state.recordingSource,
      'gps_fallback_active': state.gpsFallbackActive,
      'mode_decision_locked': state.modeDecisionLocked,
      'recording_status': state.status.name,
      'duration_seconds': state.durationSeconds,
      'distance_meters': state.distanceMeters,
      'avg_speed_kmh': state.avgSpeedKmh,
      'route_point_count': state.routePoints.length,
      'last_gps_event_age_sec': lastGpsAgeSeconds,
      if (silence != null) 'stream_silence_sec': silence.inSeconds,
      if (error != null) 'error': error.toString(),
      if (payloadOverrides != null) ...payloadOverrides,
    };

    unawaited(
      _recordingCoordinator.logProcessingEvent(
        workoutId: workoutId,
        eventType: eventType,
        message: message,
        payload: payload,
        logLevel: logLevel,
      ),
    );
  }

  bool _isMoving(double speedKmh, String activityType) {
    return _trackingEngine.isMoving(speedKmh, activityType);
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
    _gpsHealthTimer?.cancel();
    _locationSub?.cancel();
    _stepSub?.cancel();
    unawaited(_environmentController.stop());
    _recordingCoordinator.dispose();
    super.dispose();
  }
}
