import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/availability_recovery_tracker.dart';

void main() {
  const distance = Distance();
  final baseTime = DateTime.utc(2026, 10, 19, 8, 0, 0);

  group('TASK 2.6 — Deterministic FSM State & Recovery Unit Tests', () {
    test('1. S0 Normal Tracking: clean fixes commit distance directly', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();

      var currentPos = const LatLng(10.738082, 106.625303);

      for (int i = 0; i < 10; i++) {
        final t = baseTime.add(Duration(seconds: i));
        currentPos = distance.offset(currentPos, 5.0, 90.0); // 5 m/s eastward
        final out = fsm.processMeasurement(
          point: currentPos,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          timestamp: t,
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensors: true,
        );

        acc.recordStep(result: out, dt: 1.0, timestamp: t);

        expect(out.state, equals(GpsRecoveryState.s0NormalTracking));
        expect(out.decision, equals(EkfMeasurementDecision.normal));
        expect(out.escrowDistanceMeters, equals(0.0));
      }

      acc.finalizeScenario();

      final occupancy = acc.computeStateOccupancy();
      expect(occupancy.s0NormalCount, equals(10));
      expect(occupancy.s2LossCount, equals(0));
      expect(acc.lossOfLockEventCount, equals(0));
      expect(acc.unresolvedEventCount, equals(0));

      final residuals = acc.computeReconciliationResiduals();
      expect(residuals.allInvariantsHold, isTrue);
    });

    test('2. Rejection without loss of lock: single isolated spike in S0', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();

      var currentPos = const LatLng(10.738082, 106.625303);

      // Initialize
      final out0 = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: out0, dt: 1.0, timestamp: baseTime);

      // Normal fix
      currentPos = distance.offset(currentPos, 5.0, 90.0);
      final out1 = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: out1, dt: 1.0, timestamp: baseTime.add(const Duration(seconds: 1)));

      // Isolated spike: 60m jump
      final spikePos = distance.offset(currentPos, 60.0, 0.0);
      final out2 = fsm.processMeasurement(
        point: spikePos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 2)),
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: out2, dt: 1.0, timestamp: baseTime.add(const Duration(seconds: 2)));

      expect(out2.decision, equals(EkfMeasurementDecision.rejected));
      // Rejection count is 1 < 3 -> remains in S0
      expect(out2.state, equals(GpsRecoveryState.s0NormalTracking));
      expect(out2.consecutiveRejections, equals(1));
      // Distance is added along inertial velocity, not the 60m jump!
      expect(out2.addedDistanceMeters, lessThan(10.0));

      acc.finalizeScenario();
      final residuals = acc.computeReconciliationResiduals();
      expect(residuals.allInvariantsHold, isTrue);
    });

    test('3. S1 Degraded Tracking: 3 consecutive rejections and hysteresis recovery', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();

      var currentPos = const LatLng(10.738082, 106.625303);

      // Seed 2 clean fixes
      for (int i = 0; i < 2; i++) {
        currentPos = distance.offset(currentPos, 5.0, 90.0);
        final out = fsm.processMeasurement(
          point: currentPos,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: i)),
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensors: true,
        );
        acc.recordStep(result: out, dt: 1.0, timestamp: baseTime.add(Duration(seconds: i)));
      }

      // Inject 3 consecutive spikes to reach S1 (N_reject = 3)
      GpsRecoveryFsmResult? lastOut;
      for (int i = 2; i < 5; i++) {
        final spike = distance.offset(currentPos, 50.0 + (i * 10), 0.0);
        lastOut = fsm.processMeasurement(
          point: spike,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: i)),
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensors: true,
        );
        acc.recordStep(result: lastOut, dt: 1.0, timestamp: baseTime.add(Duration(seconds: i)));
      }

      expect(lastOut!.state, equals(GpsRecoveryState.s1SuspectedDegraded));
      expect(lastOut.consecutiveRejections, equals(3));

      // Hysteresis test: 1 clean fix keeps it in S1
      currentPos = distance.offset(currentPos, 5.0, 90.0);
      final clean1 = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 5)),
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: clean1, dt: 1.0, timestamp: baseTime.add(const Duration(seconds: 5)));
      expect(clean1.state, equals(GpsRecoveryState.s1SuspectedDegraded));

      // 2nd clean fix: exits hysteresis -> returns to S0 Normal Tracking!
      currentPos = distance.offset(currentPos, 5.0, 90.0);
      final clean2 = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 6)),
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: clean2, dt: 1.0, timestamp: baseTime.add(const Duration(seconds: 6)));
      expect(clean2.state, equals(GpsRecoveryState.s0NormalTracking));

      acc.finalizeScenario();
      final residuals = acc.computeReconciliationResiduals();
      expect(residuals.allInvariantsHold, isTrue);
    });

    test('4. S2 Loss of Lock: time gap dt >= 5.0s freezes distance', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();

      final currentPos = const LatLng(10.738082, 106.625303);

      // First fix
      final out0 = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: out0, dt: 1.0, timestamp: baseTime);

      // Large time gap: dt = 6.0s >= 5.0s -> immediate S2 Loss of Lock
      final gapPos = distance.offset(currentPos, 30.0, 90.0);
      final out1 = fsm.processMeasurement(
        point: gapPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 6.0,
        timestamp: baseTime.add(const Duration(seconds: 6)),
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: out1, dt: 6.0, timestamp: baseTime.add(const Duration(seconds: 6)));

      expect(out1.state, equals(GpsRecoveryState.s2LossOfLock));
      expect(out1.addedDistanceMeters, equals(0.0));
      expect(acc.lossOfLockEventCount, equals(1));

      acc.finalizeScenario();
      expect(acc.unresolvedEventCount, equals(1));
      final residuals = acc.computeReconciliationResiduals();
      expect(residuals.allInvariantsHold, isTrue);
    });

    test('5. S3 Candidate Reacquisition: sliding buffer kinematic filtering', () {
      final fsm = GpsRecoveryStateMachine();
      final currentPos = const LatLng(10.738082, 106.625303);

      // Enter S2 via time gap
      fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 6.0,
        timestamp: baseTime.add(const Duration(seconds: 6)),
      );
      expect(fsm.state, equals(GpsRecoveryState.s2LossOfLock));

      // Candidate 1: valid dt = 1.0s, accuracy = 8.0m <= 20.0m
      final c1Pos = distance.offset(currentPos, 10.0, 90.0);
      final outC1 = fsm.processMeasurement(
        point: c1Pos,
        accuracyMeters: 8.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 7)),
        speedMs: 5.0,
        headingDeg: 90.0,
      );
      expect(outC1.state, equals(GpsRecoveryState.s3CandidateReacquisition));
      expect(outC1.isCandidateBuffered, isTrue);
      expect(outC1.candidateCount, equals(1));

      // Candidate 2: speed <= 20m/s, accel <= 4m/s^2
      final c2Pos = distance.offset(c1Pos, 6.0, 90.0);
      final outC2 = fsm.processMeasurement(
        point: c2Pos,
        accuracyMeters: 7.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 8)),
        speedMs: 6.0,
        headingDeg: 90.0,
      );
      expect(outC2.state, equals(GpsRecoveryState.s3CandidateReacquisition));
      expect(outC2.isCandidateBuffered, isTrue);
      expect(outC2.candidateCount, equals(2));
    });

    test('6. Failed Recovery: buffer expiry (> 6.0s) and kinematic speed violation', () {
      final fsm = GpsRecoveryStateMachine();
      final currentPos = const LatLng(10.738082, 106.625303);

      // Enter S2
      fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );
      fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 6.0,
        timestamp: baseTime.add(const Duration(seconds: 6)),
      );

      // Add candidate 1
      fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 7)),
      );
      expect(fsm.state, equals(GpsRecoveryState.s3CandidateReacquisition));

      // Attempt candidate 2 with speed violation: 35 m in 1.0s = 35 m/s > 20 m/s
      final fastPos = distance.offset(currentPos, 35.0, 90.0);
      final outFail = fsm.processMeasurement(
        point: fastPos,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 8)),
      );

      // Kinematic violation: flushes buffer and drops back to S2!
      expect(outFail.state, equals(GpsRecoveryState.s2LossOfLock));
      expect(outFail.candidateCount, equals(0));
    });

    test('7. S4 Validated Re-Anchor and S5 Probation with Auxiliary Sensors (Full Recovery)', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();

      var currentPos = const LatLng(10.738082, 106.625303);

      // 1. Initial fix
      final out0 = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: out0, dt: 1.0, timestamp: baseTime);

      // 2. Drop into S2 via 5.0s time gap
      final outLoss = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 5.0,
        timestamp: baseTime.add(const Duration(seconds: 5)),
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: outLoss, dt: 5.0, timestamp: baseTime.add(const Duration(seconds: 5)));
      expect(outLoss.state, equals(GpsRecoveryState.s2LossOfLock));

      // 3. Feed K=3 candidates
      for (int i = 1; i <= 3; i++) {
        currentPos = distance.offset(currentPos, 5.0, 90.0);
        final t = baseTime.add(Duration(seconds: 5 + i));
        final outCand = fsm.processMeasurement(
          point: currentPos,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: t,
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensors: true,
        );
        acc.recordStep(result: outCand, dt: 1.0, timestamp: t);

        if (i == 3) {
          // 3rd candidate validates S4 and transitions to S5 Safe Reset
          expect(outCand.state, equals(GpsRecoveryState.s5SafeReset));
          expect(outCand.wasResetApplied, isTrue);
          expect(outCand.escrowDistanceMeters, greaterThan(0.0));
        } else {
          expect(outCand.state, equals(GpsRecoveryState.s3CandidateReacquisition));
        }
      }

      // 4. Feed M=3 probation fixes in S5
      for (int i = 4; i <= 6; i++) {
        currentPos = distance.offset(currentPos, 5.0, 90.0);
        final t = baseTime.add(Duration(seconds: 5 + i));
        final outProb = fsm.processMeasurement(
          point: currentPos,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          timestamp: t,
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensors: true,
        );
        acc.recordStep(result: outProb, dt: 1.0, timestamp: t);

        if (i == 6) {
          // On 3rd probation fix with auxiliary sensors, transitions to S0 Normal Tracking!
          expect(outProb.state, equals(GpsRecoveryState.s0NormalTracking));
          expect(outProb.addedDistanceMeters, greaterThan(0.0));
          expect(outProb.escrowDistanceMeters, equals(0.0));
        } else {
          expect(outProb.state, equals(GpsRecoveryState.s5SafeReset));
        }
      }

      acc.finalizeScenario();

      expect(acc.lossOfLockEventCount, equals(1));
      expect(acc.recoveredEventCount, equals(1));
      expect(acc.unresolvedEventCount, equals(0));
      expect(acc.latencies.length, equals(1));
      // Latency from entry to S2 (t=5s) to exit to S0 (t=11s) = 6.0s
      expect(acc.latencies.first, closeTo(6.0, 0.01));

      final residuals = acc.computeReconciliationResiduals();
      expect(residuals.allInvariantsHold, isTrue);
    });

    test('8. Heading Dropout: GPS-only re-anchor transitions S5 -> S0 Provisional -> S0 Normal', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();

      var currentPos = const LatLng(10.738082, 106.625303);

      // Initial fix
      final out0 = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        hasAuxiliarySensors: false,
      );
      acc.recordStep(result: out0, dt: 1.0, timestamp: baseTime);

      // S2 Loss
      final outLoss = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 5.0,
        timestamp: baseTime.add(const Duration(seconds: 5)),
        hasAuxiliarySensors: false,
      );
      acc.recordStep(result: outLoss, dt: 5.0, timestamp: baseTime.add(const Duration(seconds: 5)));

      // 3 candidates -> S5 Safe Reset
      for (int i = 1; i <= 3; i++) {
        currentPos = distance.offset(currentPos, 5.0, 90.0);
        final t = baseTime.add(Duration(seconds: 5 + i));
        final outCand = fsm.processMeasurement(
          point: currentPos,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: t,
          hasAuxiliarySensors: false, // NO heading corroboration
        );
        acc.recordStep(result: outCand, dt: 1.0, timestamp: t);
      }

      // 3 probation fixes in S5 without auxiliary sensors
      GpsRecoveryFsmResult? s5Out;
      for (int i = 4; i <= 6; i++) {
        currentPos = distance.offset(currentPos, 5.0, 90.0);
        final t = baseTime.add(Duration(seconds: 5 + i));
        s5Out = fsm.processMeasurement(
          point: currentPos,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          timestamp: t,
          hasAuxiliarySensors: false,
        );
        acc.recordStep(result: s5Out, dt: 1.0, timestamp: t);
      }

      // Without auxiliary sensors, S5 exits into S0 PROVISIONAL!
      expect(s5Out!.state, equals(GpsRecoveryState.s0Provisional));
      expect(s5Out.escrowDistanceMeters, greaterThan(0.0));

      // Feed 5 consecutive clean fixes to validate provisional mode
      GpsRecoveryFsmResult? provOut;
      for (int i = 7; i <= 11; i++) {
        currentPos = distance.offset(currentPos, 5.0, 90.0);
        final t = baseTime.add(Duration(seconds: 5 + i));
        provOut = fsm.processMeasurement(
          point: currentPos,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          timestamp: t,
          hasAuxiliarySensors: false,
        );
        acc.recordStep(result: provOut, dt: 1.0, timestamp: t);
      }

      // 5th clean fix promotes to S0 Normal Tracking and commits escrow!
      expect(provOut!.state, equals(GpsRecoveryState.s0NormalTracking));
      expect(provOut.escrowDistanceMeters, equals(0.0));

      acc.finalizeScenario();
      final residuals = acc.computeReconciliationResiduals();
      expect(residuals.allInvariantsHold, isTrue);
    });

    test('9. Unresolved recovery at end of scenario', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();

      final currentPos = const LatLng(10.738082, 106.625303);

      // Normal fix
      final out0 = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );
      acc.recordStep(result: out0, dt: 1.0, timestamp: baseTime);

      // Trigger S2 loss
      final outLoss = fsm.processMeasurement(
        point: currentPos,
        accuracyMeters: 4.0,
        timeDeltaSec: 5.0,
        timestamp: baseTime.add(const Duration(seconds: 5)),
      );
      acc.recordStep(result: outLoss, dt: 5.0, timestamp: baseTime.add(const Duration(seconds: 5)));

      // Scenario terminates right now while in S2!
      acc.finalizeScenario();

      expect(acc.lossOfLockEventCount, equals(1));
      expect(acc.recoveredEventCount, equals(0));
      expect(acc.unresolvedEventCount, equals(1));
      expect(acc.latencies, isEmpty);

      final residuals = acc.computeReconciliationResiduals();
      expect(residuals.allInvariantsHold, isTrue);
      expect(residuals.recoveryEventResidual, equals(0));
    });

    test('10. Edge cases: stationary suppression and zero/negative dt', () {
      final fsm = GpsRecoveryStateMachine();

      final pos = const LatLng(10.738082, 106.625303);

      // Fix 1
      fsm.processMeasurement(
        point: pos,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 0.2, // stationary
      );

      // Fix 2: micro displacement (0.5m) and stationary speed
      final microPos = distance.offset(pos, 0.5, 90.0);
      final outStationary = fsm.processMeasurement(
        point: microPos,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 1)),
        speedMs: 0.1,
      );

      // Stationary jitter suppression: 0.0 added distance
      expect(outStationary.addedDistanceMeters, equals(0.0));
      expect(outStationary.estimatedSpeedMs, equals(0.0));

      // Fix 3: dt <= 0 guarded to dt = 1.0s without throwing
      final outGuarded = fsm.processMeasurement(
        point: microPos,
        accuracyMeters: 3.0,
        timeDeltaSec: -0.5,
        timestamp: baseTime.add(const Duration(seconds: 2)),
      );
      expect(outGuarded.state, equals(GpsRecoveryState.s0NormalTracking));
    });
  });

  group('TASK 2 — Trust Semantics & State x Decision Classification Tests', () {
    test('11. Accepted measurement in S0: updates EKF and commits distance directly', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();
      final p0 = const LatLng(10.738082, 106.625303);

      // Init
      final outInit = fsm.processMeasurement(
        point: p0,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: outInit, dt: 1.0, timestamp: baseTime);

      // Clean measurement
      final p1 = distance.offset(p0, 5.0, 90.0);
      final t1 = baseTime.add(const Duration(seconds: 1));
      final out1 = fsm.processMeasurement(
        point: p1,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: t1,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: out1, dt: 1.0, timestamp: t1);

      expect(out1.state, equals(GpsRecoveryState.s0NormalTracking));
      expect(out1.decision, equals(EkfMeasurementDecision.normal));
      expect(out1.addedDistanceMeters, closeTo(5.0, 0.5));
      expect(out1.escrowDistanceMeters, equals(0.0));

      final avail = acc.computeOperationalAvailability();
      expect(avail.s0NormalStateOccupancyCount, equals(2));
      expect(avail.s0MeasurementValidatedCount, equals(2));
      expect(avail.s0PredictOnlyCount, equals(0));
    });

    test('12. Rejected measurement while FSM remains S0: predict-only step without measurement admittance', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();
      final p0 = const LatLng(10.738082, 106.625303);

      // Init
      final out0 = fsm.processMeasurement(
        point: p0,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: out0, dt: 1.0, timestamp: baseTime);

      // Outlier measurement: 55m jump with accuracy 4.0m -> NIS >> 13.816 -> rejection
      final pSpike = distance.offset(p0, 55.0, 45.0);
      final t1 = baseTime.add(const Duration(seconds: 1));
      final outSpike = fsm.processMeasurement(
        point: pSpike,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: t1,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: outSpike, dt: 1.0, timestamp: t1);

      // State is S0, BUT measurement decision is REJECTED
      expect(outSpike.state, equals(GpsRecoveryState.s0NormalTracking));
      expect(outSpike.decision, equals(EkfMeasurementDecision.rejected));
      expect(outSpike.consecutiveRejections, equals(1));

      // Emitted position is inertial prediction, NOT the 55m spike!
      final distToTruthInertial = distance.as(
        LengthUnit.Meter,
        outSpike.estimatedPosition,
        distance.offset(p0, 5.0, 90.0),
      );
      expect(distToTruthInertial, lessThan(2.0));
      expect(outSpike.addedDistanceMeters, closeTo(5.0, 1.5)); // Inertial step

      final avail = acc.computeOperationalAvailability();
      expect(avail.s0NormalStateOccupancyCount, equals(2));
      expect(avail.s0MeasurementValidatedCount, equals(1)); // Only out0 was admitted
      expect(avail.s0PredictOnlyCount, equals(1)); // outSpike was predict-only
    });

    test('13. S0 Provisional Escrow: tentative distance held in escrow until validated', () {
      final fsm = GpsRecoveryStateMachine();
      final acc = AvailabilityRecoveryAccumulator();
      var pos = const LatLng(10.738082, 106.625303);

      // Init
      fsm.processMeasurement(
        point: pos,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
        hasAuxiliarySensors: false,
      );

      // Force S2 loss
      fsm.processMeasurement(
        point: pos,
        accuracyMeters: 3.0,
        timeDeltaSec: 5.0,
        timestamp: baseTime.add(const Duration(seconds: 5)),
        hasAuxiliarySensors: false,
      );

      // Re-anchor through S3 (3 candidates)
      for (int i = 1; i <= 3; i++) {
        pos = distance.offset(pos, 5.0, 90.0);
        fsm.processMeasurement(
          point: pos,
          accuracyMeters: 5.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 5 + i)),
          hasAuxiliarySensors: false,
        );
      }

      // S5 probation (3 fixes) without auxiliary sensors
      GpsRecoveryFsmResult? outProb;
      for (int i = 4; i <= 6; i++) {
        pos = distance.offset(pos, 5.0, 90.0);
        outProb = fsm.processMeasurement(
          point: pos,
          accuracyMeters: 4.0,
          timeDeltaSec: 1.0,
          timestamp: baseTime.add(Duration(seconds: 5 + i)),
          hasAuxiliarySensors: false,
        );
      }

      // Enters S0 Provisional
      expect(outProb!.state, equals(GpsRecoveryState.s0Provisional));
      expect(outProb.escrowDistanceMeters, greaterThan(0.0));

      // Provisional step: measurement admitted with 4x variance, tentative step added to escrow
      pos = distance.offset(pos, 5.0, 90.0);
      final tProv = baseTime.add(const Duration(seconds: 12));
      final outProv = fsm.processMeasurement(
        point: pos,
        accuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        timestamp: tProv,
        hasAuxiliarySensors: false,
      );
      acc.recordStep(result: outProv, dt: 1.0, timestamp: tProv);

      expect(outProv.state, equals(GpsRecoveryState.s0Provisional));
      expect(outProv.decision, equals(EkfMeasurementDecision.normal));
      expect(outProv.addedDistanceMeters, equals(0.0)); // Uncommitted
      expect(outProv.escrowDistanceMeters, greaterThan(0.0)); // Held in escrow
    });

    test('14. S3 Candidate Buffering: fixes buffered without EKF admittance or distance', () {
      final fsm = GpsRecoveryStateMachine();
      final p0 = const LatLng(10.738082, 106.625303);

      fsm.processMeasurement(
        point: p0,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime,
      );
      fsm.processMeasurement(
        point: p0,
        accuracyMeters: 3.0,
        timeDeltaSec: 5.0,
        timestamp: baseTime.add(const Duration(seconds: 5)),
      );
      expect(fsm.state, equals(GpsRecoveryState.s2LossOfLock));

      final pCand = distance.offset(p0, 6.0, 90.0);
      final outCand = fsm.processMeasurement(
        point: pCand,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        timestamp: baseTime.add(const Duration(seconds: 6)),
      );

      expect(outCand.state, equals(GpsRecoveryState.s3CandidateReacquisition));
      expect(outCand.isCandidateBuffered, isTrue);
      expect(outCand.candidateCount, equals(1));
      expect(outCand.addedDistanceMeters, equals(0.0));
      expect(outCand.totalAccumulatedDistanceMeters, equals(0.0));
    });

    test('15. State x Decision matrix reconciliation invariants', () {
      final acc = AvailabilityRecoveryAccumulator();
      final fsm = GpsRecoveryStateMachine();

      var pos = const LatLng(10.738082, 106.625303);

      // 5 normal steps
      for (int i = 0; i < 5; i++) {
        pos = distance.offset(pos, 5.0, 90.0);
        final t = baseTime.add(Duration(seconds: i));
        final out = fsm.processMeasurement(
          point: pos,
          accuracyMeters: 3.0,
          timeDeltaSec: 1.0,
          timestamp: t,
          speedMs: 5.0,
          headingDeg: 90.0,
          hasAuxiliarySensors: true,
        );
        acc.recordStep(result: out, dt: 1.0, timestamp: t);
      }

      // 1 isolated spike in S0
      final spikePos = distance.offset(pos, 60.0, 0.0);
      final tSpike = baseTime.add(const Duration(seconds: 5));
      final outSpike = fsm.processMeasurement(
        point: spikePos,
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        timestamp: tSpike,
        speedMs: 5.0,
        headingDeg: 90.0,
        hasAuxiliarySensors: true,
      );
      acc.recordStep(result: outSpike, dt: 1.0, timestamp: tSpike);

      acc.finalizeScenario();

      final avail = acc.computeOperationalAvailability();
      final residuals = acc.computeReconciliationResiduals();

      expect(residuals.allInvariantsHold, isTrue);
      expect(residuals.s0ValidationResidual, equals(0));
      expect(avail.s0NormalStateOccupancyCount, equals(6));
      expect(avail.s0MeasurementValidatedCount, equals(5));
      expect(avail.s0PredictOnlyCount, equals(1));
      expect(
        avail.s0MeasurementValidatedCount + avail.s0PredictOnlyCount,
        equals(avail.s0NormalStateOccupancyCount),
      );
    });
  });
}

