import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum GpsPointOutcome { accepted, softRejected, hardRejected, signalGap }

enum GpsConfidence { high, medium, low }

enum GpsRejectReason {
  none,
  waitingForBetterFirstFix,
  tinySegment,
  lowAccuracy,
  gpsSpeedHardSpike,
  impliedSpeedHardSpike,
  headingSpike,
  staleSignalGap,
}

class GpsValidationDebugEntry {
  final LatLng point;
  final double accuracyMeters;
  final double speedMs;
  final double? headingDegrees;
  final DateTime timestamp;
  final GpsPointOutcome outcome;
  final GpsRejectReason reason;
  final double segmentMeters;
  final double routeSegmentMeters;
  final double timeDeltaSec;
  final String detail;

  const GpsValidationDebugEntry({
    required this.point,
    required this.accuracyMeters,
    required this.speedMs,
    required this.headingDegrees,
    required this.timestamp,
    required this.outcome,
    required this.reason,
    required this.segmentMeters,
    required this.routeSegmentMeters,
    required this.timeDeltaSec,
    required this.detail,
  });

  factory GpsValidationDebugEntry.fromPosition({
    required Position position,
    required GpsPointOutcome outcome,
    required GpsRejectReason reason,
    required double segmentMeters,
    required double routeSegmentMeters,
    required double timeDeltaSec,
    required String detail,
  }) {
    return GpsValidationDebugEntry(
      point: LatLng(position.latitude, position.longitude),
      accuracyMeters: position.accuracy,
      speedMs: position.speed,
      headingDegrees: position.heading > 0 ? position.heading : null,
      timestamp: position.timestamp,
      outcome: outcome,
      reason: reason,
      segmentMeters: segmentMeters,
      routeSegmentMeters: routeSegmentMeters,
      timeDeltaSec: timeDeltaSec,
      detail: detail,
    );
  }
}
