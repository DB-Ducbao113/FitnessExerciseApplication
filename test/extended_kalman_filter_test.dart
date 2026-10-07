import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('ExtendedKalmanFilter', () {
    late ExtendedKalmanFilter ekf;

    setUp(() {
      ekf = ExtendedKalmanFilter();
    });

    test('initializes on first point and returns initial position', () {
      const initial = LatLng(10.7769, 106.7009);
      final est = ekf.update(
        measurementPoint: initial,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
      );

      expect(ekf.isInitialized, isTrue);
      expect(est.position.latitude, closeTo(initial.latitude, 1e-6));
      expect(est.position.longitude, closeTo(initial.longitude, 1e-6));
    });

    test('trusts high-accuracy measurement much more than low-accuracy measurement', () {
      const p0 = LatLng(10.0000, 106.0000);
      ekf.update(
        measurementPoint: p0,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 2.0,
        headingDeg: 90.0, // Moving East
      );

      // Point with high accuracy (low noise R = 4^2 = 16)
      const cleanMeasurement = LatLng(10.0000, 106.0001);
      final cleanEst = ekf.update(
        measurementPoint: cleanMeasurement,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
      );

      // Reset and simulate noisy measurement with low accuracy (high noise R = 35^2 = 1225)
      final ekfNoisy = ExtendedKalmanFilter();
      ekfNoisy.update(
        measurementPoint: p0,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 2.0,
        headingDeg: 90.0,
      );

      const noisyMeasurement = LatLng(10.0000, 106.0001);
      final noisyEst = ekfNoisy.update(
        measurementPoint: noisyMeasurement,
        accuracyMeters: 35.0,
        timeDeltaSec: 1.0,
      );

      // Clean update should pull the state closer to the measurement than the noisy one
      final cleanPull = (cleanEst.position.longitude - p0.longitude).abs();
      final noisyPull = (noisyEst.position.longitude - p0.longitude).abs();

      expect(cleanPull, greaterThan(noisyPull));
    });

    test('tracks 90-degree turn adaptively without manual turn threshold', () {
      const start = LatLng(10.0000, 106.0000);
      ekf.update(
        measurementPoint: start,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 3.0,
        headingDeg: 0.0, // Heading North
      );

      // Moving North for 3 steps
      var current = start;
      const dist = Distance();
      for (var i = 0; i < 3; i++) {
        current = dist.offset(current, 3.0, 0.0);
        ekf.update(
          measurementPoint: current,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 3.0,
          headingDeg: 0.0,
        );
      }

      // Sharp 90-degree turn East
      for (var i = 0; i < 4; i++) {
        current = dist.offset(current, 3.0, 90.0);
        final est = ekf.update(
          measurementPoint: current,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 3.0,
          headingDeg: 90.0,
        );
        expect(est.position.latitude.isFinite, isTrue);
        expect(est.position.longitude.isFinite, isTrue);
      }

      // After 4 Eastward steps, estimated heading should adapt toward ~90 degrees
      final finalEst = ekf.update(
        measurementPoint: current,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 3.0,
        headingDeg: 90.0,
      );

      expect(finalEst.headingDeg, closeTo(90.0, 15.0));
    });

    test('execution latency is strictly under 1.0 ms per point (Slide 15 requirement)', () {
      const p0 = LatLng(10.7769, 106.7009);
      ekf.update(
        measurementPoint: p0,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
      );

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      var cur = p0;
      const d = Distance();

      for (var i = 0; i < iterations; i++) {
        cur = d.offset(cur, 2.5, 45.0);
        ekf.update(
          measurementPoint: cur,
          accuracyMeters: 4.5,
          timeDeltaSec: 1.0,
          speedMs: 2.5,
          headingDeg: 45.0,
        );
      }
      stopwatch.stop();

      final totalTimeMs = stopwatch.elapsedMicroseconds / 1000.0;
      final timePerPointMs = totalTimeMs / iterations;

      expect(timePerPointMs, lessThan(0.5)); // Well below the 1.0 ms limit!
    });
  });
}
