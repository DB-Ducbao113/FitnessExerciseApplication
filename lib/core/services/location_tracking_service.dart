import 'dart:async';
import 'dart:io';
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationTrackingServiceProvider = Provider(
  (ref) => LocationTrackingService(
    debugLocationMode: kDebugLocationMode,
    debugMockPlaybackMode: kDebugMockPlaybackMode,
  ),
);

class LocationTrackingService {
  final bool debugLocationMode;
  final bool debugMockPlaybackMode;

  LocationTrackingService({
    this.debugLocationMode = false,
    this.debugMockPlaybackMode = false,
  });

  StreamSubscription<Position>? _positionStream;
  final _positionController = StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  Future<void> ensurePermissionsOrThrow() async {
    final t0 = DateTime.now();
    debugPrint('[GPS] ensurePermissions start');

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('location_disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('[GPS] requesting permission...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('permission_denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('permission_denied_forever');
    }

    debugPrint(
      '[GPS] permissions OK in ${DateTime.now().difference(t0).inMilliseconds}ms',
    );
  }

  Future<Position?> getLastKnownPosition() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      debugPrint('[GPS] lastKnown lat=${p?.latitude} lng=${p?.longitude}');
      return p;
    } catch (e) {
      debugPrint('[GPS] getLastKnownPosition error: $e');
      return null;
    }
  }

  Future<Position?> getCurrentPositionWithTimeout({
    Position? fallback,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: timeout,
        ),
      );
      debugPrint(
        '[GPS] getCurrentPosition lat=${p.latitude}, lng=${p.longitude}, acc=${p.accuracy}m',
      );
      return p;
    } on TimeoutException {
      debugPrint('[GPS] getCurrentPosition timeout, fallback to lastKnown');
      return fallback;
    } catch (e) {
      debugPrint('[GPS] getCurrentPosition error: $e, fallback to lastKnown');
      return fallback;
    }
  }

  Future<void> startTracking(String activityType) async {
    await ensurePermissionsOrThrow();

    const distanceFilter = 0;
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        intervalDuration: debugLocationMode
            ? const Duration(milliseconds: 250)
            : const Duration(milliseconds: 500),
        // forceLocationManager=true makes Android Emulator mock routes work correctly.
        // The FusedLocationProvider sometimes ignores emulator mock locations.
        forceLocationManager: debugLocationMode ? true : false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Tracking your workout',
          notificationTitle: 'Fitness Tracker',
          enableWakeLock: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
      );
    }

    debugPrint(
      '[GPS] startTracking activity=$activityType debug=$debugLocationMode mockPlayback=$debugMockPlaybackMode distanceFilter=$distanceFilter forceLocationManager=$debugLocationMode',
    );

    if (_positionStream != null) {
      await _positionStream!.cancel();
    }
    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (raw) {
            if (debugLocationMode) {
              debugPrint(
                '[GPS-RAW] lat=${raw.latitude}, lng=${raw.longitude}, acc=${raw.accuracy}, speed=${raw.speed}',
              );
            }
            _positionController.add(raw);
          },
          onError: (e) {
            debugPrint('[GPS] stream error: $e');
            _positionController.addError(e);
          },
        );

    debugPrint('[GPS] stream subscription started OK');
  }

  void stopTracking() {
    debugPrint('[GPS] stopTracking');
    _positionStream?.cancel();
    _positionStream = null;
  }
}
