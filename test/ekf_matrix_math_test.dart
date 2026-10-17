import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/matrix_math_4x4.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Matrix4x4', () {
    test('identity matrix properties', () {
      final i = Matrix4x4.identity();
      expect(i.get(0, 0), 1.0);
      expect(i.get(1, 1), 1.0);
      expect(i.get(2, 2), 1.0);
      expect(i.get(3, 3), 1.0);
      expect(i.get(0, 1), 0.0);

      final v = Float64List.fromList([2.0, 3.0, 5.0, 7.0]);
      final res = i.multiplyVector(v);
      expect(res, equals(v));
    });

    test('matrix multiplication & transpose', () {
      final m = Matrix4x4.diagonal(2.0, 3.0, 4.0, 5.0);
      final mt = m.transpose();
      expect(mt.get(0, 0), 2.0);
      expect(mt.get(1, 1), 3.0);

      final prod = m * Matrix4x4.diagonal(0.5, 1.0 / 3.0, 0.25, 0.2);
      expect(prod.get(0, 0), closeTo(1.0, 1e-12));
      expect(prod.get(1, 1), closeTo(1.0, 1e-12));
      expect(prod.get(2, 2), closeTo(1.0, 1e-12));
      expect(prod.get(3, 3), closeTo(1.0, 1e-12));
    });

    test('matrix inversion for general invertible matrix', () {
      final a = Matrix4x4.fromList([
        4.0, 1.0, 0.0, 0.0,
        1.0, 3.0, 1.0, 0.0,
        0.0, 1.0, 2.0, 1.0,
        0.0, 0.0, 1.0, 5.0,
      ]);

      final aInv = a.invert();
      final prod = a * aInv;

      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          final expected = (r == c) ? 1.0 : 0.0;
          expect(prod.get(r, c), closeTo(expected, 1e-9));
        }
      }
    });

    test('throws StateError on singular matrix inversion', () {
      final singular = Matrix4x4.fromList([
        1.0, 2.0, 3.0, 4.0,
        2.0, 4.0, 6.0, 8.0, // linearly dependent row
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
      ]);

      expect(() => singular.invert(), throwsStateError);
    });

    test('exact 4x4 determinant', () {
      expect(Matrix4x4.identity().determinant, closeTo(1.0, 1e-12));
      expect(Matrix4x4.diagonal(2.0, 3.0, 4.0, 5.0).determinant, closeTo(120.0, 1e-12));

      final singular = Matrix4x4.fromList([
        1.0, 2.0, 3.0, 4.0,
        2.0, 4.0, 6.0, 8.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
      ]);
      expect(singular.determinant, closeTo(0.0, 1e-12));
    });

    test('verifies positive semi-definiteness via principal minors', () {
      expect(Matrix4x4.identity().isPositiveSemiDefinite(), isTrue);
      expect(Matrix4x4.diagonal(5.0, 2.0, 0.5, 0.1).isPositiveSemiDefinite(), isTrue);

      // Negative diagonal -> not PSD
      expect(Matrix4x4.diagonal(5.0, -0.1, 0.5, 0.1).isPositiveSemiDefinite(), isFalse);

      // Asymmetric matrix -> not PSD
      final asymmetric = Matrix4x4.identity();
      asymmetric.set(0, 1, 5.0);
      expect(asymmetric.isPositiveSemiDefinite(), isFalse);

      // Symmetric but violation of 2x2 minor (P00*P11 - P01^2 = 1*1 - 4 = -3 < 0)
      final nonPsd = Matrix4x4.identity();
      nonPsd.set(0, 1, 2.0);
      nonPsd.set(1, 0, 2.0);
      expect(nonPsd.isPositiveSemiDefinite(), isFalse);

      // Valid full rank covariance with cross-correlations
      final validP = Matrix4x4.fromList([
        4.0, 1.0, 0.2, 0.1,
        1.0, 3.0, 0.5, 0.2,
        0.2, 0.5, 2.0, 0.3,
        0.1, 0.2, 0.3, 1.5,
      ]);
      expect(validP.isPositiveSemiDefinite(), isTrue);
    });

    test('adversarial PSD tests: near-singular, rank-deficient, and subtle indefinite matrices', () {
      // 1. Rank-1 semidefinite matrix (v * v^T): true PSD with 3 zero eigenvalues
      final v = [1.0, 2.0, -1.0, 3.0];
      final rank1 = Matrix4x4();
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 4; j++) {
          rank1.set(i, j, v[i] * v[j]);
        }
      }
      expect(rank1.determinant, closeTo(0.0, 1e-12));
      expect(rank1.isPositiveSemiDefinite(), isTrue);

      // 2. Near-singular diagonal matrix with 14 orders of magnitude dynamic range
      final nearSingular = Matrix4x4.diagonal(1e6, 1.0, 1e-4, 1e-8);
      expect(nearSingular.isPositiveSemiDefinite(), isTrue);

      // 3. Cauchy-Schwarz violation in 2x2 submatrix (P00*P11 - P01^2 = 36 - 36.0012 < 0)
      final csViolation = Matrix4x4.fromList([
        4.0, 6.0001, 0.0, 0.0,
        6.0001, 9.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
      ]);
      expect(csViolation.isPositiveSemiDefinite(), isFalse);

      // 4. Adversarial 3x3 indefinite: all 1x1 (>0) and 2x2 (>0) minors positive, but 3x3 minor is -1.944 < 0
      final adv3 = Matrix4x4.fromList([
        1.0, 0.8, 0.8, 0.0,
        0.8, 1.0, -0.8, 0.0,
        0.8, -0.8, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
      ]);
      // Verify principal minors manually:
      expect(adv3.get(0, 0), 1.0); // 1x1 > 0
      expect(adv3.get(0, 0) * adv3.get(1, 1) - adv3.get(0, 1) * adv3.get(1, 0), closeTo(0.36, 1e-9)); // 2x2 > 0
      expect(adv3.determinant, closeTo(-1.944, 1e-9)); // 3x3 minor (and 4x4 det since col 4 is [0,0,0,1]) < 0
      expect(adv3.isPositiveSemiDefinite(), isFalse);

      // 5. Adversarial 4x4 indefinite (Schur complement construction):
      // All 1x1 (1.0 > 0), all six 2x2 (>= 0.64 > 0), and all four 3x3 (>= 0.28 > 0)
      // principal minors are strictly positive, but 4x4 determinant is 1 - 3*(0.6^2) = -0.08 < 0.
      final adv4 = Matrix4x4.fromList([
        1.0, 0.0, 0.0, 0.6,
        0.0, 1.0, 0.0, 0.6,
        0.0, 0.0, 1.0, 0.6,
        0.6, 0.6, 0.6, 1.0,
      ]);
      expect(adv4.determinant, closeTo(-0.08, 1e-9));
      expect(adv4.isPositiveSemiDefinite(), isFalse);

      // 6. Slightly negative eigenvalue (-1e-4) on diagonal
      final slightNegative = Matrix4x4.diagonal(100.0, 50.0, 10.0, -1e-4);
      expect(slightNegative.isPositiveSemiDefinite(), isFalse);
    });
  });

  group('Matrix2x2', () {
    test('determinant and inversion', () {
      const m = Matrix2x2(4.0, 7.0, 2.0, 6.0);
      expect(m.determinant, 10.0);

      final mInv = m.invert();
      expect(mInv.m00, closeTo(0.6, 1e-12));
      expect(mInv.m01, closeTo(-0.7, 1e-12));
      expect(mInv.m10, closeTo(-0.2, 1e-12));
      expect(mInv.m11, closeTo(0.4, 1e-12));
    });

    test('throws on singular 2x2', () {
      const singular = Matrix2x2(1.0, 2.0, 2.0, 4.0);
      expect(() => singular.invert(), throwsStateError);
    });
  });

  group('EquirectangularProjection', () {
    test('round-trip projection within sub-millimeter error', () {
      const origin = LatLng(10.7769, 106.7009); // Ho Chi Minh City
      final proj = EquirectangularProjection(origin);

      final testPoint = LatLng(10.7780, 106.7020);
      final (xEast, yNorth) = proj.project(testPoint);

      expect(xEast, greaterThan(0.0));
      expect(yNorth, greaterThan(0.0));

      final restored = proj.unproject(xEast, yNorth);
      expect(restored.latitude, closeTo(testPoint.latitude, 1e-9));
      expect(restored.longitude, closeTo(testPoint.longitude, 1e-9));
    });

    test('angle normalization in radians and degrees', () {
      expect(
        EquirectangularProjection.normalizeAngleRad(3 * math.pi),
        closeTo(math.pi, 1e-9),
      );
      expect(
        EquirectangularProjection.normalizeAngleRad(-3 * math.pi),
        closeTo(math.pi, 1e-9),
      );
      expect(EquirectangularProjection.normalizeAngleDeg(370.0), 10.0);
      expect(EquirectangularProjection.normalizeAngleDeg(-10.0), 350.0);
    });
  });

  group('Independent Numerical Reference (Jacobi Eigenvalue Decomposition)', () {
    test('cross-validates Sylvester PSD against Jacobi eigenvalues across diverse matrices', () {
      final matrices = <(String, Matrix4x4, bool)>[
        ('Identity', Matrix4x4.identity(), true),
        ('Diagonal Positive', Matrix4x4.diagonal(10.0, 5.0, 2.0, 0.5), true),
        ('Diagonal with One Zero (Semidefinite)', Matrix4x4.diagonal(10.0, 5.0, 0.0, 2.0), true),
        ('Diagonal with Slight Negative (-1e-4)', Matrix4x4.diagonal(10.0, 5.0, 2.0, -1e-4), false),
        (
          'Rank-1 Semidefinite (v * v^T)',
          () {
            final m = Matrix4x4();
            final v = [1.0, 2.0, -1.0, 3.0];
            for (var r = 0; r < 4; r++) {
              for (var c = 0; c < 4; c++) {
                m.set(r, c, v[r] * v[c]);
              }
            }
            return m;
          }(),
          true,
        ),
        (
          'Cauchy-Schwarz 2x2 Violation',
          Matrix4x4.fromList([
            4.0, 6.0001, 0.0, 0.0,
            6.0001, 9.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
          ]),
          false,
        ),
        (
          'Adversarial 3x3 Indefinite',
          Matrix4x4.fromList([
            1.0, 0.8, 0.8, 0.0,
            0.8, 1.0, -0.8, 0.0,
            0.8, -0.8, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
          ]),
          false,
        ),
        (
          'Adversarial 4x4 Indefinite (Schur Complement)',
          Matrix4x4.fromList([
            1.0, 0.0, 0.0, 0.6,
            0.0, 1.0, 0.0, 0.6,
            0.0, 0.0, 1.0, 0.6,
            0.6, 0.6, 0.6, 1.0,
          ]),
          false,
        ),
        (
          'Valid Full-Rank GPS Covariance',
          Matrix4x4.fromList([
            25.0, 3.0, 0.5, 0.1,
            3.0, 20.0, 0.4, 0.2,
            0.5, 0.4, 4.0, 0.05,
            0.1, 0.2, 0.05, 1.0,
          ]),
          true,
        ),
      ];

      for (final (label, mat, expectedPsd) in matrices) {
        final sylvesterResult = mat.isPositiveSemiDefinite();
        final jacobi = JacobiEigenvalueSolver4x4.solve(mat);
        expect(jacobi.converged, isTrue, reason: '$label Jacobi solver must converge');
        final jacobiPsd = jacobi.isPositiveSemiDefinite();

        expect(
          sylvesterResult,
          expectedPsd,
          reason: '$label: Sylvester principal minors expected $expectedPsd but got $sylvesterResult',
        );
        expect(
          jacobiPsd,
          expectedPsd,
          reason: '$label: Jacobi eigenvalues (${jacobi.eigenvalues}) expected $expectedPsd but got $jacobiPsd',
        );
        expect(
          sylvesterResult,
          equals(jacobiPsd),
          reason: '$label: Sylvester ($sylvesterResult) must agree with independent Jacobi eigenvalues ($jacobiPsd)',
        );
      }
    });
  });
}

/// Independent numerical reference solver using classical Jacobi rotations for symmetric 4x4 matrices.
class JacobiEigenvalueSolver4x4 {
  final List<double> eigenvalues;
  final bool converged;

  const JacobiEigenvalueSolver4x4(this.eigenvalues, this.converged);

  static JacobiEigenvalueSolver4x4 solve(Matrix4x4 matrix, {int maxIter = 50}) {
    final a = List<double>.from(matrix.storage);

    for (var iter = 0; iter < maxIter; iter++) {
      var p = 0, q = 1;
      var maxOff = (a[p * 4 + q]).abs();
      for (var r = 0; r < 4; r++) {
        for (var c = r + 1; c < 4; c++) {
          final val = (a[r * 4 + c]).abs();
          if (val > maxOff) {
            maxOff = val;
            p = r;
            q = c;
          }
        }
      }

      final maxDiag = math.max(
        math.max(a[0].abs(), a[5].abs()),
        math.max(a[10].abs(), a[15].abs()),
      );

      if (maxOff <= 1e-13 * math.max(1.0, maxDiag)) {
        final ev = [a[0], a[5], a[10], a[15]]..sort();
        return JacobiEigenvalueSolver4x4(ev, true);
      }

      final app = a[p * 4 + p];
      final aqq = a[q * 4 + q];
      final apq = a[p * 4 + q];

      final theta = 0.5 * math.atan2(2.0 * apq, aqq - app);
      final c = math.cos(theta);
      final s = math.sin(theta);

      final appNew = c * c * app - 2.0 * s * c * apq + s * s * aqq;
      final aqqNew = s * s * app + 2.0 * s * c * apq + c * c * aqq;
      a[p * 4 + p] = appNew;
      a[q * 4 + q] = aqqNew;
      a[p * 4 + q] = 0.0;
      a[q * 4 + p] = 0.0;

      for (var r = 0; r < 4; r++) {
        if (r != p && r != q) {
          final arp = a[r * 4 + p];
          final arq = a[r * 4 + q];
          final arpNew = c * arp - s * arq;
          final arqNew = s * arp + c * arq;
          a[r * 4 + p] = arpNew;
          a[p * 4 + r] = arpNew;
          a[r * 4 + q] = arqNew;
          a[q * 4 + r] = arqNew;
        }
      }
    }

    final ev = [a[0], a[5], a[10], a[15]]..sort();
    return JacobiEigenvalueSolver4x4(ev, false);
  }

  bool isPositiveSemiDefinite({double relTol = -1e-9}) {
    final maxEig = math.max(1.0, eigenvalues.map((e) => e.abs()).reduce(math.max));
    for (final lambda in eigenvalues) {
      if (lambda < relTol * maxEig) return false;
    }
    return true;
  }
}
