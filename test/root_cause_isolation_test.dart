// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:latlong2/latlong.dart';
import 'helpers/historical_phase3_ekf.dart';

const Distance _distance = Distance();

const _route = <LatLng>[
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

double _routeLengthMeters() {
  double d = 0;
  for (int i = 1; i < _route.length; i++) {
    d += _distance.distance(_route[i - 1], _route[i]);
  }
  return d;
}

(LatLng, double) _interpolateRoute(double distAlongRoute, double totalDist) {
  var remaining = distAlongRoute % totalDist;
  for (int i = 1; i < _route.length; i++) {
    final segLen = _distance.distance(_route[i - 1], _route[i]);
    if (remaining <= segLen || i == _route.length - 1) {
      final frac = segLen > 0 ? (remaining / segLen).clamp(0.0, 1.0) : 0.0;
      final lat = _route[i - 1].latitude + frac * (_route[i].latitude - _route[i - 1].latitude);
      final lng = _route[i - 1].longitude + frac * (_route[i].longitude - _route[i - 1].longitude);
      final bearing = _distance.bearing(_route[i - 1], _route[i]);
      return (LatLng(lat, lng), bearing);
    }
    remaining -= segLen;
  }
  return (_route.first, 0.0);
}

void main() {
  test('Detailed Root Cause Analysis & Burst Evolution', () {
    final totalRouteDist = _routeLengthMeters();

    // 1. Rejection burst evolution in Scenario 61
    print('### REJECTION BURST EVOLUTION (SCENARIO 61: 30 km/h, dt=2.0s, Heading Dropout)');
    final rand61 = math.Random(101);
    final ekfC = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
    final ekfB1 = HistoricalPhase3Ekf();
    const smoother = GpsSmoothingService();
    LatLng? prevAccA, prevSmA, lastRtA, lastOutA;

    double dist = 0.0;
    print('| Step | Time (s) | Event / Motion Context | Truth Bearing | Raw Measurement | Pred Pos (C) | Truth Pos | Innovation (m) | NIS | Decision | P11 (m²) | Error A (m) | Error B1 (m) | Error C (m) |');
    print('|:---:|:---:|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|');

    for (int s = 0; s <= 20; s++) {
      dist += 8.33 * 2.0;
      final (truthPos, truthBearing) = _interpolateRoute(dist, totalRouteDist);
      final u1 = rand61.nextDouble().clamp(1e-7, 1.0);
      final u2 = rand61.nextDouble();
      final radiusNoise = 5.0 * math.sqrt(-2.0 * math.log(u1));
      final angleNoise = 2.0 * math.pi * u2;
      final eastNoise = radiusNoise * math.sin(angleNoise);
      final northNoise = radiusNoise * math.cos(angleNoise);
      final rawPos = _distance.offset(_distance.offset(truthPos, eastNoise, 90.0), northNoise, 0.0);
      final acc = (7.0 + (rand61.nextDouble() - 0.5) * 3.0).clamp(2.0, 30.0);

      // Baseline A
      if (acc <= 40.0) {
        final up = smoother.smoothAcceptedPoint(
          activityType: 'cycling',
          acceptedPoint: rawPos,
          previousAcceptedPoint: prevAccA,
          previousSmoothedPoint: prevSmA,
          lastSmoothedRoutePoint: lastRtA,
          accuracyMeters: acc,
          speedMs: 8.33,
          timeDeltaSec: 2.0,
          gpsGapDurationSec: 0.0,
        );
        lastOutA = up.smoothedPoint;
        prevAccA = rawPos;
        prevSmA = up.smoothedPoint;
        if (up.shouldAppendRoutePoint) lastRtA = up.smoothedPoint;
      }
      final errA = _distance.distance(lastOutA ?? truthPos, truthPos);

      // B1
      EkfEstimate estB1;
      if (s == 0) {
        ekfB1.init(initialPoint: rawPos, initialSpeedMs: 8.33, initialHeadingDeg: null);
        estB1 = EkfEstimate(position: rawPos, speedMs: 8.33, headingDeg: 0, positionVariance: 1.0, diagnostics: const EkfUpdateDiagnostics());
      } else {
        estB1 = ekfB1.update(measurementPoint: rawPos, accuracyMeters: acc, timeDeltaSec: 2.0, speedMs: 8.33, headingDeg: null);
      }
      final errB1 = _distance.distance(estB1.position, truthPos);

      // C
      EkfEstimate estC;
      if (s == 0) {
        ekfC.init(initialPoint: rawPos, initialSpeedMs: 8.33, initialHeadingDeg: null);
        estC = EkfEstimate(position: rawPos, speedMs: 8.33, headingDeg: 0, positionVariance: 1.0, diagnostics: const EkfUpdateDiagnostics());
      } else {
        estC = ekfC.update(measurementPoint: rawPos, accuracyMeters: acc, timeDeltaSec: 2.0, speedMs: 8.33, headingDeg: null);
      }
      final errC = _distance.distance(estC.position, truthPos);

      String event = 'Straight tracking';
      if (s == 3) event = 'Enter 105° turn';
      if (s == 4) event = 'Sharp reverse corner (-175°)';
      if (s == 5) event = 'Turn to +24° (160° turn!)';
      if (s == 6) event = '💥 First NIS rejection (Gate lock)';
      if (s == 7) event = 'Diverging dead-reckon (South)';
      if (s == 10) event = 'Vehicle turning East, EKF goes South';
      if (s == 20) event = 'Divergence: 259m error';

      final inov = estC.diagnostics.positionInnovationMeters?.toStringAsFixed(1) ?? '0.0';
      final nis = estC.diagnostics.positionNis?.toStringAsFixed(1) ?? '0.0';
      final dec = estC.diagnostics.positionDecision.name;
      final p11 = ekfC.covariance[0][0].toStringAsFixed(1);

      print('| $s | ${s * 2.0}s | $event | ${truthBearing.toStringAsFixed(1)}° | ${rawPos.latitude.toStringAsFixed(6)},${rawPos.longitude.toStringAsFixed(6)} | ${estC.position.latitude.toStringAsFixed(6)},${estC.position.longitude.toStringAsFixed(6)} | ${truthPos.latitude.toStringAsFixed(6)},${truthPos.longitude.toStringAsFixed(6)} | ${inov}m | $nis | $dec | ${p11}m² | ${errA.toStringAsFixed(1)}m | ${errB1.toStringAsFixed(1)}m | **${errC.toStringAsFixed(1)}m** |');
    }

    // 2. Audit Distance Error Median vs Macro-Mean
    print('\n### DISTANCE ERROR RECONCILIATION: WHY MEDIAN ABSOLUTE ERROR REGRESSED (+15.8%) WHILE MACRO-MEAN IMPROVED (-3.2%)');
    // We already have the 108 scenario report, let's analyze how many scenarios had lower vs higher error
    final reportFile = File('/tmp/aetron_phase4a_benchmark_report.json');
    if (reportFile.existsSync()) {
      final jsonMap = jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
      final scenarios = jsonMap['scenarios'] as List<dynamic>;

      int cBetter = 0;
      int b1Better = 0;
      int ties = 0;
      final diffs = <double>[];

      for (final sc in scenarios) {
        final errs = sc['distance_errors_abs_percent'] as Map<String, dynamic>;
        final eb1 = (errs['config_b1'] as num).toDouble();
        final ec = (errs['config_c'] as num).toDouble();
        final diff = ec - eb1;
        diffs.add(diff);
        if (diff < -0.01) {
          cBetter++;
        } else if (diff > 0.01) {
          b1Better++;
        } else {
          ties++;
        }
      }
      diffs.sort();
      final medianDiff = diffs[diffs.length ~/ 2];
      print('Scenario-by-scenario distance error comparison (Config C vs Config B1):');
      print('  Config C has LOWER absolute distance error: $cBetter / 108 scenarios');
      print('  Config B1 has LOWER absolute distance error: $b1Better / 108 scenarios');
      print('  Ties (within 0.01%): $ties / 108 scenarios');
      print('  Median diff (ec - eb1): ${medianDiff.toStringAsFixed(2)}%');
    }
  });
}
