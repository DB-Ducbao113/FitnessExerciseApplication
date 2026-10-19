import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/covariance_stability_validator.dart';

void main() {
  group('TASK 3.4 — Covariance Stability & Numerical Unit Tests', () {
    test('1. Symmetric positive-definite matrix passes with positive min eigenvalue', () {
      final p = [
        [25.0, 2.0, 0.5, 0.1],
        [2.0, 25.0, 0.2, 0.05],
        [0.5, 0.2, 4.0, 0.01],
        [0.1, 0.05, 0.01, 1.0],
      ];

      final result = CovarianceStabilityValidator.validate(p);

      expect(result.isFinite, isTrue);
      expect(result.isSymmetric, isTrue);
      expect(result.worstSymmetryResidual, lessThanOrEqualTo(result.toleranceSym));
      expect(result.isPositiveSemiDefinite, isTrue);
      expect(result.minEigenvalue, greaterThan(0.0));
      expect(result.isLdltPsd, isTrue);
      expect(result.conditionNumber, isNotNull);
      expect(result.conditionNumber!, greaterThan(1.0));

      // Spectral trace invariant: sum(eigenvalues) == trace
      final eigSum = result.eigenvalues.reduce((a, b) => a + b);
      expect((eigSum - result.trace).abs(), lessThan(1e-10 * result.trace));
    });

    test('2. Positive semi-definite matrix with a zero eigenvalue passes PSD check', () {
      // Construct a rank-3 matrix: v1*v1^T + v2*v2^T + v3*v3^T
      // v1 = [1, 0, 0, 0], v2 = [0, 2, 0, 0], v3 = [0, 0, 3, 0]
      // Row 3 / Col 3 is all zeros -> lambda_0 = 0.0 exactly.
      final p = [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 4.0, 0.0, 0.0],
        [0.0, 0.0, 9.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
      ];

      final result = CovarianceStabilityValidator.validate(p);

      expect(result.isFinite, isTrue);
      expect(result.isSymmetric, isTrue);
      expect(result.isPositiveSemiDefinite, isTrue);
      expect(result.minEigenvalue.abs(), lessThanOrEqualTo(result.tolerancePsd));
      expect(result.isLdltPsd, isTrue);
      expect(result.eigenvalues[0], closeTo(0.0, 1e-12));
      expect(result.eigenvalues[1], closeTo(1.0, 1e-12));
      expect(result.eigenvalues[2], closeTo(4.0, 1e-12));
      expect(result.eigenvalues[3], closeTo(9.0, 1e-12));
    });

    test('3. Indefinite symmetric matrix fails PSD despite positive diagonals', () {
      // Diagonals are all strictly positive: 1.0, 1.0, 4.0, 1.0
      // But off-diagonal 3.0 produces eigenvalues -2.0 and 4.0 for the top-left 2x2 block!
      final p = [
        [1.0, 3.0, 0.0, 0.0],
        [3.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 4.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
      ];

      final result = CovarianceStabilityValidator.validate(p);

      expect(result.isFinite, isTrue);
      expect(result.isSymmetric, isTrue);
      // FAILS PSD: positionVariance >= 0 is INSUFFICIENT to prove PSD!
      expect(result.isPositiveSemiDefinite, isFalse);
      expect(result.minEigenvalue, closeTo(-2.0, 1e-10));
      expect(result.isLdltPsd, isFalse);
      expect(result.conditionNumber, isNull);
    });

    test('4. Asymmetric matrix fails symmetry check with exact residual', () {
      final p = [
        [25.0, 5.0, 0.0, 0.0],
        [1.0, 25.0, 0.0, 0.0], // P_10 (1.0) != P_01 (5.0) -> residual 4.0
        [0.0, 0.0, 4.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
      ];

      final result = CovarianceStabilityValidator.validate(p);

      expect(result.isFinite, isTrue);
      expect(result.isSymmetric, isFalse);
      expect(result.worstSymmetryResidual, closeTo(4.0, 1e-12));
      expect(result.worstSymmetryResidual, greaterThan(result.toleranceSym));
    });

    test('5. Matrix with NaN and Infinity fails finiteness and PSD', () {
      // 5a: NaN element
      final pNan = [
        [double.nan, 0.0, 0.0, 0.0],
        [0.0, 25.0, 0.0, 0.0],
        [0.0, 0.0, 4.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
      ];
      final resNan = CovarianceStabilityValidator.validate(pNan);
      expect(resNan.isFinite, isFalse);
      expect(resNan.isSymmetric, isFalse);
      expect(resNan.isPositiveSemiDefinite, isFalse);

      // 5b: Infinity element
      final pInf = [
        [25.0, double.infinity, 0.0, 0.0],
        [double.infinity, 25.0, 0.0, 0.0],
        [0.0, 0.0, 4.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
      ];
      final resInf = CovarianceStabilityValidator.validate(pInf);
      expect(resInf.isFinite, isFalse);
      expect(resInf.isSymmetric, isFalse);
      expect(resInf.isPositiveSemiDefinite, isFalse);
    });

    test('6. Near-singular covariance is correctly handled by scale-aware tolerances', () {
      // Tiny eigenvalue 1e-8, large eigenvalue 1000.0 -> condition number 1e11
      final p = [
        [1e-8, 0.0, 0.0, 0.0],
        [0.0, 25.0, 0.0, 0.0],
        [0.0, 0.0, 100.0, 0.0],
        [0.0, 0.0, 0.0, 1000.0],
      ];

      final result = CovarianceStabilityValidator.validate(p);

      expect(result.isFinite, isTrue);
      expect(result.isSymmetric, isTrue);
      expect(result.isPositiveSemiDefinite, isTrue);
      expect(result.minEigenvalue, closeTo(1e-8, 1e-14));
      expect(result.maxEigenvalue, closeTo(1000.0, 1e-10));
      expect(result.conditionNumber, isNotNull);
      expect(result.conditionNumber!, closeTo(1e11, 1e8));
    });

    test('7. High covariance inflation after re-anchor maintains PSD and symmetry', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: const LatLng(10.7769, 106.7009),
        initialAccuracyMeters: 40.0, // High inflated uncertainty at Safe Reset
        initialSpeedMs: 5.0,
        initialHeadingDeg: 90.0,
      );

      final cov = ekf.covariance;
      final result = CovarianceStabilityValidator.validate(cov);

      expect(result.isFinite, isTrue);
      expect(result.isSymmetric, isTrue);
      expect(result.isPositiveSemiDefinite, isTrue);
      expect(result.minEigenvalue, greaterThan(0.0));
      // Inflated position variances: (40 * 0.75)^2 = 30^2 = 900.0
      expect(result.diagonalVariances[0], closeTo(900.0, 1e-6));
      expect(result.diagonalVariances[1], closeTo(900.0, 1e-6));
      expect(result.diagonalVariances[2], closeTo(4.0, 1e-6));
      expect(result.diagonalVariances[3], closeTo(1.0, 1e-6));
      expect(result.trace, closeTo(1805.0, 1e-6));
    });

    test('8. Normal versus heading-dropout recovery covariance evolution', () {
      final ekfNormal = ExtendedKalmanFilter();
      final ekfDropout = ExtendedKalmanFilter();

      final origin = const LatLng(10.7769, 106.7009);
      ekfNormal.init(initialPoint: origin, initialAccuracyMeters: 5.0, initialSpeedMs: 5.0, initialHeadingDeg: 0.0);
      ekfDropout.init(initialPoint: origin, initialAccuracyMeters: 5.0, initialSpeedMs: 5.0, initialHeadingDeg: 0.0);

      // Simulate 10 update steps
      var currentPoint = origin;
      for (var step = 1; step <= 10; step++) {
        currentPoint = LatLng(currentPoint.latitude + 0.00005, currentPoint.longitude);

        // ekfNormal receives valid headingDeg
        ekfNormal.update(
          measurementPoint: currentPoint,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: 0.0,
        );

        // ekfDropout has heading dropout (null heading)
        ekfDropout.update(
          measurementPoint: currentPoint,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          speedMs: 5.0,
          headingDeg: null,
        );

        final resNormal = CovarianceStabilityValidator.validate(ekfNormal.covariance);
        final resDropout = CovarianceStabilityValidator.validate(ekfDropout.covariance);

        expect(resNormal.isFinite, isTrue);
        expect(resNormal.isSymmetric, isTrue);
        expect(resNormal.isPositiveSemiDefinite, isTrue);
        expect(resNormal.minEigenvalue, greaterThan(0.0));

        expect(resDropout.isFinite, isTrue);
        expect(resDropout.isSymmetric, isTrue);
        expect(resDropout.isPositiveSemiDefinite, isTrue);
        expect(resDropout.minEigenvalue, greaterThan(0.0));

        // Normal tracking with heading sensor contracts heading uncertainty
        // Dropout tracking allows heading uncertainty to grow via process noise Q
        expect(resDropout.diagonalVariances[3], greaterThan(resNormal.diagonalVariances[3]));
      }
    });
  });
}
