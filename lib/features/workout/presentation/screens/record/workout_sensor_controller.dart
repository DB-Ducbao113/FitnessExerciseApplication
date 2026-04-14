import 'dart:async';

import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:geolocator/geolocator.dart';

class WorkoutSensorController {
  const WorkoutSensorController();

  Future<Position?> getLastKnownPosition(
    LocationTrackingService locationService,
  ) {
    return locationService.getLastKnownPosition();
  }

  Future<StreamSubscription<Position>> startGpsTracking({
    required LocationTrackingService locationService,
    required String activityType,
    required void Function(Position position) onPosition,
  }) async {
    await locationService.startTracking(activityType);
    return locationService.positionStream.listen(onPosition);
  }

  Future<void> stopGpsTracking({
    required LocationTrackingService locationService,
    required StreamSubscription<Position>? subscription,
  }) async {
    locationService.stopTracking();
    await subscription?.cancel();
  }

  Future<StreamSubscription<int>> startStepTracking({
    required StepTrackingService stepService,
    required void Function(int sessionSteps) onStep,
  }) async {
    await stepService.startTracking();
    return stepService.stepStream.listen(onStep);
  }

  Future<void> stopStepTracking({
    required StepTrackingService stepService,
    required StreamSubscription<int>? subscription,
  }) async {
    stepService.stopTracking();
    await subscription?.cancel();
  }
}
