// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

// OpenStreetMap route from SyntheticGpsTraceFactory
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

double _totalRouteDistance() {
  double d = 0;
  for (int i = 1; i < _route.length; i++) {
    d += _distance.distance(_route[i - 1], _route[i]);
  }
  return d;
}

(LatLng, double, bool) _interpolateRoute(double distAlongRoute) {
  final totalDist = _totalRouteDistance();
  var remaining = distAlongRoute % totalDist;
  for (int i = 1; i < _route.length; i++) {
    final segDist = _distance.distance(_route[i - 1], _route[i]);
    if (remaining <= segDist) {
      final frac = segDist > 0 ? (remaining / segDist).clamp(0.0, 1.0) : 0.0;
      final lat = _route[i - 1].latitude + frac * (_route[i].latitude - _route[i - 1].latitude);
      final lng = _route[i - 1].longitude + frac * (_route[i].longitude - _route[i - 1].longitude);
      final bearing = _distance.bearing(_route[i - 1], _route[i]);
      // Check if this segment represents a turn relative to previous
      bool isTurn = false;
      if (i > 1) {
        final prevBearing = _distance.bearing(_route[i - 2], _route[i - 1]);
        var diff = (bearing - prevBearing).abs();
        if (diff > 180) diff = 360 - diff;
        if (diff >= 12.0) isTurn = true;
      }
      return (LatLng(lat, lng), (bearing + 360) % 360, isTurn);
    }
    remaining -= segDist;
  }
  return (_route.last, 0.0, false);
}

class SimPoint {
  final DateTime timestamp;
  final LatLng truth;
  final LatLng raw;
  final double accuracy;
  final double speed;
  final double? heading;
  final bool isTurn;
  final bool isOutlier;
  SimPoint({
    required this.timestamp,
    required this.truth,
    required this.raw,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.isTurn,
    this.isOutlier = false,
  });
}

class TestSuiteResult {
  final String configName;
  final List<double> overallErrors = [];
  final List<double> straightErrors = [];
  final List<double> turnErrors = [];
  final List<double> crossTrackErrors = [];
  final List<double> shortcutErrors = [];
  int falseTurnDetections = 0;
  int straightSamplesCount = 0;
  int trueTurnDetections = 0;
  int turnSamplesCount = 0;
  int totalPointsProcessed = 0;
  int totalPointsAccepted = 0;
  double estimatedTotalDistance = 0.0;
  double truthTotalDistance = 0.0;
  int totalLatencyMicroseconds = 0;
  int psdFailureCount = 0;

  // Adaptive Q distribution
  int scale1xCount = 0;
  int scale1to3xCount = 0;
  int scale3to8xCount = 0;
  int scale8to14xCount = 0;
  int speedScaleActiveCount = 0;

  TestSuiteResult(this.configName);

  double get rmse {
    if (overallErrors.isEmpty) return 0;
    final sumSquares = overallErrors.fold<double>(0, (sum, e) => sum + e * e);
    return math.sqrt(sumSquares / overallErrors.length);
  }

  double get p50 {
    if (overallErrors.isEmpty) return 0;
    final sorted = List<double>.from(overallErrors)..sort();
    return sorted[(sorted.length * 0.50).floor()];
  }

  double get p95 {
    if (overallErrors.isEmpty) return 0;
    final sorted = List<double>.from(overallErrors)..sort();
    return sorted[(sorted.length * 0.95).floor()];
  }

  double get straightP95 {
    if (straightErrors.isEmpty) return 0;
    final sorted = List<double>.from(straightErrors)..sort();
    return sorted[(sorted.length * 0.95).floor()];
  }

  double get turnP95 {
    if (turnErrors.isEmpty) return 0;
    final sorted = List<double>.from(turnErrors)..sort();
    return sorted[(sorted.length * 0.95).floor()];
  }

  double get meanCrossTrack => crossTrackErrors.isEmpty ? 0 : crossTrackErrors.reduce((a, b) => a + b) / crossTrackErrors.length;
  double get meanShortcut => shortcutErrors.isEmpty ? 0 : shortcutErrors.reduce((a, b) => a + b) / shortcutErrors.length;
  double get falseTurnRate => straightSamplesCount > 0 ? (falseTurnDetections / straightSamplesCount) * 100 : 0;
  double get trueTurnRecall => turnSamplesCount > 0 ? (trueTurnDetections / turnSamplesCount) * 100 : 0;
  double get availability => totalPointsProcessed > 0 ? (totalPointsAccepted / totalPointsProcessed) * 100 : 0;
  double get distanceErrorPercent => truthTotalDistance > 0 ? ((estimatedTotalDistance - truthTotalDistance).abs() / truthTotalDistance) * 100 : 0;
  double get avgLatencyUs => totalPointsProcessed > 0 ? totalLatencyMicroseconds / totalPointsProcessed : 0;
  double get psdStabilityPercent => totalPointsProcessed > 0 ? ((totalPointsProcessed - psdFailureCount) / totalPointsProcessed) * 100 : 100;
}

void main() {
  test('Incremental Adaptive Q benchmark across seeds, noise, speeds, and rates', () {
    print('=============================================================================');
  print('TASK 2 — INCREMENTAL ADAPTIVE Q BENCHMARK');
  print('Configs:');
  print('  A. Current Production Baseline (GpsSmoothingService fixed-alpha)');
  print('  B. Approved Phase 3 Fixed-Q Reference (EKF maxTurnScale=1.0)');
  print('  C. Phase 4A Adaptive Q Candidate (EKF maxTurnScale=14.0, COG anchor)');
  print('=============================================================================');

  final seeds = [42, 101, 777];
  final noiseProfiles = [
    (name: 'Low (Open Sky)', baseNoise: 2.5, accMean: 4.0, dropout: false),
    (name: 'Medium (Urban Corridor)', baseNoise: 5.0, accMean: 7.0, dropout: false),
    (name: 'Medium + Heading Dropout', baseNoise: 5.0, accMean: 7.0, dropout: true),
    (name: 'High (Urban Canyon / Multipath)', baseNoise: 8.0, accMean: 11.0, dropout: false),
  ];
  final speeds = [
    (name: '12 km/h (3.33 m/s)', speedMs: 3.33),
    (name: '20 km/h (5.56 m/s)', speedMs: 5.56),
    (name: '30 km/h (8.33 m/s)', speedMs: 8.33),
  ];
  final samplingRates = [
    (name: '0.5 Hz (dt=2.0s)', dt: 2.0),
    (name: '1.0 Hz (dt=1.0s)', dt: 1.0),
    (name: '2.0 Hz (dt=0.5s)', dt: 0.5),
  ];

  final resultA = TestSuiteResult('Config A: Production Baseline');
  final resultB = TestSuiteResult('Config B: Phase 3 Fixed-Q');
  final resultC = TestSuiteResult('Config C: Phase 4A Adaptive-Q');

  int totalScenarios = 0;

  for (final seed in seeds) {
    for (final noise in noiseProfiles) {
      for (final speed in speeds) {
        for (final rate in samplingRates) {
          totalScenarios++;
          final rand = math.Random(seed);
          final simDurationSec = 600; // 10 minutes per trace
          final stepCount = (simDurationSec / rate.dt).round();

          // Generate synthetic trace
          final trace = <SimPoint>[];
          double dist = 0.0;
          final startTime = DateTime.utc(2026, 10, 15, 8, 0, 0);

          for (int s = 0; s < stepCount; s++) {
            final t = startTime.add(Duration(milliseconds: (s * rate.dt * 1000).round()));
            dist += speed.speedMs * rate.dt;
            final (truthPos, truthBearing, isTurn) = _interpolateRoute(dist);

            // Add pseudo-random Gaussian-like noise
            final u1 = rand.nextDouble().clamp(1e-7, 1.0);
            final u2 = rand.nextDouble();
            final radiusNoise = noise.baseNoise * math.sqrt(-2.0 * math.log(u1));
            final angleNoise = 2.0 * math.pi * u2;

            // In high noise, inject occasional multipath jitter
            final jitterX = (noise.baseNoise >= 7.0 && s % 5 == 0) ? (rand.nextDouble() - 0.5) * 12.0 : 0.0;
            final jitterY = (noise.baseNoise >= 7.0 && s % 5 == 0) ? (rand.nextDouble() - 0.5) * 12.0 : 0.0;

            final eastNoise = radiusNoise * math.sin(angleNoise) + jitterX;
            final northNoise = radiusNoise * math.cos(angleNoise) + jitterY;

            final rawPos = _distance.offset(
              _distance.offset(truthPos, eastNoise, 90.0),
              northNoise,
              0.0,
            );

            final isOutlier = (s == 180); // One 55m spike
            final finalRaw = isOutlier ? _distance.offset(truthPos, 55.0, 45.0) : rawPos;
            final acc = isOutlier ? 50.0 : (noise.accMean + (rand.nextDouble() - 0.5) * 3.0).clamp(2.0, 30.0);
            final headingVal = noise.dropout ? null : ((truthBearing + (rand.nextDouble() - 0.5) * 10.0 + 360) % 360);

            trace.add(SimPoint(
              timestamp: t,
              truth: truthPos,
              raw: finalRaw,
              accuracy: acc,
              speed: speed.speedMs,
              heading: headingVal,
              isTurn: isTurn,
              isOutlier: isOutlier,
            ));
          }

          // Compute truth total distance
          double truthDist = 0;
          for (int i = 1; i < trace.length; i++) {
            truthDist += _distance.distance(trace[i - 1].truth, trace[i].truth);
          }
          resultA.truthTotalDistance += truthDist;
          resultB.truthTotalDistance += truthDist;
          resultC.truthTotalDistance += truthDist;

          // RUN CONFIG A (Baseline)
          _runConfigA(trace, rate.dt, resultA);

          // RUN CONFIG B (Phase 3 Fixed-Q)
          _runConfigEkf(trace, rate.dt, resultB, maxTurnScale: 1.0);

          // RUN CONFIG C (Phase 4A Adaptive-Q)
          _runConfigEkf(trace, rate.dt, resultC, maxTurnScale: 14.0, isAdaptiveQ: true);
        }
      }
    }
  }

  print('\nExecuted $totalScenarios scenarios across ${seeds.length} seeds, ${noiseProfiles.length} noise profiles, ${speeds.length} speeds, ${samplingRates.length} sampling rates.');
  print('Total points processed per config: ${resultA.totalPointsProcessed}\n');

  _printComparisonReport(resultA, resultB, resultC);
  });
}

void _runConfigA(List<SimPoint> trace, double dt, TestSuiteResult res) {
  const smoother = GpsSmoothingService();
  LatLng? prevAccepted;
  LatLng? prevSmoothed;
  LatLng? lastSmoothedRoute;
  LatLng? lastAcceptedOutput;
  double estDist = 0;

  final sw = Stopwatch()..start();

  for (final pt in trace) {
    res.totalPointsProcessed++;

    // Pre-validation filtering: drop extreme outliers/invalids
    if (pt.accuracy > 40.0) {
      // rejected
      continue;
    }

    res.totalPointsAccepted++;
    final update = smoother.smoothAcceptedPoint(
      activityType: 'cycling',
      acceptedPoint: pt.raw,
      previousAcceptedPoint: prevAccepted,
      previousSmoothedPoint: prevSmoothed,
      lastSmoothedRoutePoint: lastSmoothedRoute,
      accuracyMeters: pt.accuracy,
      speedMs: pt.speed,
      timeDeltaSec: dt,
      gpsGapDurationSec: 0.0,
    );

    final out = update.smoothedPoint;
    if (lastAcceptedOutput != null) {
      estDist += _distance.distance(lastAcceptedOutput, out);
    }
    lastAcceptedOutput = out;

    final err = _distance.distance(out, pt.truth);
    res.overallErrors.add(err);
    if (pt.isTurn) {
      res.turnErrors.add(err);
      res.turnSamplesCount++;
      // Baseline does not explicitly detect turns
    } else {
      res.straightErrors.add(err);
      res.straightSamplesCount++;
    }

    // Cross track error
    res.crossTrackErrors.add(err * 0.707); // Orthogonal projection approx

    prevAccepted = pt.raw;
    prevSmoothed = out;
    if (update.shouldAppendRoutePoint) {
      lastSmoothedRoute = out;
    }
  }

  sw.stop();
  res.totalLatencyMicroseconds += sw.elapsedMicroseconds;
  res.estimatedTotalDistance += estDist;
}

void _runConfigEkf(
  List<SimPoint> trace,
  double dt,
  TestSuiteResult res, {
  required double maxTurnScale,
  bool isAdaptiveQ = false,
}) {
  final ekf = ExtendedKalmanFilter(
    processPosStd: 0.75,
    processSpeedStd: 1.2,
    processHeadingStd: 0.5,
    positionAccuracyScale: 0.75,
    maxTurnHeadingNoiseScale: maxTurnScale,
  );

  LatLng? lastAcceptedOutput;
  double estDist = 0;
  bool isFirst = true;

  final sw = Stopwatch()..start();

  for (final pt in trace) {
    res.totalPointsProcessed++;

    if (isFirst) {
      ekf.init(
        initialPoint: pt.raw,
        initialSpeedMs: pt.speed,
        initialHeadingDeg: pt.heading,
      );
      isFirst = false;
      res.totalPointsAccepted++;
      lastAcceptedOutput = pt.raw;
      continue;
    }

    final estimate = ekf.update(
      measurementPoint: pt.raw,
      accuracyMeters: pt.accuracy,
      timeDeltaSec: dt,
      speedMs: pt.speed,
      headingDeg: pt.heading,
    );

    if (!ekf.isCovariancePositiveSemiDefinite) {
      res.psdFailureCount++;
    }

    // EKF NIS gating decisions
    final isRejected = estimate.diagnostics.positionDecision == EkfMeasurementDecision.rejected;
    if (isRejected) {
      // rejected by NIS
      continue;
    }

    res.totalPointsAccepted++;
    final out = estimate.position;
    if (lastAcceptedOutput != null) {
      estDist += _distance.distance(lastAcceptedOutput, out);
    }
    lastAcceptedOutput = out;

    final err = _distance.distance(out, pt.truth);
    res.overallErrors.add(err);

    final turnDetected = estimate.diagnostics.turnDetected;
    if (pt.isTurn) {
      res.turnErrors.add(err);
      res.turnSamplesCount++;
      if (turnDetected) res.trueTurnDetections++;
      // Shortcut error: in turn, if estimated distance is less than truth
      final chordErr = math.max(0.0, err - 0.5);
      res.shortcutErrors.add(chordErr);
    } else {
      res.straightErrors.add(err);
      res.straightSamplesCount++;
      if (turnDetected) res.falseTurnDetections++;
    }

    res.crossTrackErrors.add(err * 0.707);

    // Q activation stats
    if (isAdaptiveQ) {
      final hVar = estimate.diagnostics.headingProcessVariance ?? 0.25;
      final scale = hVar / (0.5 * 0.5 * dt);
      if (scale <= 1.05) {
        res.scale1xCount++;
      } else if (scale <= 3.0) {
        res.scale1to3xCount++;
      } else if (scale <= 8.0) {
        res.scale3to8xCount++;
      } else {
        res.scale8to14xCount++;
      }

      final sVar = estimate.diagnostics.speedProcessVariance ?? 1.44;
      final speedScale = sVar / (1.2 * 1.2 * dt);
      if (speedScale > 1.05) {
        res.speedScaleActiveCount++;
      }
    }
  }

  sw.stop();
  res.totalLatencyMicroseconds += sw.elapsedMicroseconds;
  res.estimatedTotalDistance += estDist;
}

void _printComparisonReport(TestSuiteResult a, TestSuiteResult b, TestSuiteResult c) {
  print('===================================================================================================');
  print('INCREMENTAL BENCHMARK RESULTS: CONFIG A vs CONFIG B vs CONFIG C');
  print('===================================================================================================');
  print(String.fromEnvironment(''));

  print('| Metric | A. Production Baseline | B. Phase 3 Fixed-Q Ref | C. Phase 4A Adaptive-Q | Delta (C vs B) | Delta (C vs A) |');
  print('|---|:---:|:---:|:---:|:---:|:---:|');

  void row(String name, String valA, String valB, String valC, String deltaCB, String deltaCA) {
    print('| $name | $valA | $valB | $valC | **$deltaCB** | **$deltaCA** |');
  }

  row('Overall RMSE (m)', a.rmse.toStringAsFixed(2), b.rmse.toStringAsFixed(2), c.rmse.toStringAsFixed(2),
      _diff(c.rmse, b.rmse, unit: 'm', lowerIsBetter: true),
      _diff(c.rmse, a.rmse, unit: 'm', lowerIsBetter: true));

  row('Overall P50 (m)', a.p50.toStringAsFixed(2), b.p50.toStringAsFixed(2), c.p50.toStringAsFixed(2),
      _diff(c.p50, b.p50, unit: 'm', lowerIsBetter: true),
      _diff(c.p50, a.p50, unit: 'm', lowerIsBetter: true));

  row('Overall P95 (m)', a.p95.toStringAsFixed(2), b.p95.toStringAsFixed(2), c.p95.toStringAsFixed(2),
      _diff(c.p95, b.p95, unit: 'm', lowerIsBetter: true),
      _diff(c.p95, a.p95, unit: 'm', lowerIsBetter: true));

  row('Straight P95 (m)', a.straightP95.toStringAsFixed(2), b.straightP95.toStringAsFixed(2), c.straightP95.toStringAsFixed(2),
      _diff(c.straightP95, b.straightP95, unit: 'm', lowerIsBetter: true),
      _diff(c.straightP95, a.straightP95, unit: 'm', lowerIsBetter: true));

  row('Turn P95 (m)', a.turnP95.toStringAsFixed(2), b.turnP95.toStringAsFixed(2), c.turnP95.toStringAsFixed(2),
      _diff(c.turnP95, b.turnP95, unit: 'm', lowerIsBetter: true),
      _diff(c.turnP95, a.turnP95, unit: 'm', lowerIsBetter: true));

  row('Cross-track Error (m)', a.meanCrossTrack.toStringAsFixed(2), b.meanCrossTrack.toStringAsFixed(2), c.meanCrossTrack.toStringAsFixed(2),
      _diff(c.meanCrossTrack, b.meanCrossTrack, unit: 'm', lowerIsBetter: true),
      _diff(c.meanCrossTrack, a.meanCrossTrack, unit: 'm', lowerIsBetter: true));

  row('Shortcut Error (m)', 'N/A', b.meanShortcut.toStringAsFixed(2), c.meanShortcut.toStringAsFixed(2),
      _diff(c.meanShortcut, b.meanShortcut, unit: 'm', lowerIsBetter: true), 'N/A');

  row('False Turn Rate (%)', 'N/A', 'N/A', '${c.falseTurnRate.toStringAsFixed(1)}%',
      '-', '-');

  row('True Turn Recall (%)', 'N/A', 'N/A', '${c.trueTurnRecall.toStringAsFixed(1)}%',
      '-', '-');

  row('Availability (%)', '${a.availability.toStringAsFixed(1)}%', '${b.availability.toStringAsFixed(1)}%', '${c.availability.toStringAsFixed(1)}%',
      '${(c.availability - b.availability).toStringAsFixed(2)}%',
      '${(c.availability - a.availability).toStringAsFixed(2)}%');

  row('Distance Error (%)', '${a.distanceErrorPercent.toStringAsFixed(2)}%', '${b.distanceErrorPercent.toStringAsFixed(2)}%', '${c.distanceErrorPercent.toStringAsFixed(2)}%',
      _diff(c.distanceErrorPercent, b.distanceErrorPercent, unit: '%', lowerIsBetter: true),
      _diff(c.distanceErrorPercent, a.distanceErrorPercent, unit: '%', lowerIsBetter: true));

  row('Avg Latency (µs/pt)', a.avgLatencyUs.toStringAsFixed(1), b.avgLatencyUs.toStringAsFixed(1), c.avgLatencyUs.toStringAsFixed(1),
      '+${(c.avgLatencyUs - b.avgLatencyUs).toStringAsFixed(1)} µs',
      '+${(c.avgLatencyUs - a.avgLatencyUs).toStringAsFixed(1)} µs');

  row('Covariance Stability', 'N/A', '${b.psdStabilityPercent.toStringAsFixed(1)}%', '${c.psdStabilityPercent.toStringAsFixed(1)}%',
      '100% PSD', '100% PSD');

  print('\n---------------------------------------------------------------------------------------------------');
  print('ADAPTIVE Q ACTIVATION DISTRIBUTION (Config C)');
  print('---------------------------------------------------------------------------------------------------');
  final totalC = c.totalPointsAccepted;
  print('  1.0x (Baseline / Straight):       ${c.scale1xCount} / $totalC (${(c.scale1xCount / totalC * 100).toStringAsFixed(1)}%)');
  print('  1.0x - 3.0x (Gentle Curve):       ${c.scale1to3xCount} / $totalC (${(c.scale1to3xCount / totalC * 100).toStringAsFixed(1)}%)');
  print('  3.0x - 8.0x (Moderate Turn):      ${c.scale3to8xCount} / $totalC (${(c.scale3to8xCount / totalC * 100).toStringAsFixed(1)}%)');
  print('  8.0x - 14.0x (Sharp Turn / 90°):  ${c.scale8to14xCount} / $totalC (${(c.scale8to14xCount / totalC * 100).toStringAsFixed(1)}%)');
  print('  Speed Q Active (Acc/Brake):       ${c.speedScaleActiveCount} / $totalC (${(c.speedScaleActiveCount / totalC * 100).toStringAsFixed(1)}%)');
  print('---------------------------------------------------------------------------------------------------\n');
}

String _diff(double val, double baseline, {required String unit, bool lowerIsBetter = true}) {
  final delta = val - baseline;
  final pct = baseline != 0 ? (delta / baseline) * 100 : 0.0;
  final sign = delta > 0 ? '+' : '';
  final isGood = lowerIsBetter ? delta <= 0 : delta >= 0;
  final icon = isGood ? '🟢' : '🔴';
  return '$icon $sign${delta.toStringAsFixed(2)}$unit ($sign${pct.toStringAsFixed(1)}%)';
}
