import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Scenarios intentionally generated for repeatable pipeline tests.
///
/// These traces are not field measurements and must never be included in a
/// user workout, uploaded to Supabase, or reported as benchmark evidence.
enum SyntheticGpsScenario { stationary, urbanCycling }

/// One simulated observation with a known reference position.
class SyntheticGpsPoint {
  final DateTime timestamp;
  final LatLng groundTruth;
  final LatLng rawMeasurement;
  final double accuracyMeters;
  final double speedMs;
  final double headingDeg;
  final bool isInjectedOutlier;

  const SyntheticGpsPoint({
    required this.timestamp,
    required this.groundTruth,
    required this.rawMeasurement,
    required this.accuracyMeters,
    required this.speedMs,
    required this.headingDeg,
    this.isInjectedOutlier = false,
  });
}

/// A trace whose ground truth is known because it was synthetically created.
class SyntheticGpsTrace {
  final String id;
  final SyntheticGpsScenario scenario;
  final List<SyntheticGpsPoint> points;

  const SyntheticGpsTrace({
    required this.id,
    required this.scenario,
    required this.points,
  });

  /// Guards callers from accidentally presenting generated data as field data.
  bool get isSynthetic => true;

  Duration get maxObservedGap {
    if (points.length < 2) return Duration.zero;
    var maxGap = Duration.zero;
    for (var index = 1; index < points.length; index += 1) {
      final gap = points[index].timestamp.difference(
        points[index - 1].timestamp,
      );
      if (gap > maxGap) maxGap = gap;
    }
    return maxGap;
  }
}

/// Generates deterministic, clearly-labelled input for unit and replay tests.
///
/// The patterns model noise, a GPS outage, and one obvious outlier. They do
/// not model a particular phone, city, satellite constellation, or person.
class SyntheticGpsTraceFactory {
  const SyntheticGpsTraceFactory();

  static const Distance _distance = Distance();

  /// Bike-routable loop returned by OpenStreetMap's bicycle router on
  /// 2026-10-12. It begins on Đường số 23 and passes Đường số 17,
  /// Đường Lý Chiêu Hoàng, and Trần Văn Kiểu in Bình Phú, HCMC.
  static const _urbanCyclingRoute = <LatLng>[
    LatLng(10.738082, 106.625303),
    LatLng(10.738585, 106.625314),
    LatLng(10.738560, 106.625412),
    LatLng(10.738530, 106.625517),
    LatLng(10.738474, 106.625512),
    LatLng(10.738450, 106.625583),
    LatLng(10.738566, 106.625636),
    LatLng(10.738773, 106.625718),
    LatLng(10.739004, 106.625790),
    LatLng(10.738969, 106.625882),
    LatLng(10.738790, 106.626305),
    LatLng(10.738713, 106.626487),
    LatLng(10.738550, 106.626873),
    LatLng(10.738396, 106.627229),
    LatLng(10.738519, 106.627265),
    LatLng(10.738673, 106.626902),
    LatLng(10.738940, 106.626974),
    LatLng(10.739053, 106.627001),
    LatLng(10.738673, 106.626902),
    LatLng(10.738519, 106.627265),
    LatLng(10.738478, 106.627363),
    LatLng(10.738353, 106.627336),
    LatLng(10.738334, 106.627386),
    LatLng(10.738080, 106.628067),
    LatLng(10.737994, 106.628298),
    LatLng(10.737850, 106.628688),
    LatLng(10.737952, 106.628729),
    LatLng(10.738194, 106.628106),
    LatLng(10.738458, 106.627415),
    LatLng(10.738478, 106.627363),
    LatLng(10.738353, 106.627336),
    LatLng(10.738272, 106.627324),
    LatLng(10.737586, 106.627226),
    LatLng(10.737326, 106.627191),
    LatLng(10.736859, 106.627126),
    LatLng(10.736589, 106.627089),
    LatLng(10.736488, 106.627075),
    LatLng(10.735926, 106.626997),
    LatLng(10.735603, 106.626935),
    LatLng(10.735625, 106.626838),
    LatLng(10.735754, 106.626266),
    LatLng(10.735968, 106.625335),
    LatLng(10.736011, 106.625157),
    LatLng(10.736488, 106.625241),
    LatLng(10.736753, 106.625275),
    LatLng(10.738082, 106.625303),
  ];

  SyntheticGpsTrace stationary({
    required DateTime startedAt,
    required LatLng center,
    required Duration duration,
  }) {
    final points = <SyntheticGpsPoint>[];
    for (var second = 0; second <= duration.inSeconds; second += 1) {
      final timestamp = startedAt.add(Duration(seconds: second));
      final rawMeasurement = _noisyMeasurement(
        truth: center,
        sampleIndex: second,
        baseNoiseMeters: 3.2,
      );
      points.add(
        SyntheticGpsPoint(
          timestamp: timestamp,
          groundTruth: center,
          rawMeasurement: rawMeasurement,
          accuracyMeters: 5.0 + (second % 5),
          speedMs: 0.0,
          headingDeg: 0.0,
        ),
      );
    }
    return SyntheticGpsTrace(
      id: 'synthetic-stationary-${startedAt.toUtc().toIso8601String()}',
      scenario: SyntheticGpsScenario.stationary,
      points: List<SyntheticGpsPoint>.unmodifiable(points),
    );
  }

  SyntheticGpsTrace urbanCycling({
    required DateTime startedAt,
    required Duration duration,
  }) {
    const speedMs = 5.5;
    final points = <SyntheticGpsPoint>[];

    for (var second = 0; second <= duration.inSeconds; second += 1) {
      // A 10-second satellite outage produces a visible 11-second sample gap.
      if (second >= 150 && second < 160) continue;

      final truth = _cyclingRoutePoint(second * speedMs);
      final heading = _cyclingRouteHeading(second * speedMs);
      final isOutlier = second == 260;
      final rawMeasurement = isOutlier
          ? _distance.offset(truth, 55.0, 225.0)
          : _noisyMeasurement(
              truth: truth,
              sampleIndex: second,
              baseNoiseMeters: 6.0,
            );
      points.add(
        SyntheticGpsPoint(
          timestamp: startedAt.add(Duration(seconds: second)),
          groundTruth: truth,
          rawMeasurement: rawMeasurement,
          accuracyMeters: isOutlier ? 45.0 : 7.0 + (second % 7),
          speedMs: speedMs,
          headingDeg: heading,
          isInjectedOutlier: isOutlier,
        ),
      );
    }

    return SyntheticGpsTrace(
      id: 'synthetic-urban-cycling-${startedAt.toUtc().toIso8601String()}',
      scenario: SyntheticGpsScenario.urbanCycling,
      points: List<SyntheticGpsPoint>.unmodifiable(points),
    );
  }

  LatLng _cyclingRoutePoint(double distanceMeters) {
    final totalDistance = _routeLengthMeters;
    var remaining = distanceMeters % totalDistance;
    for (var index = 1; index < _urbanCyclingRoute.length; index += 1) {
      final from = _urbanCyclingRoute[index - 1];
      final to = _urbanCyclingRoute[index];
      final segmentDistance = _distance.distance(from, to);
      if (remaining <= segmentDistance) {
        final bearing = _distance.bearing(from, to);
        return _distance.offset(from, remaining, bearing);
      }
      remaining -= segmentDistance;
    }
    return _urbanCyclingRoute.first;
  }

  double _cyclingRouteHeading(double distanceMeters) {
    final current = _cyclingRoutePoint(distanceMeters);
    final next = _cyclingRoutePoint(distanceMeters + 3.0);
    final bearing = _distance.bearing(current, next);
    return (bearing % 360.0 + 360.0) % 360.0;
  }

  double get _routeLengthMeters {
    var total = 0.0;
    for (var index = 1; index < _urbanCyclingRoute.length; index += 1) {
      total += _distance.distance(
        _urbanCyclingRoute[index - 1],
        _urbanCyclingRoute[index],
      );
    }
    return total;
  }

  LatLng _noisyMeasurement({
    required LatLng truth,
    required int sampleIndex,
    required double baseNoiseMeters,
  }) {
    final magnitude =
        baseNoiseMeters * (0.35 + 0.65 * math.sin(sampleIndex * 0.73).abs());
    final bearing = (sampleIndex * 137.5) % 360.0;
    return _distance.offset(truth, magnitude, bearing);
  }
}
