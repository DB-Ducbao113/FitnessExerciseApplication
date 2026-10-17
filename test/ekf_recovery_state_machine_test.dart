import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final baseTime = DateTime(2026, 10, 17, 10, 0, 0);

  // Helper to project a point East and North from origin by dx, dy meters
  LatLng offsetMeters(LatLng origin, double dxMeters, double dyMeters) {
    const earthRadius = 6378137.0;
    final dLat = (dyMeters / earthRadius) * (180.0 / math.pi);
    final latCos = math.cos(origin.latitude * math.pi / 180.0);
    final dLng = (dxMeters / (earthRadius * latCos)) * (180.0 / math.pi);
    return LatLng(origin.latitude + dLat, origin.longitude + dLng);
  }

  // Helper to drive the FSM into S2 via 5 consecutive NIS rejections (27m offset: NIS >= 13.816, but < D_max 30m)
  void driveFsmToS2(GpsRecoveryStateMachine fsm, LatLng origin, DateTime startTime) {
    for (var i = 1; i <= 5; i++) {
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0 + i * 5.0, 27.0),
        accuracyMeters: 1.0,
        timeDeltaSec: 1.0,
        timestamp: startTime.add(Duration(seconds: i)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
    }
    expect(fsm.state, GpsRecoveryState.s2LossOfLock);
    expect(fsm.candidateCount, 0);
  }

  group('GPS Recovery FSM - Phase 5 Milestone 1 Isolated Tests', () {
    test('1. Lockout progression S0 -> S1 -> S2 with pure rejection counters', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Initial fix at t=0
      var res = fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.state, GpsRecoveryState.s0NormalTracking);
      expect(res.consecutiveRejections, 0);

      // Clean fix at t=1 (moving East by 5m)
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.state, GpsRecoveryState.s0NormalTracking);
      expect(res.decision, isNot(EkfMeasurementDecision.rejected));
      expect(res.consecutiveRejections, 0);

      // Outlier 1 at t=2 (27m North, acc 1m -> NIS rejected, but < D_max 30m) -> N_reject = 1
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 10.0, 27.0),
        accuracyMeters: 1.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 2)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.decision, EkfMeasurementDecision.rejected);
      expect(res.consecutiveRejections, 1);
      expect(res.state, GpsRecoveryState.s0NormalTracking,
          reason: '1 rejection must not degrade state to S1');

      // Outlier 2 at t=3 -> Rejected (N_reject = 2)
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 15.0, 27.0),
        accuracyMeters: 1.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 3)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.decision, EkfMeasurementDecision.rejected);
      expect(res.consecutiveRejections, 2);
      expect(res.state, GpsRecoveryState.s0NormalTracking,
          reason: '2 rejections must not degrade state to S1');

      // Outlier 3 at t=4 -> Rejected (N_reject = 3) -> Transitions to S1
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 20.0, 27.0),
        accuracyMeters: 1.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 4)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.decision, EkfMeasurementDecision.rejected);
      expect(res.consecutiveRejections, 3);
      expect(res.state, GpsRecoveryState.s1SuspectedDegraded,
          reason: 'N_reject >= 3 must trigger transition to S1');

      // Outlier 4 at t=5 -> Rejected (N_reject = 4) -> Remains S1
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 25.0, 27.0),
        accuracyMeters: 1.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 5)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.decision, EkfMeasurementDecision.rejected);
      expect(res.consecutiveRejections, 4);
      expect(res.state, GpsRecoveryState.s1SuspectedDegraded);

      // Outlier 5 at t=6 -> Rejected (N_reject = 5) -> Transitions to S2
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 30.0, 27.0),
        accuracyMeters: 1.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 6)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.decision, EkfMeasurementDecision.rejected);
      expect(res.consecutiveRejections, 5);
      expect(res.state, GpsRecoveryState.s2LossOfLock,
          reason: 'N_reject >= 5 must trigger transition to S2');
      expect(res.addedDistanceMeters, 0.0,
          reason: 'Distance accumulation must be completely frozen in S2');
    });

    test('1b. S1 transitions immediately to S2 on large distance deviation > D_max', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // S0 init & movement
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );
      // Drive to S1 with 3 rejections
      for (var i = 1; i <= 3; i++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, i * 5.0, 22.0),
          accuracyMeters: 1.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: i)),
        );
      }
      expect(fsm.state, GpsRecoveryState.s1SuspectedDegraded);

      // 4th measurement has 100m error (> D_max = 30m) -> immediately triggers S2!
      final res = fsm.processMeasurement(
        point: offsetMeters(origin, 20.0, 100.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 4)),
      );
      expect(res.state, GpsRecoveryState.s2LossOfLock,
          reason: 'Deviation > D_max in S1 must immediately trigger S2');
    });

    test('2. Hysteresis recovery S1 -> S0 requires 2 consecutive clean fixes', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Setup: 2 initial normal fixes
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      // Inject 3 rejections to enter S1
      for (var i = 1; i <= 3; i++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 5.0 + i * 5.0, 27.0),
          accuracyMeters: 1.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 1 + i)),
          speedMs: 5.0,
          headingDeg: 90.0,
        );
      }
      expect(fsm.state, GpsRecoveryState.s1SuspectedDegraded);

      // Clean fix 1 on genuine track: S1 should NOT exit yet
      var res = fsm.processMeasurement(
        point: offsetMeters(origin, 25.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 5)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.state, GpsRecoveryState.s1SuspectedDegraded,
          reason: 'Single clean fix must not exit S1 (hysteresis requires 2)');

      // Clean fix 2 on genuine track: now S1 exits to S0!
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 30.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 6)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.state, GpsRecoveryState.s0NormalTracking,
          reason: '2 consecutive clean fixes must restore S0 normal tracking');
      expect(res.consecutiveRejections, 0);
    });

    test('3. Time gap triggers S1 (gap >= 3s) and S2 (gap >= 5s)', () {
      final fsm1 = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      fsm1.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );

      // dt = 3.5s -> S1
      var res = fsm1.processMeasurement(
        point: offsetMeters(origin, 15.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 3.5,
        timestamp: baseTime.add(const Duration(milliseconds: 3500)),
      );
      expect(res.state, GpsRecoveryState.s1SuspectedDegraded);

      // Fresh FSM: dt = 5.5s -> S2 directly
      final fsm2 = GpsRecoveryStateMachine();
      fsm2.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );
      res = fsm2.processMeasurement(
        point: offsetMeters(origin, 25.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 5.5,
        timestamp: baseTime.add(const Duration(milliseconds: 5500)),
      );
      expect(res.state, GpsRecoveryState.s2LossOfLock);
    });

    test('4. Genuine reacquisition S2 -> S3 -> S4 -> S5 -> S0 with K=3 candidates', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Start in S0
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      // Drive into S2 cleanly
      driveFsmToS2(fsm, origin, baseTime.add(const Duration(seconds: 1)));
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);
      final distAtS2 = fsm.accumulatedDistanceMeters;

      // Candidate 1 at t=10s
      final p1 = offsetMeters(origin, 45.0, 0.0);
      var res = fsm.processMeasurement(
        point: p1,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 10)),
        speedMs: 5.0,
      );
      expect(res.state, GpsRecoveryState.s3CandidateReacquisition);
      expect(res.candidateCount, 1);
      expect(res.addedDistanceMeters, 0.0,
          reason: 'Distance during candidate buffering must be frozen');

      // Candidate 2 at t=11s (moving at 5 m/s)
      final p2 = offsetMeters(origin, 50.0, 0.0);
      res = fsm.processMeasurement(
        point: p2,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 11)),
        speedMs: 5.0,
      );
      expect(res.state, GpsRecoveryState.s3CandidateReacquisition);
      expect(res.candidateCount, 2);

      // Candidate 3 at t=12s (moving at 5 m/s) -> K=3 reached!
      final p3 = offsetMeters(origin, 55.0, 0.0);
      res = fsm.processMeasurement(
        point: p3,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 12)),
        speedMs: 5.0,
      );
      expect(res.wasResetApplied, isTrue,
          reason: 'Safe Reset must be executed upon K=3 valid candidates');
      expect(res.state, GpsRecoveryState.s5SafeReset);
      expect(fsm.snapshot, isNotNull,
          reason: 'Snapshot must be captured prior to Safe Reset');
      expect(fsm.accumulatedDistanceMeters, equals(distAtS2),
          reason: 'Euclidean jump to re-anchor must NOT be added to accumulated distance');
      expect(fsm.escrowDistanceMeters, greaterThan(0.0),
          reason: 'Bridged chord distance must be placed in escrow buffer');

      // Probation window: 3 clean fixes at t=13s, 14s, 15s
      for (var m = 1; m <= 3; m++) {
        res = fsm.processMeasurement(
          point: offsetMeters(origin, 55.0 + m * 5.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 12 + m)),
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensors: true,
        );
      }
      expect(res.state, GpsRecoveryState.s0NormalTracking,
          reason: 'Passing probation window must restore S0 normal tracking');
      expect(fsm.escrowDistanceMeters, 0.0,
          reason: 'Escrow buffer must be cleared after probation pass');
      expect(fsm.accumulatedDistanceMeters, greaterThan(distAtS2),
          reason: 'Escrow and bridged distance must be committed to total workout distance');
    });

    test('5. Stationary jitter clamps speed and suppresses phantom distance (TC-06)', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Initialize
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );

      // Simulate 60 seconds of stationary jitter at traffic light
      // Random-like deterministic circle jitter within 8m, speed reported 0.2 - 0.5 m/s
      for (var t = 1; t <= 60; t++) {
        final angle = (t * 47.0) * math.pi / 180.0;
        final radius = 0.5 + (t % 5) * 0.3; // <= 2m jitter
        final dx = radius * math.cos(angle);
        final dy = radius * math.sin(angle);

        fsm.processMeasurement(
          point: offsetMeters(origin, dx, dy),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: t)),
          speedMs: 0.3,
        );
      }

      // Assert accumulated distance across 60s stationary is <= 0.5m
      expect(fsm.accumulatedDistanceMeters, lessThanOrEqualTo(0.5),
          reason: 'Stationary jitter must not accumulate phantom distance (TC-06 threshold <= 1.0m)');
      expect(fsm.currentSpeedMs, equals(0.0),
          reason: 'Speed must be clamped to 0.0 m/s when stationary');
      expect(fsm.state, GpsRecoveryState.s0NormalTracking);
    });

    test('6. Isolated single spike in S0 adds zero outlier distance (TC-03)', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Fix 1 at t=0
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      // Fix 2 at t=1: 5m East
      var res = fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      final distAtFix2 = fsm.accumulatedDistanceMeters;
      expect(distAtFix2, closeTo(5.0, 0.5));

      // Fix 3 at t=2: isolated 100m spike North
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 10.0, 100.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 2)),
      );
      expect(res.decision, EkfMeasurementDecision.rejected);
      expect(res.state, GpsRecoveryState.s0NormalTracking,
          reason: 'Single isolated spike must not trigger S1 degradation');
      expect(res.addedDistanceMeters, closeTo(5.0, 0.8),
          reason: 'Added distance must correspond to inertial 5.0m step, not 100m spike');
      final distAtSpike = fsm.accumulatedDistanceMeters;

      // Fix 4 at t=3: true fix 15m East (normal path continues)
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 15.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 3)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(res.decision, isNot(EkfMeasurementDecision.rejected));
      expect(res.state, GpsRecoveryState.s0NormalTracking);
      expect(res.consecutiveRejections, 0);

      // Total distance after 3 steps at 5 m/s should be ~15m (+- 1.5m), definitely not 115m!
      expect(fsm.accumulatedDistanceMeters, closeTo(15.0, 2.0));
      expect(distAtSpike - distAtFix2, lessThan(8.0),
          reason: 'Spike contribution must be strictly bounded, no 100m jump');
    });

    test('7. Coherent false multipath cluster triggers Snapshot Rollback & blacklisting (TC-04)', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Start in S0, drive into S2
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      driveFsmToS2(fsm, origin, baseTime.add(const Duration(seconds: 1)));
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);
      final distBeforeCluster = fsm.accumulatedDistanceMeters;

      // Coherent false multipath cluster: 3 points offset 50m North, moving East at 4 m/s
      final c1 = offsetMeters(origin, 40.0, 50.0);
      final c2 = offsetMeters(origin, 44.0, 50.0);
      final c3 = offsetMeters(origin, 48.0, 50.0);

      fsm.processMeasurement(
        point: c1,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 10)),
        speedMs: 4.0,
      );
      fsm.processMeasurement(
        point: c2,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 11)),
        speedMs: 4.0,
      );
      var res = fsm.processMeasurement(
        point: c3,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 12)),
        speedMs: 4.0,
      );
      expect(res.state, GpsRecoveryState.s5SafeReset,
          reason: 'Internally consistent false cluster triggers tentative Safe Reset');

      // Next fix at t=13s is on the TRUE road (50m South of false cluster)
      // This causes NIS explosion relative to the false cluster state
      final trueFix = offsetMeters(origin, 52.0, 0.0);
      res = fsm.processMeasurement(
        point: trueFix,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 13)),
        speedMs: 4.0,
      );

      // Assert probation failure and Snapshot Rollback
      expect(res.wasRollbackApplied, isTrue,
          reason: 'Probation failure must trigger Snapshot Rollback');
      expect(res.state, GpsRecoveryState.s2LossOfLock,
          reason: 'After rollback, state must return to S2');
      expect(fsm.accumulatedDistanceMeters, equals(distBeforeCluster),
          reason: 'All distance from false cluster must be purged on rollback');
      expect(fsm.currentPosition, equals(fsm.snapshot!.lastValidPosition),
          reason: 'Position must be restored to snapshot last valid position on rollback');
      expect(fsm.currentPositionVariance, greaterThanOrEqualTo(100.0),
          reason: 'Position uncertainty must be set to conservative value after rollback');
      expect(fsm.currentSpeedMs, equals(0.0),
          reason: 'Speed must be reset to 0.0 m/s after rollback');
      expect(fsm.escrowDistanceMeters, 0.0);

      // Verify spatial blacklist: c3 must be blacklisted
      expect(fsm.isPointBlacklisted(c3, baseTime.add(const Duration(seconds: 14))), isTrue,
          reason: 'False cluster anchor must be added to spatial blacklist');

      // Attempting to feed candidate from false cluster again must be rejected by blacklist
      res = fsm.processMeasurement(
        point: c3,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 15)),
        speedMs: 4.0,
      );
      expect(res.state, GpsRecoveryState.s2LossOfLock,
          reason: 'Blacklisted candidate must be rejected');
      expect(fsm.candidateCount, 0);
    });

    test('8. Fail-closed on ambiguous reacquisition (speed, acceleration, timeout violations)', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Init and drive into S2
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );
      driveFsmToS2(fsm, origin, baseTime);
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);

      // Subtest 8a: Pairwise speed violation (> 20 m/s)
      fsm.processMeasurement(
        point: offsetMeters(origin, 30.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 10)),
      );
      expect(fsm.candidateCount, 1);

      // Candidate 2 is 30m away after 1s -> speed = 30 m/s > 20 m/s!
      var res = fsm.processMeasurement(
        point: offsetMeters(origin, 60.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 11)),
      );
      expect(res.state, GpsRecoveryState.s2LossOfLock,
          reason: 'Speed > 20 m/s must invalidate candidate buffer (fail-closed)');
      expect(fsm.candidateCount, 0);

      // Subtest 8b: Buffer lifetime timeout (> 6.0s)
      fsm.processMeasurement(
        point: offsetMeters(origin, 30.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 20)),
      );
      expect(fsm.candidateCount, 1);

      // Candidate 2 arrives at t=27s (7.0s after candidate 1 -> lifespan > 6.0s!)
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 35.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 27)),
      );
      expect(res.state, GpsRecoveryState.s2LossOfLock,
          reason: 'Buffer lifespan > 6.0s must invalidate candidate buffer (fail-closed)');
      expect(fsm.candidateCount, 0);
    });

    test('9. Covariance positive semi-definiteness across all states and transitions', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Check PSD at init
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );
      expect(fsm.isCovariancePositiveSemiDefinite, isTrue);

      // S0 normal tracking
      for (var i = 1; i <= 5; i++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, i * 5.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: i)),
          speedMs: 5.0,
          headingDeg: 90.0,
        );
        expect(fsm.isCovariancePositiveSemiDefinite, isTrue,
            reason: 'Covariance must remain PSD during S0 tracking');
      }

      // Drive into S1 -> S2
      for (var i = 1; i <= 5; i++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 25.0 + i * 5.0, 25.0),
          accuracyMeters: 2.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 5 + i)),
        );
        expect(fsm.isCovariancePositiveSemiDefinite, isTrue,
            reason: 'Covariance must remain PSD during degradation');
      }

      // Reacquisition K=3
      for (var k = 1; k <= 3; k++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 60.0 + k * 5.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 15 + k)),
          speedMs: 5.0,
        );
        expect(fsm.isCovariancePositiveSemiDefinite, isTrue,
            reason: 'Covariance must remain PSD during reacquisition / S5 reset');
      }
    });

    test('10. No phantom distance step jump upon S5 re-anchor', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Start in S0
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      // Drive into S2 cleanly
      driveFsmToS2(fsm, origin, baseTime.add(const Duration(seconds: 1)));
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);
      final distAtS2 = fsm.accumulatedDistanceMeters;

      // Re-anchor far away (e.g. 500m away, user cycled through tunnel)
      final farAnchor = offsetMeters(origin, 500.0, 0.0);
      fsm.processMeasurement(
        point: farAnchor,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 30)),
        speedMs: 5.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(farAnchor, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 31)),
        speedMs: 5.0,
      );
      final res = fsm.processMeasurement(
        point: offsetMeters(farAnchor, 10.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 32)),
        speedMs: 5.0,
      );

      expect(res.state, GpsRecoveryState.s5SafeReset);
      expect(res.wasResetApplied, isTrue);

      // The step distance added at the moment of Safe Reset must NOT include the 500m Euclidean jump!
      expect(res.addedDistanceMeters, 0.0,
          reason: 'Safe Reset step must NOT add the Euclidean jump to accumulated distance');
      expect(fsm.accumulatedDistanceMeters, equals(distAtS2),
          reason: 'Accumulated distance before probation pass must remain unchanged');
    });

    test('11. Cold reinitialization & covariance behavior on rollback (Task 1)', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Start in S0
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      // Drive into S2
      driveFsmToS2(fsm, origin, baseTime.add(const Duration(seconds: 1)));
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);
      final preAttemptDist = fsm.accumulatedDistanceMeters;

      // Reacquisition: K=3 candidates
      for (var k = 1; k <= 3; k++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 40.0 + k * 5.0, 30.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 10 + k)),
          speedMs: 5.0,
        );
      }
      expect(fsm.state, GpsRecoveryState.s5SafeReset);

      // Probation fix 1: severe outlier triggering NIS >= 13.816 -> rollback!
      final res = fsm.processMeasurement(
        point: offsetMeters(origin, 55.0, -100.0),
        accuracyMeters: 2.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 14)),
      );

      expect(res.wasRollbackApplied, isTrue);
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);

      // Verify Cold Reinitialization properties:
      // 1. Covariance is valid and PSD (never corrupted, NaN, or indefinite)
      expect(fsm.isCovariancePositiveSemiDefinite, isTrue);
      final cov = fsm.covariance;
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          expect(cov[r][c].isFinite, isTrue, reason: 'Covariance entries must be finite');
        }
      }

      // 2. Position variance is set conservatively (>= 100 m^2), never claiming converged filter
      expect(fsm.currentPositionVariance, greaterThanOrEqualTo(100.0));

      // 3. Speed is reset to 0.0 m/s
      expect(fsm.currentSpeedMs, equals(0.0));

      // 4. Accumulated workout distance strictly preserved at pre-attempt baseline
      expect(fsm.accumulatedDistanceMeters, equals(preAttemptDist));

      // 5. Escrow buffer completely purged
      expect(fsm.escrowDistanceMeters, equals(0.0));
      expect(res.addedDistanceMeters, equals(0.0));
    });

    test('12. Repeated failed re-anchors maintain zero distance leak and spatial blacklist (Task 1)', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Start in S0
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      driveFsmToS2(fsm, origin, baseTime.add(const Duration(seconds: 1)));
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);
      final preAttemptDist = fsm.accumulatedDistanceMeters;

      // ATTEMPT 1: False Cluster A (East 40m, North 50m)
      final clusterAAnchor = offsetMeters(origin, 50.0, 50.0);
      for (var k = 1; k <= 3; k++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 40.0 + k * 5.0, 50.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 10 + k)),
          speedMs: 5.0,
        );
      }
      expect(fsm.state, GpsRecoveryState.s5SafeReset);

      // Fail probation 1
      var res = fsm.processMeasurement(
        point: offsetMeters(origin, 55.0, 0.0),
        accuracyMeters: 2.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 14)),
      );
      expect(res.wasRollbackApplied, isTrue);
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);
      expect(fsm.isPointBlacklisted(clusterAAnchor, baseTime.add(const Duration(seconds: 15))), isTrue);

      // ATTEMPT 2: False Cluster B (East 80m, South 60m)
      final clusterBAnchor = offsetMeters(origin, 90.0, -60.0);
      for (var k = 1; k <= 3; k++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 80.0 + k * 5.0, -60.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 15 + k)),
          speedMs: 5.0,
        );
      }
      expect(fsm.state, GpsRecoveryState.s5SafeReset);

      // Fail probation 2 at t=19s
      res = fsm.processMeasurement(
        point: offsetMeters(origin, 95.0, 0.0),
        accuracyMeters: 2.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 19)),
      );
      expect(res.wasRollbackApplied, isTrue);
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);

      // At t=20s (6s after Cluster A failure, 1s after Cluster B failure):
      // Both anchors must remain blacklisted simultaneously (< 10s duration)
      expect(fsm.isPointBlacklisted(clusterAAnchor, baseTime.add(const Duration(seconds: 20))), isTrue);
      expect(fsm.isPointBlacklisted(clusterBAnchor, baseTime.add(const Duration(seconds: 20))), isTrue);

      // At t=26s (12s after Cluster A failure, 7s after Cluster B failure):
      // Cluster A has expired (>10s), but Cluster B remains active (<10s)
      expect(fsm.isPointBlacklisted(clusterAAnchor, baseTime.add(const Duration(seconds: 26))), isFalse,
          reason: 'Cluster A must expire after 10s blacklist window');
      expect(fsm.isPointBlacklisted(clusterBAnchor, baseTime.add(const Duration(seconds: 26))), isTrue,
          reason: 'Cluster B must remain active within its 10s window');

      // Total distance after 2 failed re-anchors must have ZERO distance leak
      expect(fsm.accumulatedDistanceMeters, equals(preAttemptDist));
      expect(fsm.escrowDistanceMeters, equals(0.0));
      expect(fsm.isCovariancePositiveSemiDefinite, isTrue);
    });

    test('13. Provisional distance escrow & exact-once accounting (Task 2)', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Start in S0
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      driveFsmToS2(fsm, origin, baseTime.add(const Duration(seconds: 1)));
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);
      final distAtS2 = fsm.accumulatedDistanceMeters;

      // Reacquire K=3 candidates on genuine track
      for (var k = 1; k <= 3; k++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 30.0 + k * 5.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 10 + k)),
          speedMs: 5.0,
        );
      }
      expect(fsm.state, GpsRecoveryState.s5SafeReset);

      // S5 probation with hasAuxiliarySensors = false (GPS-only)
      for (var m = 1; m <= 3; m++) {
        final res = fsm.processMeasurement(
          point: offsetMeters(origin, 45.0 + m * 5.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 13 + m)),
          speedMs: 5.0,
          hasAuxiliarySensors: false, // GPS-only!
        );
        expect(res.addedDistanceMeters, 0.0, reason: 'Distance in S5 must be held in escrow');
      }

      // After 3 probation fixes, GPS-only enters s0Provisional (NOT s0NormalTracking)
      expect(fsm.state, GpsRecoveryState.s0Provisional);
      expect(fsm.accumulatedDistanceMeters, equals(distAtS2),
          reason: 'Accumulated workout distance must remain unchanged while in provisional escrow');
      expect(fsm.escrowDistanceMeters, greaterThan(0.0),
          reason: 'Escrow must hold tentative distance');

      final escrowBeforeProv = fsm.escrowDistanceMeters;

      // Feed 4 clean fixes in s0Provisional: distance must stay in escrow (addedDistance == 0.0)
      for (var p = 1; p <= 4; p++) {
        final res = fsm.processMeasurement(
          point: offsetMeters(origin, 60.0 + p * 5.0, 0.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 16 + p)),
          speedMs: 5.0,
          hasAuxiliarySensors: false,
        );
        expect(res.state, GpsRecoveryState.s0Provisional);
        expect(res.addedDistanceMeters, 0.0,
            reason: 'Each provisional fix must keep addedDistance == 0.0');
        expect(fsm.accumulatedDistanceMeters, equals(distAtS2));
      }

      // 5th clean fix in s0Provisional: provisional validation window passes!
      final res5 = fsm.processMeasurement(
        point: offsetMeters(origin, 85.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 21)),
        speedMs: 5.0,
        hasAuxiliarySensors: false,
      );

      // Now state transitions to s0NormalTracking and commits escrow
      expect(res5.state, GpsRecoveryState.s0NormalTracking);
      expect(res5.addedDistanceMeters, greaterThan(escrowBeforeProv),
          reason: 'Escrow must be committed in bulk on passing provisional validation window');
      expect(fsm.escrowDistanceMeters, equals(0.0),
          reason: 'Escrow must be cleared once committed');
      final committedTotal = fsm.accumulatedDistanceMeters;
      expect(committedTotal, equals(distAtS2 + res5.addedDistanceMeters));

      // 6th fix in s0NormalTracking: standard per-step incremental accumulation
      final res6 = fsm.processMeasurement(
        point: offsetMeters(origin, 90.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 22)),
        speedMs: 5.0,
      );
      expect(res6.state, GpsRecoveryState.s0NormalTracking);
      expect(res6.addedDistanceMeters, closeTo(5.0, 0.8));
      expect(fsm.accumulatedDistanceMeters, closeTo(committedTotal + 5.0, 0.8),
          reason: 'Exact-once accounting: subsequent fixes add only their incremental step');
    });

    test('14. Coherent false GPS cluster persisting beyond probation is purged on breakdown (Task 3)', () {
      final fsm = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      // Start in S0
      fsm.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsm.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      driveFsmToS2(fsm, origin, baseTime.add(const Duration(seconds: 1)));
      expect(fsm.state, GpsRecoveryState.s2LossOfLock);
      final distBeforeFalseCluster = fsm.accumulatedDistanceMeters;

      // Coherent false cluster (East 40m, North 80m, moving at 4 m/s East)
      // 3 candidates collected in S3
      for (var k = 1; k <= 3; k++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 30.0 + k * 4.0, 80.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 10 + k)),
          speedMs: 4.0,
        );
      }
      expect(fsm.state, GpsRecoveryState.s5SafeReset);

      // 3 false probation fixes (also moving at 4 m/s East) - GPS-only!
      for (var m = 1; m <= 3; m++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 42.0 + m * 4.0, 80.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 13 + m)),
          speedMs: 4.0,
          hasAuxiliarySensors: false, // GPS-only!
        );
      }

      // FSM MUST NOT claim verified absolute positioning! It MUST enter s0Provisional!
      expect(fsm.state, GpsRecoveryState.s0Provisional,
          reason: 'GPS-only reacquisition must enter provisional state, not verified normal tracking');
      expect(fsm.accumulatedDistanceMeters, equals(distBeforeFalseCluster),
          reason: 'Accumulated distance must NOT include false cluster fixes');
      expect(fsm.escrowDistanceMeters, greaterThan(0.0),
          reason: 'False cluster distance must be trapped in escrow');

      // False cluster continues for 2 more fixes in s0Provisional
      for (var p = 1; p <= 2; p++) {
        fsm.processMeasurement(
          point: offsetMeters(origin, 54.0 + p * 4.0, 80.0),
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 16 + p)),
          speedMs: 4.0,
          hasAuxiliarySensors: false,
        );
        expect(fsm.state, GpsRecoveryState.s0Provisional);
        expect(fsm.accumulatedDistanceMeters, equals(distBeforeFalseCluster));
      }

      // Now false cluster breaks down: multipath wall ends, true signal appears 80m South (on real road)
      final trueFix = offsetMeters(origin, 66.0, 0.0);
      final resBreakdown = fsm.processMeasurement(
        point: trueFix,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 19)),
        speedMs: 4.0,
        hasAuxiliarySensors: false,
      );

      // On breakdown in provisional mode:
      // Escrow is completely purged to 0.0!
      // Added distance is strictly 0.0!
      // Total accumulated workout distance has ZERO contribution from the 8 false fixes!
      expect(fsm.escrowDistanceMeters, equals(0.0),
          reason: 'All tentative distance in escrow must be discarded on breakdown');
      expect(resBreakdown.addedDistanceMeters, equals(0.0));
      expect(fsm.accumulatedDistanceMeters, equals(distBeforeFalseCluster),
          reason: 'Permanent workout distance must have zero corruption from false cluster');
    });

    test('15. Transitions from S0 and S1 to S2 add strictly zero distance increment (Task 2)', () {
      // Case A: S0 -> S2 via time gap (dt >= 5.0s)
      final fsmA = GpsRecoveryStateMachine();
      final origin = LatLng(10.7769, 106.7009);

      fsmA.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      final distA1 = fsmA.accumulatedDistanceMeters;

      final resA2 = fsmA.processMeasurement(
        point: offsetMeters(origin, 50.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 5.5,
        timestamp: baseTime.add(const Duration(milliseconds: 5500)),
      );
      expect(resA2.state, GpsRecoveryState.s2LossOfLock);
      expect(resA2.addedDistanceMeters, equals(0.0),
          reason: 'Transition S0 -> S2 on time gap must add strictly 0.0m');
      expect(fsmA.accumulatedDistanceMeters, equals(distA1));

      // Case B: S1 -> S2 on 5th consecutive rejection
      final fsmB = GpsRecoveryStateMachine();
      fsmB.processMeasurement(
        point: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      fsmB.processMeasurement(
        point: offsetMeters(origin, 5.0, 0.0),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );

      // Rejections 1-4 drive FSM into S1
      for (var i = 1; i <= 4; i++) {
        fsmB.processMeasurement(
          point: offsetMeters(origin, 5.0 + i * 5.0, 27.0),
          accuracyMeters: 1.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 1 + i)),
          speedMs: 5.0,
          headingDeg: 90.0,
        );
      }
      expect(fsmB.state, GpsRecoveryState.s1SuspectedDegraded);
      final distBeforeS2 = fsmB.accumulatedDistanceMeters;

      // 5th rejection triggers S1 -> S2 transition
      final resB5 = fsmB.processMeasurement(
        point: offsetMeters(origin, 30.0, 27.0),
        accuracyMeters: 1.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 6)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(resB5.state, GpsRecoveryState.s2LossOfLock);
      expect(resB5.addedDistanceMeters, equals(0.0),
          reason: 'Transition S1 -> S2 on 5th rejection must add strictly 0.0m');
      expect(fsmB.accumulatedDistanceMeters, equals(distBeforeS2));
    });
  });
}
