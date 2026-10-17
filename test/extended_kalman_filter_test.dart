import 'dart:math' as math;

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

    test('reports valid speed and heading used to seed the first state', () {
      final estimate = ekf.update(
        measurementPoint: const LatLng(10.0, 106.0),
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      expect(estimate.diagnostics.usedSpeedMeasurement, isTrue);
      expect(estimate.diagnostics.usedHeadingMeasurement, isTrue);
      expect(estimate.diagnostics.effectivePositionVariance, 9.0);
    });

    test(
      'rejects invalid coordinates before initializing or mutating state',
      () {
        expect(
          () => ekf.update(
            measurementPoint: const LatLng(double.nan, 106.0),
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
          ),
          throwsArgumentError,
        );
        expect(ekf.isInitialized, isFalse);

        const valid = LatLng(10.0, 106.0);
        ekf.update(
          measurementPoint: valid,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
        );
        final covarianceBefore = ekf.covariance;

        expect(
          () => ekf.update(
            measurementPoint: const LatLng(10.0, double.infinity),
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
          ),
          throwsArgumentError,
        );
        expect(ekf.covariance, covarianceBefore);
        expect(
          () => ekf.update(
            measurementPoint: const LatLng(91.0, 106.0),
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
          ),
          throwsArgumentError,
        );
      },
    );

    test('rejects invalid noise configuration in every build mode', () {
      expect(
        () => ExtendedKalmanFilter(processPosStd: double.nan),
        throwsArgumentError,
      );
      expect(
        () => ExtendedKalmanFilter(processSpeedStd: -0.1),
        throwsArgumentError,
      );
      expect(
        () => ExtendedKalmanFilter(processHeadingStd: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => ExtendedKalmanFilter(positionAccuracyScale: 0.0),
        throwsArgumentError,
      );
      expect(
        () => ExtendedKalmanFilter(
          nisDownWeightThreshold: 10.0,
          nisRejectThreshold: 9.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExtendedKalmanFilter(turnThresholdRad: math.pi / 2),
        throwsArgumentError,
      );
    });

    test(
      'trusts high-accuracy measurement much more than low-accuracy measurement',
      () {
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
      },
    );

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

    test('wraps heading innovation across 359 to 1 degrees', () {
      const point = LatLng(10.0000, 106.0000);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 359.0,
      );

      final estimate = ekf.update(
        measurementPoint: const Distance().offset(point, 5.0, 1.0),
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 1.0,
      );

      final circularError = math.min(
        (estimate.headingDeg - 1.0).abs(),
        360.0 - (estimate.headingDeg - 1.0).abs(),
      );
      expect(circularError, lessThan(10.0));
      expect(estimate.diagnostics.headingInnovationRad!.abs(), lessThan(0.1));
    });

    test('uses variances for adaptive heading and speed measurement noise', () {
      ekf = ExtendedKalmanFilter(positionAccuracyScale: 1.0);
      const point = LatLng(10.0000, 106.0000);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        speedMs: 4.0,
        headingDeg: 0.0,
      );

      final estimate = ekf.update(
        measurementPoint: const Distance().offset(point, 4.0, 0.0),
        accuracyMeters: 8.0,
        timeDeltaSec: 2.0,
        speedMs: 4.0,
        headingDeg: 5.0,
      );

      final diagnostics = estimate.diagnostics;
      expect(diagnostics.usedSpeedMeasurement, isTrue);
      expect(diagnostics.usedHeadingMeasurement, isTrue);
      expect(diagnostics.speedVariance, closeTo(32.0, 1e-9));
      final expectedHeadingStd = math.atan2(math.sqrt(2) * 8.0, 4.0 * 2.0);
      expect(
        diagnostics.headingVarianceRad2,
        closeTo(expectedHeadingStd * expectedHeadingStd, 1e-9),
      );
    });

    test('reports Q as variance and the sanitized effective time delta', () {
      ekf = ExtendedKalmanFilter(
        processPosStd: 2.0,
        processSpeedStd: 3.0,
        processHeadingStd: 0.25,
        maxAccelerationNoiseScale: 1.0,
        maxTurnHeadingNoiseScale: 1.0,
      );
      const point = LatLng(10.0, 106.0);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
      );

      final estimate = ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: 2.0,
      );
      expect(estimate.diagnostics.effectiveTimeDeltaSec, 2.0);
      expect(estimate.diagnostics.timeDeltaWasSanitized, isFalse);
      expect(estimate.diagnostics.positionProcessVariance, closeTo(8.0, 1e-12));
      expect(estimate.diagnostics.speedProcessVariance, closeTo(18.0, 1e-12));
      expect(
        estimate.diagnostics.headingProcessVariance,
        closeTo(0.125, 1e-12),
      );

      final invalidDt = ekf.update(
        measurementPoint: point,
        accuracyMeters: 4.0,
        timeDeltaSec: double.nan,
      );
      expect(invalidDt.diagnostics.effectiveTimeDeltaSec, 1.0);
      expect(invalidDt.diagnostics.timeDeltaWasSanitized, isTrue);
    });

    test(
      'rejects a 55 meter position spike using NIS gating and recovers in 1 sample',
      () {
        const distance = Distance();
        var truth = const LatLng(10.0000, 106.0000);
        ekf.update(
          measurementPoint: truth,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        for (var index = 0; index < 5; index += 1) {
          truth = distance.offset(truth, 5.0, 90.0);
          ekf.update(
            measurementPoint: truth,
            accuracyMeters: 3.0,
            timeDeltaSec: 1.0,
            speedMs: 5.0,
            headingDeg: 90.0,
          );
        }

        final expected = distance.offset(truth, 5.0, 90.0);
        final spike = distance.offset(expected, 55.0, 0.0);
        final spikeEstimate = ekf.update(
          measurementPoint: spike,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );

        // 1. Spike rejected, NIS exceeds threshold
        expect(
          spikeEstimate.diagnostics.positionDecision,
          EkfMeasurementDecision.rejected,
        );
        expect(spikeEstimate.diagnostics.positionNis, greaterThan(13.816));
        expect(
          spikeEstimate.diagnostics.positionInnovationMeters,
          closeTo(55.0, 1.0),
        );
        // Effective variance for rejected measurement remains base rPos
        expect(
          spikeEstimate.diagnostics.effectivePositionVariance,
          closeTo((3.0 * 0.75) * (3.0 * 0.75), 1e-9),
        );
        // State remains on dead-reckoned corridor, not pulled toward spike
        expect(
          distance.distance(spikeEstimate.position, expected),
          lessThan(0.5),
        );
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

        // 2. Recovery: immediately at next valid measurement (1 sample)
        final nextTruth = distance.offset(expected, 5.0, 90.0);
        final recoveryEstimate = ekf.update(
          measurementPoint: nextTruth,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );

        expect(
          recoveryEstimate.diagnostics.positionDecision,
          EkfMeasurementDecision.normal,
        );
        expect(recoveryEstimate.diagnostics.positionNis, lessThan(5.991));
        expect(
          distance.distance(recoveryEstimate.position, nextTruth),
          lessThan(0.2),
        );
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
      },
    );

    test(
      'handles multipath burst by rejecting consecutive outliers and recovers within 2 samples',
      () {
        const distance = Distance();
        var truth = const LatLng(10.0000, 106.0000);
        ekf.update(
          measurementPoint: truth,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        for (var index = 0; index < 5; index += 1) {
          truth = distance.offset(truth, 5.0, 90.0);
          ekf.update(
            measurementPoint: truth,
            accuracyMeters: 3.0,
            timeDeltaSec: 1.0,
            speedMs: 5.0,
            headingDeg: 90.0,
          );
        }

        final initialCovariance = ekf.covariance[0][0];

        // 4 consecutive erratic multipath outliers (+40m to +60m at various angles)
        final burstOffsets = [
          (45.0, 0.0),
          (60.0, 45.0),
          (50.0, 315.0),
          (55.0, 180.0),
        ];

        var previousPosVariance = initialCovariance;
        for (var i = 0; i < burstOffsets.length; i++) {
          truth = distance.offset(truth, 5.0, 90.0);
          final corrupted = distance.offset(
            truth,
            burstOffsets[i].$1,
            burstOffsets[i].$2,
          );
          final estimate = ekf.update(
            measurementPoint: corrupted,
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
            speedMs: 5.0,
            headingDeg: 90.0,
          );

          // All burst measurements must be rejected
          expect(
            estimate.diagnostics.positionDecision,
            EkfMeasurementDecision.rejected,
          );
          expect(estimate.diagnostics.positionNis, greaterThan(13.816));
          // Filter stays on dead-reckoned path
          expect(distance.distance(estimate.position, truth), lessThan(1.5));
          expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

          // Covariance grows during outage / rejection reflecting accumulated process noise
          final currentPosVariance = ekf.covariance[0][0];
          expect(currentPosVariance, greaterThan(previousPosVariance));
          previousPosVariance = currentPosVariance;
        }

        // Clean measurements resume after burst
        truth = distance.offset(truth, 5.0, 90.0);
        final cleanEst1 = ekf.update(
          measurementPoint: truth,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(
          cleanEst1.diagnostics.positionDecision,
          EkfMeasurementDecision.normal,
        );
        expect(distance.distance(cleanEst1.position, truth), lessThan(0.5));
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

        truth = distance.offset(truth, 5.0, 90.0);
        final cleanEst2 = ekf.update(
          measurementPoint: truth,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(
          cleanEst2.diagnostics.positionDecision,
          EkfMeasurementDecision.normal,
        );
        expect(distance.distance(cleanEst2.position, truth), lessThan(0.1));
        // Covariance contracts back
        expect(ekf.covariance[0][0], lessThan(previousPosVariance));
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
      },
    );

    test(
      'adapts to sustained bias smoothly transitioning from rejected to downWeighted to locked',
      () {
        const distance = Distance();
        var truth = const LatLng(10.0000, 106.0000);
        ekf.update(
          measurementPoint: truth,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        for (var index = 0; index < 5; index += 1) {
          truth = distance.offset(truth, 5.0, 90.0);
          ekf.update(
            measurementPoint: truth,
            accuracyMeters: 3.0,
            timeDeltaSec: 1.0,
            speedMs: 5.0,
            headingDeg: 90.0,
          );
        }

        // Sustained +15.0m North step bias
        const stepBias = 15.0;
        final decisions = <EkfMeasurementDecision>[];

        for (var step = 0; step < 10; step++) {
          truth = distance.offset(truth, 5.0, 90.0);
          final biasedMeasurement = distance.offset(truth, stepBias, 0.0);
          final est = ekf.update(
            measurementPoint: biasedMeasurement,
            accuracyMeters: 3.0,
            timeDeltaSec: 1.0,
            speedMs: 5.0,
            headingDeg: 90.0,
          );
          decisions.add(est.diagnostics.positionDecision);
          expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

          if (step >= 3) {
            // By step 3, filter has locked onto the new line within 0.1m
            expect(
              distance.distance(est.position, biasedMeasurement),
              lessThan(0.1),
            );
            expect(est.diagnostics.positionDecision, EkfMeasurementDecision.normal);
          }
        }

        // Proves decision evolution: rejected -> downWeighted -> normal
        expect(decisions[0], EkfMeasurementDecision.rejected);
        expect(decisions[1], EkfMeasurementDecision.downWeighted);
        expect(decisions[2], EkfMeasurementDecision.normal);
        expect(decisions[3], EkfMeasurementDecision.normal);
      },
    );

    test(
      'down-weights a suspicious position innovation and inflates effective variance',
      () {
        const distance = Distance();
        const start = LatLng(10.0000, 106.0000);
        ekf.update(
          measurementPoint: start,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        final expected = distance.offset(start, 5.0, 90.0);
        final suspicious = distance.offset(expected, 20.0, 0.0);

        final estimate = ekf.update(
          measurementPoint: suspicious,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );

        expect(
          estimate.diagnostics.positionDecision,
          EkfMeasurementDecision.downWeighted,
        );
        const baseVariance = (3.0 * 0.75) * (3.0 * 0.75); // 5.0625
        expect(
          estimate.diagnostics.effectivePositionVariance,
          greaterThan(baseVariance),
        );
        expect(
          estimate.diagnostics.effectivePositionVariance,
          lessThanOrEqualTo(baseVariance * 16.0),
        );
        expect(
          distance.distance(estimate.position, expected),
          lessThan(distance.distance(suspicious, expected)),
        );
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
      },
    );

    test(
      'handles invalid and extreme reported accuracy policies robustly',
      () {
        const p0 = LatLng(10.0000, 106.0000);
        ekf.update(
          measurementPoint: p0,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );

        // 1. NaN accuracy: fallback to 5.0m std
        final nanEst = ekf.update(
          measurementPoint: p0,
          accuracyMeters: double.nan,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(nanEst.diagnostics.effectivePositionVariance, closeTo(25.0, 1e-9));
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

        // 2. Negative accuracy: fallback to 5.0m std
        final negEst = ekf.update(
          measurementPoint: p0,
          accuracyMeters: -5.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(negEst.diagnostics.effectivePositionVariance, closeTo(25.0, 1e-9));
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

        // 3. Zero accuracy: fallback to 5.0m std
        final zeroEst = ekf.update(
          measurementPoint: p0,
          accuracyMeters: 0.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(zeroEst.diagnostics.effectivePositionVariance, closeTo(25.0, 1e-9));
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

        // 4. Infinite accuracy: fallback to 5.0m std
        final infEst = ekf.update(
          measurementPoint: p0,
          accuracyMeters: double.infinity,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(infEst.diagnostics.effectivePositionVariance, closeTo(25.0, 1e-9));
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

        // 5. Extremely small accuracy (0.1m): clamped to minimum 1.5m std
        final smallEst = ekf.update(
          measurementPoint: p0,
          accuracyMeters: 0.1,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(smallEst.diagnostics.effectivePositionVariance, closeTo(2.25, 1e-9));
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);

        // 6. Extremely large accuracy (500m): clamped to 100m std
        final largeEst = ekf.update(
          measurementPoint: p0,
          accuracyMeters: 500.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(largeEst.diagnostics.effectivePositionVariance, closeTo(10000.0, 1e-9));
        expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
      },
    );

    test(
      'raises heading process noise as soon as a valid sharp turn arrives',
      () {
        const distance = Distance();
        var point = const LatLng(10.0000, 106.0000);
        ekf.update(
          measurementPoint: point,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 0.0,
        );
        point = distance.offset(point, 5.0, 0.0);
        ekf.update(
          measurementPoint: point,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 0.0,
        );

        point = distance.offset(point, 5.0, 90.0);
        final turn = ekf.update(
          measurementPoint: point,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 90.0,
        );

        expect(turn.diagnostics.turnDetected, isTrue);
        expect(turn.diagnostics.headingDeltaRad, closeTo(math.pi / 2, 0.05));
        expect(
          turn.diagnostics.headingProcessVariance,
          greaterThan(0.35 * 0.35),
        );
        expect(turn.headingDeg, closeTo(90.0, 30.0));
      },
    );

    test(
      'ignores negative speed and heading measured at walking-still speed',
      () {
        const point = LatLng(10.0000, 106.0000);
        ekf.update(
          measurementPoint: point,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 0.1,
          headingDeg: 20.0,
        );

        expect(
          ekf
              .update(
                measurementPoint: point,
                accuracyMeters: 3.0,
                timeDeltaSec: 1.0,
              )
              .headingDeg,
          closeTo(0.0, 1e-9),
        );

        final estimate = ekf.update(
          measurementPoint: point,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: -4.0,
          headingDeg: 200.0,
        );

        expect(estimate.speedMs, greaterThanOrEqualTo(0.0));
        expect(estimate.diagnostics.usedSpeedMeasurement, isFalse);
        expect(estimate.diagnostics.usedHeadingMeasurement, isFalse);
      },
    );

    test('does not seed an out-of-range initial heading', () {
      final estimate = ekf.update(
        measurementPoint: const LatLng(10.0, 106.0),
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 361.0,
      );

      expect(estimate.headingDeg, 0.0);
      expect(estimate.diagnostics.usedHeadingMeasurement, isFalse);
    });

    test('ignores heading outside the normalized degree range', () {
      const point = LatLng(10.0000, 106.0000);
      ekf.update(
        measurementPoint: point,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 0.0,
      );

      final estimate = ekf.update(
        measurementPoint: point,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 361.0,
      );

      expect(estimate.diagnostics.usedSpeedMeasurement, isTrue);
      expect(estimate.diagnostics.usedHeadingMeasurement, isFalse);
      expect(estimate.diagnostics.headingInnovationRad, isNull);
    });

    test(
      'keeps Joseph-updated covariance finite symmetric and non-negative',
      () {
        var point = const LatLng(10.0000, 106.0000);
        ekf.update(
          measurementPoint: point,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 359.0,
        );

        for (var index = 0; index < 2000; index += 1) {
          final heading = index.isEven ? 1.0 : 359.0;
          point = const Distance().offset(point, 5.0, heading);
          final estimate = ekf.update(
            measurementPoint: point,
            accuracyMeters: 3.0 + (index % 20),
            timeDeltaSec: index % 97 == 0 ? double.nan : 1.0,
            speedMs: index % 113 == 0 ? -1.0 : 5.0,
            headingDeg: heading,
          );

          final covariance = ekf.covariance;
          expect(estimate.diagnostics.covarianceCorrectionApplied, isFalse);
          expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
          for (var row = 0; row < 4; row += 1) {
            expect(covariance[row][row].isFinite, isTrue);
            expect(covariance[row][row], greaterThanOrEqualTo(0.0));
            for (var column = 0; column < 4; column += 1) {
              expect(covariance[row][column].isFinite, isTrue);
              expect(
                covariance[row][column],
                closeTo(covariance[column][row], 1e-9),
              );
            }
          }
        }
      },
    );

    test(
      'execution latency is strictly under 1.0 ms per point (Slide 15 requirement)',
      () {
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
      },
    );
  });
}
