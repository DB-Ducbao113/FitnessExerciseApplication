// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const distance = Distance(roundResult: false);
  const startPoint = LatLng(10.7380, 106.6252);

  group('Task 1: Accuracy-Aware Course-Over-Ground Audit & Regression Tests', () {
    test('Audit 1: Straight cycling at 3 m/s with 8 m accuracy and heading dropout', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 3.0,
        initialHeadingDeg: null,
      );

      var truth = startPoint;
      var falseTurnCount = 0;
      final headingScales = <double>[];
      final positionErrors = <double>[];

      // 15 seconds of straight North riding (0.0° heading), but GPS has lateral noise ±3.5m (well within 8m accuracy)
      for (var second = 1; second <= 15; second++) {
        truth = distance.offset(startPoint, second * 3.0, 0.0);
        // Alternating lateral jitter: +3.5m East on even seconds, -3.5m West on odd seconds
        final lateralOffsetMeters = (second % 2 == 0) ? 3.5 : -3.5;
        final rawPoint = distance.offset(truth, lateralOffsetMeters.abs(), lateralOffsetMeters > 0 ? 90.0 : 270.0);

        final estimate = ekf.update(
          measurementPoint: rawPoint,
          accuracyMeters: 8.0,
          timeDeltaSec: 1.0,
          speedMs: 3.0,
          headingDeg: null, // Heading dropout throughout
        );

        headingScales.add(estimate.diagnostics.headingProcessVariance! / (0.5 * 0.5 * 1.0));
        if (estimate.diagnostics.turnDetected) {
          falseTurnCount++;
        }
        positionErrors.add(distance.distance(estimate.position, truth));
      }

      print('Audit 1 - Straight 3 m/s, 8m accuracy, heading dropout:');
      print('  False turn detections: $falseTurnCount / 15 (${(falseTurnCount / 15 * 100).toStringAsFixed(1)}%)');
      print('  Max heading scale: ${headingScales.reduce(math.max).toStringAsFixed(2)}x');
      print('  Mean heading scale: ${(headingScales.reduce((a, b) => a + b) / headingScales.length).toStringAsFixed(2)}x');
      print('  Max position error: ${positionErrors.reduce(math.max).toStringAsFixed(2)} m');

      // Regression Assertion: On a straight road, false turn detection rate MUST be low (<= 20%)
      // and heading process noise MUST NOT be repeatedly inflated to max (14x)
      expect(
        falseTurnCount,
        lessThanOrEqualTo(3),
        reason: 'Raw jitter on straight road must not cause repeated false turn detections',
      );
      expect(
        headingScales.reduce(math.max),
        lessThan(5.0),
        reason: 'Heading noise scale must not hit max (14x) on straight line jitter',
      );
    });

    test('Audit 2: Lateral jitter greater than actual movement per sample (2 m/s, 6 m accuracy)', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 2.0,
        initialHeadingDeg: null,
      );

      var truth = startPoint;
      var falseTurnCount = 0;
      final headingScales = <double>[];

      // 10 seconds of straight riding at 2 m/s (2m movement per sec) with ±2.5m jitter (accuracy 6m)
      for (var second = 1; second <= 10; second++) {
        truth = distance.offset(startPoint, second * 2.0, 0.0);
        final lateralOffset = (second % 2 == 0) ? 2.5 : -2.5;
        final rawPoint = distance.offset(truth, lateralOffset.abs(), lateralOffset > 0 ? 90.0 : 270.0);

        final estimate = ekf.update(
          measurementPoint: rawPoint,
          accuracyMeters: 6.0,
          timeDeltaSec: 1.0,
          speedMs: 2.0,
          headingDeg: null,
        );

        headingScales.add(estimate.diagnostics.headingProcessVariance! / (0.5 * 0.5 * 1.0));
        if (estimate.diagnostics.turnDetected) falseTurnCount++;
      }

      print('Audit 2 - 2 m/s, 6m accuracy, lateral jitter > movement:');
      print('  False turn detections: $falseTurnCount / 10');
      print('  Max heading scale: ${headingScales.reduce(math.max).toStringAsFixed(2)}x');

      expect(
        falseTurnCount,
        lessThanOrEqualTo(2),
        reason: 'Lateral jitter exceeding travel distance must be filtered out of turn detection',
      );
    });

    test('Audit 3: Heading dropout lasting multiple samples (10 samples)', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 5.0,
        initialHeadingDeg: 0.0,
      );

      var truth = startPoint;
      var falseTurnCount = 0;

      // 10 straight samples without heading sensor
      for (var second = 1; second <= 10; second++) {
        truth = distance.offset(truth, 5.0, 0.0);
        // Slight realistic GPS noise ±1.5m
        final noise = (second % 3 == 0) ? 1.5 : -1.0;
        final raw = distance.offset(truth, noise.abs(), noise > 0 ? 90.0 : 270.0);

        final estimate = ekf.update(
          measurementPoint: raw,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: null, // Sustained dropout
        );

        if (estimate.diagnostics.turnDetected) falseTurnCount++;
      }

      print('Audit 3 - Sustained heading dropout (10 samples):');
      print('  False turn detections: $falseTurnCount / 10');

      expect(falseTurnCount, lessThanOrEqualTo(2));
    });

    test('Audit 4: Low-speed motion near stationary threshold (0.9 m/s)', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: 0.9,
        initialHeadingDeg: null,
      );

      var truth = startPoint;
      var falseTurnCount = 0;

      // 10 samples creeping at 0.9 m/s with 4m accuracy and heading dropout
      for (var second = 1; second <= 10; second++) {
        truth = distance.offset(truth, 0.9, 0.0);
        final jitter = (second % 2 == 0) ? 1.5 : -1.5;
        final raw = distance.offset(truth, jitter.abs(), jitter > 0 ? 90.0 : 270.0);

        final estimate = ekf.update(
          measurementPoint: raw,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          speedMs: 0.9,
          headingDeg: null,
        );

        if (estimate.diagnostics.turnDetected) falseTurnCount++;
      }

      print('Audit 4 - Creeping motion 0.9 m/s:');
      print('  False turn detections: $falseTurnCount / 10');

      expect(falseTurnCount, lessThanOrEqualTo(2));
    });

    test('Audit 5: Genuine 30°, 60°, 90°, and hairpin turns WITH HEADING DROPOUT', () {
      final turnAngles = [30.0, 60.0, 90.0, 180.0];
      const speedMs = 5.0;

      for (final targetTurnDeg in turnAngles) {
        final ekf = ExtendedKalmanFilter();
        ekf.init(
          initialPoint: startPoint,
          initialSpeedMs: speedMs,
          initialHeadingDeg: null, // Heading absent
        );

        var truth = startPoint;
        // 5 steps straight North
        for (var i = 0; i < 5; i++) {
          truth = distance.offset(truth, speedMs, 0.0);
          ekf.update(
            measurementPoint: truth,
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
            speedMs: speedMs,
            headingDeg: null,
          );
        }

        // Execute genuine turn over 5 steps
        var turnDetectedDuringCorner = false;
        var maxScaleDuringCorner = 1.0;
        for (var i = 0; i < 5; i++) {
          truth = distance.offset(truth, speedMs, targetTurnDeg);
          final estimate = ekf.update(
            measurementPoint: truth,
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
            speedMs: speedMs,
            headingDeg: null, // Still dropout!
          );

          if (estimate.diagnostics.turnDetected) {
            turnDetectedDuringCorner = true;
          }
          final scale = estimate.diagnostics.headingProcessVariance! / (0.5 * 0.5 * 1.0);
          if (scale > maxScaleDuringCorner) maxScaleDuringCorner = scale;
        }

        print('Audit 5 - Genuine $targetTurnDeg° turn with heading dropout:');
        print('  Turn detected: $turnDetectedDuringCorner, Max scale: ${maxScaleDuringCorner.toStringAsFixed(2)}x');

        expect(
          turnDetectedDuringCorner,
          isTrue,
          reason: 'Genuine $targetTurnDeg° turn MUST be detected even during heading dropout',
        );
        expect(
          maxScaleDuringCorner,
          greaterThan(2.0),
          reason: 'Heading scale must adapt during genuine $targetTurnDeg° turn',
        );
      }
    });
  });
}
