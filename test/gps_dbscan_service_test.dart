import 'package:fitness_exercise_application/features/workout/domain/services/dbscan/gps_dbscan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GpsDbscanService', () {
    const service = GpsDbscanService(
      epsilonMeters: 6.5,
      minDurationSeconds: 10.0,
      minPts: 4,
    );
    const dist = Distance();

    test('detects red-light dwell cluster with jitter points and computes centroid', () {
      final now = DateTime.now();
      final points = <TimedGpsPoint>[];

      // 1. Moving phase: 3 points moving North
      var pos = const LatLng(10.7700, 106.7000);
      for (var i = 0; i < 3; i++) {
        points.add(
          TimedGpsPoint(
            point: pos,
            timestamp: now.add(Duration(seconds: i)),
            speedMs: 3.0,
          ),
        );
        pos = dist.offset(pos, 3.0, 0.0);
      }

      // 2. Stationary dwell phase: red light for 30s with ±2-3m jitter
      final redLightAnchor = pos;
      for (var i = 0; i < 30; i++) {
        // slight jitter around anchor within 3m
        final jitterBearing = (i * 45.0) % 360.0;
        final jitterDist = (i % 3) * 1.0;
        final jittered = dist.offset(redLightAnchor, jitterDist, jitterBearing);
        points.add(
          TimedGpsPoint(
            point: jittered,
            timestamp: now.add(Duration(seconds: 3 + i)),
            speedMs: 0.1,
          ),
        );
      }

      // 3. Moving phase: 5 points resuming movement
      pos = redLightAnchor;
      for (var i = 0; i < 5; i++) {
        pos = dist.offset(pos, 3.0, 0.0);
        points.add(
          TimedGpsPoint(
            point: pos,
            timestamp: now.add(Duration(seconds: 33 + i)),
            speedMs: 3.0,
          ),
        );
      }

      final clusters = service.findDwellClusters(points);

      expect(clusters.length, 1);
      final cluster = clusters.first;
      expect(cluster.startIndex, 3);
      expect(cluster.pointCount, 30);
      expect(cluster.durationSeconds, greaterThanOrEqualTo(29.0));

      // Centroid should be within 1.5m of the redLightAnchor
      final error = dist.distance(cluster.centroid, redLightAnchor);
      expect(error, lessThan(1.5));
    });

    test('ignores normal moving points where points exceed epsilon', () {
      final now = DateTime.now();
      final points = <TimedGpsPoint>[];

      var pos = const LatLng(10.7700, 106.7000);
      for (var i = 0; i < 20; i++) {
        points.add(
          TimedGpsPoint(
            point: pos,
            timestamp: now.add(Duration(seconds: i)),
            speedMs: 3.2,
          ),
        );
        pos = dist.offset(pos, 3.2, 0.0); // 3.2m per second
      }

      final clusters = service.findDwellClusters(points);
      expect(clusters, isEmpty);
    });
  });
}
