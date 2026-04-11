import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

List<LatLng> sanitizeRouteForDisplay(
  List<LatLng> points, {
  required String activityType,
}) {
  if (points.length < 3) return List<LatLng>.from(points);

  final normalized = activityType.toLowerCase();
  var cleaned = _removeTinySegments(points, _minDisplaySegmentMeters(normalized));
  cleaned = _removeSharpSpikes(cleaned, normalized);
  cleaned = _douglasPeucker(cleaned, _simplifyToleranceMeters(normalized));
  cleaned = _removeSharpSpikes(cleaned, normalized);
  cleaned = _constrainedSmooth(cleaned, normalized);
  return cleaned;
}

double _minDisplaySegmentMeters(String activityType) {
  switch (activityType) {
    case 'cycling':
      return 4.5;
    case 'running':
      return 2.5;
    case 'walking':
      return 1.8;
    default:
      return 2.0;
  }
}

double _simplifyToleranceMeters(String activityType) {
  switch (activityType) {
    case 'cycling':
      return 4.0;
    case 'running':
      return 2.0;
    case 'walking':
      return 1.4;
    default:
      return 2.0;
  }
}

double _maxSmoothingShiftMeters(String activityType) {
  switch (activityType) {
    case 'cycling':
      return 2.4;
    case 'running':
      return 1.8;
    case 'walking':
      return 1.4;
    default:
      return 1.8;
  }
}

List<LatLng> _removeTinySegments(List<LatLng> points, double minDistanceMeters) {
  if (points.length < 2) return List<LatLng>.from(points);

  final result = <LatLng>[points.first];
  for (var i = 1; i < points.length; i++) {
    final previous = result.last;
    final current = points[i];
    if (_distance.distance(previous, current) >= minDistanceMeters ||
        i == points.length - 1) {
      result.add(current);
    }
  }
  return result;
}

List<LatLng> _removeSharpSpikes(List<LatLng> points, String activityType) {
  if (points.length < 3) return List<LatLng>.from(points);

  final result = <LatLng>[points.first];
  final maxShortSegment = activityType == 'cycling' ? 32.0 : 20.0;
  final minDetour = activityType == 'cycling' ? 7.0 : 4.0;
  final minAngle = activityType == 'cycling' ? 45.0 : 58.0;

  for (var i = 1; i < points.length - 1; i++) {
    final prev = result.last;
    final curr = points[i];
    final next = points[i + 1];

    final a = _distance.distance(prev, curr);
    final b = _distance.distance(curr, next);
    final c = _distance.distance(prev, next);
    final detour = (a + b) - c;
    final angle = _bearingDelta(_computeBearing(prev, curr), _computeBearing(curr, next));

    final isSpike =
        a <= maxShortSegment &&
        b <= maxShortSegment &&
        detour >= minDetour &&
        angle >= minAngle;

    if (!isSpike) {
      result.add(curr);
    }
  }

  result.add(points.last);
  return result;
}

List<LatLng> _douglasPeucker(List<LatLng> points, double epsilonMeters) {
  if (points.length < 3) return List<LatLng>.from(points);

  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  void simplify(int start, int end) {
    if (end <= start + 1) return;

    double maxDistance = 0;
    var index = -1;

    for (var i = start + 1; i < end; i++) {
      final distance = _perpendicularDistanceMeters(
        points[i],
        points[start],
        points[end],
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }

    if (maxDistance > epsilonMeters && index != -1) {
      keep[index] = true;
      simplify(start, index);
      simplify(index, end);
    }
  }

  simplify(0, points.length - 1);
  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}

double _perpendicularDistanceMeters(LatLng point, LatLng lineStart, LatLng lineEnd) {
  final meanLatRad = ((lineStart.latitude + lineEnd.latitude) / 2.0) * math.pi / 180.0;
  final metersPerDegLat = 111320.0;
  final metersPerDegLng = 111320.0 * math.cos(meanLatRad);

  final ax = lineStart.longitude * metersPerDegLng;
  final ay = lineStart.latitude * metersPerDegLat;
  final bx = lineEnd.longitude * metersPerDegLng;
  final by = lineEnd.latitude * metersPerDegLat;
  final px = point.longitude * metersPerDegLng;
  final py = point.latitude * metersPerDegLat;

  final dx = bx - ax;
  final dy = by - ay;
  if (dx.abs() < 1e-6 && dy.abs() < 1e-6) {
    final distX = px - ax;
    final distY = py - ay;
    return math.sqrt(distX * distX + distY * distY);
  }

  final t = (((px - ax) * dx) + ((py - ay) * dy)) / ((dx * dx) + (dy * dy));
  final clampedT = t.clamp(0.0, 1.0);
  final projX = ax + dx * clampedT;
  final projY = ay + dy * clampedT;
  final diffX = px - projX;
  final diffY = py - projY;
  return math.sqrt(diffX * diffX + diffY * diffY);
}

List<LatLng> _constrainedSmooth(List<LatLng> points, String activityType) {
  if (points.length < 3) return List<LatLng>.from(points);

  final result = <LatLng>[points.first];
  final maxShift = _maxSmoothingShiftMeters(activityType);

  for (var i = 1; i < points.length - 1; i++) {
    final prev = points[i - 1];
    final curr = points[i];
    final next = points[i + 1];

    final blended = LatLng(
      prev.latitude * 0.18 + curr.latitude * 0.64 + next.latitude * 0.18,
      prev.longitude * 0.18 + curr.longitude * 0.64 + next.longitude * 0.18,
    );

    final shift = _distance.distance(curr, blended);
    result.add(shift <= maxShift ? blended : curr);
  }

  result.add(points.last);
  return result;
}


double _computeBearing(LatLng from, LatLng to) {
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
