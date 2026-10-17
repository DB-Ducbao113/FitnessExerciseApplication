import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Lightweight, zero-allocation friendly 4x4 matrix stored in row-major order:
/// [ m00, m01, m02, m03,
///   m10, m11, m12, m13,
///   m20, m21, m22, m23,
///   m30, m31, m32, m33 ]
class Matrix4x4 {
  final Float64List storage;

  Matrix4x4([Float64List? initial]) : storage = initial ?? Float64List(16);

  factory Matrix4x4.identity() {
    final m = Matrix4x4();
    m.storage[0] = 1.0;
    m.storage[5] = 1.0;
    m.storage[10] = 1.0;
    m.storage[15] = 1.0;
    return m;
  }

  factory Matrix4x4.diagonal(double d0, double d1, double d2, double d3) {
    final m = Matrix4x4();
    m.storage[0] = d0;
    m.storage[5] = d1;
    m.storage[10] = d2;
    m.storage[15] = d3;
    return m;
  }

  factory Matrix4x4.fromList(List<double> values) {
    assert(values.length == 16, 'Matrix4x4 requires 16 elements');
    final m = Matrix4x4();
    for (var i = 0; i < 16; i++) {
      m.storage[i] = values[i];
    }
    return m;
  }

  double get(int row, int col) => storage[row * 4 + col];
  void set(int row, int col, double val) => storage[row * 4 + col] = val;

  Matrix4x4 copy() {
    final out = Matrix4x4();
    out.storage.setAll(0, storage);
    return out;
  }

  Matrix4x4 operator +(Matrix4x4 other) {
    final out = Matrix4x4();
    for (var i = 0; i < 16; i++) {
      out.storage[i] = storage[i] + other.storage[i];
    }
    return out;
  }

  Matrix4x4 operator -(Matrix4x4 other) {
    final out = Matrix4x4();
    for (var i = 0; i < 16; i++) {
      out.storage[i] = storage[i] - other.storage[i];
    }
    return out;
  }

  Matrix4x4 operator *(Matrix4x4 other) {
    final out = Matrix4x4();
    for (var r = 0; r < 4; r++) {
      final rOffset = r * 4;
      for (var c = 0; c < 4; c++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += storage[rOffset + k] * other.storage[k * 4 + c];
        }
        out.storage[rOffset + c] = sum;
      }
    }
    return out;
  }

  Float64List multiplyVector(Float64List v) {
    assert(v.length == 4);
    final out = Float64List(4);
    for (var r = 0; r < 4; r++) {
      final rOffset = r * 4;
      out[r] =
          storage[rOffset] * v[0] +
          storage[rOffset + 1] * v[1] +
          storage[rOffset + 2] * v[2] +
          storage[rOffset + 3] * v[3];
    }
    return out;
  }

  Matrix4x4 transpose() {
    final out = Matrix4x4();
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        out.storage[c * 4 + r] = storage[r * 4 + c];
      }
    }
    return out;
  }

  /// Inverts a 4x4 matrix using Gauss-Jordan elimination with partial pivoting.
  /// Throws [StateError] if the matrix is singular or near-singular.
  Matrix4x4 invert([double epsilon = 1e-12]) {
    final a = Float64List(16)..setAll(0, storage);
    final b = Matrix4x4.identity().storage;

    for (var col = 0; col < 4; col++) {
      // Find pivot
      var pivotRow = col;
      var maxVal = a[col * 4 + col].abs();
      for (var row = col + 1; row < 4; row++) {
        final val = a[row * 4 + col].abs();
        if (val > maxVal) {
          maxVal = val;
          pivotRow = row;
        }
      }

      if (maxVal < epsilon) {
        throw StateError('Matrix4x4 is singular or near-singular (pivot: $maxVal)');
      }

      // Swap rows in a and b
      if (pivotRow != col) {
        for (var c = 0; c < 4; c++) {
          final tempA = a[col * 4 + c];
          a[col * 4 + c] = a[pivotRow * 4 + c];
          a[pivotRow * 4 + c] = tempA;

          final tempB = b[col * 4 + c];
          b[col * 4 + c] = b[pivotRow * 4 + c];
          b[pivotRow * 4 + c] = tempB;
        }
      }

      // Scale pivot row to 1
      final pivot = a[col * 4 + col];
      final invPivot = 1.0 / pivot;
      for (var c = 0; c < 4; c++) {
        a[col * 4 + c] *= invPivot;
        b[col * 4 + c] *= invPivot;
      }

      // Eliminate other rows
      for (var row = 0; row < 4; row++) {
        if (row != col) {
          final factor = a[row * 4 + col];
          if (factor.abs() > 1e-15) {
            for (var c = 0; c < 4; c++) {
              a[row * 4 + c] -= factor * a[col * 4 + c];
              b[row * 4 + c] -= factor * b[col * 4 + c];
            }
          }
        }
      }
    }

    return Matrix4x4(b);
  }

  /// Exact determinant of 4x4 matrix via cofactor expansion along row 0.
  double get determinant {
    final a00 = storage[0], a01 = storage[1], a02 = storage[2], a03 = storage[3];
    final a10 = storage[4], a11 = storage[5], a12 = storage[6], a13 = storage[7];
    final a20 = storage[8], a21 = storage[9], a22 = storage[10], a23 = storage[11];
    final a30 = storage[12], a31 = storage[13], a32 = storage[14], a33 = storage[15];

    final c00 = a11 * (a22 * a33 - a23 * a32) -
        a12 * (a21 * a33 - a23 * a31) +
        a13 * (a21 * a32 - a22 * a31);
    final c01 = a10 * (a22 * a33 - a23 * a32) -
        a12 * (a20 * a33 - a23 * a30) +
        a13 * (a20 * a32 - a22 * a30);
    final c02 = a10 * (a21 * a33 - a23 * a31) -
        a11 * (a20 * a33 - a23 * a30) +
        a13 * (a20 * a31 - a21 * a30);
    final c03 = a10 * (a21 * a32 - a22 * a31) -
        a11 * (a20 * a32 - a22 * a30) +
        a12 * (a20 * a31 - a21 * a30);

    return a00 * c00 - a01 * c01 + a02 * c02 - a03 * c03;
  }

  /// Verifies whether this matrix is symmetric and positive semi-definite (PSD)
  /// within numerical [tolerance].
  ///
  /// Evaluates Sylvester's criterion: for a symmetric matrix, all principal minors
  /// must be non-negative.
  bool isPositiveSemiDefinite([double tolerance = -1e-9]) {
    // 1. Verify finite elements and symmetry
    for (var r = 0; r < 4; r++) {
      for (var c = r; c < 4; c++) {
        final a = get(r, c);
        final b = get(c, r);
        if (!a.isFinite || !b.isFinite) return false;
        final scale = math.max(1.0, math.max(a.abs(), b.abs()));
        if ((a - b).abs() > 1e-6 * scale) return false;
      }
    }

    // 2. 1x1 principal minors (diagonal entries) >= tolerance
    for (var i = 0; i < 4; i++) {
      if (get(i, i) < tolerance) return false;
    }

    // 3. 2x2 principal minors
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        final m2 = get(i, i) * get(j, j) - get(i, j) * get(j, i);
        if (m2 < tolerance) return false;
      }
    }

    // 4. 3x3 principal minors
    for (var k = 0; k < 4; k++) {
      final idx = [0, 1, 2, 3]..removeAt(k);
      final r0 = idx[0], r1 = idx[1], r2 = idx[2];
      final m3 =
          get(r0, r0) * (get(r1, r1) * get(r2, r2) - get(r1, r2) * get(r2, r1)) -
          get(r0, r1) * (get(r1, r0) * get(r2, r2) - get(r1, r2) * get(r2, r0)) +
          get(r0, r2) * (get(r1, r0) * get(r2, r1) - get(r1, r1) * get(r2, r0));
      if (m3 < tolerance) return false;
    }

    // 5. 4x4 determinant
    return determinant >= tolerance;
  }
}

/// Fast 2x2 matrix operations used for position measurement updates:
/// S = H P H^T + R (when H is 2x4 position selector)
class Matrix2x2 {
  final double m00, m01;
  final double m10, m11;

  const Matrix2x2(this.m00, this.m01, this.m10, this.m11);

  double get determinant => m00 * m11 - m01 * m10;

  Matrix2x2 invert([double epsilon = 1e-12]) {
    final det = determinant;
    if (det.abs() < epsilon) {
      throw StateError('Matrix2x2 is singular (det: $det)');
    }
    final invDet = 1.0 / det;
    return Matrix2x2(
      m11 * invDet,
      -m01 * invDet,
      -m10 * invDet,
      m00 * invDet,
    );
  }
}

/// Geometric projection between WGS84 (Lat, Lng) and local metric tangent plane (East, North)
class EquirectangularProjection {
  final LatLng origin;
  final double _latCos;

  static const double earthRadiusMeters = 6378137.0;
  static const double degToRad = math.pi / 180.0;
  static const double radToDeg = 180.0 / math.pi;

  EquirectangularProjection(this.origin)
      : _latCos = math.cos(origin.latitude * degToRad);

  /// Projects [point] to local metric plane relative to [origin]:
  /// returns `(xMeters (East), yMeters (North))`.
  (double, double) project(LatLng point) {
    final dLat = (point.latitude - origin.latitude) * degToRad;
    final dLng = (point.longitude - origin.longitude) * degToRad;

    final y = dLat * earthRadiusMeters;
    final x = dLng * earthRadiusMeters * _latCos;
    return (x, y);
  }

  /// Inverse projects local metric coordinates `(x, y)` back to [LatLng].
  LatLng unproject(double xEast, double yNorth) {
    final dLat = (yNorth / earthRadiusMeters) * radToDeg;
    final dLng = (_latCos.abs() > 1e-7)
        ? (xEast / (earthRadiusMeters * _latCos)) * radToDeg
        : 0.0;

    return LatLng(
      origin.latitude + dLat,
      origin.longitude + dLng,
    );
  }

  /// Normalizes angle in radians to [-pi, pi]
  static double normalizeAngleRad(double angleRad) {
    var a = angleRad % (2 * math.pi);
    if (a > math.pi) a -= 2 * math.pi;
    if (a < -math.pi) a += 2 * math.pi;
    return a;
  }

  /// Normalizes angle in degrees to [0, 360)
  static double normalizeAngleDeg(double angleDeg) {
    return (angleDeg % 360.0 + 360.0) % 360.0;
  }
}
