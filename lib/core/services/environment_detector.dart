import 'dart:async';
import 'dart:collection';
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// ─── Public types ────────────────────────────────────────────────────────────

enum TrackingEnvironment { detecting, outdoor, indoor }

/// Emitted each time the classifier commits a new state.
class ClassifierEvent {
  final TrackingEnvironment environment;
  final String reason;
  const ClassifierEvent(this.environment, this.reason);
}

// ─── Thresholds ──────────────────────────────────────────────────────────────

/// Hard timeout: if no confident classification after this duration → Indoor.
const Duration _kMaxDetectDuration = Duration(seconds: 25);

/// Minimum number of GPS points required before evaluating.
const int _kMinWindowSize = 3;

/// Sliding window size.
const int _kWindowSize = 10;

/// Outdoor: accuracy must be ≤ this.
/// In debug mode we allow weaker accuracy (emulator GPS is simulated).
double get _kOutdoorMaxAccuracy => kDebugLocationMode ? 50.0 : 20.0; // m

/// Outdoor: net displacement must be ≥ this in the window.
/// In debug (emulator) mode this is reduced to 3 m so the classifier fires
/// quickly on short emulator routes.
double get _kOutdoorMinDisplacement => kDebugLocationMode ? 3.0 : 25.0; // m

/// Outdoor: OR average GPS speed ≥ this (m/s).
double get _kOutdoorMinSpeed => kDebugLocationMode ? 0.2 : 0.8; // m/s

/// Outdoor: jitter ratio must be ≤ this (path is coherent).
const double _kOutdoorMaxJitterRatio = 4.0;

/// Indoor (strong): accuracy ≥ this.
const double _kIndoorMinAccuracy = 35.0; // m

/// Indoor (displacement): standing still = net displacement below this.
const double _kIndoorMaxDisplacement =
    20.0; // m (generous — covers slow walkers too)

/// Indoor (jitter): GPS thrashing in place.
const double _kIndoorMinJitterRatio = 8.0;

/// Hysteresis: Outdoor → Indoor only after Indoor holds for this long.
const Duration _kOutdoorToIndoorHold = Duration(seconds: 30);

/// Hysteresis: Indoor → Outdoor only after Outdoor holds for this long.
const Duration _kIndoorToOutdoorHold = Duration(seconds: 20);

/// Debug logging every N seconds while detecting.
const Duration _kDebugInterval = Duration(seconds: 2);

// ─── Classifier ──────────────────────────────────────────────────────────────

/// Continuous, stream-based Indoor/Outdoor state machine.
///
/// Call [addPosition] for every GPS update.
/// Call [addStepDelta] whenever the pedometer fires.
/// Listen to [stateStream] for [ClassifierEvent] transitions.
/// Always call [dispose] when done.
class EnvironmentClassifier {
  // ── State ─────────────────────────────────────────────────────────────────
  final _window = Queue<Position>();
  int _stepsDeltaSinceLastEval = 0;
  TrackingEnvironment _committed = TrackingEnvironment.detecting;
  TrackingEnvironment? _candidate;
  DateTime? _candidateStart;
  DateTime? _detectingStartTime;

  // Timers
  Timer? _timeoutTimer;
  Timer? _debugTimer;

  // Stream
  final _controller = StreamController<ClassifierEvent>.broadcast();
  Stream<ClassifierEvent> get stateStream => _controller.stream;
  TrackingEnvironment get currentState => _committed;

  // ── Public API ─────────────────────────────────────────────────────────────

  void addPosition(Position p) {
    if (_controller.isClosed) return;

    // Record when we first get GPS data (start the timeout clock)
    _detectingStartTime ??= DateTime.now();
    _scheduleTimeoutIfNeeded();

    _window.addLast(p);
    if (_window.length > _kWindowSize) _window.removeFirst();

    if (_window.length < _kMinWindowSize) return;
    _evaluate();
  }

  void addStepDelta(int delta) {
    if (delta > 0) _stepsDeltaSinceLastEval += delta;
  }

  void dispose() {
    _timeoutTimer?.cancel();
    _debugTimer?.cancel();
    if (!_controller.isClosed) _controller.close();
  }

  // ── Timeout / Debug setup ─────────────────────────────────────────────────

  void _scheduleTimeoutIfNeeded() {
    if (_committed != TrackingEnvironment.detecting) return;
    if (_timeoutTimer != null) return; // already scheduled

    // Hard timeout: force Indoor if still detecting after 25s
    _timeoutTimer = Timer(_kMaxDetectDuration, _forceCommitOnTimeout);

    // Debug log every 2s while detecting
    if (kDebugMode) {
      _debugTimer = Timer.periodic(_kDebugInterval, (_) {
        if (_committed != TrackingEnvironment.detecting) {
          _debugTimer?.cancel();
          return;
        }
        if (_window.length >= _kMinWindowSize) {
          final m = _computeMetrics();
          final elapsed = _detectingStartTime == null
              ? 0
              : DateTime.now().difference(_detectingStartTime!).inSeconds;
          debugPrint(
            '[Classifier] t=${elapsed}s '
            'samples=${_window.length} '
            'accuracy=${m.avgAccuracy.toStringAsFixed(1)}m '
            'disp=${m.netDisplacement.toStringAsFixed(1)}m '
            'jitter=${m.jitterRatio.toStringAsFixed(2)} '
            'speed=${m.avgSpeed.toStringAsFixed(2)}m/s '
            'steps=$_stepsDeltaSinceLastEval',
          );
        } else {
          final elapsed = _detectingStartTime == null
              ? 0
              : DateTime.now().difference(_detectingStartTime!).inSeconds;
          debugPrint(
            '[Classifier] t=${elapsed}s samples=${_window.length} — waiting for data',
          );
        }
      });
    }
  }

  void _forceCommitOnTimeout() {
    if (_committed != TrackingEnvironment.detecting) return;
    if (_controller.isClosed) return;

    final reason = StringBuffer('TIMEOUT(25s)');
    TrackingEnvironment result = TrackingEnvironment.indoor; // safe fallback

    // If window has data, do one last strict outdoor check
    if (_window.length >= _kMinWindowSize) {
      final m = _computeMetrics();
      reason.write(
        ' accuracy=${m.avgAccuracy.toStringAsFixed(1)}m'
        ' disp=${m.netDisplacement.toStringAsFixed(1)}m'
        ' jitter=${m.jitterRatio.toStringAsFixed(2)}',
      );
      if (m.avgAccuracy <= _kOutdoorMaxAccuracy &&
          m.netDisplacement >= _kOutdoorMinDisplacement &&
          m.jitterRatio <= _kOutdoorMaxJitterRatio) {
        result = TrackingEnvironment.outdoor;
      }
    }

    debugPrint('[Classifier] forced → $result ($reason)');
    _committed = result;
    _candidate = null;
    _candidateStart = null;
    _controller.add(ClassifierEvent(result, reason.toString()));
  }

  // ── Evaluation ────────────────────────────────────────────────────────────

  void _evaluate() {
    final metrics = _computeMetrics();
    // Returns outdoor, indoor, or null (ambiguous)
    final candidateNow = _classify(metrics);

    if (candidateNow == null) {
      // Ambiguous: during detecting, check if we've been ambiguous long enough
      // to lean indoor (low displacement but accuracy in the grey zone 20–35m)
      if (_committed == TrackingEnvironment.detecting) {
        final elapsed = _detectingStartTime == null
            ? Duration.zero
            : DateTime.now().difference(_detectingStartTime!);
        // After 15s of ambiguous signals, commit indoor (better than staying stuck)
        if (elapsed >= const Duration(seconds: 15) &&
            metrics.netDisplacement < _kIndoorMaxDisplacement) {
          _commitDirect(
            TrackingEnvironment.indoor,
            metrics,
            'ambiguous→indoor after 15s low-displacement',
          );
        }
      }
      // For committed states, ambiguous = hold current state
      return;
    }

    // Candidate is the same as committed (already in right state) — reset
    if (candidateNow == _committed) {
      _candidate = null;
      _candidateStart = null;
      return;
    }

    // New candidate or same candidate still holding?
    if (_candidate != candidateNow) {
      _candidate = candidateNow;
      _candidateStart = DateTime.now();
      return;
    }

    // Same candidate holding — check hysteresis duration
    final held = DateTime.now().difference(_candidateStart!);
    final required = _holdRequired(_committed, candidateNow);
    if (held >= required) {
      _commitDirect(
        candidateNow,
        metrics,
        'hysteresis satisfied ${held.inSeconds}s',
      );
    }
  }

  // ── Classification ────────────────────────────────────────────────────────

  /// Returns outdoor, indoor, or null (ambiguous — not enough evidence yet).
  TrackingEnvironment? _classify(_WindowMetrics m) {
    // ── Emulator Debug Mode ──────────────────────────────────────────────────
    if (kDebugLocationMode) {
      // In debug mode, we assume emulator testing is for outdoor routes.
      // Force outdoor so `record_providers.dart` accumulates distance correctly.
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.outdoor;
    }

    // ── Outdoor ──────────────────────────────────────────────────────────────
    if (m.avgAccuracy <= _kOutdoorMaxAccuracy &&
        (m.netDisplacement >= _kOutdoorMinDisplacement ||
            m.avgSpeed >= _kOutdoorMinSpeed) &&
        m.jitterRatio <= _kOutdoorMaxJitterRatio) {
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.outdoor;
    }

    // ── Indoor ───────────────────────────────────────────────────────────────
    // Rule 1: poor accuracy — GPS unreliable indoors
    if (m.avgAccuracy >= _kIndoorMinAccuracy) {
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.indoor;
    }
    // Rule 2: not moving (displacement alone — no pedometer dependency)
    if (m.netDisplacement < _kIndoorMaxDisplacement) {
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.indoor;
    }
    // Rule 3: GPS thrashing (high jitter, not progressing)
    if (m.jitterRatio >= _kIndoorMinJitterRatio) {
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.indoor;
    }

    // ── Ambiguous ────────────────────────────────────────────────────────────
    // accuracy between 20–35 m AND some displacement but not enough for outdoor
    return null;
  }

  // ── Metrics ───────────────────────────────────────────────────────────────

  _WindowMetrics _computeMetrics() {
    final pts = _window.toList();
    final netDisplacement = Geolocator.distanceBetween(
      pts.first.latitude,
      pts.first.longitude,
      pts.last.latitude,
      pts.last.longitude,
    );

    double totalPath = 0;
    double totalSpeed = 0;
    double totalAccuracy = 0;

    for (int i = 0; i < pts.length; i++) {
      totalAccuracy += pts[i].accuracy;
      totalSpeed += pts[i].speed.clamp(0.0, 50.0);
      if (i > 0) {
        totalPath += Geolocator.distanceBetween(
          pts[i - 1].latitude,
          pts[i - 1].longitude,
          pts[i].latitude,
          pts[i].longitude,
        );
      }
    }

    return _WindowMetrics(
      netDisplacement: netDisplacement,
      totalPath: totalPath,
      avgAccuracy: totalAccuracy / pts.length,
      avgSpeed: totalSpeed / pts.length,
      jitterRatio: totalPath / netDisplacement.clamp(1.0, double.infinity),
      stepsIncreasing: _stepsDeltaSinceLastEval > 2,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Duration _holdRequired(TrackingEnvironment from, TrackingEnvironment to) {
    if (from == TrackingEnvironment.outdoor &&
        to == TrackingEnvironment.indoor) {
      return _kOutdoorToIndoorHold;
    }
    if (from == TrackingEnvironment.indoor &&
        to == TrackingEnvironment.outdoor) {
      return _kIndoorToOutdoorHold;
    }
    // detecting → outdoor/indoor: no hold, commit immediately
    return Duration.zero;
  }

  void _commitDirect(TrackingEnvironment env, _WindowMetrics m, String reason) {
    if (_controller.isClosed) return;
    _committed = env;
    _candidate = null;
    _candidateStart = null;
    _timeoutTimer?.cancel();
    _debugTimer?.cancel();

    final msg =
        '$reason | acc=${m.avgAccuracy.toStringAsFixed(1)}m '
        'disp=${m.netDisplacement.toStringAsFixed(1)}m '
        'jitter=${m.jitterRatio.toStringAsFixed(2)} '
        'speed=${m.avgSpeed.toStringAsFixed(2)}m/s';
    debugPrint('[Classifier] committed → $env ($msg)');
    _controller.add(ClassifierEvent(env, msg));
  }
}

// ─── Window metrics ───────────────────────────────────────────────────────────

class _WindowMetrics {
  final double netDisplacement;
  final double totalPath;
  final double avgAccuracy;
  final double avgSpeed;
  final double jitterRatio;
  final bool stepsIncreasing;

  const _WindowMetrics({
    required this.netDisplacement,
    required this.totalPath,
    required this.avgAccuracy,
    required this.avgSpeed,
    required this.jitterRatio,
    required this.stepsIncreasing,
  });
}
