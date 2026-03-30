import 'dart:async';
import 'dart:collection';
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// State types

enum TrackingEnvironment { detecting, outdoor, indoor }

/// State change event.
class ClassifierEvent {
  final TrackingEnvironment environment;
  final String reason;
  const ClassifierEvent(this.environment, this.reason);
}

// Thresholds

/// Detect timeout.
const Duration _kMaxDetectDuration = Duration(seconds: 25);

/// Minimum samples before classification.
const int _kMinWindowSize = 3;

/// Sliding window size.
const int _kWindowSize = 10;

/// Outdoor accuracy limit.
double get _kOutdoorMaxAccuracy => kDebugLocationMode ? 50.0 : 20.0; // m

/// Outdoor displacement limit.
double get _kOutdoorMinDisplacement => kDebugLocationMode ? 3.0 : 25.0; // m

/// Outdoor speed limit.
double get _kOutdoorMinSpeed => kDebugLocationMode ? 0.2 : 0.8; // m/s

/// Outdoor jitter limit.
const double _kOutdoorMaxJitterRatio = 4.0;

/// Indoor accuracy limit.
const double _kIndoorMinAccuracy = 35.0; // m

/// Indoor displacement limit.
const double _kIndoorMaxDisplacement = 20.0; // m

/// Indoor jitter limit.
const double _kIndoorMinJitterRatio = 8.0;

/// Hold time for outdoor -> indoor.
const Duration _kOutdoorToIndoorHold = Duration(seconds: 30);

/// Hold time for indoor -> outdoor.
const Duration _kIndoorToOutdoorHold = Duration(seconds: 20);

/// Debug log interval.
const Duration _kDebugInterval = Duration(seconds: 2);

// Classifier

/// Stream-based indoor/outdoor classifier.
class EnvironmentClassifier {
  // State
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

  // Public API

  void addPosition(Position p) {
    if (_controller.isClosed) return;

    // Start detect timeout on first GPS sample.
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

  // Timeout and debug

  void _scheduleTimeoutIfNeeded() {
    if (_committed != TrackingEnvironment.detecting) return;
    if (_timeoutTimer != null) return;

    // Force indoor if detection takes too long.
    _timeoutTimer = Timer(_kMaxDetectDuration, _forceCommitOnTimeout);

    // Periodic debug log while detecting.
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
    TrackingEnvironment result = TrackingEnvironment.indoor;

    // Final outdoor check before fallback.
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

  // Evaluation

  void _evaluate() {
    final metrics = _computeMetrics();
    final candidateNow = _classify(metrics);

    if (candidateNow == null) {
      // During initial detection, ambiguous signals can still settle indoor.
      if (_committed == TrackingEnvironment.detecting) {
        final elapsed = _detectingStartTime == null
            ? Duration.zero
            : DateTime.now().difference(_detectingStartTime!);
        if (elapsed >= const Duration(seconds: 15) &&
            metrics.netDisplacement < _kIndoorMaxDisplacement) {
          _commitDirect(
            TrackingEnvironment.indoor,
            metrics,
            'ambiguous→indoor after 15s low-displacement',
          );
        }
      }
      return;
    }

    // Reset when the candidate matches the committed state.
    if (candidateNow == _committed) {
      _candidate = null;
      _candidateStart = null;
      return;
    }

    // Start or continue hysteresis.
    if (_candidate != candidateNow) {
      _candidate = candidateNow;
      _candidateStart = DateTime.now();
      return;
    }

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

  // Classification

  /// Returns outdoor, indoor, or null.
  TrackingEnvironment? _classify(_WindowMetrics m) {
    // Outdoor rules
    if (m.avgAccuracy <= _kOutdoorMaxAccuracy &&
        (m.netDisplacement >= _kOutdoorMinDisplacement ||
            m.avgSpeed >= _kOutdoorMinSpeed) &&
        m.jitterRatio <= _kOutdoorMaxJitterRatio) {
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.outdoor;
    }

    // Indoor rules
    if (m.avgAccuracy >= _kIndoorMinAccuracy) {
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.indoor;
    }
    if (m.netDisplacement < _kIndoorMaxDisplacement) {
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.indoor;
    }
    if (m.jitterRatio >= _kIndoorMinJitterRatio) {
      _stepsDeltaSinceLastEval = 0;
      return TrackingEnvironment.indoor;
    }

    // Otherwise keep detecting.
    return null;
  }

  // Metrics

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

  // Helpers

  Duration _holdRequired(TrackingEnvironment from, TrackingEnvironment to) {
    if (from == TrackingEnvironment.outdoor &&
        to == TrackingEnvironment.indoor) {
      return _kOutdoorToIndoorHold;
    }
    if (from == TrackingEnvironment.indoor &&
        to == TrackingEnvironment.outdoor) {
      return _kIndoorToOutdoorHold;
    }
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

// Window metrics

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
