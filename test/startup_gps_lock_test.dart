import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('LocationTrackingService startup GPS freshness', () {
    final service = LocationTrackingService();
    final now = DateTime(2026, 5, 8, 8);

    Position makePosition({
      required DateTime timestamp,
      required double accuracy,
    }) {
      return Position(
        latitude: 10,
        longitude: 106,
        timestamp: timestamp,
        accuracy: accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    test('accepts a fresh accurate startup fix', () {
      final fix = makePosition(
        timestamp: now.subtract(const Duration(seconds: 2)),
        accuracy: 10,
      );

      expect(
        service.isFreshStartupLock(fix, activityType: 'running', now: now),
        isTrue,
      );
    });

    test('rejects stale last-known position as startup lock', () {
      final stale = makePosition(
        timestamp: now.subtract(const Duration(minutes: 2)),
        accuracy: 8,
      );

      expect(
        service.isFreshStartupLock(stale, activityType: 'walking', now: now),
        isFalse,
      );
    });

    test(
      'rejects weak low-accuracy startup fix while waiting for better GPS',
      () {
        final weak = makePosition(
          timestamp: now.subtract(const Duration(seconds: 1)),
          accuracy: 55,
        );

        expect(
          service.isFreshStartupLock(weak, activityType: 'walking', now: now),
          isFalse,
        );
      },
    );
  });
}
