// ignore_for_file: avoid_print
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/recovery_fsm_benchmark_adapter.dart';

const _distance = Distance();

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
  final baseTime = DateTime.utc(2026, 10, 17, 8, 0, 0);

  LatLng offsetMeters(LatLng origin, double dxMeters, double dyMeters) {
    const earthRadius = 6378137.0;
    final dLat = (dyMeters / earthRadius) * (180.0 / math.pi);
    final latCos = math.cos(origin.latitude * math.pi / 180.0);
    final dLng = (dxMeters / (earthRadius * latCos)) * (180.0 / math.pi);
    return LatLng(origin.latitude + dLat, origin.longitude + dLng);
  }

  group('Phase 5 Milestone 2A — Recovery Validation & Benchmark Stress Tests', () {
    test('1. Scenario 61 Severe Heading Dropout: Config C Diverges vs Config D Recovers (TC-01)', () {
      final totalRouteDist = _routeLengthMeters();
      final rand61 = math.Random(101); // exact seed for Scenario 61
      final ekfC = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
      final adapterD = RecoveryFsmBenchmarkAdapter(maxTurnHeadingNoiseScale: 14.0);

      const speedMs = 8.33; // 30 km/h
      const dt = 2.0; // 0.5 Hz
      const totalSteps = 300; // 600s

      double maxErrorC = 0.0;
      double finalErrorC = 0.0;
      double maxErrorD = 0.0;
      double finalErrorD = 0.0;
      final errorsD = <double>[];

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
        final time = baseTime.add(Duration(milliseconds: (s * dt * 1000).round()));

        // Heading dropout: no compass heading available
        const double? headingVal = null;

        // Config C (open-loop without recovery FSM)
        if (s == 0) {
          ekfC.init(initialPoint: rawPos, initialSpeedMs: speedMs, initialHeadingDeg: headingVal);
        }
        final estC = s == 0
            ? EkfEstimate(position: rawPos, speedMs: speedMs, headingDeg: headingVal ?? 0, positionVariance: 1.0, diagnostics: const EkfUpdateDiagnostics())
            : ekfC.update(measurementPoint: rawPos, accuracyMeters: acc, timeDeltaSec: dt, speedMs: speedMs, headingDeg: headingVal);
        final errC = _distance.distance(estC.position, truthPos);
        if (errC > maxErrorC) maxErrorC = errC;
        if (s == totalSteps - 1) finalErrorC = errC;

        // Config D (with isolated GPS Recovery FSM)
        final outD = adapterD.processMeasurement(
          rawPoint: rawPos,
          truthPoint: truthPos,
          accuracyMeters: acc,
          timeDeltaSec: dt,
          timestamp: time,
          speedMs: speedMs,
          headingDeg: headingVal,
          hasAuxiliarySensorsHint: false, // Heading is dropped!
        );
        final errD = outD.currentErrorMeters;
        errorsD.add(errD);
        if (errD > maxErrorD) maxErrorD = errD;
        if (s == totalSteps - 1) finalErrorD = errD;
      }

      // Compute all-scheduled RMSE for Config D on Scenario 61
      final sumSqD = errorsD.fold<double>(0.0, (sum, e) => sum + e * e);
      final rmseD = math.sqrt(sumSqD / errorsD.length);

      print('Scenario 61 Results:');
      print('  Config C: Max Error = ${maxErrorC.toStringAsFixed(1)}m | Final Error = ${finalErrorC.toStringAsFixed(1)}m');
      print('  Config D: Max Error = ${maxErrorD.toStringAsFixed(1)}m | Final Error = ${finalErrorD.toStringAsFixed(1)}m | RMSE = ${rmseD.toStringAsFixed(2)}m');
      print('  Config D: Re-anchors = ${adapterD.reAnchorEventCount} | Latencies = ${adapterD.recoveryLatenciesSec}');

      // 1. Config C diverges across 4 laps of open-loop dead-reckoning to > 4,800m
      expect(maxErrorC, greaterThan(4800.0),
          reason: 'Config C must demonstrate the latched rejection root cause');
      expect(finalErrorC, greaterThan(4800.0));

      // 2. Config D recovers gracefully:
      // Re-anchoring occurs upon loss-of-lock, bringing RMSE down to < 80m (vs > 2,000m on Config C)
      expect(rmseD, lessThan(80.0),
          reason: 'Config D all-scheduled RMSE must be < 80m on Scenario 61 (vs > 2,000m on Config C)');
      expect(finalErrorD, lessThanOrEqualTo(10.0),
          reason: 'Config D steady-state error after recovery must be <= 10m (TC-01 gate)');
      expect(adapterD.reAnchorEventCount, greaterThanOrEqualTo(1),
          reason: 'Re-anchor must have been executed to resolve lockout');
      expect(adapterD.totalReAnchorJumpMeters, greaterThan(0.0),
          reason: 'Euclidean jump occurred but was excluded from distance');
    });

    test('2. Coherent Multipath Cluster During Outage: Escrow Purged on Breakdown (TC-04)', () {
      final origin = LatLng(10.7769, 106.7009);
      final adapter = RecoveryFsmBenchmarkAdapter();

      // Init and establish baseline distance
      adapter.processMeasurement(
        rawPoint: origin,
        truthPoint: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensorsHint: true,
      );
      adapter.processMeasurement(
        rawPoint: offsetMeters(origin, 5.0, 0.0),
        truthPoint: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensorsHint: true,
      );

      // Force into S2 via 5 rejections
      for (var i = 1; i <= 5; i++) {
        adapter.processMeasurement(
          rawPoint: offsetMeters(origin, 5.0 + i * 5.0, 27.0),
          truthPoint: offsetMeters(origin, 5.0 + i * 5.0, 0.0),
          accuracyMeters: 1.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 1 + i)),
          speedMs: 5.0,
          headingDeg: 90.0,
        );
      }
      expect(adapter.state, GpsRecoveryState.s2LossOfLock);
      final distAtS2 = adapter.accumulatedDistanceMeters;

      // Inject coherent false multipath cluster offset 60m North, moving at 4 m/s East
      for (var k = 1; k <= 3; k++) {
        adapter.processMeasurement(
          rawPoint: offsetMeters(origin, 30.0 + k * 4.0, 60.0),
          truthPoint: offsetMeters(origin, 30.0 + k * 4.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 10 + k)),
          speedMs: 4.0,
          hasAuxiliarySensorsHint: false, // Standalone GPS!
        );
      }
      expect(adapter.state, GpsRecoveryState.s5SafeReset);

      // 3 probation fixes in S5
      for (var m = 1; m <= 3; m++) {
        adapter.processMeasurement(
          rawPoint: offsetMeters(origin, 42.0 + m * 4.0, 60.0),
          truthPoint: offsetMeters(origin, 42.0 + m * 4.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 13 + m)),
          speedMs: 4.0,
          hasAuxiliarySensorsHint: false,
        );
      }

      // Standalone GPS enters s0Provisional, NOT s0NormalTracking
      expect(adapter.state, GpsRecoveryState.s0Provisional);
      expect(adapter.accumulatedDistanceMeters, equals(distAtS2),
          reason: 'Distance must remain frozen in escrow during provisional tracking');
      expect(adapter.escrowDistanceMeters, greaterThan(0.0));

      // Now false cluster breaks down: true signal appears on real road
      final trueFix = offsetMeters(origin, 60.0, 0.0);
      final outBreakdown = adapter.processMeasurement(
        rawPoint: trueFix,
        truthPoint: trueFix,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 17)),
        speedMs: 4.0,
        hasAuxiliarySensorsHint: false,
      );

      // Assert fail-closed safety: all escrow purged, zero permanent distance corruption
      expect(outBreakdown.escrowDistanceMeters, equals(0.0));
      expect(outBreakdown.addedDistanceMeters, equals(0.0));
      expect(adapter.accumulatedDistanceMeters, equals(distAtS2),
          reason: 'Permanent workout distance must be untainted by the false cluster');
    });

    test('3. Prolonged Outage Blackout Sweep (1s, 5s, 10s, 30s, 60s) (TC-05)', () {
      final origin = LatLng(10.7769, 106.7009);
      final outageDurations = [1.0, 5.0, 10.0, 30.0, 60.0];

      for (final gapSec in outageDurations) {
        final adapter = RecoveryFsmBenchmarkAdapter();

        // 1. Init in S0
        adapter.processMeasurement(
          rawPoint: origin,
          truthPoint: origin,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime,
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensorsHint: true,
        );
        adapter.processMeasurement(
          rawPoint: offsetMeters(origin, 5.0, 0.0),
          truthPoint: offsetMeters(origin, 5.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(const Duration(seconds: 1)),
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensorsHint: true,
        );

        final distBeforeGap = adapter.accumulatedDistanceMeters;
        final gapEndTime = baseTime.add(Duration(milliseconds: (1000 + gapSec * 1000).round()));
        final exitPoint = offsetMeters(origin, 5.0 + gapSec * 5.0, 0.0);

        if (gapSec <= 1.0) {
          // 1s gap: stays in S0
          final out = adapter.processMeasurement(
            rawPoint: exitPoint,
            truthPoint: exitPoint,
            accuracyMeters: 5.0,
            timeDeltaSec: gapSec,
            timestamp: gapEndTime,
            speedMs: 5.0,
            headingDeg: 90.0,
            hasAuxiliarySensorsHint: true,
          );
          expect(out.state, GpsRecoveryState.s0NormalTracking);
          expect(adapter.accumulatedDistanceMeters, greaterThan(distBeforeGap));
        } else {
          // Outage gap >= 5s: triggers S2 loss-of-lock immediately
          final outEntry = adapter.processMeasurement(
            rawPoint: exitPoint,
            truthPoint: exitPoint,
            accuracyMeters: 5.0,
            timeDeltaSec: gapSec,
            timestamp: gapEndTime,
            speedMs: 5.0,
            headingDeg: 90.0,
            hasAuxiliarySensorsHint: true,
          );
          expect(adapter.state, anyOf(GpsRecoveryState.s2LossOfLock, GpsRecoveryState.s3CandidateReacquisition));
          expect(outEntry.addedDistanceMeters, equals(0.0),
              reason: 'Entering S2 on outage gap must add strictly 0.0m distance');

          // Candidate reacquisition post-outage
          for (var k = 1; k <= 3; k++) {
            final candPoint = offsetMeters(exitPoint, k * 5.0, 0.0);
            adapter.processMeasurement(
              rawPoint: candPoint,
              truthPoint: candPoint,
              accuracyMeters: 5.0,
              timeDeltaSec: 1.0,
              timestamp: gapEndTime.add(Duration(seconds: k)),
              speedMs: 5.0,
              headingDeg: 90.0,
              hasAuxiliarySensorsHint: true,
            );
          }
          expect(adapter.state, GpsRecoveryState.s5SafeReset);

          // Probation passes
          for (var m = 1; m <= 3; m++) {
            final probPoint = offsetMeters(exitPoint, 15.0 + m * 5.0, 0.0);
            adapter.processMeasurement(
              rawPoint: probPoint,
              truthPoint: probPoint,
              accuracyMeters: 5.0,
              timeDeltaSec: 1.0,
              timestamp: gapEndTime.add(Duration(seconds: 3 + m)),
              speedMs: 5.0,
              headingDeg: 90.0,
              hasAuxiliarySensorsHint: true,
            );
          }
          expect(adapter.state, GpsRecoveryState.s0NormalTracking);

          // Verify distance bridging: bridged distance must not exceed linear velocity clamp
          final maxAllowedDistance = distBeforeGap + (5.0 * gapSec) + 50.0;
          expect(adapter.accumulatedDistanceMeters, lessThanOrEqualTo(maxAllowedDistance));
        }
      }
    });

    test('4. Sharp Turns Cornering Accuracy & Apex Shortcutting (TC-02)', () {
      final origin = LatLng(10.7769, 106.7009);
      final turnAngles = [30.0, 60.0, 90.0, 180.0];

      for (final angle in turnAngles) {
        final adapter = RecoveryFsmBenchmarkAdapter();

        // 10 points approach North
        for (var i = 0; i < 10; i++) {
          final truth = offsetMeters(origin, 0.0, i * 5.0);
          adapter.processMeasurement(
            rawPoint: truth,
            truthPoint: truth,
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
            timestamp: baseTime.add(Duration(seconds: i)),
            speedMs: 5.0,
            headingDeg: 0.0,
            hasAuxiliarySensorsHint: false, // No compass!
          );
        }

        // Apex turn
        final rad = angle * math.pi / 180.0;
        final exitBearing = rad;
        for (var j = 1; j <= 10; j++) {
          final dx = j * 5.0 * math.sin(exitBearing);
          final dy = 45.0 + j * 5.0 * math.cos(exitBearing);
          final truth = offsetMeters(origin, dx, dy);
          final out = adapter.processMeasurement(
            rawPoint: truth,
            truthPoint: truth,
            accuracyMeters: 4.0,
            timeDeltaSec: 1.0,
            timestamp: baseTime.add(Duration(seconds: 9 + j)),
            speedMs: 5.0,
            headingDeg: null, // Complete heading dropout during turn
            hasAuxiliarySensorsHint: false,
          );

          // Point-to-truth error during turn must remain tightly bounded (<= 12.0m)
          expect(out.currentErrorMeters, lessThanOrEqualTo(12.0),
              reason: 'Turn tracking error for angle $angle° must be <= 12m');
        }

        // Covariance remains PSD
        expect(adapter.isCovariancePositiveSemiDefinite, isTrue);
      }
    });

    test('5. Clearly Distinguish Initialized vs Uninitialized Covariance State (Scope 7)', () {
      final origin = LatLng(10.7769, 106.7009);
      final adapter = RecoveryFsmBenchmarkAdapter();

      // Before session start: not initialized
      expect(adapter.fsm.isSessionStarted, isFalse);

      // t=0: first fix initializes tracking
      var out = adapter.processMeasurement(
        rawPoint: origin,
        truthPoint: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(out.isCovarianceInitialized, isTrue);
      expect(adapter.initializedCovarianceCount, 1);
      expect(adapter.uninitializedCovarianceCount, 0);

      // Force into S2 loss-of-lock
      for (var i = 1; i <= 5; i++) {
        out = adapter.processMeasurement(
          rawPoint: offsetMeters(origin, 5.0 + i * 5.0, 27.0),
          truthPoint: offsetMeters(origin, 5.0 + i * 5.0, 0.0),
          accuracyMeters: 1.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: i)),
          speedMs: 5.0,
          headingDeg: 90.0,
        );
      }
      expect(adapter.state, GpsRecoveryState.s2LossOfLock);

      // In S2 loss-of-lock, covariance is clearly distinguished as UNINITIALIZED
      expect(out.isCovarianceInitialized, isFalse);
      expect(adapter.uninitializedCovarianceCount, greaterThan(0));

      // Feeding candidates in S3: still uninitialized
      out = adapter.processMeasurement(
        rawPoint: offsetMeters(origin, 35.0, 0.0),
        truthPoint: offsetMeters(origin, 35.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 10)),
        speedMs: 5.0,
      );
      expect(out.isCovarianceInitialized, isFalse);
    });

    test('6. Treat hasAuxiliarySensors as Capability Hint Without Evidence (Scope 8)', () {
      final origin = LatLng(10.7769, 106.7009);
      final adapter = RecoveryFsmBenchmarkAdapter();

      // Init in S0
      adapter.processMeasurement(
        rawPoint: origin,
        truthPoint: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensorsHint: true,
      );

      // Supply hasAuxiliarySensorsHint = true, BUT headingDeg = null
      adapter.processMeasurement(
        rawPoint: offsetMeters(origin, 5.0, 0.0),
        truthPoint: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: null, // No sensor corroboration!
        hasAuxiliarySensorsHint: true, // Capability hint present!
      );

      // Verify adapter detected capability hint without corroborating evidence
      expect(adapter.capabilityHintWithoutEvidenceCount, equals(1),
          reason: 'Missing heading must be detected as capability hint without evidence');
    });

    test('7. Separate Accounting: Overcount, Undercount, and Re-Anchor Jump Exclusion (Scope 5)', () {
      final origin = LatLng(10.7769, 106.7009);
      final adapter = RecoveryFsmBenchmarkAdapter();

      // Run 20 steps with simulated speed and distance
      for (var i = 0; i < 20; i++) {
        final truth = offsetMeters(origin, i * 5.0, 0.0);
        adapter.processMeasurement(
          rawPoint: truth,
          truthPoint: truth,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: i)),
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensorsHint: true,
        );
      }

      final totalEst = adapter.accumulatedDistanceMeters;
      final totalTruth = 19 * 5.0; // 95m

      final overcount = math.max(0.0, totalEst - totalTruth);
      final undercount = math.max(0.0, totalTruth - totalEst);

      expect(overcount / totalTruth * 100.0, lessThanOrEqualTo(1.0),
          reason: 'Overcount error must be <= 1.0%');
      expect(undercount / totalTruth * 100.0, lessThanOrEqualTo(3.0),
          reason: 'Undercount error must be <= 3.0%');
      expect(adapter.totalReAnchorJumpMeters, equals(0.0),
          reason: 'No re-anchor jump occurred on clean tracking');
    });

    test('8. Deterministic Reproduction: S0 Euclidean Step Distance Jitter Accumulation (Task 3 & 4)', () {
      final origin = LatLng(10.738082, 106.625303);
      final fsm = GpsRecoveryStateMachine(
        ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
      );

      final rand = math.Random(42);
      const dt = 0.5; // 2.0 Hz
      const speedMs = 8.33; // 30 km/h
      const steps = 600; // 300 seconds
      final startTime = DateTime.utc(2026, 10, 15, 8, 0, 0);

      double truthDistance = 0.0;
      for (int s = 0; s < steps; s++) {
        final t = startTime.add(Duration(milliseconds: (s * dt * 1000).round()));
        truthDistance += speedMs * dt;
        final truthPoint = offsetMeters(origin, truthDistance, 0.0);

        // Add 8.0m Gaussian noise (Urban Canyon profile)
        final u1 = rand.nextDouble().clamp(1e-7, 1.0);
        final u2 = rand.nextDouble();
        final radiusNoise = 8.0 * math.sqrt(-2.0 * math.log(u1));
        final angleNoise = 2.0 * math.pi * u2;
        final noisyPoint = offsetMeters(truthPoint, radiusNoise * math.cos(angleNoise), radiusNoise * math.sin(angleNoise));

        fsm.processMeasurement(
          point: noisyPoint,
          accuracyMeters: 11.0,
          timeDeltaSec: dt,
          timestamp: t,
          speedMs: speedMs,
          headingDeg: 90.0,
          hasAuxiliarySensors: true,
        );
      }

      final estimatedDistance = fsm.accumulatedDistanceMeters;
      final overcountPercent = (estimatedDistance - truthDistance) / truthDistance * 100.0;

      // Deterministic reproduction:
      // Even with 0 re-anchors, S0 pairwise Euclidean integration accumulates > 15% distance overcount
      expect(fsm.state, equals(GpsRecoveryState.s0NormalTracking));
      expect(overcountPercent, greaterThan(15.0),
          reason: 'Deterministic reproduction: raw Euclidean step distance accumulates > 15% overcount under 8m noise at 2 Hz');
    });

    test('9. Deterministic Reproduction: Scenario 25 S5 Probation Heading Rollback Loop (Task 2 & 4)', () {
      final totalRouteDist = _routeLengthMeters();
      final rand = math.Random(42); // exact seed for Scenario 25
      const dt = 2.0;
      const speedMs = 8.33;
      const stepCount = 90; // inspect first 180 seconds covering the turn
      final startTime = DateTime.utc(2026, 10, 15, 8, 0, 0);

      final fsm = GpsRecoveryStateMachine(
        ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
      );

      double dist = 0.0;
      int rollbackCount = 0;
      double maxTransientError = 0.0;
      int reAnchorCount = 0;

      for (int s = 0; s < stepCount; s++) {
        final t = startTime.add(Duration(milliseconds: (s * dt * 1000).round()));
        dist += speedMs * dt;
        final (truthPos, _) = _interpolateRoute(dist, totalRouteDist);

        final u1 = rand.nextDouble().clamp(1e-7, 1.0);
        final u2 = rand.nextDouble();
        final radiusNoise = 5.0 * math.sqrt(-2.0 * math.log(u1));
        final angleNoise = 2.0 * math.pi * u2;
        final eastNoise = radiusNoise * math.sin(angleNoise);
        final northNoise = radiusNoise * math.cos(angleNoise);
        final noisyPos = _distance.offset(_distance.offset(truthPos, eastNoise, 90.0), northNoise, 0.0);
        final isOutlier = (s == 180);
        final finalRaw = isOutlier ? _distance.offset(truthPos, 55.0, 45.0) : noisyPos;
        final acc = isOutlier ? 50.0 : (7.0 + (rand.nextDouble() - 0.5) * 3.0).clamp(2.0, 30.0);

        final res = fsm.processMeasurement(
          point: finalRaw,
          accuracyMeters: acc,
          timeDeltaSec: dt,
          timestamp: t,
          speedMs: speedMs,
          headingDeg: null, // heading dropout during turn
          hasAuxiliarySensors: false,
        );

        final err = _distance.distance(res.estimatedPosition, truthPos);
        maxTransientError = math.max(maxTransientError, err);

        if (res.wasRollbackApplied) {
          rollbackCount++;
        }
        if (res.wasResetApplied) {
          reAnchorCount++;
        }
      }

      // Assert that Scenario 25 exhibits the exact root-cause failure mode:
      // 1. Multiple rollback events occur during probation (rollbackCount >= 4)
      expect(rollbackCount, greaterThanOrEqualTo(4),
          reason: 'Scenario 25 must reproduce the multiple S5 probation rollback loop');
      // 2. Max transient error exceeds 300m due to stale snapshot restoration
      expect(maxTransientError, greaterThan(300.0),
          reason: 'Scenario 25 must reproduce > 300m transient tracking error');
      // 3. Repeated re-anchor attempts occur
      expect(reAnchorCount, greaterThanOrEqualTo(5));
    });

    test('10. Controlled Experimental Hypothesis: Along-Track Displacement Damps Noise Overcount (Task 4)', () {
      final origin = LatLng(10.738082, 106.625303);
      final rand = math.Random(42);
      const dt = 0.5;
      const speedMs = 8.33;
      const steps = 600;

      final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
      double truthDistance = 0.0;
      double projectedAccumulatedDistance = 0.0;
      LatLng? prevEkfPos;

      for (int s = 0; s < steps; s++) {
        truthDistance += speedMs * dt;
        final truthPoint = offsetMeters(origin, truthDistance, 0.0);

        final u1 = rand.nextDouble().clamp(1e-7, 1.0);
        final u2 = rand.nextDouble();
        final radiusNoise = 8.0 * math.sqrt(-2.0 * math.log(u1));
        final angleNoise = 2.0 * math.pi * u2;
        final noisyPoint = offsetMeters(truthPoint, radiusNoise * math.cos(angleNoise), radiusNoise * math.sin(angleNoise));

        final est = ekf.update(
          measurementPoint: noisyPoint,
          accuracyMeters: 11.0,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: 90.0,
        );

        if (s > 0 && prevEkfPos != null) {
          final stepDist = _distance.distance(prevEkfPos, est.position);
          final stepBearingRad = _distance.bearing(prevEkfPos, est.position) * math.pi / 180.0;
          final headingRad = est.headingDeg * math.pi / 180.0;
          final alongTrack = stepDist * math.max(0.0, math.cos(stepBearingRad - headingRad));
          projectedAccumulatedDistance += alongTrack;
        }

        prevEkfPos = est.position;
      }

      final projectedOvercountPercent =
          (projectedAccumulatedDistance - truthDistance).abs() / truthDistance * 100.0;

      // Along-track projection eliminates transverse jitter and damps overcount from > 15% down to <= 7%
      expect(projectedOvercountPercent, lessThanOrEqualTo(7.0),
          reason: 'Controlled hypothesis: along-track displacement damping contains overcount <= 7.0% under 8m noise');
    });
  });
}
