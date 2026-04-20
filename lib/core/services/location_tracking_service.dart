import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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

  Future<Position?> acquireStartupLock({
    required String activityType,
    Position? fallback,
    Duration maxWait = const Duration(seconds: 6),
  }) async {
    await ensurePermissionsOrThrow();

    final desiredAccuracy = _startupLockAccuracy(activityType);
    final stableRadiusMeters = math.max(6.0, desiredAccuracy * 0.7);
    final completer = Completer<Position?>();
    Position? bestFix = fallback;
    Position? stableCandidate;
    StreamSubscription<Position>? subscription;
    Timer? timeoutTimer;

    void finish(Position? result) {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      unawaited(subscription?.cancel());
      completer.complete(result);
    }

    try {
      subscription =
          Geolocator.getPositionStream(
            locationSettings: _buildLocationSettings(),
          ).listen((position) {
            final currentBestAccuracy = bestFix?.accuracy ?? double.infinity;
            if (position.accuracy < currentBestAccuracy) {
              bestFix = position;
            }

            if (position.accuracy > desiredAccuracy) return;

            final candidate = stableCandidate;
            if (candidate == null) {
              stableCandidate = position;
              if (position.accuracy <= desiredAccuracy * 0.65) {
                finish(position);
              }
              return;
            }

            final delta = Geolocator.distanceBetween(
              candidate.latitude,
              candidate.longitude,
              position.latitude,
              position.longitude,
            );
            final preferredFix = position.accuracy <= candidate.accuracy
                ? position
                : candidate;
            if (delta <= stableRadiusMeters ||
                position.accuracy <= desiredAccuracy * 0.65) {
              finish(preferredFix);
              return;
            }

            stableCandidate = preferredFix;
          }, onError: (_) => finish(bestFix ?? fallback));

      timeoutTimer = Timer(maxWait, () => finish(bestFix ?? fallback));
      return await completer.future;
    } catch (e) {
      debugPrint('[GPS] acquireStartupLock error: $e');
      return bestFix ?? fallback;
    }
  }

  Future<void> startTracking(String activityType) async {
    await ensurePermissionsOrThrow();

    final settings = _buildLocationSettings();

    debugPrint(
      '[GPS] startTracking activity=$activityType debug=$debugLocationMode mockPlayback=$debugMockPlaybackMode distanceFilter=0 forceLocationManager=$debugLocationMode',
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

  LocationSettings _buildLocationSettings() {
    const distanceFilter = 0;
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        intervalDuration: debugLocationMode
            ? const Duration(milliseconds: 250)
            : const Duration(milliseconds: 500),
        forceLocationManager: debugLocationMode ? true : false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Tracking your workout',
          notificationTitle: 'Fitness Tracker',
          enableWakeLock: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
    );
  }

  double _startupLockAccuracy(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 18.0;
      case 'walking':
        return 16.0;
      case 'running':
      default:
        return 14.0;
    }
  }

  void stopTracking() {
    debugPrint('[GPS] stopTracking');
    _positionStream?.cancel();
    _positionStream = null;
  }
}
