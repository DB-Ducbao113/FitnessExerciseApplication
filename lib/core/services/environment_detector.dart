import 'dart:async';
import 'dart:collection';

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum TrackingEnvironment { detecting, outdoor, indoor }

class ClassifierEvent {
  final TrackingEnvironment environment;
  final String reason;
  final double confidence;
  final bool fallbackSuggested;

  const ClassifierEvent(
    this.environment,
    this.reason, {
    this.confidence = 0.0,
    this.fallbackSuggested = false,
  });
}

const int _kMinWindowSize = 3;
const int _kWindowSize = 10;

class EnvironmentClassifier {
  EnvironmentClassifier({required this.activityType});

  final String activityType;
  final _window = Queue<Position>();
  int _stepsDeltaSinceLastEval = 0;
  TrackingEnvironment _hint = TrackingEnvironment.detecting;
  final _controller = StreamController<ClassifierEvent>.broadcast();

  Stream<ClassifierEvent> get stateStream => _controller.stream;
  TrackingEnvironment get currentState => _hint;

  void addPosition(Position p) {
    if (_controller.isClosed) return;

    _window.addLast(p);
    if (_window.length > _kWindowSize) _window.removeFirst();

    if (_window.length < _kMinWindowSize) {
      _emit(
        TrackingEnvironment.detecting,
        'warming_up samples=${_window.length}',
        confidence: 0.0,
      );
      return;
    }

    _evaluate();
  }

  void addStepDelta(int delta) {
    if (delta > 0) _stepsDeltaSinceLastEval += delta;
  }

  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }

  void _evaluate() {
    final metrics = _computeMetrics();
    final activity = activityType.toLowerCase();

    final outdoorAccuracy = _outdoorMaxAccuracy(activity);
    final outdoorDisplacement = _outdoorMinDisplacement(activity);
    final outdoorSpeed = _outdoorMinSpeed(activity);
    final indoorAccuracy = _indoorMinAccuracy(activity);
    final indoorDisplacement = _indoorMaxDisplacement(activity);

    final outdoorScore = _score(
      accuracyScore: metrics.avgAccuracy <= outdoorAccuracy ? 0.45 : 0.10,
      displacementScore: metrics.netDisplacement >= outdoorDisplacement
          ? 0.30
          : (metrics.netDisplacement / outdoorDisplacement).clamp(0.0, 1.0) * 0.30,
      speedScore: metrics.avgSpeed >= outdoorSpeed
          ? 0.15
          : (metrics.avgSpeed / outdoorSpeed).clamp(0.0, 1.0) * 0.15,
      jitterScore: metrics.jitterRatio <= _outdoorMaxJitterRatio(activity)
          ? 0.10
          : 0.02,
    );

    final fallbackSuggested =
        metrics.avgAccuracy >= indoorAccuracy &&
        metrics.netDisplacement <= indoorDisplacement &&
        metrics.stepsIncreasing;

    final indoorScore = _score(
      accuracyScore: metrics.avgAccuracy >= indoorAccuracy ? 0.40 : 0.10,
      displacementScore: metrics.netDisplacement <= indoorDisplacement
          ? 0.30
          : 0.05,
      speedScore: metrics.avgSpeed <= _indoorMaxSpeed(activity) ? 0.15 : 0.03,
      jitterScore: metrics.jitterRatio >= _indoorMinJitterRatio(activity)
          ? 0.15
          : 0.05,
    );

    final nextHint = outdoorScore >= indoorScore
        ? TrackingEnvironment.outdoor
        : TrackingEnvironment.indoor;
    final confidence = (outdoorScore - indoorScore).abs().clamp(0.0, 1.0);
    final reason =
        'acc=${metrics.avgAccuracy.toStringAsFixed(1)}m '
        'disp=${metrics.netDisplacement.toStringAsFixed(1)}m '
        'speed=${metrics.avgSpeed.toStringAsFixed(2)}m/s '
        'jitter=${metrics.jitterRatio.toStringAsFixed(2)} '
        'steps=$_stepsDeltaSinceLastEval';

    _emit(
      nextHint,
      reason,
      confidence: confidence,
      fallbackSuggested: fallbackSuggested,
    );
    _stepsDeltaSinceLastEval = 0;
  }

  void _emit(
    TrackingEnvironment environment,
    String reason, {
    required double confidence,
    bool fallbackSuggested = false,
  }) {
    if (_controller.isClosed) return;
    final changed = environment != _hint;
    _hint = environment;
    if (changed || kDebugMode) {
      debugPrint(
        '[Classifier] hint=$environment confidence=${confidence.toStringAsFixed(2)} '
        'fallbackSuggested=$fallbackSuggested $reason',
      );
    }
    _controller.add(
      ClassifierEvent(
        environment,
        reason,
        confidence: confidence,
        fallbackSuggested: fallbackSuggested,
      ),
    );
  }

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

  double _outdoorMaxAccuracy(String activity) {
    if (kDebugLocationMode) return 60.0;
    switch (activity) {
      case 'walking':
        return 40.0;
      case 'running':
        return 35.0;
      case 'cycling':
        return 28.0;
      default:
        return 35.0;
    }
  }

  double _outdoorMinDisplacement(String activity) {
    if (kDebugLocationMode) return 2.0;
    switch (activity) {
      case 'walking':
        return 6.0;
      case 'running':
        return 10.0;
      case 'cycling':
        return 18.0;
      default:
        return 8.0;
    }
  }

  double _outdoorMinSpeed(String activity) {
    if (kDebugLocationMode) return 0.15;
    switch (activity) {
      case 'walking':
        return 0.35;
      case 'running':
        return 0.85;
      case 'cycling':
        return 1.8;
      default:
        return 0.5;
    }
  }

  double _outdoorMaxJitterRatio(String activity) {
    switch (activity) {
      case 'walking':
        return 7.0;
      case 'running':
        return 6.0;
      case 'cycling':
        return 5.0;
      default:
        return 6.0;
    }
  }

  double _indoorMinAccuracy(String activity) {
    switch (activity) {
      case 'walking':
        return 45.0;
      case 'running':
        return 40.0;
      case 'cycling':
        return 35.0;
      default:
        return 40.0;
    }
  }

  double _indoorMaxDisplacement(String activity) {
    switch (activity) {
      case 'walking':
        return 5.0;
      case 'running':
        return 6.5;
      case 'cycling':
        return 10.0;
      default:
        return 6.0;
    }
  }

  double _indoorMaxSpeed(String activity) {
    switch (activity) {
      case 'walking':
        return 1.8;
      case 'running':
        return 2.5;
      case 'cycling':
        return 4.0;
      default:
        return 2.0;
    }
  }

  double _indoorMinJitterRatio(String activity) {
    switch (activity) {
      case 'walking':
        return 8.0;
      case 'running':
        return 7.0;
      case 'cycling':
        return 6.0;
      default:
        return 7.0;
    }
  }

  double _score({
    required double accuracyScore,
    required double displacementScore,
    required double speedScore,
    required double jitterScore,
  }) {
    return (accuracyScore + displacementScore + speedScore + jitterScore)
        .clamp(0.0, 1.0);
  }
}

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
