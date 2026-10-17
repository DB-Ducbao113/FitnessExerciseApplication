// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:latlong2/latlong.dart';

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
  group('Task A: Root Cause Isolation Regression Assertions', () {
    final totalRouteDist = _routeLengthMeters();

    test('Scenario 61: Reproduces sustained NIS rejection lockout and characterizes tracking failure', () {
      final rand61 = math.Random(101); // seed for Scenario 61
      final ekfC = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
      const smoother = GpsSmoothingService();
      LatLng? prevAccA, prevSmA, lastRtA, lastOutA;

      const speedMs = 8.33; // 30 km/h
      const dt = 2.0; // 0.5 Hz
      const totalSteps = 300; // 600s

      int? firstRejectionStep;
      double? firstRejectionNis;
      int currentConsecutiveRejections = 0;
      int longestRejectionBurst = 0;
      int totalRejections = 0;

      double maxErrorC = 0.0;
      double finalErrorC = 0.0;
      double maxErrorA = 0.0;

      double dist = 0.0;
      for (int s = 0; s < totalSteps; s++) {
        dist += speedMs * dt;
        final (truthPos, truthBearing) = _interpolateRoute(dist, totalRouteDist);
        final u1 = rand61.nextDouble().clamp(1e-7, 1.0);
        final u2 = rand61.nextDouble();
        final radiusNoise = 5.0 * math.sqrt(-2.0 * math.log(u1));
        final angleNoise = 2.0 * math.pi * u2;
        final eastNoise = radiusNoise * math.sin(angleNoise);
        final northNoise = radiusNoise * math.cos(angleNoise);
        final rawPos = _distance.offset(_distance.offset(truthPos, eastNoise, 90.0), northNoise, 0.0);
        final acc = (7.0 + (rand61.nextDouble() - 0.5) * 3.0).clamp(2.0, 30.0);

        // Heading dropout: no compass heading available
        final double? headingVal = null;

        // Baseline A (exponential smoother)
        if (acc <= 40.0) {
          final up = smoother.smoothAcceptedPoint(
            activityType: 'cycling',
            acceptedPoint: rawPos,
            previousAcceptedPoint: prevAccA,
            previousSmoothedPoint: prevSmA,
            lastSmoothedRoutePoint: lastRtA,
            accuracyMeters: acc,
            speedMs: speedMs,
            timeDeltaSec: dt,
            gpsGapDurationSec: 0.0,
          );
          lastOutA = up.smoothedPoint;
          prevAccA = rawPos;
          prevSmA = up.smoothedPoint;
          if (up.shouldAppendRoutePoint) lastRtA = up.smoothedPoint;
        }
        final errA = _distance.distance(lastOutA ?? truthPos, truthPos);
        if (errA > maxErrorA) maxErrorA = errA;

        // EKF Candidate C
        EkfEstimate estC;
        if (s == 0) {
          ekfC.init(initialPoint: rawPos, initialSpeedMs: speedMs, initialHeadingDeg: headingVal);
          estC = EkfEstimate(
            position: rawPos,
            speedMs: speedMs,
            headingDeg: headingVal ?? 0,
            positionVariance: 1.0,
            diagnostics: const EkfUpdateDiagnostics(),
          );
        } else {
          estC = ekfC.update(
            measurementPoint: rawPos,
            accuracyMeters: acc,
            timeDeltaSec: dt,
            speedMs: speedMs,
            headingDeg: headingVal,
          );
        }

        final isRejected = s > 0 && estC.diagnostics.positionDecision == EkfMeasurementDecision.rejected;
        if (isRejected) {
          totalRejections++;
          currentConsecutiveRejections++;
          if (firstRejectionStep == null) {
            firstRejectionStep = s;
            firstRejectionNis = estC.diagnostics.positionNis;
          }
          if (currentConsecutiveRejections > longestRejectionBurst) {
            longestRejectionBurst = currentConsecutiveRejections;
          }
        } else {
          currentConsecutiveRejections = 0;
        }

        final errC = _distance.distance(estC.position, truthPos);
        if (errC > maxErrorC) maxErrorC = errC;
        if (s == totalSteps - 1) finalErrorC = errC;

        // Covariance stability assertion at every step
        expect(ekfC.covariance[0][0].isFinite, isTrue, reason: 'Covariance element [0][0] must remain finite at step $s');
        expect(ekfC.isCovariancePositiveSemiDefinite, isTrue, reason: 'Covariance must remain positive semi-definite at step $s');
      }

      print('Scenario 61 Characterization Results:');
      print('  First rejection step: $firstRejectionStep (at t = ${(firstRejectionStep! * dt).toStringAsFixed(1)}s, NIS = ${firstRejectionNis?.toStringAsFixed(1)})');
      print('  Longest rejection burst: $longestRejectionBurst consecutive steps (${(longestRejectionBurst * dt).toStringAsFixed(1)}s)');
      print('  Total rejections: $totalRejections / $totalSteps (${(totalRejections / totalSteps * 100).toStringAsFixed(1)}%)');
      print('  Max Positional Error: Config C = ${maxErrorC.toStringAsFixed(1)}m | Baseline A = ${maxErrorA.toStringAsFixed(1)}m');
      print('  Final Positional Error: Config C = ${finalErrorC.toStringAsFixed(1)}m');

      // Regression Assertions proving the failure mechanism:
      // 1. The first rejection occurs at step 6 due to 160° turn exceeding NIS reject threshold (13.816)
      expect(firstRejectionStep, equals(6));
      expect(firstRejectionNis, greaterThanOrEqualTo(13.816));

      // 2. Sustained rejection lockout engages: once rejected, the filter fails to recover,
      // rejecting 294 consecutive steps (588 seconds of dead reckoning)
      expect(longestRejectionBurst, equals(294));
      expect(totalRejections, equals(294));

      // 3. Expected tracking failure is explicitly characterized:
      // In the absence of Phase 5 re-anchoring, open-loop dead-reckoning across 4 laps diverges to > 4,800m
      expect(maxErrorC, greaterThan(4800.0));
      expect(finalErrorC, greaterThan(4800.0));

      // 4. Baseline A (no NIS gate) tracks the vehicle with max error < 25m
      expect(maxErrorA, lessThan(25.0));
    });

    test('Mandatory benchmark artifact validation (no silent skip)', () {
      File reportFile = File('test/fixtures/phase4a_benchmark_report.json');
      if (!reportFile.existsSync()) {
        reportFile = File('/tmp/aetron_phase4a_benchmark_report.json');
      }

      // Mandatory assertion: fixture must exist, no silent fallback
      expect(
        reportFile.existsSync(),
        isTrue,
        reason: 'Mandatory benchmark artifact must exist at test/fixtures/phase4a_benchmark_report.json or /tmp/aetron_phase4a_benchmark_report.json',
      );

      final content = reportFile.readAsStringSync();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;

      expect(jsonMap['benchmark_label'], equals('phase4a_final_benchmark_correctness_remediation'));
      expect(jsonMap['config_fingerprint'], equals('fnv1a32-12b93cef'));
      expect(jsonMap['total_scenarios'], equals(108));
      expect(jsonMap['total_scheduled_points_per_variant'], equals(75600));

      final scenarios = jsonMap['scenarios'] as List<dynamic>;
      expect(scenarios.length, equals(108));

      // Assert that Global Output SHA-256 checksums match across all 75,600 coordinates
      final globalHashes = jsonMap['global_output_sha256'] as Map<String, dynamic>;
      expect(globalHashes['config_a'], equals('069db86716721d2187217acc0e7352be6aed476358f419f7d05ca13333224b18'));
      expect(globalHashes['config_b1'], equals('e8aaa8d27692ef75276fe3fc8ae8f50a0b58a14438bfeecc0724682a28218261'));
      expect(globalHashes['config_b2'], equals('cdfd7139f937797363f3f36f469379445beba282e46831856411f8a10e9670ed'));
      expect(globalHashes['config_c'], equals('62e51c8863238d7798924c07e9ab481a9b97b9583eefbd868eff07436808c517'));

      // Validate that sustained rejection bursts occur exclusively in heading dropout scenarios
      int dropoutScenariosWithBurst = 0;
      int nonDropoutScenariosWithBurst = 0;
      int maxNonDropoutRejections = 0;

      for (final sc in scenarios) {
        final noise = sc['noise_profile'] as String;
        final counts = sc['counts']['config_c'] as Map<String, dynamic>;
        final rejected = counts['rejected'] as int;

        if (noise.contains('Dropout')) {
          if (rejected > 100) dropoutScenariosWithBurst++;
        } else {
          if (rejected > 100) nonDropoutScenariosWithBurst++;
          if (rejected > maxNonDropoutRejections) {
            maxNonDropoutRejections = rejected;
          }
        }
      }

      print('Artifact Audit: Dropout scenarios with severe rejection burst (>100 rejections): $dropoutScenariosWithBurst / 27');
      print('Artifact Audit: Non-dropout scenarios with severe rejection burst (>100 rejections): $nonDropoutScenariosWithBurst / 81');
      print('Artifact Audit: Max rejections across all 81 non-dropout scenarios: $maxNonDropoutRejections');

      // 100% of non-dropout scenarios maintain normal gating (max rejections <= 16 across 600-1200 points)
      expect(nonDropoutScenariosWithBurst, equals(0));
      expect(maxNonDropoutRejections, lessThanOrEqualTo(20));
      expect(dropoutScenariosWithBurst, greaterThan(10));
    });
  });
}
