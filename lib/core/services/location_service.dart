import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;

  final _locationController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationController.stream;

  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<void> startTracking({bool debugMode = true}) async {
    final minDistance = debugMode ? 1 : 3;
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: minDistance,
      forceLocationManager: false,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'Tracking your workout',
        notificationTitle: 'Fitness Tracker',
        enableWakeLock: true,
      ),
    );

    debugPrint(
      '[LocationService] startTracking debug=$debugMode distanceFilter=$minDistance',
    );

    await _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      final ts = position.timestamp?.toIso8601String() ?? 'null';
      debugPrint(
        '[LocationService] event lat=${position.latitude}, lng=${position.longitude}, acc=${position.accuracy}, speed=${position.speed}, ts=$ts',
      );
      _locationController.add(position);
    });
  }

  void stopTracking() {
    debugPrint('[LocationService] stopTracking');
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      debugPrint(
        '[LocationService] current lat=${p.latitude}, lng=${p.longitude}, acc=${p.accuracy}',
      );
      return p;
    } catch (e) {
      debugPrint('[LocationService] getCurrentPosition error: $e');
      return null;
    }
  }
}
