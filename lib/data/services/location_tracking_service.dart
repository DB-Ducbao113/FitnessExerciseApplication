import 'dart:async';
import 'package:fitness_exercise_application/core/config/debug_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationTrackingServiceProvider = Provider(
  (ref) => LocationTrackingService(debugLocationMode: kDebugLocationMode),
);

class _KalmanAxis {
  double estimate;
  double errorEstimate;
  static const double _processNoise = 1e-3;

  _KalmanAxis({required this.estimate, required this.errorEstimate});

  double update(double measured, double measuredNoise) {
    errorEstimate += _processNoise;
    final k = errorEstimate / (errorEstimate + measuredNoise);
    estimate = estimate + k * (measured - estimate);
    errorEstimate = (1 - k) * errorEstimate;
    return estimate;
  }
}

class LocationTrackingService {
  final bool debugLocationMode;

  LocationTrackingService({this.debugLocationMode = false});

  StreamSubscription<Position>? _positionStream;
  final _positionController = StreamController<Position>.broadcast();

  Position? _lastValidPosition;
  _KalmanAxis? _latFilter;
  _KalmanAxis? _lngFilter;

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

    final distanceFilter = debugLocationMode
        ? 0
        : 3; // 0 = every point on emulator
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
      // forceLocationManager=true makes Android Emulator mock routes work correctly.
      // The FusedLocationProvider sometimes ignores emulator mock locations.
      forceLocationManager: debugLocationMode ? true : false,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'Tracking your workout',
        notificationTitle: 'Fitness Tracker',
        enableWakeLock: true,
      ),
    );

    debugPrint(
      '[GPS] startTracking activity=$activityType debug=$debugLocationMode distanceFilter=$distanceFilter forceLocationManager=${debugLocationMode}',
    );

    _lastValidPosition = null;
    _latFilter = null;
    _lngFilter = null;

    await _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
      (raw) {
        // Always log raw incoming position in debug mode.
        if (debugLocationMode) {
          debugPrint(
            '[GPS-RAW] lat=${raw.latitude}, lng=${raw.longitude}, acc=${raw.accuracy}, speed=${raw.speed}',
          );
        }

        // In debug/emulator mode, skip the Kalman filter entirely.
        // Emulator sends accuracy=0.0 which causes NaN in the filter.
        final smoothed = debugLocationMode ? raw : _applyKalmanFilter(raw);
        final validation = _validatePosition(smoothed, activityType);

        if (debugLocationMode) {
          debugPrint(
            '[GPS-VAL] accepted=${validation.accepted} reason=${validation.reason}',
          );
        }

        if (!validation.accepted) return;

        _lastValidPosition = smoothed;
        _positionController.add(smoothed);
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
    _lastValidPosition = null;
    _latFilter = null;
    _lngFilter = null;
  }

  Position _applyKalmanFilter(Position raw) {
    final measuredNoise = raw.accuracy * raw.accuracy;

    _latFilter ??= _KalmanAxis(
      estimate: raw.latitude,
      errorEstimate: measuredNoise,
    );
    _lngFilter ??= _KalmanAxis(
      estimate: raw.longitude,
      errorEstimate: measuredNoise,
    );

    final smoothLat = _latFilter!.update(raw.latitude, measuredNoise);
    final smoothLng = _lngFilter!.update(raw.longitude, measuredNoise);

    return Position(
      latitude: smoothLat,
      longitude: smoothLng,
      timestamp: raw.timestamp,
      accuracy: raw.accuracy,
      altitude: raw.altitude,
      altitudeAccuracy: raw.altitudeAccuracy,
      heading: raw.heading,
      headingAccuracy: raw.headingAccuracy,
      speed: raw.speed,
      speedAccuracy: raw.speedAccuracy,
    );
  }

  _ValidationResult _validatePosition(Position position, String activityType) {
    final maxAccuracy = debugLocationMode ? 80.0 : 35.0;
    if (position.accuracy > maxAccuracy) {
      return _ValidationResult(
        false,
        'accuracy>${maxAccuracy.toStringAsFixed(0)}m',
      );
    }

    if (_lastValidPosition == null) {
      return const _ValidationResult(true, 'first_point');
    }

    final prev = _lastValidPosition!;
    final distance = Geolocator.distanceBetween(
      prev.latitude,
      prev.longitude,
      position.latitude,
      position.longitude,
    );

    if (distance < 0.3) {
      return const _ValidationResult(false, 'duplicate_or_tiny_move');
    }

    final nowTs = position.timestamp;
    final prevTs = prev.timestamp;
    if (nowTs != null && prevTs != null) {
      final sec = nowTs.difference(prevTs).inMilliseconds / 1000;
      if (sec > 0) {
        final speed = distance / sec;
        final maxSpeed = debugLocationMode
            ? 40.0
            : (activityType.toLowerCase() == 'cycling' ? 25.0 : 15.0);
        if (speed > maxSpeed) {
          return _ValidationResult(
            false,
            'unrealistic_speed=${speed.toStringAsFixed(2)}m/s',
          );
        }
      }
    }

    return const _ValidationResult(true, 'ok');
  }
}

class _ValidationResult {
  final bool accepted;
  final String reason;

  const _ValidationResult(this.accepted, this.reason);
}
