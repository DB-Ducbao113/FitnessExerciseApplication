import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';

/// Detailed result of validating a 4x4 covariance matrix.
class CovarianceValidationResult {
  /// Whether all 16 matrix elements are finite numbers (not NaN, not Inf).
  final bool isFinite;

  /// Whether the matrix is symmetric within the scale-aware tolerance [toleranceSym].
  final bool isSymmetric;

  /// The maximum absolute asymmetry residual: max_{i < j} |P_ij - P_ji|.
  final double worstSymmetryResidual;

  /// Scale-aware symmetry tolerance used for the check.
  final double toleranceSym;

  /// Whether the matrix is Positive Semi-Definite (PSD): minEigenvalue >= -tolerancePsd.
  final bool isPositiveSemiDefinite;

  /// Scale-aware PSD tolerance used for the check: 1e-7 * max(1.0, trace).
  final double tolerancePsd;

  /// The 4 sorted real eigenvalues of the symmetrized matrix (lambda_0 <= lambda_1 <= lambda_2 <= lambda_3).
  final List<double> eigenvalues;

  /// The minimum eigenvalue lambda_0.
  final double minEigenvalue;

  /// The maximum eigenvalue lambda_3.
  final double maxEigenvalue;

  /// The matrix trace: sum_{i=0}^3 P_ii.
  final double trace;

  /// The 4 diagonal elements: [P_00, P_11, P_22, P_33].
  final List<double> diagonalVariances;

  /// Estimated matrix condition number: lambda_max / lambda_min (null if lambda_min <= 0).
  final double? conditionNumber;

  /// Dual-check result: whether LDLT decomposition confirms non-negative pivots.
  final bool isLdltPsd;

  /// Diagonals of D matrix from LDLT decomposition.
  final List<double> ldltDiagonals;

  const CovarianceValidationResult({
    required this.isFinite,
    required this.isSymmetric,
    required this.worstSymmetryResidual,
    required this.toleranceSym,
    required this.isPositiveSemiDefinite,
    required this.tolerancePsd,
    required this.eigenvalues,
    required this.minEigenvalue,
    required this.maxEigenvalue,
    required this.trace,
    required this.diagonalVariances,
    this.conditionNumber,
    required this.isLdltPsd,
    required this.ldltDiagonals,
  });

  Map<String, dynamic> toJson() => {
        'is_finite': isFinite,
        'is_symmetric': isSymmetric,
        'worst_symmetry_residual': worstSymmetryResidual,
        'tolerance_sym': toleranceSym,
        'is_psd': isPositiveSemiDefinite,
        'tolerance_psd': tolerancePsd,
        'eigenvalues': eigenvalues,
        'min_eigenvalue': minEigenvalue,
        'max_eigenvalue': maxEigenvalue,
        'trace': trace,
        'diagonal_variances': diagonalVariances,
        'condition_number': conditionNumber,
        'is_ldlt_psd': isLdltPsd,
        'ldlt_diagonals': ldltDiagonals,
      };
}

/// Mathematically rigorous validator for 4x4 EKF covariance matrices.
class CovarianceStabilityValidator {
  /// Validates a 4x4 covariance matrix.
  ///
  /// - [matrix]: 4x4 nested list of double values.
  /// - [relSymTol]: relative tolerance for symmetry (default 1e-6).
  /// - [relPsdTol]: relative tolerance for PSD minimum eigenvalue (default 1e-7).
  static CovarianceValidationResult validate(
    List<List<double>> matrix, {
    double relSymTol = 1e-6,
    double relPsdTol = 1e-7,
  }) {
    if (matrix.length != 4 || matrix.any((row) => row.length != 4)) {
      throw ArgumentError('Covariance matrix must be 4x4');
    }

    // 1. Finiteness check
    var allFinite = true;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final val = matrix[r][c];
        if (!val.isFinite || val.isNaN) {
          allFinite = false;
          break;
        }
      }
      if (!allFinite) break;
    }

    if (!allFinite) {
      return CovarianceValidationResult(
        isFinite: false,
        isSymmetric: false,
        worstSymmetryResidual: double.nan,
        toleranceSym: 0.0,
        isPositiveSemiDefinite: false,
        tolerancePsd: 0.0,
        eigenvalues: const [double.nan, double.nan, double.nan, double.nan],
        minEigenvalue: double.nan,
        maxEigenvalue: double.nan,
        trace: double.nan,
        diagonalVariances: const [double.nan, double.nan, double.nan, double.nan],
        conditionNumber: null,
        isLdltPsd: false,
        ldltDiagonals: const [double.nan, double.nan, double.nan, double.nan],
      );
    }

    // 2. Diagonal variances & trace
    final diags = [matrix[0][0], matrix[1][1], matrix[2][2], matrix[3][3]];
    final trace = diags[0] + diags[1] + diags[2] + diags[3];

    // 3. Symmetry check with scale-aware tolerance
    var maxDiag = 1.0;
    for (final d in diags) {
      if (d.abs() > maxDiag) maxDiag = d.abs();
    }
    final tolSym = relSymTol * maxDiag;

    var worstResidual = 0.0;
    for (var r = 0; r < 4; r++) {
      for (var c = r + 1; c < 4; c++) {
        final diff = (matrix[r][c] - matrix[c][r]).abs();
        if (diff > worstResidual) {
          worstResidual = diff;
        }
      }
    }
    final isSymmetric = worstResidual <= tolSym;

    // 4. Symmetrize matrix for spectral eigenvalue analysis
    final sym = List.generate(
      4,
      (r) => List.generate(4, (c) => (matrix[r][c] + matrix[c][r]) / 2.0),
    );

    // 5. Symmetric Jacobi Eigenvalue Decomposition
    final (eigenvalues, _) = jacobiEigenvalues(sym);
    final minEig = eigenvalues.first;
    final maxEig = eigenvalues.last;

    // 6. Scale-aware PSD tolerance based on trace
    final tolPsd = relPsdTol * math.max(1.0, trace.abs());
    final isPsd = minEig >= -tolPsd;

    // 7. Condition number
    final double? condNum = (minEig > 0.0) ? (maxEig / minEig) : null;

    // 8. Dual check: LDLT decomposition
    final (isLdltPsd, ldltDiagonals) = ldltDecomposition(sym, tol: -tolPsd);

    return CovarianceValidationResult(
      isFinite: true,
      isSymmetric: isSymmetric,
      worstSymmetryResidual: worstResidual,
      toleranceSym: tolSym,
      isPositiveSemiDefinite: isPsd,
      tolerancePsd: tolPsd,
      eigenvalues: eigenvalues,
      minEigenvalue: minEig,
      maxEigenvalue: maxEig,
      trace: trace,
      diagonalVariances: diags,
      conditionNumber: condNum,
      isLdltPsd: isLdltPsd,
      ldltDiagonals: ldltDiagonals,
    );
  }

  /// Cyclic Jacobi algorithm for real symmetric 4x4 matrix.
  ///
  /// Computes all 4 eigenvalues in ascending order and the orthogonal eigenvector matrix V.
  static (List<double>, List<List<double>>) jacobiEigenvalues(
    List<List<double>> symMatrix, {
    int maxSweeps = 50,
    double tol = 1e-15,
  }) {
    // Clone matrix
    final a = List.generate(4, (r) => List.generate(4, (c) => symMatrix[r][c]));
    // Identity eigenvector matrix
    final v = List.generate(4, (r) => List.generate(4, (c) => (r == c) ? 1.0 : 0.0));

    final matrixTrace = (a[0][0] + a[1][1] + a[2][2] + a[3][3]).abs();
    final stopTol = tol * math.max(1.0, matrixTrace);

    for (var sweep = 0; sweep < maxSweeps; sweep++) {
      var maxOffDiag = 0.0;
      for (var p = 0; p < 4; p++) {
        for (var q = p + 1; q < 4; q++) {
          final off = a[p][q].abs();
          if (off > maxOffDiag) maxOffDiag = off;
        }
      }
      if (maxOffDiag <= stopTol) break;

      for (var p = 0; p < 3; p++) {
        for (var q = p + 1; q < 4; q++) {
          final apq = a[p][q];
          final app = a[p][p];
          final aqq = a[q][q];

          if (apq.abs() <= 1e-16 * math.max(1.0, math.sqrt(app.abs() * aqq.abs()))) {
            a[p][q] = 0.0;
            a[q][p] = 0.0;
            continue;
          }

          final tau = (aqq - app) / (2.0 * apq);
          final double t;
          if (tau >= 0.0) {
            t = 1.0 / (tau + math.sqrt(1.0 + tau * tau));
          } else {
            t = -1.0 / (-tau + math.sqrt(1.0 + tau * tau));
          }
          final c = 1.0 / math.sqrt(1.0 + t * t);
          final s = t * c;
          final tau2 = s / (1.0 + c);

          // Update pivot elements
          a[p][p] = app - t * apq;
          a[q][q] = aqq + t * apq;
          a[p][q] = 0.0;
          a[q][p] = 0.0;

          // Update rest of matrix
          for (var r = 0; r < 4; r++) {
            if (r != p && r != q) {
              final arp = a[r][p];
              final arq = a[r][q];
              a[r][p] = arp - s * (arq + tau2 * arp);
              a[p][r] = a[r][p];
              a[r][q] = arq + s * (arp - tau2 * arq);
              a[q][r] = a[r][q];
            }
          }

          // Accumulate eigenvectors
          for (var r = 0; r < 4; r++) {
            final vrp = v[r][p];
            final vrq = v[r][q];
            v[r][p] = vrp - s * (vrq + tau2 * vrp);
            v[r][q] = vrq + s * (vrp - tau2 * vrq);
          }
        }
      }
    }

    final eigs = [a[0][0], a[1][1], a[2][2], a[3][3]];
    eigs.sort();
    return (eigs, v);
  }

  /// LDLT decomposition of a symmetric 4x4 matrix: A = L * D * L^T.
  ///
  /// Returns (isPsd, [D_00, D_11, D_22, D_33]).
  static (bool, List<double>) ldltDecomposition(
    List<List<double>> symMatrix, {
    double tol = -1e-9,
  }) {
    final d = List<double>.filled(4, 0.0);
    final l = List.generate(4, (r) => List<double>.filled(4, 0.0));
    for (var i = 0; i < 4; i++) {
      l[i][i] = 1.0;
    }

    for (var j = 0; j < 4; j++) {
      var djj = symMatrix[j][j];
      for (var k = 0; k < j; k++) {
        djj -= l[j][k] * l[j][k] * d[k];
      }
      d[j] = djj;

      if (djj.abs() < 1e-14) {
        // Near-zero pivot
        for (var i = j + 1; i < 4; i++) {
          l[i][j] = 0.0;
        }
      } else {
        for (var i = j + 1; i < 4; i++) {
          var lij = symMatrix[i][j];
          for (var k = 0; k < j; k++) {
            lij -= l[i][k] * l[j][k] * d[k];
          }
          l[i][j] = lij / djj;
        }
      }
    }

    final isPsd = d.every((val) => val >= tol);
    return (isPsd, d);
  }
}

/// Stratified accumulator tracking covariance matrix validity across the 108 scenarios.
class CovarianceStratifiedAccumulator {
  int totalScheduledObservations = 0;
  int initializedObservations = 0;
  int uninitializedObservations = 0;

  int finiteCount = 0;
  int nonFiniteCount = 0;

  int symmetryPassCount = 0;
  int symmetryFailCount = 0;
  double worstSymmetryResidual = 0.0;

  int psdPassCount = 0;
  int psdFailCount = 0;
  double minObservedEigenvalue = double.infinity;
  double maxObservedEigenvalue = -double.infinity;
  double maxObservedTrace = 0.0;

  // Breakdown by FSM State
  final Map<GpsRecoveryState, int> observationsByState = {};
  final Map<GpsRecoveryState, int> psdPassByState = {};
  final Map<GpsRecoveryState, int> psdFailByState = {};
  final Map<GpsRecoveryState, double> minEigenvalueByState = {};
  final Map<GpsRecoveryState, double> worstResidualByState = {};
  final Map<GpsRecoveryState, double> maxTraceByState = {};

  // Post-re-anchor stability tracking (Safe Reset S5 and first 5 subsequent samples)
  int reAnchorObservations = 0;
  int reAnchorPsdPassCount = 0;
  double reAnchorMinEigenvalue = double.infinity;
  double reAnchorMaxTrace = 0.0;

  void recordObservation({
    required bool isInitialized,
    required GpsRecoveryState state,
    required CovarianceValidationResult result,
    bool isReAnchorOrProbation = false,
  }) {
    totalScheduledObservations++;

    if (!isInitialized) {
      uninitializedObservations++;
      return;
    }

    initializedObservations++;
    observationsByState[state] = (observationsByState[state] ?? 0) + 1;

    // Finiteness
    if (result.isFinite) {
      finiteCount++;
    } else {
      nonFiniteCount++;
      psdFailCount++;
      psdFailByState[state] = (psdFailByState[state] ?? 0) + 1;
      return;
    }

    // Symmetry
    if (result.isSymmetric) {
      symmetryPassCount++;
    } else {
      symmetryFailCount++;
    }
    if (result.worstSymmetryResidual > worstSymmetryResidual) {
      worstSymmetryResidual = result.worstSymmetryResidual;
    }
    final curWorstForState = worstResidualByState[state] ?? 0.0;
    if (result.worstSymmetryResidual > curWorstForState) {
      worstResidualByState[state] = result.worstSymmetryResidual;
    }

    // PSD
    if (result.isPositiveSemiDefinite) {
      psdPassCount++;
      psdPassByState[state] = (psdPassByState[state] ?? 0) + 1;
    } else {
      psdFailCount++;
      psdFailByState[state] = (psdFailByState[state] ?? 0) + 1;
    }

    // Eigenvalues & Trace
    if (result.minEigenvalue < minObservedEigenvalue) {
      minObservedEigenvalue = result.minEigenvalue;
    }
    if (result.maxEigenvalue > maxObservedEigenvalue) {
      maxObservedEigenvalue = result.maxEigenvalue;
    }
    if (result.trace > maxObservedTrace) {
      maxObservedTrace = result.trace;
    }

    final curMinEigForState = minEigenvalueByState[state] ?? double.infinity;
    if (result.minEigenvalue < curMinEigForState) {
      minEigenvalueByState[state] = result.minEigenvalue;
    }
    final curMaxTraceForState = maxTraceByState[state] ?? 0.0;
    if (result.trace > curMaxTraceForState) {
      maxTraceByState[state] = result.trace;
    }

    // Re-anchor stability
    if (isReAnchorOrProbation) {
      reAnchorObservations++;
      if (result.isPositiveSemiDefinite) {
        reAnchorPsdPassCount++;
      }
      if (result.minEigenvalue < reAnchorMinEigenvalue) {
        reAnchorMinEigenvalue = result.minEigenvalue;
      }
      if (result.trace > reAnchorMaxTrace) {
        reAnchorMaxTrace = result.trace;
      }
    }
  }

  double get finitePercentage =>
      initializedObservations > 0 ? (finiteCount / initializedObservations) * 100.0 : 0.0;

  double get symmetryPassPercentage =>
      initializedObservations > 0 ? (symmetryPassCount / initializedObservations) * 100.0 : 0.0;

  double get psdPassPercentage =>
      initializedObservations > 0 ? (psdPassCount / initializedObservations) * 100.0 : 0.0;

  Map<String, dynamic> toJson() => {
        'total_scheduled_observations': totalScheduledObservations,
        'initialized_observations': initializedObservations,
        'uninitialized_observations': uninitializedObservations,
        'finite_count': finiteCount,
        'finite_percentage': finitePercentage,
        'symmetry_pass_count': symmetryPassCount,
        'symmetry_pass_percentage': symmetryPassPercentage,
        'worst_symmetry_residual': worstSymmetryResidual,
        'psd_pass_count': psdPassCount,
        'psd_fail_count': psdFailCount,
        'psd_pass_percentage': psdPassPercentage,
        'min_observed_eigenvalue': minObservedEigenvalue.isFinite ? minObservedEigenvalue : null,
        'max_observed_eigenvalue': maxObservedEigenvalue.isFinite ? maxObservedEigenvalue : null,
        'max_observed_trace': maxObservedTrace,
        'by_fsm_state': observationsByState.map((state, count) => MapEntry(state.name, {
              'observations': count,
              'psd_pass_count': psdPassByState[state] ?? 0,
              'psd_fail_count': psdFailByState[state] ?? 0,
              'psd_pass_percentage':
                  count > 0 ? ((psdPassByState[state] ?? 0) / count) * 100.0 : 0.0,
              'min_eigenvalue': minEigenvalueByState[state],
              'worst_symmetry_residual': worstResidualByState[state] ?? 0.0,
              'max_trace': maxTraceByState[state] ?? 0.0,
            })),
        're_anchor_stability': {
          'observations': reAnchorObservations,
          'psd_pass_count': reAnchorPsdPassCount,
          'psd_pass_percentage': reAnchorObservations > 0
              ? (reAnchorPsdPassCount / reAnchorObservations) * 100.0
              : 100.0,
          'min_eigenvalue':
              reAnchorMinEigenvalue.isFinite ? reAnchorMinEigenvalue : null,
          'max_trace': reAnchorMaxTrace,
        },
      };
}
