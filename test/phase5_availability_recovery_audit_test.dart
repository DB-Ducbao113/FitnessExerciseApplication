// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/availability_recovery_tracker.dart';
import 'helpers/experimental_gps_recovery_state_machine.dart';

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

(LatLng, double, bool) _interpolateRoute(double distAlongRoute, double totalDist) {
  var remaining = distAlongRoute % totalDist;
  for (int i = 1; i < _route.length; i++) {
    final segLen = _distance.distance(_route[i - 1], _route[i]);
    if (remaining <= segLen || i == _route.length - 1) {
      final frac = segLen > 0 ? (remaining / segLen).clamp(0.0, 1.0) : 0.0;
      final lat = _route[i - 1].latitude + frac * (_route[i].latitude - _route[i - 1].latitude);
      final lng = _route[i - 1].longitude + frac * (_route[i].longitude - _route[i - 1].longitude);
      final bearing = _distance.bearing(_route[i - 1], _route[i]);
      final prevBearing = i > 1 ? _distance.bearing(_route[i - 2], _route[i - 1]) : bearing;
      final turnAngle = (bearing - prevBearing).abs();
      final isTurn = turnAngle > 10.0 && turnAngle < 350.0;
      return (LatLng(lat, lng), bearing, isTurn);
    }
    remaining -= segLen;
  }
  return (_route.first, 0.0, false);
}

String _getGitCommit() {
  try {
    final result = Process.runSync('git', ['rev-parse', 'HEAD']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}
  return 'unknown';
}

void main() {
  group('TASK 2: Validate Availability & Recovery Reliability', () {
    test('108-scenario audit of 5 configurations with reconciliation invariants', () {
      final totalRouteDist = _routeLengthMeters();
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

      ExperimentalGpsRecoveryStateMachine makeD() => ExperimentalGpsRecoveryStateMachine(
            ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
            enableAlongTrackProjection: false,
            enableGapOverlapCorrection: false,
            enableProbationVarianceInflation: false,
            enableAlternativeRollbackRecovery: false,
          );

      ExperimentalGpsRecoveryStateMachine makeDH1() => ExperimentalGpsRecoveryStateMachine(
            ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
            enableAlongTrackProjection: true,
            enableGapOverlapCorrection: true,
            enableProbationVarianceInflation: false,
            enableAlternativeRollbackRecovery: false,
          );

      ExperimentalGpsRecoveryStateMachine makeDH2() => ExperimentalGpsRecoveryStateMachine(
            ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
            enableAlongTrackProjection: false,
            enableGapOverlapCorrection: false,
            enableProbationVarianceInflation: true,
            enableAlternativeRollbackRecovery: true,
          );

      ExperimentalGpsRecoveryStateMachine makeDH1H2() => ExperimentalGpsRecoveryStateMachine(
            ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
            enableAlongTrackProjection: true,
            enableGapOverlapCorrection: true,
            enableProbationVarianceInflation: true,
            enableAlternativeRollbackRecovery: true,
          );

      ExperimentalGpsRecoveryStateMachine makeDOpt() => ExperimentalGpsRecoveryStateMachine(
            ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
            enableAlongTrackProjection: false,
            enableBoundedHybridDistance: true,
            enableGapOverlapCorrection: true,
            enableProbationVarianceInflation: true,
            enableAlternativeRollbackRecovery: true,
            enableMultiFixHeadingEstimation: true,
            enableProbationConsecutiveRejections: true,
            enableAdaptiveTurnUncertainty: true,
            enableNoiseAwareKinematicScreening: true,
          );

      final configs = [
        (id: 'D', name: 'Config D (Original)', factory: makeD),
        (id: 'DH1', name: 'Config D+H1', factory: makeDH1),
        (id: 'DH2', name: 'Config D+H2', factory: makeDH2),
        (id: 'DH1H2', name: 'Config D+H1+H2', factory: makeDH1H2),
        (id: 'DOpt', name: 'Proposed D+Opt', factory: makeDOpt),
      ];

      final Map<String, dynamic> evidenceConfigurations = {};

      for (final cfg in configs) {
        final globalAcc = AvailabilityRecoveryAccumulator();

        final Map<String, AvailabilityRecoveryAccumulator> noiseAcc = {};
        final Map<String, AvailabilityRecoveryAccumulator> speedAcc = {};
        final Map<String, AvailabilityRecoveryAccumulator> rateAcc = {};
        final Map<String, AvailabilityRecoveryAccumulator> dropoutAcc = {
          'Heading Present': AvailabilityRecoveryAccumulator(),
          'Heading Dropout': AvailabilityRecoveryAccumulator(),
        };

        final List<Map<String, dynamic>> scenarioSummaries = [];
        int scenarioId = 0;

        for (final seed in seeds) {
          for (final noise in noiseProfiles) {
            for (final speed in speeds) {
              for (final rate in samplingRates) {
                scenarioId++;
                final scenAcc = AvailabilityRecoveryAccumulator();

                final rand = math.Random(seed);
                final stepCount = (600 / rate.dt).round();
                double scenarioDist = 0.0;
                final startTime = DateTime.utc(2026, 10, 15, 8, 0, 0);

                final fsm = cfg.factory();
                fsm.setScenario('Scenario_$scenarioId');

                for (int s = 0; s < stepCount; s++) {
                  final t = startTime.add(Duration(milliseconds: (s * rate.dt * 1000).round()));
                  scenarioDist += speed.speedMs * rate.dt;
                  final (truthPos, truthBearing, _) = _interpolateRoute(scenarioDist, totalRouteDist);

                  final u1 = rand.nextDouble().clamp(1e-7, 1.0);
                  final u2 = rand.nextDouble();
                  final radiusNoise = noise.baseNoise * math.sqrt(-2.0 * math.log(u1));
                  final angleNoise = 2.0 * math.pi * u2;
                  final jitterX = (noise.baseNoise >= 7.0 && s % 5 == 0) ? (rand.nextDouble() - 0.5) * 12.0 : 0.0;
                  final jitterY = (noise.baseNoise >= 7.0 && s % 5 == 0) ? (rand.nextDouble() - 0.5) * 12.0 : 0.0;

                  final eastNoise = radiusNoise * math.sin(angleNoise) + jitterX;
                  final northNoise = radiusNoise * math.cos(angleNoise) + jitterY;
                  final rawPos = _distance.offset(_distance.offset(truthPos, eastNoise, 90.0), northNoise, 0.0);

                  final isOutlier = (s == 180);
                  final finalRaw = isOutlier ? _distance.offset(truthPos, 55.0, 45.0) : rawPos;
                  final acc = isOutlier ? 50.0 : (noise.accMean + (rand.nextDouble() - 0.5) * 3.0).clamp(2.0, 30.0);
                  final headingVal = noise.dropout ? null : ((truthBearing + (rand.nextDouble() - 0.5) * 10.0 + 360) % 360);

                  final out = fsm.processMeasurement(
                    point: finalRaw,
                    accuracyMeters: acc,
                    timeDeltaSec: rate.dt,
                    timestamp: t,
                    speedMs: speed.speedMs,
                    headingDeg: headingVal,
                    hasAuxiliarySensors: headingVal != null,
                  );

                  scenAcc.recordStep(result: out, dt: rate.dt, timestamp: t);
                }

                scenAcc.finalizeScenario();

                // Merge into accumulators
                globalAcc.merge(scenAcc);
                noiseAcc.putIfAbsent(noise.name, () => AvailabilityRecoveryAccumulator()).merge(scenAcc);
                speedAcc.putIfAbsent(speed.name, () => AvailabilityRecoveryAccumulator()).merge(scenAcc);
                rateAcc.putIfAbsent(rate.name, () => AvailabilityRecoveryAccumulator()).merge(scenAcc);
                if (noise.dropout) {
                  dropoutAcc['Heading Dropout']!.merge(scenAcc);
                } else {
                  dropoutAcc['Heading Present']!.merge(scenAcc);
                }

                final scenAvail = scenAcc.computeOperationalAvailability();
                final scenResiduals = scenAcc.computeReconciliationResiduals();
                expect(scenResiduals.allInvariantsHold, isTrue,
                    reason: 'Scenario $scenarioId failed invariants');

                scenarioSummaries.add({
                  'scenarioId': scenarioId,
                  'description': '${noise.name} | ${speed.name} | ${rate.name}',
                  'noise': noise.name,
                  'speed': speed.name,
                  'rate': rate.name,
                  'hasHeadingDropout': noise.dropout,
                  'scheduledPoints': scenAcc.scheduledCount,
                  'trustedOperationalPoints': scenAvail.trustedOperationalCount,
                  'legacyAvailablePoints': scenAvail.legacyAvailableCount,
                  'unavailablePoints': scenAvail.unavailableCount,
                  'untrustedOrProvisionalPoints': scenAvail.untrustedOrProvisionalCount,
                  'trustedOperationalPercent': scenAvail.trustedOperationalAvailabilityPercent,
                  'legacyAvailabilityPercent': scenAvail.legacyAvailabilityPercent,
                  'lossEvents': scenAcc.lossOfLockEventCount,
                  'recoveredEvents': scenAcc.recoveredEventCount,
                  'unresolvedEvents': scenAcc.unresolvedEventCount,
                });
              }
            }
          }
        }

        // Compute global metrics and residuals
        final globalInput = globalAcc.computeInputAccounting();
        final globalAccept = globalAcc.computeMeasurementAcceptance();
        final globalOccupancy = globalAcc.computeStateOccupancy();
        final globalAvail = globalAcc.computeOperationalAvailability();
        final globalRecovery = globalAcc.computeRecoveryReliability();
        final globalResiduals = globalAcc.computeReconciliationResiduals();

        // TASK 2.4 — Reconciliation Invariants Assertions
        expect(globalResiduals.allInvariantsHold, isTrue,
            reason: '${cfg.name}: reconciliation residuals invariant check failed');
        expect(globalInput.scheduledCount, equals(75600),
            reason: '${cfg.name}: total scheduled count must be exactly 75,600');
        expect(globalInput.scheduledCount, equals(globalInput.receivedCount + globalInput.missingCount));
        expect(globalInput.receivedCount, equals(globalInput.processedCount + globalInput.unprocessedCount));
        expect(globalOccupancy.totalOccupancyCount, equals(globalInput.processedCount),
            reason: '${cfg.name}: sum of FSM state occupancy must equal processed count');
        expect(
          globalAvail.trustedOperationalCount +
              globalAvail.untrustedOrProvisionalCount +
              globalAvail.unavailableCount,
          equals(globalInput.scheduledCount),
          reason: '${cfg.name}: mutually exclusive availability partition must sum to scheduled count',
        );
        expect(
          globalRecovery.lossOfLockEventCount,
          equals(globalRecovery.recoveredEventCount + globalRecovery.unresolvedEventCount),
          reason: '${cfg.name}: loss events must reconcile with recovered + unresolved events',
        );
        expect(globalRecovery.totalUnavailableDurationSec, greaterThanOrEqualTo(0.0));
        if (globalRecovery.latencies.isNotEmpty) {
          expect(globalRecovery.recoveryLatencyP50, lessThanOrEqualTo(globalRecovery.recoveryLatencyP95));
          expect(globalRecovery.recoveryLatencyP95, lessThanOrEqualTo(globalRecovery.recoveryLatencyMax));
        }

        // Verify that stratifications partition exactly to global
        int noiseScheduledSum = 0;
        int noiseS0Sum = 0;
        for (final entry in noiseAcc.entries) {
          noiseScheduledSum += entry.value.scheduledCount;
          noiseS0Sum += entry.value.s0NormalCount;
          expect(entry.value.computeReconciliationResiduals().allInvariantsHold, isTrue);
        }
        expect(noiseScheduledSum, equals(75600));
        expect(noiseS0Sum, equals(globalOccupancy.s0NormalCount));

        int speedScheduledSum = 0;
        int speedS0Sum = 0;
        for (final entry in speedAcc.entries) {
          speedScheduledSum += entry.value.scheduledCount;
          speedS0Sum += entry.value.s0NormalCount;
          expect(entry.value.computeReconciliationResiduals().allInvariantsHold, isTrue);
        }
        expect(speedScheduledSum, equals(75600));
        expect(speedS0Sum, equals(globalOccupancy.s0NormalCount));

        int rateScheduledSum = 0;
        int rateS0Sum = 0;
        for (final entry in rateAcc.entries) {
          rateScheduledSum += entry.value.scheduledCount;
          rateS0Sum += entry.value.s0NormalCount;
          expect(entry.value.computeReconciliationResiduals().allInvariantsHold, isTrue);
        }
        expect(rateScheduledSum, equals(75600));
        expect(rateS0Sum, equals(globalOccupancy.s0NormalCount));

        int dropoutScheduledSum = 0;
        int dropoutS0Sum = 0;
        for (final entry in dropoutAcc.entries) {
          dropoutScheduledSum += entry.value.scheduledCount;
          dropoutS0Sum += entry.value.s0NormalCount;
          expect(entry.value.computeReconciliationResiduals().allInvariantsHold, isTrue);
        }
        expect(dropoutScheduledSum, equals(75600));
        expect(dropoutS0Sum, equals(globalOccupancy.s0NormalCount));

        // Format stratifications for evidence
        Map<String, dynamic> formatStrat(Map<String, AvailabilityRecoveryAccumulator> map) {
          final out = <String, dynamic>{};
          for (final entry in map.entries) {
            final a = entry.value;
            final occ = a.computeStateOccupancy();
            final av = a.computeOperationalAvailability();
            final rec = a.computeRecoveryReliability();
            out[entry.key] = {
              'scheduledCount': a.scheduledCount,
              'trustedOperationalCount': av.trustedOperationalCount,
              'legacyAvailableCount': av.legacyAvailableCount,
              'unavailableCount': av.unavailableCount,
              'untrustedOrProvisionalCount': av.untrustedOrProvisionalCount,
              'trustedOperationalPercent': av.trustedOperationalAvailabilityPercent,
              'legacyAvailabilityPercent': av.legacyAvailabilityPercent,
              'positionOutputAvailabilityPercent': av.positionOutputAvailabilityPercent,
              'gapDeltaPercent': av.gapDeltaPercent,
              's0NormalCount': occ.s0NormalCount,
              's0ProvisionalCount': occ.s0ProvisionalCount,
              's1DegradedCount': occ.s1DegradedCount,
              's2LossCount': occ.s2LossCount,
              's3ReacquisitionCount': occ.s3ReacquisitionCount,
              's4ValidatedCount': occ.s4ValidatedCount,
              's5ProbationCount': occ.s5ProbationCount,
              'lossEvents': rec.lossOfLockEventCount,
              'recoveredEvents': rec.recoveredEventCount,
              'unresolvedEvents': rec.unresolvedEventCount,
              'recoveryLatencyP50': rec.recoveryLatencyP50,
              'recoveryLatencyP95': rec.recoveryLatencyP95,
              'recoveryLatencyMax': rec.recoveryLatencyMax,
            };
          }
          return out;
        }

        evidenceConfigurations[cfg.id] = {
          'id': cfg.id,
          'name': cfg.name,
          'inputAccounting': globalInput.toJson(),
          'measurementAcceptance': globalAccept.toJson(),
          'stateOccupancy': globalOccupancy.toJson(),
          'operationalAvailability': globalAvail.toJson(),
          'recoveryReliability': globalRecovery.toJson(),
          'reconciliationResiduals': globalResiduals.toJson(),
          'stratifications': {
            'byNoiseProfile': formatStrat(noiseAcc),
            'bySpeed': formatStrat(speedAcc),
            'bySamplingRate': formatStrat(rateAcc),
            'byHeadingDropout': formatStrat(dropoutAcc),
          },
          'scenarios': scenarioSummaries,
        };

        // Print benchmark summary
        print('\n======================================================================');
        print('AUDIT SUMMARY: ${cfg.name}');
        print('======================================================================');
        print('Scheduled Points: ${globalInput.scheduledCount}');
        print('Legacy Availability (state != S2): ${globalAvail.legacyAvailabilityPercent.toStringAsFixed(2)}% (${globalAvail.legacyAvailableCount} / ${globalInput.scheduledCount})');
        print('Trusted Operational Availability (S0 Normal): ${globalAvail.trustedOperationalAvailabilityPercent.toStringAsFixed(2)}% (${globalAvail.trustedOperationalCount} / ${globalInput.scheduledCount})');
        print('Position-Output Availability (S0 + Prov + S1 + S5): ${globalAvail.positionOutputAvailabilityPercent.toStringAsFixed(2)}% (${globalAvail.positionOutputAvailableCount} / ${globalInput.scheduledCount})');
        print('Measurement Acceptance Rate: ${globalAvail.measurementAcceptanceRatePercent.toStringAsFixed(2)}% (${globalAccept.acceptedMeasurementCount} / ${globalInput.scheduledCount})');
        print('Availability Gap Delta: ${globalAvail.gapDeltaPercent.toStringAsFixed(2)}%');
        print('--- FSM State Breakdown ---');
        print('  S0 Normal Tracking: ${globalOccupancy.s0NormalCount} (${(globalOccupancy.s0NormalCount / globalInput.scheduledCount * 100).toStringAsFixed(2)}%)');
        print('  S0 Provisional (Escrowed): ${globalOccupancy.s0ProvisionalCount} (${(globalOccupancy.s0ProvisionalCount / globalInput.scheduledCount * 100).toStringAsFixed(2)}%)');
        print('  S1 Degraded Tracking: ${globalOccupancy.s1DegradedCount} (${(globalOccupancy.s1DegradedCount / globalInput.scheduledCount * 100).toStringAsFixed(2)}%)');
        print('  S2 Loss of Lock: ${globalOccupancy.s2LossCount} (${(globalOccupancy.s2LossCount / globalInput.scheduledCount * 100).toStringAsFixed(2)}%)');
        print('  S3 Candidate Reacquisition: ${globalOccupancy.s3ReacquisitionCount} (${(globalOccupancy.s3ReacquisitionCount / globalInput.scheduledCount * 100).toStringAsFixed(2)}%)');
        print('  S4 Validated Re-Anchor: ${globalOccupancy.s4ValidatedCount}');
        print('  S5 Safe Reset / Probation: ${globalOccupancy.s5ProbationCount} (${(globalOccupancy.s5ProbationCount / globalInput.scheduledCount * 100).toStringAsFixed(2)}%)');
        print('--- Recovery Tracking ---');
        print('  Loss-of-Lock Events: ${globalRecovery.lossOfLockEventCount}');
        print('  Recovered Events: ${globalRecovery.recoveredEventCount}');
        print('  Unresolved Events: ${globalRecovery.unresolvedEventCount}');
        print('  Recovery Latency P50: ${globalRecovery.recoveryLatencyP50.toStringAsFixed(1)}s');
        print('  Recovery Latency P95: ${globalRecovery.recoveryLatencyP95.toStringAsFixed(1)}s');
        print('  Recovery Latency Max: ${globalRecovery.recoveryLatencyMax.toStringAsFixed(1)}s');
        print('  Total Unavailable Duration: ${globalRecovery.totalUnavailableDurationSec.toStringAsFixed(1)}s');
        print('--- Reconciliation Residuals ---');
        print('  Input Residual: ${globalResiduals.inputResidual}');
        print('  Processing Residual: ${globalResiduals.processingResidual}');
        print('  State Occupancy Residual: ${globalResiduals.stateOccupancyResidual}');
        print('  Availability Partition Residual: ${globalResiduals.availabilityPartitionResidual}');
        print('  Recovery Event Residual: ${globalResiduals.recoveryEventResidual}');
        print('  All Invariants Hold: ${globalResiduals.allInvariantsHold ? "PASS (0 residual)" : "FAIL"}');
      }

      // TASK 2.5 — Gate Assessment for Proposed D+Opt
      final dOptData = evidenceConfigurations['DOpt']!;
      final dOptAvail = dOptData['operationalAvailability'] as Map<String, dynamic>;
      final dOptRecovery = dOptData['recoveryReliability'] as Map<String, dynamic>;

      final legacyAvailPercent = dOptAvail['legacyAvailabilityPercent'] as double;
      final trustedAvailPercent = dOptAvail['trustedOperationalAvailabilityPercent'] as double;
      final recoveryLatencyP95 = dOptRecovery['recoveryLatencyP95'] as double;

      final bool isLegacyPassing = legacyAvailPercent >= 99.00;
      final bool isTrustedPassing = trustedAvailPercent >= 99.00;
      final bool isLatencyPassing = recoveryLatencyP95 <= 30.0;

      print('\n======================================================================');
      print('TASK 2.5 — GATE ASSESSMENT FOR PROPOSED D+OPT');
      print('======================================================================');
      print('Legacy Availability (state != S2): ${legacyAvailPercent.toStringAsFixed(2)}% (Threshold >= 99.00% -> ${isLegacyPassing ? "PASS" : "FAIL"})');
      print('Trusted Operational Availability (S0 Normal): ${trustedAvailPercent.toStringAsFixed(2)}% (Threshold >= 99.00% -> ${isTrustedPassing ? "PASS" : "FAIL"})');
      print('Recovery Latency P95: ${recoveryLatencyP95.toStringAsFixed(1)}s (Threshold <= 30.0s -> ${isLatencyPassing ? "PASS" : "FAIL"})');
      print('Gate Assessment Decision: ${isTrustedPassing && isLatencyPassing ? "PASS" : "FAIL"}');
      print('======================================================================\n');

      expect(isLegacyPassing, isTrue);
      expect(isTrustedPassing, isTrue,
          reason: 'Proposed D+Opt trusted operational availability (${trustedAvailPercent.toStringAsFixed(2)}%) meets >= 99.00%');
      expect(isLatencyPassing, isTrue,
          reason: 'Proposed D+Opt recovery latency P95 (${recoveryLatencyP95.toStringAsFixed(1)}s) meets <= 30.0s');

      // TASK 2.6 — Versioned Evidence JSON
      final evidenceReport = {
        'schema_version': 'aetron.phase5.task2.availability_recovery.v1',
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'git_commit': _getGitCommit(),
        'metric_definitions': {
          'scheduledCount': 'Total scheduled sample epochs over 108 scenarios (75,600 total).',
          'legacyAvailabilityPercent': 'Historical metric: (scheduledCount - s2LossCount) / scheduledCount.',
          'trustedOperationalAvailabilityPercent': 'Strict operational tracking metric: s0NormalCount / scheduledCount.',
          'positionOutputAvailabilityPercent': 'Fixes where valid position estimate is produced: (S0 + S0_prov + S1 + S5) / scheduledCount.',
          'trustedDistanceAccountingAvailabilityPercent': 'Fixes where distance increments are committed directly: s0NormalCount / scheduledCount.',
          'measurementAcceptanceRatePercent': 'Ratio of admitted GPS measurements: acceptedMeasurementCount / scheduledCount.',
          'gapDeltaPercent': 'Difference between legacy availability and trusted operational availability: legacyAvailabilityPercent - trustedOperationalAvailabilityPercent.',
          'recoveryLatencyP95': '95th percentile duration (seconds) from entry to S2 until reaching S0 Normal Tracking.',
          'unresolvedEventCount': 'Loss-of-lock events that did not fully recover to S0 before the scenario terminated.',
        },
        'gate_thresholds': {
          'availability_min_percent': 99.00,
          'recovery_latency_p95_max_seconds': 30.0,
        },
        'gate_assessment': {
          'config': 'DOpt',
          'legacy_availability_percent': legacyAvailPercent,
          'trusted_operational_availability_percent': trustedAvailPercent,
          'recovery_latency_p95_seconds': recoveryLatencyP95,
          'unresolved_recovery_events': dOptRecovery['unresolvedEventCount'],
          'gate_status': (isTrustedPassing && isLatencyPassing) ? 'PASS' : 'FAIL',
        },
        'configurations': evidenceConfigurations,
      };

      final dir = Directory('test/artifacts');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('test/artifacts/phase5_task2_availability_report.json');
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(evidenceReport));
      print('Wrote Task 2 evidence JSON to: ${file.path}');
    });
  });
}
