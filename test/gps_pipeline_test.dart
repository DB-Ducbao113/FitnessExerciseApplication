import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GpsPipeline Tests', () {
    test('seedRoute correctly initializes all lists and EKF', () {
      final pipeline = GpsPipeline();
      const p1 = LatLng(10.7769, 106.7009);

      pipeline.seedRoute(p1);

      expect(pipeline.totalRoutePointsCount, 1);
      expect(pipeline.filteredRoutePoints, [p1]);
      expect(pipeline.smoothedRoutePoints, [p1]);
      expect(pipeline.routePoints, [p1]);
      expect(pipeline.routeSegments.length, 1);
      expect(pipeline.routeSegments.first, [p1]);
      expect(pipeline.ekf.isInitialized, true);
      expect(pipeline.hasPendingChanges, true);

      final snapshot = pipeline.createSnapshot();
      expect(snapshot.routePoints.length, 1);
      expect(pipeline.hasPendingChanges, false);
    });

    test('appendAcceptedSegment appends points O(1) without recreating lists', () {
      final pipeline = GpsPipeline();
      const p1 = LatLng(10.7769, 106.7009);
      const p2 = LatLng(10.7770, 106.7010);
      const p3 = LatLng(10.7771, 106.7011);

      pipeline.seedRoute(p1);

      pipeline.appendAcceptedSegment(
        routeCandidate: p2,
        displayRoutePoint: p2,
        shouldBreakRouteForDisplay: false,
        gpsGapDurationSec: 0,
        shouldAppendSmoothedPoint: true,
      );

      pipeline.appendAcceptedSegment(
        routeCandidate: p3,
        displayRoutePoint: p3,
        shouldBreakRouteForDisplay: false,
        gpsGapDurationSec: 0,
        shouldAppendSmoothedPoint: true,
      );

      expect(pipeline.totalRoutePointsCount, 3);
      expect(pipeline.routeSegments.length, 1);
      expect(pipeline.routeSegments.first.length, 3);
      expect(pipeline.hasPendingChanges, true);
    });

    test('appendAcceptedSegment handles route break gap segments', () {
      final pipeline = GpsPipeline();
      const p1 = LatLng(10.7769, 106.7009);
      const p2 = LatLng(10.7800, 106.7050);

      pipeline.seedRoute(p1);

      pipeline.appendAcceptedSegment(
        routeCandidate: p2,
        displayRoutePoint: p2,
        shouldBreakRouteForDisplay: true,
        gpsGapDurationSec: 8.5,
        shouldAppendSmoothedPoint: true,
      );

      expect(pipeline.routeSegments.length, 2);
      expect(pipeline.gpsGapSegments.length, 1);
      expect(pipeline.gpsGapSegments.first.durationSec, 8.5);
      expect(pipeline.gpsGapSegments.first.start, p1);
      expect(pipeline.gpsGapSegments.first.end, p2);
    });

    test('createSnapshot produces unmodifiable snapshot for state isolation', () {
      final pipeline = GpsPipeline();
      pipeline.seedRoute(const LatLng(10.0, 106.0));
      final snapshot = pipeline.createSnapshot();

      expect(
        () => (snapshot.routePoints as dynamic).add(const LatLng(11.0, 107.0)),
        throwsUnsupportedError,
      );
    });
  });
}
