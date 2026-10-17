import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const distance = Distance(roundResult: false);
  const startPoint = LatLng(10.7380, 106.6252);

  group('Phase 4A: Adaptive Q Turn Motion Model Tests', () {
    test('Turn angle scaling: 30°, 60°, 90°, and 180° hairpin', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 5.5,
        initialHeadingDeg: 0.0,
      );

      // 1. Straight line: heading delta < 12° (e.g. 5°) -> no turn detected, scale = 1.0
      var nextPoint = distance.offset(startPoint, 5.5, 0.0);
      var estimate = ekf.update(
        measurementPoint: nextPoint,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        speedMs: 5.5,
        headingDeg: 5.0,
      );
      expect(estimate.diagnostics.turnDetected, isFalse);
      expect(
        estimate.diagnostics.headingProcessVariance,
        closeTo(0.5 * 0.5 * 1.0 * 1.0, 1e-4),
      );

      // 2. 30° turn: delta = 30° - 5° = 25° >= 12° -> turn detected, scale > 1.0
      nextPoint = distance.offset(nextPoint, 5.5, 30.0);
      estimate = ekf.update(
        measurementPoint: nextPoint,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        speedMs: 5.5,
        headingDeg: 30.0,
      );
      expect(estimate.diagnostics.turnDetected, isTrue);
      // turnStrength = (25° - 12°) / (90° - 12°) = 13 / 78 ≈ 0.1667
      // scale = 1.0 + 13.0 * 0.1667 ≈ 3.167
      final qBase = 0.5 * 0.5 * 1.0;
      expect(
        estimate.diagnostics.headingProcessVariance!,
        greaterThan(qBase * 2.5),
      );
      expect(
        estimate.diagnostics.headingProcessVariance!,
        lessThan(qBase * 5.0),
      );

      // 3. 60° turn: heading jumps to 90° (delta = 60°)
      nextPoint = distance.offset(nextPoint, 5.5, 90.0);
      estimate = ekf.update(
        measurementPoint: nextPoint,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        speedMs: 5.5,
        headingDeg: 90.0,
      );
      expect(estimate.diagnostics.turnDetected, isTrue);
      // turnStrength = (60° - 12°) / 78° = 48 / 78 ≈ 0.6154
      // scale = 1.0 + 13.0 * 0.6154 ≈ 9.0
      expect(
        estimate.diagnostics.headingProcessVariance!,
        greaterThan(qBase * 7.0),
      );
      expect(
        estimate.diagnostics.headingProcessVariance!,
        lessThan(qBase * 11.0),
      );

      // 4. 90° turn: heading jumps to 180° (delta = 90°) -> full max scale (14.0x)
      nextPoint = distance.offset(nextPoint, 5.5, 180.0);
      estimate = ekf.update(
        measurementPoint: nextPoint,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        speedMs: 5.5,
        headingDeg: 180.0,
      );
      expect(estimate.diagnostics.turnDetected, isTrue);
      expect(
        estimate.diagnostics.headingProcessVariance!,
        closeTo(qBase * 14.0, 1e-4),
      );

      // 5. Hairpin 180° turn: heading jumps from 180° to 0° (delta = 180°) -> clamped to max scale (14.0x)
      nextPoint = distance.offset(nextPoint, 5.5, 0.0);
      estimate = ekf.update(
        measurementPoint: nextPoint,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        speedMs: 5.5,
        headingDeg: 0.0,
      );
      expect(estimate.diagnostics.turnDetected, isTrue);
      expect(
        estimate.diagnostics.headingProcessVariance!,
        closeTo(qBase * 14.0, 1e-4),
      );
      expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
    });

    test('Cycling speeds coverage: 10 km/h, 20 km/h, 30 km/h turn tracking', () {
      final speedsKmh = [10.0, 20.0, 30.0];
      for (final speedKmh in speedsKmh) {
        final speedMs = speedKmh / 3.6;
        final ekf = ExtendedKalmanFilter();
        ekf.init(
          initialPoint: startPoint,
          initialSpeedMs: speedMs,
          initialHeadingDeg: 0.0,
        );

        var currentPoint = startPoint;
        // 5 steps straight
        for (var i = 0; i < 5; i++) {
          currentPoint = distance.offset(currentPoint, speedMs, 0.0);
          ekf.update(
            measurementPoint: currentPoint,
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
            speedMs: speedMs,
            headingDeg: 0.0,
          );
        }

        // 90-degree right turn
        currentPoint = distance.offset(currentPoint, speedMs, 90.0);
        final turnEstimate = ekf.update(
          measurementPoint: currentPoint,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          speedMs: speedMs,
          headingDeg: 90.0,
        );

        expect(
          turnEstimate.diagnostics.turnDetected,
          isTrue,
          reason: 'Turn must be detected at speed $speedKmh km/h',
        );
        expect(
          turnEstimate.diagnostics.headingProcessVariance,
          closeTo(0.5 * 0.5 * 1.0 * 14.0, 1e-3),
        );
        expect(
          ekf.isCovariancePositiveSemiDefinite,
          isTrue,
          reason: 'Covariance must remain PSD at $speedKmh km/h',
        );
      }
    });

    test('GPS sampling rates: 0.5 Hz, 1.0 Hz, 2.0 Hz invariance', () {
      final samplingDts = [2.0, 1.0, 0.5]; // 0.5 Hz, 1.0 Hz, 2.0 Hz
      const speedMs = 5.0;

      for (final dt in samplingDts) {
        final ekf = ExtendedKalmanFilter();
        ekf.init(
          initialPoint: startPoint,
          initialSpeedMs: speedMs,
          initialHeadingDeg: 0.0,
        );

        // Straight step
        var point = distance.offset(startPoint, speedMs * dt, 0.0);
        var estimate = ekf.update(
          measurementPoint: point,
          accuracyMeters: 4.0,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: 0.0,
        );
        // Base Q = sigma^2 * dt
        expect(
          estimate.diagnostics.headingProcessVariance,
          closeTo(0.5 * 0.5 * dt * 1.0, 1e-4),
        );

        // 90° Turn step
        point = distance.offset(point, speedMs * dt, 90.0);
        estimate = ekf.update(
          measurementPoint: point,
          accuracyMeters: 4.0,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: 90.0,
        );
        expect(estimate.diagnostics.turnDetected, isTrue);
        // Adaptive Q = sigma^2 * dt * 14.0
        expect(
          estimate.diagnostics.headingProcessVariance,
          closeTo(0.5 * 0.5 * dt * 14.0, 1e-4),
        );
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
      }
    });

    test('Heading wrap across 360°/0° boundary: 359° -> 1° and 340° -> 70°', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 5.0,
        initialHeadingDeg: 359.0,
      );

      // 1. Minimal wrap: 359° -> 1° (delta = 2° < 12°)
      // Must NOT trigger turn adaptation (guarantees no straight-line jitter on north headings)
      var point = distance.offset(startPoint, 5.0, 1.0);
      var estimate = ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 1.0,
      );
      expect(
        estimate.diagnostics.turnDetected,
        isFalse,
        reason: '359° -> 1° is only 2° delta, must be treated as straight line',
      );
      expect(
        estimate.diagnostics.headingProcessVariance,
        closeTo(0.5 * 0.5 * 1.0, 1e-4),
      );

      // 2. Turn across north: initialize step at 340°, then turn to 70° (delta = 90°)
      // Must trigger full turn adaptation
      point = distance.offset(point, 5.0, 340.0);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 340.0,
      );

      point = distance.offset(point, 5.0, 70.0);
      estimate = ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 70.0,
      );
      expect(
        estimate.diagnostics.turnDetected,
        isTrue,
        reason: '340° -> 70° is a 90° right turn across North',
      );
      expect(
        estimate.diagnostics.headingProcessVariance,
        closeTo(0.5 * 0.5 * 1.0 * 14.0, 1e-4),
      );

      // 3. Turn across north counter-clockwise: 20° -> 300° (delta = 80°)
      point = distance.offset(point, 5.0, 20.0);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 20.0,
      );

      point = distance.offset(point, 5.0, 300.0);
      estimate = ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 300.0,
      );
      expect(estimate.diagnostics.turnDetected, isTrue);
      expect(
        estimate.diagnostics.headingProcessVariance!,
        greaterThan(0.5 * 0.5 * 10.0),
      );
      expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
    });

    test('Heading dropout fallback and stationary suppression', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 5.0,
        initialHeadingDeg: null, // Initial heading absent
      );

      // 1. Moving north with no heading reported: course inferred from displacement
      var point = distance.offset(startPoint, 5.0, 0.0);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: null, // Missing heading sensor
      );
      point = distance.offset(point, 5.0, 0.0);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: null,
      );
      expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

      // Subsequent points moving east: 90° turn derived from displacement
      point = distance.offset(point, 5.0, 90.0);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: null,
      );
      point = distance.offset(point, 5.0, 90.0);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: null,
      );
      point = distance.offset(point, 5.0, 90.0);
      var estimate = ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: null, // Still missing heading
      );
      expect(
        estimate.diagnostics.turnDetected,
        isTrue,
        reason: 'EKF must detect 90° turn from position displacement even when heading is null',
      );
      expect(
        estimate.diagnostics.headingProcessVariance!,
        greaterThan(0.5 * 0.5 * 1.0 * 10.0),
      );

      // 2. Stationary suppression: cyclist stops (speed = 0 m/s)
      // Compass reports wild 180° swing while standing still
      estimate = ekf.update(
        measurementPoint: point, // Stationary position
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 0.0, // Stationary
        headingDeg: 270.0, // Erroneous compass fluctuation
      );
      expect(
        estimate.diagnostics.turnDetected,
        isFalse,
        reason: 'Turn adaptation must be suppressed when stationary to prevent heading wandering',
      );
      expect(
        estimate.diagnostics.headingProcessVariance,
        closeTo(0.5 * 0.5 * 1.0, 1e-4),
      );
    });

    test('Straight-line stability and physically plausible acceleration bounds', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 5.0,
        initialHeadingDeg: 45.0,
      );

      // Straight line with realistic micro-steering wobble (3° to 8°)
      var currentPoint = startPoint;
      for (var i = 0; i < 10; i++) {
        final wobbleHeading = 45.0 + (i % 3 == 0 ? 4.0 : -3.0);
        currentPoint = distance.offset(currentPoint, 5.0, wobbleHeading);
        final estimate = ekf.update(
          measurementPoint: currentPoint,
          accuracyMeters: 3.5,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: wobbleHeading,
        );
        expect(
          estimate.diagnostics.turnDetected,
          isFalse,
          reason: 'Steering wobble < 12° must not trigger turn adaptation',
        );
        expect(
          estimate.diagnostics.headingProcessVariance,
          closeTo(0.5 * 0.5 * 1.0, 1e-4),
        );
      }

      // Normal cycling acceleration: 5.0 m/s to 8.0 m/s in 1s (a = 3.0 m/s²)
      currentPoint = distance.offset(currentPoint, 8.0, 45.0);
      var estimate = ekf.update(
        measurementPoint: currentPoint,
        accuracyMeters: 3.5,
        timeDeltaSec: 1.0,
        speedMs: 8.0,
        headingDeg: 45.0,
      );
      // a = 3.0 m/s² -> max plausible acceleration scale (4.0x)
      expect(
        estimate.diagnostics.speedProcessVariance,
        closeTo(1.2 * 1.2 * 1.0 * 4.0, 1e-3),
      );

      // Extreme unphysical speed spike: 8.0 m/s to 40.0 m/s in 1s (a = 32.0 m/s²)
      // Must be clamped to 5.0 m/s² and noise scale bounded to 4.0x
      currentPoint = distance.offset(currentPoint, 8.0, 45.0);
      estimate = ekf.update(
        measurementPoint: currentPoint,
        accuracyMeters: 3.5,
        timeDeltaSec: 1.0,
        speedMs: 40.0,
        headingDeg: 45.0,
      );
      expect(
        estimate.diagnostics.speedProcessVariance,
        closeTo(1.2 * 1.2 * 1.0 * 4.0, 1e-3),
        reason: 'Process speed variance must remain bounded by maxAccelerationNoiseScale',
      );
      expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
    });

    test('Noisy GPS during 90° turn maintains positive semi-definiteness continuously', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 6.0,
        initialHeadingDeg: 0.0,
      );

      var truthPoint = startPoint;
      final random = math.Random(42);

      // Enter corner: 5 points straight north, then 5 points east (90° corner)
      for (var i = 0; i < 15; i++) {
        final heading = i < 5 ? 0.0 : 90.0;
        truthPoint = distance.offset(truthPoint, 6.0, heading);
        // Inject high GPS noise: ±7 meters
        final noiseDist = (random.nextDouble() - 0.5) * 14.0;
        final noiseBearing = random.nextDouble() * 360.0;
        final measuredPoint = distance.offset(truthPoint, noiseDist.abs(), noiseBearing);

        final estimate = ekf.update(
          measurementPoint: measuredPoint,
          accuracyMeters: 8.0,
          timeDeltaSec: 1.0,
          speedMs: 6.0 + (random.nextDouble() - 0.5) * 2.0,
          headingDeg: heading,
        );

        expect(
          ekf.isCovariancePositiveSemiDefinite,
          isTrue,
          reason: 'Covariance matrix must remain PSD on step $i under noisy turn conditions',
        );
        expect(estimate.positionVariance, greaterThan(0.0));
        expect(estimate.positionVariance.isFinite, isTrue);
      }
    });

    test('Turn responsiveness: adaptive Q reduces cross-track error during 90° turn', () {
      // Compare fixed Q (scale = 1.0) with adaptive Q (scale = 14.0)
      final fixedEkf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 1.0);
      final adaptiveEkf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);

      fixedEkf.init(initialPoint: startPoint, initialSpeedMs: 5.5, initialHeadingDeg: 0.0);
      adaptiveEkf.init(initialPoint: startPoint, initialSpeedMs: 5.5, initialHeadingDeg: 0.0);

      var truth = startPoint;
      // Approach straight
      for (var i = 0; i < 5; i++) {
        truth = distance.offset(truth, 5.5, 0.0);
        fixedEkf.update(measurementPoint: truth, accuracyMeters: 4.0, timeDeltaSec: 1.0, speedMs: 5.5, headingDeg: 0.0);
        adaptiveEkf.update(measurementPoint: truth, accuracyMeters: 4.0, timeDeltaSec: 1.0, speedMs: 5.5, headingDeg: 0.0);
      }

      // Execute sharp 90° right turn
      var fixedSumError = 0.0;
      var adaptiveSumError = 0.0;
      final fixedErrors = <double>[];
      final adaptiveErrors = <double>[];

      for (var i = 0; i < 5; i++) {
        truth = distance.offset(truth, 5.5, 90.0);
        final fixedEst = fixedEkf.update(
          measurementPoint: truth,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          speedMs: 5.5,
          headingDeg: 90.0,
        );
        final adaptiveEst = adaptiveEkf.update(
          measurementPoint: truth,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          speedMs: 5.5,
          headingDeg: 90.0,
        );

        final fixedErr = distance.distance(fixedEst.position, truth);
        final adaptiveErr = distance.distance(adaptiveEst.position, truth);
        fixedErrors.add(fixedErr);
        adaptiveErrors.add(adaptiveErr);
        fixedSumError += fixedErr;
        adaptiveSumError += adaptiveErr;
      }

      // 1. Mean cross-track error across the turn is significantly lower for adaptive Q (~20% reduction)
      expect(
        adaptiveSumError / 5,
        lessThan(fixedSumError / 5),
        reason: 'Adaptive Q turn model must reduce mean cross-track error across the corner',
      );

      // 2. From Step 1 onwards, adaptive Q tracks the new heading with significantly lower error
      for (var step = 1; step < 5; step++) {
        expect(
          adaptiveErrors[step],
          lessThan(fixedErrors[step]),
          reason: 'Step $step error must be lower for adaptive Q (faster recovery)',
        );
      }

      // 3. Final turn convergence error at Step 4 is substantially lower (> 50% reduction)
      expect(
        adaptiveErrors.last,
        lessThan(fixedErrors.last * 0.5),
        reason: 'Step 4 error must converge faster with adaptive Q',
      );
    });

    test('Turn latency is strictly under 1.0 ms per point', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(initialPoint: startPoint, initialSpeedMs: 6.0, initialHeadingDeg: 0.0);

      var point = startPoint;
      final stopwatch = Stopwatch()..start();
      const iterations = 1000;

      for (var i = 0; i < iterations; i++) {
        final heading = (i * 15.0) % 360.0;
        point = distance.offset(point, 6.0, heading);
        ekf.update(
          measurementPoint: point,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          speedMs: 6.0,
          headingDeg: heading,
        );
      }
      stopwatch.stop();
      final usPerPoint = stopwatch.elapsedMicroseconds / iterations;
      expect(
        usPerPoint,
        lessThan(1000.0),
        reason: 'Phase 4A update latency must be < 1000 µs (1 ms) per point',
      );
    });
  });
}
