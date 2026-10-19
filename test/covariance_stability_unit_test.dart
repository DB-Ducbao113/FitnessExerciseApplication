import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/covariance_stability_validator.dart';

void main() {
  group('TASK 3 — Covariance Stability & Numerical Decomposition Unit Tests', () {
    test('A. Asymmetric matrix with positive eigenvalues of sym(P) must have overallValid = false', () {
      // Off-diagonal asymmetry: P_10 = 1.0, P_01 = 5.0
      // Symmetrized matrix sym(P) has strictly positive eigenvalues [1.0, 4.0, 22.0, 28.0]
      // An asymmetric matrix MUST NOT be reported as overallValid!
      final p = [
        [25.0, 5.0, 0.0, 0.0],
        [1.0, 25.0, 0.0, 0.0],
        [0.0, 0.0, 4.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
      ];

      final result = CovarianceStabilityValidator.validate(p);

      expect(result.isFinite, isTrue);
      expect(result.isSymmetric, isFalse);
      expect(result.worstSymmetryResidual, closeTo(4.0, 1e-12));
      expect(result.worstSymmetryResidual, greaterThan(result.toleranceSym));
      expect(result.isPositiveSemiDefinite, isTrue);
      expect(result.minEigenvalue, greaterThan(0.0));
      // CRITICAL: overallValid MUST be false due to asymmetry!
      expect(result.overallValid, isFalse);
    });

    test('B. Indefinite symmetric matrix must have overallValid = false', () {
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
      expect(result.isPositiveSemiDefinite, isFalse);
      expect(result.minEigenvalue, closeTo(-2.0, 1e-10));
      expect(result.isLdltPsd, isFalse);
      expect(result.conditionNumber, isNull);
      // CRITICAL: overallValid MUST be false due to negative eigenvalue!
      expect(result.overallValid, isFalse);
    });

    test('C. PSD singular matrix with zero eigenvalue must pass', () {
      // Construct a rank-3 matrix: v1*v1^T + v2*v2^T + v3*v3^T
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
      expect(result.ldltAgreesWithEigenvalue, isTrue);
      expect(result.eigenvalues[0], closeTo(0.0, 1e-12));
      expect(result.eigenvalues[1], closeTo(1.0, 1e-12));
      expect(result.eigenvalues[2], closeTo(4.0, 1e-12));
      expect(result.eigenvalues[3], closeTo(9.0, 1e-12));
      // Singular PSD matrix is valid covariance
      expect(result.overallValid, isTrue);
    });

    test('D. Matrix with NaN and Infinity fails finiteness and overallValid', () {
      // NaN element
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
      expect(resNan.overallValid, isFalse);

      // Infinity element
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
      expect(resInf.overallValid, isFalse);
    });

    test('E. Forced Jacobi non-convergence must fail overall covariance validity', () {
      final p = [
        [25.0, 2.0, 0.5, 0.1],
        [2.0, 25.0, 0.2, 0.05],
        [0.5, 0.2, 4.0, 0.01],
        [0.1, 0.05, 0.01, 1.0],
      ];

      // Force 0 sweeps so Jacobi does not iterate and cannot converge
      final resNoConvergence = CovarianceStabilityValidator.validate(p, jacobiMaxSweeps: 0);

      expect(resNoConvergence.isFinite, isTrue);
      expect(resNoConvergence.isSymmetric, isTrue);
      expect(resNoConvergence.jacobiConverged, isFalse);
      expect(resNoConvergence.jacobiSweeps, equals(0));
      expect(resNoConvergence.jacobiResidual, greaterThan(0.0));
      // CRITICAL: failure of decomposition convergence forces overallValid = false!
      expect(resNoConvergence.overallValid, isFalse);
    });

    test('F. Near-singular covariance and zero pivots must be handled without incorrect PASS results', () {
      // 1. Zero pivot with non-zero off-diagonals (indefinite matrix)
      // Standard unpivoted LDLT would naively divide by zero or skip without checking off-diagonals.
      final pZeroPivot = [
        [0.0, 2.0, 0.0, 0.0],
        [2.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 4.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
      ];
      final resZeroPivot = CovarianceStabilityValidator.validate(pZeroPivot);
      expect(resZeroPivot.isPositiveSemiDefinite, isFalse);
      expect(resZeroPivot.isLdltPsd, isFalse);
      expect(resZeroPivot.overallValid, isFalse);
      expect(resZeroPivot.ldltAgreesWithEigenvalue, isTrue);

      // 2. Near-singular positive-definite matrix (condition number 1e11)
      final pNearSingular = [
        [1e-8, 0.0, 0.0, 0.0],
        [0.0, 25.0, 0.0, 0.0],
        [0.0, 0.0, 100.0, 0.0],
        [0.0, 0.0, 0.0, 1000.0],
      ];
      final resNearSingular = CovarianceStabilityValidator.validate(pNearSingular);
      expect(resNearSingular.isFinite, isTrue);
      expect(resNearSingular.isSymmetric, isTrue);
      expect(resNearSingular.isPositiveSemiDefinite, isTrue);
      expect(resNearSingular.isLdltPsd, isTrue);
      expect(resNearSingular.overallValid, isTrue);
      expect(resNearSingular.minEigenvalue, closeTo(1e-8, 1e-14));
      expect(resNearSingular.maxEigenvalue, closeTo(1000.0, 1e-10));
      expect(resNearSingular.conditionNumber, isNotNull);
      expect(resNearSingular.conditionNumber!, closeTo(1e11, 1e8));
    });

    test('G. Well-conditioned positive-definite matrix passes eigenvalue and LDLT checks', () {
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
      expect(result.jacobiConverged, isTrue);
      expect(result.overallValid, isTrue);
      expect(result.ldltAgreesWithEigenvalue, isTrue);
      expect(result.hasDecompositionDisagreement, isFalse);
      expect(result.conditionNumber, isNotNull);
      expect(result.conditionNumber!, greaterThan(1.0));

      // Spectral trace invariant: sum(eigenvalues) == trace
      final eigSum = result.eigenvalues.reduce((a, b) => a + b);
      expect((eigSum - result.trace).abs(), lessThan(1e-10 * result.trace));
    });

    test('H. Numerical disagreements between LDLT and eigenvalue decomposition must be observable and reported', () {
      // Deterministic case where unpivoted LDLT experiences severe pivot instability:
      // P_00 is tiny (1e-12) with a non-zero P_01 (1e-4).
      // Jacobi spectral analysis correctly determines lambda_min is within PSD tolerance (-1e-9 >= -3e-6).
      // But unpivoted LDLT pivot blows up: L_10 = 1e8, D_11 = 10 - 1e8^2 * 1e-12 = -9990.0!
      // This demonstrates why LDLT must not be treated as an infallible oracle and why disagreements are reported.
      final pDisagreement = [
        [1e-12, 1e-4, 0.0, 0.0],
        [1e-4, 10.0, 0.0, 0.0],
        [0.0, 0.0, 10.0, 0.0],
        [0.0, 0.0, 0.0, 10.0],
      ];

      final result = CovarianceStabilityValidator.validate(pDisagreement, relPsdTol: 1e-7);

      expect(result.isFinite, isTrue);
      expect(result.isSymmetric, isTrue);
      expect(result.isPositiveSemiDefinite, isTrue);
      expect(result.isLdltPsd, isFalse);
      // Dual-check disagreement is explicitly flagged!
      expect(result.ldltAgreesWithEigenvalue, isFalse);
      expect(result.hasDecompositionDisagreement, isTrue);
    });

    test('I. High covariance inflation after re-anchor maintains PSD and symmetry', () {
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
      expect(result.overallValid, isTrue);
      // Inflated position variances: (40 * 0.75)^2 = 30^2 = 900.0
      expect(result.diagonalVariances[0], closeTo(900.0, 1e-6));
      expect(result.diagonalVariances[1], closeTo(900.0, 1e-6));
      expect(result.diagonalVariances[2], closeTo(4.0, 1e-6));
      expect(result.diagonalVariances[3], closeTo(1.0, 1e-6));
      expect(result.trace, closeTo(1805.0, 1e-6));
    });

    test('J. Normal versus heading-dropout recovery covariance evolution', () {
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
        expect(resNormal.overallValid, isTrue);

        expect(resDropout.isFinite, isTrue);
        expect(resDropout.isSymmetric, isTrue);
        expect(resDropout.isPositiveSemiDefinite, isTrue);
        expect(resDropout.minEigenvalue, greaterThan(0.0));
        expect(resDropout.overallValid, isTrue);

        // Normal tracking with heading sensor contracts heading uncertainty
        // Dropout tracking allows heading uncertainty to grow via process noise Q
        expect(resDropout.diagonalVariances[3], greaterThan(resNormal.diagonalVariances[3]));
      }
    });
  });
}
