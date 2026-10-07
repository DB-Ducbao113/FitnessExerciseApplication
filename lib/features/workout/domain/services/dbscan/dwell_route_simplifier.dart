import 'package:fitness_exercise_application/features/workout/domain/services/dbscan/gps_dbscan_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Result of dwell route simplification post-processing
class DwellSimplificationResult {
  final List<List<LatLng>> simplifiedSegments;
  final List<DwellCluster> detectedClusters;
  final double phantomDriftMeters;

  const DwellSimplificationResult({
    required this.simplifiedSegments,
    required this.detectedClusters,
    required this.phantomDriftMeters,
  });
}

/// Post-processing service that collapses stationary GPS dwell clusters (e.g. red-light stops)
/// into single centroids to eliminate phantom distance inflation.
class DwellRouteSimplifier {
  final GpsDbscanService dbscanService;

  static const Distance _distance = Distance();

  const DwellRouteSimplifier({
    this.dbscanService = const GpsDbscanService(),
  });

  /// Simplifies a flat list of [TimedGpsPoint] by replacing detected dwell clusters
  /// with their respective centroid.
  (List<TimedGpsPoint>, List<DwellCluster>, double) simplifyTimedPoints(
    List<TimedGpsPoint> points,
  ) {
    if (points.isEmpty) return (const [], const [], 0.0);

    final clusters = dbscanService.findDwellClusters(points);
    if (clusters.isEmpty) {
      return (List<TimedGpsPoint>.from(points), const [], 0.0);
    }

    var phantomDriftMeters = 0.0;
    final simplified = <TimedGpsPoint>[];
    var currentPointIndex = 0;

    for (final cluster in clusters) {
      // Calculate phantom drift accumulated within this cluster
      for (var k = cluster.startIndex + 1; k <= cluster.endIndex; k++) {
        phantomDriftMeters += _distance.distance(
          points[k - 1].point,
          points[k].point,
        );
      }

      // Add all points prior to the cluster
      while (currentPointIndex < cluster.startIndex) {
        simplified.add(points[currentPointIndex]);
        currentPointIndex += 1;
      }

      // Replace the entire cluster with a single centroid point
      simplified.add(
        TimedGpsPoint(
          point: cluster.centroid,
          timestamp: cluster.startTime,
          speedMs: 0.0,
          accuracyMeters: 2.0,
        ),
      );

      // Advance index past the cluster
      currentPointIndex = cluster.endIndex + 1;
    }

    // Add any remaining points after the last cluster
    while (currentPointIndex < points.length) {
      simplified.add(points[currentPointIndex]);
      currentPointIndex += 1;
    }

    return (simplified, clusters, phantomDriftMeters);
  }

  /// Simplifies route segments given raw GPS positions containing timestamps and speeds.
  DwellSimplificationResult simplifyRouteSegments({
    required List<List<LatLng>> segments,
    required List<Position> rawPositions,
  }) {
    if (segments.isEmpty || rawPositions.isEmpty) {
      return DwellSimplificationResult(
        simplifiedSegments: segments,
        detectedClusters: const [],
        phantomDriftMeters: 0.0,
      );
    }

    // Map raw positions to TimedGpsPoint
    final timedPoints = rawPositions
        .map(
          (p) => TimedGpsPoint(
            point: LatLng(p.latitude, p.longitude),
            timestamp: p.timestamp,
            speedMs: p.speed,
            accuracyMeters: p.accuracy,
          ),
        )
        .toList(growable: false);

    final (_, clusters, phantomDriftMeters) = simplifyTimedPoints(timedPoints);
    if (clusters.isEmpty) {
      return DwellSimplificationResult(
        simplifiedSegments: segments,
        detectedClusters: const [],
        phantomDriftMeters: 0.0,
      );
    }

    // Map dwell clusters onto route segments to collapse spatial jitter
    final simplifiedSegments = <List<LatLng>>[];

    for (final segment in segments) {
      if (segment.length < 3) {
        simplifiedSegments.add(List<LatLng>.from(segment));
        continue;
      }

      final newSegment = <LatLng>[];
      var i = 0;
      while (i < segment.length) {
        final pt = segment[i];
        // Check if pt is inside any cluster
        DwellCluster? matchedCluster;
        for (final cluster in clusters) {
          if (_distance.distance(pt, cluster.centroid) <=
              dbscanService.epsilonMeters + 2.0) {
            matchedCluster = cluster;
            break;
          }
        }

        if (matchedCluster != null) {
          // Add centroid once
          if (newSegment.isEmpty ||
              _distance.distance(newSegment.last, matchedCluster.centroid) >
                  0.5) {
            newSegment.add(matchedCluster.centroid);
          }

          // Skip subsequent points that belong to the same cluster
          while (i < segment.length &&
              _distance.distance(segment[i], matchedCluster.centroid) <=
                  dbscanService.epsilonMeters + 2.0) {
            i += 1;
          }
        } else {
          newSegment.add(pt);
          i += 1;
        }
      }

      if (newSegment.isNotEmpty) {
        simplifiedSegments.add(newSegment);
      }
    }

    return DwellSimplificationResult(
      simplifiedSegments: simplifiedSegments,
      detectedClusters: clusters,
      phantomDriftMeters: phantomDriftMeters,
    );
  }
}
