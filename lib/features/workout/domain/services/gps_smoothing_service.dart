import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:latlong2/latlong.dart';

const Distance _gpsDistance = Distance();

class GpsSmoothingUpdate {
  final LatLng smoothedPoint;
  final bool shouldAppendRoutePoint;
  final bool isStationary;
  final GpsConfidence confidence;

  const GpsSmoothingUpdate({
    required this.smoothedPoint,
    required this.shouldAppendRoutePoint,
    required this.isStationary,
    required this.confidence,
  });
}

class GpsSmoothingService {
  const GpsSmoothingService();

  GpsSmoothingUpdate smoothAcceptedPoint({
    required String activityType,
    required LatLng acceptedPoint,
    required LatLng? previousAcceptedPoint,
    required LatLng? previousSmoothedPoint,
    required LatLng? lastSmoothedRoutePoint,
    required double accuracyMeters,
    required double speedMs,
    required double timeDeltaSec,
    required double gpsGapDurationSec,
  }) {
    final confidence = _confidenceFor(
      accuracyMeters: accuracyMeters,
      speedMs: speedMs,
      timeDeltaSec: timeDeltaSec,
      gpsGapDurationSec: gpsGapDurationSec,
    );
    final acceptedDelta = previousAcceptedPoint == null
        ? 0.0
        : _gpsDistance.distance(previousAcceptedPoint, acceptedPoint);
    final isStationary =
        previousAcceptedPoint != null &&
        gpsGapDurationSec <= 0 &&
        acceptedDelta <= _stationaryRadiusMeters(activityType) &&
        (speedMs <= 0.8 || timeDeltaSec >= 1.0);

    final smoothedPoint = _smoothPoint(
      acceptedPoint: acceptedPoint,
      previousAcceptedPoint: previousAcceptedPoint,
      previousSmoothedPoint: previousSmoothedPoint,
      confidence: confidence,
      activityType: activityType,
      isStationary: isStationary,
      acceptedDelta: acceptedDelta,
    );

    final appendThreshold = _minAppendDistanceMeters(activityType);
    final routeDelta = lastSmoothedRoutePoint == null
        ? double.infinity
        : _gpsDistance.distance(lastSmoothedRoutePoint, smoothedPoint);
    final shouldAppendRoutePoint =
        gpsGapDurationSec > 5.0 ||
        lastSmoothedRoutePoint == null ||
        (!isStationary &&
            routeDelta >= appendThreshold &&
            confidence != GpsConfidence.low);

    return GpsSmoothingUpdate(
      smoothedPoint: smoothedPoint,
      shouldAppendRoutePoint: shouldAppendRoutePoint,
      isStationary: isStationary,
      confidence: confidence,
    );
  }

  GpsConfidence _confidenceFor({
    required double accuracyMeters,
    required double speedMs,
    required double timeDeltaSec,
    required double gpsGapDurationSec,
  }) {
    if (gpsGapDurationSec > 5.0 || accuracyMeters > 30.0) {
      return GpsConfidence.low;
    }
    if (accuracyMeters > 15.0 || timeDeltaSec > 2.5 || speedMs <= 0.4) {
      return GpsConfidence.medium;
    }
    return GpsConfidence.high;
  }

  LatLng _smoothPoint({
    required LatLng acceptedPoint,
    required LatLng? previousAcceptedPoint,
    required LatLng? previousSmoothedPoint,
    required GpsConfidence confidence,
    required String activityType,
    required bool isStationary,
    required double acceptedDelta,
  }) {
    if (previousSmoothedPoint == null) return acceptedPoint;
    if (isStationary && acceptedDelta < _stationaryFreezeMeters(activityType)) {
      return previousSmoothedPoint;
    }

    var alpha = switch (confidence) {
      GpsConfidence.high => 0.72,
      GpsConfidence.medium => 0.52,
      GpsConfidence.low => 0.34,
    };

    if (previousAcceptedPoint != null) {
      final turnDelta = _bearingDelta(
        _bearing(previousAcceptedPoint, acceptedPoint),
        _bearing(previousSmoothedPoint, acceptedPoint),
      );
      if (turnDelta > 28.0 && acceptedDelta > 4.0) {
        alpha = math.max(alpha, 0.82);
      }
    }

    return LatLng(
      previousSmoothedPoint.latitude * (1 - alpha) +
          acceptedPoint.latitude * alpha,
      previousSmoothedPoint.longitude * (1 - alpha) +
          acceptedPoint.longitude * alpha,
    );
  }

  double _minAppendDistanceMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 2.0;
      case 'cycling':
        return 4.0;
      case 'running':
      default:
        return 2.5;
    }
  }

  double _stationaryRadiusMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 2.2;
      case 'cycling':
        return 3.5;
      case 'running':
      default:
        return 2.6;
    }
  }

  double _stationaryFreezeMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 1.6;
      case 'cycling':
        return 2.5;
      case 'running':
      default:
        return 2.0;
    }
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLng = (to.longitude - from.longitude) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  double _bearingDelta(double a, double b) {
    final delta = (a - b).abs();
    return delta > 180 ? 360 - delta : delta;
  }
}
