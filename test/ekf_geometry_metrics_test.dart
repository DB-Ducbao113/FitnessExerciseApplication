import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

class LocalPoint2D {
  final double x;
  final double y;
  const LocalPoint2D(this.x, this.y);

  double distanceTo(LocalPoint2D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  LocalPoint2D operator -(LocalPoint2D other) => LocalPoint2D(x - other.x, y - other.y);
  LocalPoint2D operator +(LocalPoint2D other) => LocalPoint2D(x + other.x, y + other.y);
  LocalPoint2D operator *(double scale) => LocalPoint2D(x * scale, y * scale);
  double dot(LocalPoint2D other) => x * other.x + y * other.y;
  double get length => math.sqrt(x * x + y * y);
}

class GeometryMetrics {
  /// Computes the exact orthogonal / clamped distance from point [p]
  /// to the polyline formed by [polyline].
  static double crossTrackDistanceToPolyline(LocalPoint2D p, List<LocalPoint2D> polyline) {
    if (polyline.isEmpty) return 0.0;
    if (polyline.length == 1) return p.distanceTo(polyline.first);

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final dist = distanceToSegment(p, a, b);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance;
  }

  /// Exact distance from point [p] to line segment [a, b].
  static double distanceToSegment(LocalPoint2D p, LocalPoint2D a, LocalPoint2D b) {
    final ab = b - a;
    final l2 = ab.dot(ab);
    if (l2 <= 1e-12) return p.distanceTo(a);

    final ap = p - a;
    final t = (ap.dot(ab) / l2).clamp(0.0, 1.0);
    final projection = a + ab * t;
    return p.distanceTo(projection);
  }

  /// Measures corner shortcutting (clipping) around a turn apex [v].
  ///
  /// For an approach vertex [a], apex [v], and exit vertex [b]:
  /// The interior normal (bisector) points towards the inside of the turn:
  ///   u1 = normalize(a - v), u2 = normalize(b - v)
  ///   bisector = normalize(u1 + u2)
  ///
  /// Any point [p] inside the turn corner has a positive projection along
  /// the interior bisector relative to the vertex:
  ///   innerDeviation = (p - v) . bisector
  ///
  /// If the filtered trajectory cuts inside the corner while ground truth
  /// stays on the centerline (or rounds the apex), shortcut error is the
  /// inner deviation:
  ///   shortcut = max(0.0, innerDeviation)
  /// If the trajectory swings wide (outside the corner), innerDeviation < 0,
  /// so shortcut = 0.0 (wide swing is tracking lag, not shortcutting).
  static double measureCornerShortcut({
    required LocalPoint2D pEst,
    required LocalPoint2D vApex,
    required LocalPoint2D aApproach,
    required LocalPoint2D bExit,
  }) {
    final vToA = aApproach - vApex;
    final vToB = bExit - vApex;
    final lenA = vToA.length;
    final lenB = vToB.length;
    if (lenA <= 1e-6 || lenB <= 1e-6) return 0.0;

    final u1 = vToA * (1.0 / lenA);
    final u2 = vToB * (1.0 / lenB);
    final sum = u1 + u2;
    final sumLen = sum.length;
    if (sumLen <= 1e-6) return 0.0; // Straight line (180 deg opposite)

    final interiorBisector = sum * (1.0 / sumLen);
    final diff = pEst - vApex;
    final innerDev = diff.dot(interiorBisector);
    return math.max(0.0, innerDev);
  }
}

void main() {
  group('GeometryMetrics Analytical Unit Tests', () {
    test('Cross-track distance: point on segment is exactly 0', () {
      final polyline = [const LocalPoint2D(0, 0), const LocalPoint2D(0, 10)];
      final dist = GeometryMetrics.crossTrackDistanceToPolyline(const LocalPoint2D(0, 5), polyline);
      expect(dist, closeTo(0.0, 1e-6));
    });

    test('Cross-track distance: point offset perpendicular to segment', () {
      final polyline = [const LocalPoint2D(0, 0), const LocalPoint2D(0, 10)];
      // Point 3m to the right at y = 5
      final dist = GeometryMetrics.crossTrackDistanceToPolyline(const LocalPoint2D(3, 5), polyline);
      expect(dist, closeTo(3.0, 1e-6));
    });

    test('Cross-track distance: point beyond end of segment clamps to endpoint', () {
      final polyline = [const LocalPoint2D(0, 0), const LocalPoint2D(0, 10)];
      // Point at (4, 13) -> closest endpoint is (0, 10) -> distance sqrt(4^2 + 3^2) = 5
      final dist = GeometryMetrics.crossTrackDistanceToPolyline(const LocalPoint2D(4, 13), polyline);
      expect(dist, closeTo(5.0, 1e-6));
    });

    test('Cross-track distance: multi-segment polyline with 90 deg corner', () {
      final polyline = [
        const LocalPoint2D(0, 0),
        const LocalPoint2D(0, 10), // Corner apex
        const LocalPoint2D(10, 10),
      ];
      // Point near first segment
      expect(GeometryMetrics.crossTrackDistanceToPolyline(const LocalPoint2D(2, 5), polyline), closeTo(2.0, 1e-6));
      // Point near second segment
      expect(GeometryMetrics.crossTrackDistanceToPolyline(const LocalPoint2D(5, 12), polyline), closeTo(2.0, 1e-6));
      // Point diagonally inside corner at (2, 8)
      // Distance to seg1 [0,0]->[0,10]: x=2 (at y=8). Distance to seg2 [0,10]->[10,10]: y=2 (at x=2).
      expect(GeometryMetrics.crossTrackDistanceToPolyline(const LocalPoint2D(2, 8), polyline), closeTo(2.0, 1e-6));
    });

    test('Corner shortcutting: 90 deg corner inside cut', () {
      // Approach North (0, -10) to Apex (0, 0), Exit East to (10, 0)
      const a = LocalPoint2D(0, -10);
      const v = LocalPoint2D(0, 0);
      const b = LocalPoint2D(10, 0);

      // u1 = (0, -1), u2 = (1, 0)
      // bisector = (1/sqrt(2), -1/sqrt(2)) pointing inside the corner (East-South)
      // If a cyclist cuts the corner by passing through (2, -2):
      // diff = (2, -2). dot product = 2*(1/sqrt(2)) + (-2)*(-1/sqrt(2)) = 4 / sqrt(2) = 2 * sqrt(2) = 2.8284 m
      final shortcut = GeometryMetrics.measureCornerShortcut(
        pEst: const LocalPoint2D(2, -2),
        vApex: v,
        aApproach: a,
        bExit: b,
      );
      expect(shortcut, closeTo(2.0 * math.sqrt(2.0), 1e-4));
    });

    test('Corner shortcutting: wide swing outside corner produces 0 shortcut error', () {
      const a = LocalPoint2D(0, -10);
      const v = LocalPoint2D(0, 0);
      const b = LocalPoint2D(10, 0);

      // Cyclist swings wide outside the corner at (-3, 3) (West-North)
      final shortcut = GeometryMetrics.measureCornerShortcut(
        pEst: const LocalPoint2D(-3, 3),
        vApex: v,
        aApproach: a,
        bExit: b,
      );
      expect(shortcut, closeTo(0.0, 1e-6));
    });

    test('Corner shortcutting: exactly on the vertex produces 0 shortcut error', () {
      const a = LocalPoint2D(0, -10);
      const v = LocalPoint2D(0, 0);
      const b = LocalPoint2D(10, 0);

      final shortcut = GeometryMetrics.measureCornerShortcut(
        pEst: const LocalPoint2D(0, 0),
        vApex: v,
        aApproach: a,
        bExit: b,
      );
      expect(shortcut, closeTo(0.0, 1e-6));
    });
  });
}
