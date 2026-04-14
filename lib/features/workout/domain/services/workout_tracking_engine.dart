import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum TrackingGpsDecisionType { skip, seedRoute, resetAnchor, acceptRoute }

class TrackingGpsDecision {
  final TrackingGpsDecisionType type;
  final LatLng livePoint;
  final LatLng? previewPoint;
  final String? skipReason;
  final double segmentMeters;
  final double rawSegmentMeters;
  final double routeSegmentMeters;
  final double candidateSpeedKmh;

  const TrackingGpsDecision({
    required this.type,
    required this.livePoint,
    required this.previewPoint,
    this.skipReason,
    this.segmentMeters = 0,
    this.rawSegmentMeters = 0,
    this.routeSegmentMeters = 0,
    this.candidateSpeedKmh = 0,
  });
}

class StepTrackingDecision {
  final int delta;
  final bool shouldActivateGpsFallback;

  const StepTrackingDecision({
    required this.delta,
    required this.shouldActivateGpsFallback,
  });
}

class IndoorStepContribution {
  final double addedDistanceMeters;
  final double? instantSpeedKmh;

  const IndoorStepContribution({
    required this.addedDistanceMeters,
    required this.instantSpeedKmh,
  });
}

class WorkoutTrackingEngine {
  const WorkoutTrackingEngine();

  TrackingGpsDecision evaluateGpsUpdate({
    required Position position,
    required String activityType,
    required List<LatLng> routePoints,
    required LatLng? currentLatLng,
    required LatLng? distanceAnchorPoint,
    required DateTime? lastAcceptedPositionTime,
    required bool shouldResetAnchorOnResume,
    bool debugLocationMode = false,
  }) {
    final livePoint = LatLng(position.latitude, position.longitude);
    final previewAccuracy = debugLocationMode
        ? 100.0
        : getPreviewAccuracy(activityType);
    final allowPreviewUpdate = position.accuracy <= previewAccuracy * 1.6;
    final previewPoint = allowPreviewUpdate ? livePoint : currentLatLng;
    final maxAccuracy = debugLocationMode
        ? 100.0
        : getMaxRouteAccuracy(activityType);

    if (routePoints.isEmpty) {
      if (position.accuracy > maxAccuracy) {
        return TrackingGpsDecision(
          type: TrackingGpsDecisionType.skip,
          livePoint: livePoint,
          previewPoint: previewPoint,
          skipReason:
              'waiting_for_better_first_fix acc=${position.accuracy.toStringAsFixed(1)}m',
        );
      }
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.seedRoute,
        livePoint: livePoint,
        previewPoint: livePoint,
      );
    }

    if (shouldResetAnchorOnResume) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.resetAnchor,
        livePoint: livePoint,
        previewPoint: livePoint,
      );
    }

    final minSegmentMeters = debugLocationMode
        ? 0.25
        : getMinSegmentMeters(activityType);
    final maxSpeedMs = getMaxSpeedMs(activityType);
    final lastPoint = routePoints.last;
    final rawDistanceAnchor = distanceAnchorPoint ?? lastPoint;
    final rawSegmentMeters = Geolocator.distanceBetween(
      rawDistanceAnchor.latitude,
      rawDistanceAnchor.longitude,
      livePoint.latitude,
      livePoint.longitude,
    );
    final routeSegmentMeters = Geolocator.distanceBetween(
      lastPoint.latitude,
      lastPoint.longitude,
      livePoint.latitude,
      livePoint.longitude,
    );
    final segmentMeters = rawSegmentMeters;

    if (segmentMeters < minSegmentMeters) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.skip,
        livePoint: livePoint,
        previewPoint: previewPoint,
        skipReason:
            'segment=${segmentMeters.toStringAsFixed(2)}m < $minSegmentMeters',
        segmentMeters: segmentMeters,
        rawSegmentMeters: rawSegmentMeters,
        routeSegmentMeters: routeSegmentMeters,
      );
    }

    if (position.accuracy > maxAccuracy) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.skip,
        livePoint: livePoint,
        previewPoint: previewPoint,
        skipReason:
            'accuracy=${position.accuracy.toStringAsFixed(2)}m > $maxAccuracy',
        segmentMeters: segmentMeters,
        rawSegmentMeters: rawSegmentMeters,
        routeSegmentMeters: routeSegmentMeters,
      );
    }

    if (position.speed > 0 && position.speed > maxSpeedMs) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.skip,
        livePoint: livePoint,
        previewPoint: previewPoint,
        skipReason:
            'gps_speed=${position.speed.toStringAsFixed(2)}m/s > ${maxSpeedMs.toStringAsFixed(2)}m/s',
        segmentMeters: segmentMeters,
        rawSegmentMeters: rawSegmentMeters,
        routeSegmentMeters: routeSegmentMeters,
      );
    }

    final previousAcceptedTime = lastAcceptedPositionTime;
    final timeDeltaSec = previousAcceptedTime == null
        ? 0.0
        : position.timestamp.difference(previousAcceptedTime).inMilliseconds /
              1000.0;
    if (timeDeltaSec > 0) {
      final impliedSpeed = segmentMeters / timeDeltaSec;
      if (impliedSpeed > maxSpeedMs * 1.2) {
        return TrackingGpsDecision(
          type: TrackingGpsDecisionType.skip,
          livePoint: livePoint,
          previewPoint: previewPoint,
          skipReason:
              'implied_speed=${impliedSpeed.toStringAsFixed(2)}m/s',
          segmentMeters: segmentMeters,
          rawSegmentMeters: rawSegmentMeters,
          routeSegmentMeters: routeSegmentMeters,
        );
      }
    }

    final canUseBearingFilter =
        activityType.toLowerCase() == 'cycling' &&
        routePoints.length >= 2 &&
        routeSegmentMeters > 22;
    if (canUseBearingFilter) {
      final previousBearing = computeBearing(
        routePoints[routePoints.length - 2],
        lastPoint,
      );
      final currentBearing = computeBearing(lastPoint, livePoint);
      final delta = bearingDelta(previousBearing, currentBearing);
      if (delta > 150.0 && rawSegmentMeters < 18) {
        return TrackingGpsDecision(
          type: TrackingGpsDecisionType.skip,
          livePoint: livePoint,
          previewPoint: previewPoint,
          skipReason: 'bearing_delta=${delta.toStringAsFixed(1)}deg',
          segmentMeters: segmentMeters,
          rawSegmentMeters: rawSegmentMeters,
          routeSegmentMeters: routeSegmentMeters,
        );
      }
    }

    final sensorSpeedKmh = position.speed > 0
        ? position.speed.clamp(0.0, 50.0) * 3.6
        : 0.0;
    final segmentSpeedKmh = timeDeltaSec > 0
        ? (segmentMeters / timeDeltaSec) * 3.6
        : sensorSpeedKmh;
    final candidateSpeedKmh = segmentSpeedKmh > 0
        ? segmentSpeedKmh
        : sensorSpeedKmh;

    return TrackingGpsDecision(
      type: TrackingGpsDecisionType.acceptRoute,
      livePoint: livePoint,
      previewPoint: previewPoint,
      segmentMeters: segmentMeters,
      rawSegmentMeters: rawSegmentMeters,
      routeSegmentMeters: routeSegmentMeters,
      candidateSpeedKmh: candidateSpeedKmh,
    );
  }

  StepTrackingDecision evaluateStepUpdate({
    required int sessionSteps,
    required int currentStepCount,
    required bool requiresGpsTracking,
    required bool gpsFallbackActive,
    required String recordingSource,
    required DateTime? lastAcceptedPositionTime,
    required DateTime now,
  }) {
    final delta = sessionSteps - currentStepCount;
    if (delta <= 0) {
      return const StepTrackingDecision(
        delta: 0,
        shouldActivateGpsFallback: false,
      );
    }

    final secondsSinceGps = lastAcceptedPositionTime == null
        ? 999
        : now.difference(lastAcceptedPositionTime).inSeconds;
    final shouldActivateGpsFallback =
        requiresGpsTracking &&
        !gpsFallbackActive &&
        recordingSource == 'gps' &&
        sessionSteps >= 8 &&
        secondsSinceGps >= 12;

    return StepTrackingDecision(
      delta: delta,
      shouldActivateGpsFallback: shouldActivateGpsFallback,
    );
  }

  IndoorStepContribution computeIndoorStepContribution({
    required int stepDelta,
    required double strideLengthMeters,
    required DateTime now,
    required DateTime? lastStepTime,
  }) {
    final addedDistanceMeters = stepDelta * strideLengthMeters;
    double? instantSpeedKmh;
    if (lastStepTime != null) {
      final secondsSinceLastStep =
          now.difference(lastStepTime).inMilliseconds / 1000.0;
      if (secondsSinceLastStep > 0) {
        instantSpeedKmh = (addedDistanceMeters / secondsSinceLastStep) * 3.6;
      }
    }
    return IndoorStepContribution(
      addedDistanceMeters: addedDistanceMeters,
      instantSpeedKmh: instantSpeedKmh,
    );
  }

  bool isMoving(double speedKmh, String activityType) {
    return speedKmh >= getMinMovingSpeedKmh(activityType);
  }

  double getMinMovingSpeedKmh(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 0.10;
      case 'cycling':
        return 0.4;
      case 'running':
      default:
        return 0.20;
    }
  }

  double getMaxSpeedMs(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 4.5;
      case 'cycling':
        return 22.0;
      case 'running':
        return 10.0;
      default:
        return 15.0;
    }
  }

  double getMinSegmentMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 0.35;
      case 'cycling':
        return 1.5;
      case 'running':
        return 0.30;
      default:
        return 0.30;
    }
  }

  double getMaxRouteAccuracy(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 32.0;
      case 'running':
        return 42.0;
      case 'walking':
        return 50.0;
      default:
        return 35.0;
    }
  }

  double getPreviewAccuracy(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 35.0;
      case 'running':
        return 45.0;
      case 'walking':
        return 60.0;
      default:
        return 45.0;
    }
  }

  double computeBearing(LatLng from, LatLng to) {
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

  double bearingDelta(double a, double b) {
    final delta = (a - b).abs();
    return delta > 180 ? 360 - delta : delta;
  }
}
