import 'dart:async';

import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:geolocator/geolocator.dart';

class WorkoutEnvironmentController {
  EnvironmentClassifier? _classifier;
  StreamSubscription<ClassifierEvent>? _subscription;

  Future<void> start({
    required String activityType,
    required void Function(ClassifierEvent event) onEvent,
  }) async {
    await stop();
    _classifier = EnvironmentClassifier(activityType: activityType);
    _subscription = _classifier!.stateStream.listen(onEvent);
  }

  void addPosition(Position position) {
    _classifier?.addPosition(position);
  }

  void addStepDelta(int delta) {
    _classifier?.addStepDelta(delta);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _classifier?.dispose();
    _classifier = null;
  }
}
