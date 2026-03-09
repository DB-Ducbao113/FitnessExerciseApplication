import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationTrackingServiceProvider = Provider(
  (ref) => LocationTrackingService(),
);

// ─── Kalman filter ────────────────────────────────────────────────────────────

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

// ─── Service ──────────────────────────────────────────────────────────────────

class LocationTrackingService {
  StreamSubscription<Position>? _positionStream;
  final _positionController = StreamController<Position>.broadcast();

  Position? _lastValidPosition;
  _KalmanAxis? _latFilter;
  _KalmanAxis? _lngFilter;

  Stream<Position> get positionStream => _positionController.stream;

  // ── Permission check (throws named exceptions, never opens settings) ────────

  /// Returns normally if permissions are ready.
  /// Throws a named exception string if the caller must show UI.
  /// Does NOT open any system settings dialog — avoids the indefinite await.
  Future<void> ensurePermissionsOrThrow() async {
    final t0 = DateTime.now();
    debugPrint('[GPS] ensurePermissions start');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Throw immediately — let the UI decide whether to open settings
      throw Exception('location_disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('[GPS] requesting permission…');
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

  // ── Location acquisition helpers ───────────────────────────────────────────

  /// Tier 1 — instant. Returns the OS-cached last known position (no GPS wait).
  /// Always call this first to show the map marker immediately.
  Future<Position?> getLastKnownPosition() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      debugPrint('[GPS] lastKnown: lat=${p?.latitude} lng=${p?.longitude}');
      return p;
    } catch (e) {
      debugPrint('[GPS] getLastKnownPosition error: $e');
      return null;
    }
  }

  /// Tier 2 — fresh GPS fix with a hard [timeout].
  /// Falls back to [fallback] (lastKnown) if the device cannot get a fix in time.
  Future<Position?> getCurrentPositionWithTimeout({
    Position? fallback,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      debugPrint(
        '[GPS] getCurrentPosition: ${p.latitude}, ${p.longitude} acc=${p.accuracy}m',
      );
      return p;
    } on TimeoutException {
      debugPrint('[GPS] getCurrentPosition timeout — using lastKnown');
      return fallback;
    } catch (e) {
      debugPrint('[GPS] getCurrentPosition error: $e — using lastKnown');
      return fallback;
    }
  }

  // ── Start / stop ───────────────────────────────────────────────────────────

  /// Starts the GPS position stream. Returns immediately after starting the
  /// subscription — does NOT await the first fix.
  Future<void> startTracking(String activityType) async {
    await ensurePermissionsOrThrow();
    debugPrint('[GPS] startTracking: setting up stream');

    // Reset Kalman state for fresh session
    _lastValidPosition = null;
    _latFilter = null;
    _lngFilter = null;

    _positionStream?.cancel();

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy:
                LocationAccuracy.high, // not "bestForNavigation" — faster fix
            distanceFilter: 2,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText: 'Tracking your workout',
              notificationTitle: 'Fitness Tracker',
              enableWakeLock: true,
            ),
          ),
        ).listen(
          (Position rawPosition) {
            final smoothed = _applyKalmanFilter(rawPosition);
            if (_isValidPosition(smoothed, activityType)) {
              _lastValidPosition = smoothed;
              _positionController.add(smoothed);
            }
          },
          onError: (e) {
            debugPrint('[GPS] stream error: $e');
            _positionController.addError(e);
          },
        );

    debugPrint('[GPS] stream subscription started');
  }

  void stopTracking() {
    debugPrint('[GPS] stopTracking');
    _positionStream?.cancel();
    _positionStream = null;
    _lastValidPosition = null;
    _latFilter = null;
    _lngFilter = null;
  }

  // ── Kalman filter ─────────────────────────────────────────────────────────

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

  // ── Noise filter ──────────────────────────────────────────────────────────

  bool _isValidPosition(Position position, String activityType) {
    // Reject poor accuracy — anything above 25m is too noisy.
    if (position.accuracy > 25.0) return false;

    // First valid position is always accepted.
    if (_lastValidPosition == null) return true;

    final distance = Geolocator.distanceBetween(
      _lastValidPosition!.latitude,
      _lastValidPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // NOTE: The 2m distance filter was intentionally removed.
    // The service's job is to forward all ACCURATE positions so that the live
    // "You" marker updates continuously. The 5m polyline jitter filter lives
    // in _onPosition() in record_providers.dart, where it belongs.

    // Sanity check: reject physically-impossible speed jumps.
    final timeDelta = position.timestamp
        .difference(_lastValidPosition!.timestamp)
        .inSeconds;
    if (timeDelta > 0) {
      final speed = distance / timeDelta; // m/s
      final maxSpeed = activityType.toLowerCase() == 'cycling' ? 25.0 : 15.0;
      if (speed > maxSpeed) return false;
    }

    return true;
  }
}
