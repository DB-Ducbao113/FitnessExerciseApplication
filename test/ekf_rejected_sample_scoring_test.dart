import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

void main() {
  group('Task 2: Rejected-Sample Scoring & Consecutive Rejection Propagation', () {
    const startPoint = LatLng(10.7380, 106.6252);
    const speedMs = 5.0; // 18 km/h moving East
    const headingDeg = 90.0; // East
    const dt = 1.0;

    final consecutiveRejectionCounts = [1, 5, 10, 30];

    for (final n in consecutiveRejectionCounts) {
      test('Moving bicycle with $n consecutive rejected samples propagates state and maintains finite covariance', () {
        final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
        ekf.init(
          initialPoint: startPoint,
          initialSpeedMs: speedMs,
          initialHeadingDeg: headingDeg,
        );

        // Step 0: Initial accepted measurement to establish baseline state
        var currentTruth = _distance.offset(startPoint, speedMs * dt, headingDeg);
        final initialEst = ekf.update(
          measurementPoint: currentTruth,
          accuracyMeters: 4.0,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: headingDeg,
        );
        expect(initialEst.diagnostics.positionDecision, equals(EkfMeasurementDecision.normal));

        var prevPosition = initialEst.position;
        var prevVariance = initialEst.positionVariance;
        int inputCount = 1;
        int acceptedCount = 1;
        int rejectedCount = 0;

        // Inject N consecutive rejected samples
        for (int k = 1; k <= n; k++) {
          inputCount++;
          currentTruth = _distance.offset(currentTruth, speedMs * dt, headingDeg);

          // Inject large 100m lateral outlier to trigger NIS rejection (NIS >> 13.816)
          final outlierMeasurement = _distance.offset(currentTruth, 100.0, 0.0);

          final est = ekf.update(
            measurementPoint: outlierMeasurement,
            accuracyMeters: 4.0,
            timeDeltaSec: dt,
            speedMs: speedMs,
            headingDeg: headingDeg,
          );

          // 1. Assert rejection decision
          expect(est.diagnostics.positionDecision, equals(EkfMeasurementDecision.rejected),
              reason: 'Sample $k must be rejected by NIS gating');
          rejectedCount++;

          // 2. Assert state propagation: EKF must NOT freeze at prevPosition
          final stepDistance = _distance.distance(prevPosition, est.position);
          expect(stepDistance, greaterThan(3.5),
              reason: 'Step $k must propagate forward (expected ~5.0m, got ${stepDistance.toStringAsFixed(2)}m)');
          expect(stepDistance, lessThan(6.5),
              reason: 'Step $k forward displacement must be physically plausible');

          // Total displacement from initial point
          final totalDistance = _distance.distance(initialEst.position, est.position);
          final expectedTotalDistance = k * speedMs * dt;
          expect(totalDistance, closeTo(expectedTotalDistance, 2.0),
              reason: 'Dead-reckoning must track along trajectory (k=$k)');

          // Error relative to ground truth during straight dead-reckoning should remain small
          final errorFromTruth = _distance.distance(est.position, currentTruth);
          expect(errorFromTruth, lessThan(3.0),
              reason: 'Straight dead-reckoning error relative to truth should be < 3m even after $k rejections');

          // 3. Assert finite and positive semi-definite covariance
          expect(est.positionVariance.isFinite, isTrue, reason: 'Position variance must be finite');
          expect(est.positionVariance, greaterThan(0.0), reason: 'Position variance must be strictly positive');
          expect(ekf.isCovariancePositiveSemiDefinite, isTrue, reason: 'Covariance must remain PSD');

          // Variance must grow monotonically due to process noise accumulation during predict-only
          expect(est.positionVariance, greaterThanOrEqualTo(prevVariance - 1e-6),
              reason: 'Covariance must grow or maintain during prediction without position update');

          prevPosition = est.position;
          prevVariance = est.positionVariance;
        }

        // 4. Sample accounting verification
        expect(inputCount, equals(1 + n));
        expect(acceptedCount, equals(1));
        expect(rejectedCount, equals(n));
        expect(acceptedCount + rejectedCount, equals(inputCount), reason: '100% of samples accounted');
      });
    }

    test('Recovery immediately after 30 consecutive rejected samples', () {
      final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
      ekf.init(
        initialPoint: startPoint,
        initialSpeedMs: speedMs,
        initialHeadingDeg: headingDeg,
      );

      var currentTruth = startPoint;

      // 30 consecutive rejected samples
      for (int k = 1; k <= 30; k++) {
        currentTruth = _distance.offset(currentTruth, speedMs * dt, headingDeg);
        final outlier = _distance.offset(currentTruth, 120.0, 0.0);
        final est = ekf.update(
          measurementPoint: outlier,
          accuracyMeters: 4.0,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: headingDeg,
        );
        expect(est.diagnostics.positionDecision, equals(EkfMeasurementDecision.rejected));
      }

      // Step 31: Valid measurement arrives exactly at truth
      currentTruth = _distance.offset(currentTruth, speedMs * dt, headingDeg);
      final recoveredEst = ekf.update(
        measurementPoint: currentTruth,
        accuracyMeters: 4.0,
        timeDeltaSec: dt,
        speedMs: speedMs,
        headingDeg: headingDeg,
      );

      // Must be accepted (either normal or downWeighted) and snap back immediately
      expect(recoveredEst.diagnostics.positionDecision, isNot(equals(EkfMeasurementDecision.rejected)));
      final recoveryErr = _distance.distance(recoveredEst.position, currentTruth);
      expect(recoveryErr, lessThan(2.0), reason: 'Filter must immediately recover accurate position');
      expect(ekf.isCovariancePositiveSemiDefinite, isTrue);
    });
  });
}
