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
}
