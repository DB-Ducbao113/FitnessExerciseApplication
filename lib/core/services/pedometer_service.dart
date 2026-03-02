import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class PedometerService {
  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream;

  // Stream of raw steps
  Stream<StepCount>? get stepStream => _stepCountStream;
  Stream<PedestrianStatus>? get statusStream => _pedestrianStatusStream;

  Future<bool> requestPermission() async {
    // Android 10+ needs ACTIVITY_RECOGNITION permission
    if (await Permission.activityRecognition.request().isGranted) {
      return true;
    }
    return false;
  }

  void init() {
    _stepCountStream = Pedometer.stepCountStream;
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
  }
}
