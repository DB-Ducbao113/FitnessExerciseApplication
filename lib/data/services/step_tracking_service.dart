import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

final stepTrackingServiceProvider = Provider((ref) => StepTrackingService());

// ─── Constants ────────────────────────────────────────────────────────────────

/// Physiological ceiling: a very fast sprint = ~4.5 steps/sec.
/// Any spike above this is sensor noise / vibration and is discarded.
const double _kMaxStepsPerSec = 4.5;

/// Minimum emit interval — throttle UI rebuilds.
const Duration _kEmitThrottle = Duration(milliseconds: 500);

// ─── Service ──────────────────────────────────────────────────────────────────

/// Pedometer service that wraps the Android/iOS step detector.
///
/// Key design rules:
///  1. BASELINE FIX — `Pedometer.stepCountStream` emits CUMULATIVE steps from
///     device boot. We store `_baselineSteps` on the FIRST event of each
///     session and compute `sessionSteps = event.steps - _baselineSteps`.
///     We NEVER accumulate `event.steps` directly into a counter.
///
///  2. SUBSCRIPTION GUARD — `_isTracking` prevents double-start.
///     `stopTracking()` must always be called before `startTracking()` again.
///
///  3. ANTI-SPIKE FILTER — events that imply > 4.5 steps/sec are discarded
///     as vibration noise. The rate is computed from timestamps so it's
///     immune to UI throttle delays.
class StepTrackingService {
  // ── Subscriptions / stream ──────────────────────────────────────────────────
  StreamSubscription<StepCount>? _pedometerSub;
  final _outController = StreamController<int>.broadcast();

  Stream<int> get stepStream => _outController.stream;

  // ── Session state ──────────────────────────────────────────────────────────
  bool _isTracking = false;

  /// Steps from device boot at the moment this session started.
  /// -1 means "not yet set"  (first event pending).
  int _baselineSteps = -1;

  /// The last VALID session step count emitted.
  int _lastSessionSteps = 0;

  // ── Spike filter state ─────────────────────────────────────────────────────
  DateTime? _lastEventTime;
  int _lastRawSteps = -1; // last raw event.steps (for rate calculation)
  DateTime? _lastEmit;

  // ─── Permission ─────────────────────────────────────────────────────────────

  Future<bool> _requestActivityPermission() async {
    debugPrint('[Steps] requesting ACTIVITY_RECOGNITION…');
    final status = await Permission.activityRecognition.request();
    debugPrint('[Steps] ACTIVITY_RECOGNITION: $status');
    return status.isGranted || status.isLimited;
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Starts a fresh pedometer session.
  /// Safe to call on any isolate — permission request is awaited first.
  Future<void> startTracking() async {
    // ── Guard: one session at a time ──────────────────────────────────────────
    if (_isTracking) {
      debugPrint('[Steps] startTracking ignored — already tracking');
      return;
    }
    _isTracking = true;

    // ── Reset session state ───────────────────────────────────────────────────
    _baselineSteps = -1;
    _lastSessionSteps = 0;
    _lastEventTime = null;
    _lastRawSteps = -1;
    _lastEmit = null;

    debugPrint('[Steps] startTracking at ${DateTime.now()}');

    final hasPermission = await _requestActivityPermission();
    if (!hasPermission) {
      debugPrint('[Steps] permission denied — steps will remain 0');
      _isTracking = false;
      return;
    }

    // Cancel any orphan subscription from previous session
    await _pedometerSub?.cancel();
    _pedometerSub = null;

    debugPrint('[Steps] subscribing to Pedometer.stepCountStream…');

    _pedometerSub = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (e) => debugPrint('[Steps] stream error: $e'),
      cancelOnError: false,
    );

    debugPrint('[Steps] subscription active');
  }

  void stopTracking() {
    debugPrint('[Steps] stopTracking (baseline was $_baselineSteps)');
    _isTracking = false;
    _pedometerSub?.cancel();
    _pedometerSub = null;
    _baselineSteps = -1;
    _lastSessionSteps = 0;
    _lastEventTime = null;
    _lastRawSteps = -1;
    _lastEmit = null;
  }

  // ─── Event handler ───────────────────────────────────────────────────────────

  void _onStepCount(StepCount event) {
    if (!_isTracking) return;

    final rawSteps = event.steps;
    final now = DateTime.now();

    // ── STEP 1: Set baseline on first event ────────────────────────────────────
    if (_baselineSteps == -1) {
      _baselineSteps = rawSteps;
      _lastRawSteps = rawSteps;
      _lastEventTime = now;
      debugPrint('[Steps] baseline=$_baselineSteps at $now');
      // Emit 0 immediately so UI shows steps from session start
      _emit(0, now);
      return;
    }

    // ── STEP 2: Compute raw delta since LAST event (for spike filter) ─────────
    final rawDelta = rawSteps - _lastRawSteps;

    if (rawDelta < 0) {
      // Device rebooted mid-session — update baseline to absorb reset
      debugPrint(
        '[Steps] counter reset detected (rawDelta=$rawDelta), adjusting baseline',
      );
      _baselineSteps = rawSteps - _lastSessionSteps;
      _lastRawSteps = rawSteps;
      _lastEventTime = now;
      return;
    }

    if (rawDelta == 0) return; // no new steps

    // ── STEP 3: Spike filter — discard physical impossibilities ───────────────
    if (_lastEventTime != null) {
      final elapsedSec =
          now.difference(_lastEventTime!).inMilliseconds / 1000.0;
      if (elapsedSec > 0) {
        final stepsPerSec = rawDelta / elapsedSec;
        if (stepsPerSec > _kMaxStepsPerSec) {
          debugPrint(
            '[Steps] SPIKE DISCARDED: rawDelta=$rawDelta '
            'in ${elapsedSec.toStringAsFixed(2)}s '
            '= ${stepsPerSec.toStringAsFixed(1)} steps/s > $_kMaxStepsPerSec',
          );
          // Update tracking position but don't count these steps
          _lastRawSteps = rawSteps;
          _lastEventTime = now;
          return;
        }
      }
    }

    // ── STEP 4: Compute session steps from baseline ───────────────────────────
    final sessionSteps = rawSteps - _baselineSteps;
    _lastSessionSteps = sessionSteps;
    _lastRawSteps = rawSteps;
    _lastEventTime = now;

    debugPrint(
      '[Steps] raw=$rawSteps baseline=$_baselineSteps '
      'session=$sessionSteps delta=$rawDelta',
    );

    // ── STEP 5: Emit (throttled) ──────────────────────────────────────────────
    _emit(sessionSteps, now);
  }

  void _emit(int sessionSteps, DateTime now) {
    // Throttle: max one emit per _kEmitThrottle
    if (_lastEmit != null && now.difference(_lastEmit!) < _kEmitThrottle) {
      return;
    }
    _lastEmit = now;

    if (!_outController.isClosed) {
      _outController.add(sessionSteps);
    }
  }
}
