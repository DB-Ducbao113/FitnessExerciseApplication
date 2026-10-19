// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/covariance_stability_validator.dart';
import 'helpers/experimental_gps_recovery_state_machine.dart';
import 'helpers/holdout_dataset.dart';

const Distance _distance = Distance();

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
  group('TASK 5 SUPPLEMENTAL: True Missing GPS Blackout Outage Evaluation', () {
    test('Evaluate true 30-second zero-fix blackout across frozen configurations', () {
      final routes = HoldoutRouteCatalog.allRoutes;
      const seed = 1337;
      const double dt = 1.0; // 1.0 Hz
      const int totalDurationSec = 600;
      const int scheduledEpochs = 600;
      const int outageStartSec = 240;
      const int outageEndSec = 270;
      const int outageDurationSec = outageEndSec - outageStartSec; // 30 seconds
      const int expectedMissingFixes = 30;
      const int expectedReceivedFixes = 570;

      (ExperimentalGpsRecoveryStateMachine, ExtendedKalmanFilter) makeD() {
        final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
        final fsm = ExperimentalGpsRecoveryStateMachine(
          ekf: ekf,
          enableAlongTrackProjection: false,
          enableGapOverlapCorrection: false,
          enableProbationVarianceInflation: false,
          enableAlternativeRollbackRecovery: false,
        );
        return (fsm, ekf);
      }

      (ExperimentalGpsRecoveryStateMachine, ExtendedKalmanFilter) makeDH1() {
        final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
        final fsm = ExperimentalGpsRecoveryStateMachine(
          ekf: ekf,
          enableAlongTrackProjection: true,
          enableGapOverlapCorrection: true,
          enableProbationVarianceInflation: false,
          enableAlternativeRollbackRecovery: false,
        );
        return (fsm, ekf);
      }

      (ExperimentalGpsRecoveryStateMachine, ExtendedKalmanFilter) makeDH2() {
        final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
        final fsm = ExperimentalGpsRecoveryStateMachine(
          ekf: ekf,
          enableAlongTrackProjection: false,
          enableGapOverlapCorrection: false,
          enableProbationVarianceInflation: true,
          enableAlternativeRollbackRecovery: true,
        );
        return (fsm, ekf);
      }

      (ExperimentalGpsRecoveryStateMachine, ExtendedKalmanFilter) makeDH1H2() {
        final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
        final fsm = ExperimentalGpsRecoveryStateMachine(
          ekf: ekf,
          enableAlongTrackProjection: true,
          enableGapOverlapCorrection: true,
          enableProbationVarianceInflation: true,
          enableAlternativeRollbackRecovery: true,
        );
        return (fsm, ekf);
      }

      (ExperimentalGpsRecoveryStateMachine, ExtendedKalmanFilter) makeDOpt() {
        final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
        final fsm = ExperimentalGpsRecoveryStateMachine(
          ekf: ekf,
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
        return (fsm, ekf);
      }

      final configs = [
        (id: 'D', name: 'Config D (Original)', factory: makeD),
        (id: 'DH1', name: 'Config D+H1', factory: makeDH1),
        (id: 'DH2', name: 'Config D+H2', factory: makeDH2),
        (id: 'DH1H2', name: 'Config D+H1+H2', factory: makeDH1H2),
        (id: 'DOpt', name: 'Proposed D+Opt', factory: makeDOpt),
      ];

      final Map<String, dynamic> configResults = {};

      for (final cfg in configs) {
        final routeEvaluations = <Map<String, dynamic>>[];

        for (final route in routes) {
          final rand = math.Random(seed);
          final startTime = DateTime.utc(2026, 10, 15, 8, 0, 0);

          final (fsm, _) = cfg.factory();
          fsm.setScenario('TrueOutage_${cfg.id}_${route.id}');

          int receivedFixes = 0;
          int missingFixes = 0;
          double truthDistance = 0.0;
          DateTime? lastDeliveryTime;
          double sumSqError = 0.0;
          final errors = <double>[];

          GpsRecoveryState? stateAtReacquisition;
          EkfMeasurementDecision? decisionAtReacquisition;
          double? reacquisitionAddedDistance;
          DateTime? reacquisitionTime;
          DateTime? recoveryToS0Time;

          int s0Count = 0;
          int s2Count = 0;
          int s3Count = 0;
          int s5Count = 0;
          int psdPassCount = 0;
          int overallValidCovCount = 0;

          for (int s = 0; s < scheduledEpochs; s++) {
            final t = startTime.add(Duration(seconds: s));
            final elapsedSec = s;

            // Route truth advancement
            truthDistance += route.defaultSpeedMs * dt;
            final (truthPos, truthBearing, _) = route.interpolate(truthDistance);

            // True blackout outage window: ZERO fixes delivered
            final isOutage = elapsedSec >= outageStartSec && elapsedSec < outageEndSec;

            if (isOutage) {
              missingFixes++;
              // NOTE: Interface limitation check:
              // Neither ExperimentalGpsRecoveryStateMachine nor production GpsRecoveryStateMachine
              // provides a polling tick method or predict-only update in the absence of a GPS fix.
              // Intermediate FSM state during blackout is strictly NOT OBSERVABLE from caller interface.
              continue;
            }

            receivedFixes++;

            // Calculate actual time delta since last delivered fix
            final double actualDt = lastDeliveryTime == null
                ? dt
                : t.difference(lastDeliveryTime).inMilliseconds / 1000.0;
            lastDeliveryTime = t;

            // Clean GPS point with nominal noise
            final u1 = rand.nextDouble().clamp(1e-7, 1.0);
            final u2 = rand.nextDouble();
            final rNoise = 2.5 * math.sqrt(-2.0 * math.log(u1));
            final aNoise = 2.0 * math.pi * u2;
            final eastNoise = rNoise * math.sin(aNoise);
            final northNoise = rNoise * math.cos(aNoise);
            final rawPos = _distance.offset(_distance.offset(truthPos, eastNoise, 90.0), northNoise, 0.0);

            final out = fsm.processMeasurement(
              point: rawPos,
              accuracyMeters: 4.0,
              timeDeltaSec: actualDt,
              timestamp: t,
              speedMs: route.defaultSpeedMs,
              headingDeg: (truthBearing + 360) % 360,
              hasAuxiliarySensors: true,
            );

            // Capture reacquisition behavior on the first fix post-outage
            if (elapsedSec == outageEndSec) {
              stateAtReacquisition = out.state;
              decisionAtReacquisition = out.decision;
              reacquisitionAddedDistance = out.addedDistanceMeters;
              reacquisitionTime = t;
            } else if (reacquisitionTime != null &&
                recoveryToS0Time == null &&
                out.state == GpsRecoveryState.s0NormalTracking) {
              recoveryToS0Time = t;
            }

            final err = _distance.distance(out.estimatedPosition, truthPos);
            sumSqError += err * err;
            errors.add(err);

            switch (out.state) {
              case GpsRecoveryState.s0NormalTracking:
                s0Count++;
                break;
              case GpsRecoveryState.s2LossOfLock:
                s2Count++;
                break;
              case GpsRecoveryState.s3CandidateReacquisition:
                s3Count++;
                break;
              case GpsRecoveryState.s5SafeReset:
                s5Count++;
                break;
              default:
                break;
            }

            final covResult = CovarianceStabilityValidator.validate(fsm.covariance);
            if (covResult.overallValid) overallValidCovCount++;
            if (covResult.isPositiveSemiDefinite) psdPassCount++;
          }

          // Exact accounting assertions
          expect(scheduledEpochs, equals(receivedFixes + missingFixes),
              reason: 'Scheduled samples must equal received + missing');
          expect(missingFixes, equals(expectedMissingFixes),
              reason: 'Exactly 30 fixes must be missing during blackout');
          expect(receivedFixes, equals(expectedReceivedFixes),
              reason: 'Exactly 570 fixes must be received');

          // Reacquisition behavior assertions
          expect(stateAtReacquisition, equals(GpsRecoveryState.s2LossOfLock),
              reason: 'Time-gap dt=30.0s must trigger S2 Loss of Lock upon reacquisition');
          expect(decisionAtReacquisition, equals(EkfMeasurementDecision.rejected),
              reason: 'Reacquisition fix must be rejected upon time-gap trip');
          expect(reacquisitionAddedDistance, equals(0.0),
              reason: 'Reacquisition fix must add strictly 0.0 m to distance');

          // Recovery latency from reacquisition to S0
          final double recoveryLatencySec = (recoveryToS0Time != null && reacquisitionTime != null)
              ? recoveryToS0Time.difference(reacquisitionTime).inMilliseconds / 1000.0
              : -1.0;

          errors.sort();
          final p95 = errors[(errors.length * 0.95).floor()];
          final rmse = math.sqrt(sumSqError / receivedFixes);
          final distBiasPct = ((fsm.accumulatedDistanceMeters - truthDistance) / truthDistance) * 100.0;

          routeEvaluations.add({
            'route_id': route.id,
            'route_name': route.name,
            'scheduled_epochs': scheduledEpochs,
            'received_fixes': receivedFixes,
            'missing_fixes': missingFixes,
            'truth_distance_m': truthDistance,
            'accumulated_distance_m': fsm.accumulatedDistanceMeters,
            'distance_bias_percent': distBiasPct,
            'rmse_m': rmse,
            'p95_m': p95,
            'reacquisition': {
              'trigger_dt_seconds': outageDurationSec.toDouble(),
              'state_at_reacquisition': stateAtReacquisition?.name,
              'decision_at_reacquisition': decisionAtReacquisition?.name,
              'reacquisition_added_distance_m': reacquisitionAddedDistance,
              'recovery_latency_from_reacquisition_seconds': recoveryLatencySec,
              'recovered_to_s0': recoveryToS0Time != null,
            },
            'state_counts_received': {
              's0': s0Count,
              's2': s2Count,
              's3': s3Count,
              's5': s5Count,
            },
            'covariance_psd_pass_percent': (psdPassCount / receivedFixes) * 100.0,
            'covariance_overall_valid_percent': (overallValidCovCount / receivedFixes) * 100.0,
          });
        }

        configResults[cfg.id] = {
          'config_id': cfg.id,
          'config_name': cfg.name,
          'routes_evaluated': routeEvaluations,
        };

        print('\n[TRUE OUTAGE] ${cfg.name} (${cfg.id}):');
        for (final r in routeEvaluations) {
          final reac = r['reacquisition'] as Map<String, dynamic>;
          print('  ${r['route_name']}: Reac State=${reac['state_at_reacquisition']} | Added=${reac['reacquisition_added_distance_m']}m | Rec Latency=${reac['recovery_latency_from_reacquisition_seconds']}s | Bias=${(r['distance_bias_percent'] as double).toStringAsFixed(2)}%');
        }
      }

      // Compile and write supplemental report
      final report = {
        'schema_version': 'aetron.phase5.task5.supplemental_true_outage.v1',
        'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source_provenance': {
          'branch': 'EKF+DBSCAN',
          'base_commit': _getGitCommit(),
          'generator': 'test/phase5_task5_supplemental_true_outage_test.dart',
          'note': 'Supplemental deterministic test evaluating true zero-fix GPS blackout outages without modifying production code.',
        },
        'test_specification': {
          'outage_type': 'true_missing_gps_blackout',
          'sampling_rate_hz': 1.0,
          'total_duration_seconds': totalDurationSec,
          'scheduled_samples': scheduledEpochs,
          'outage_window_seconds': [outageStartSec, outageEndSec],
          'outage_duration_seconds': outageDurationSec,
          'missing_samples_count': expectedMissingFixes,
          'received_samples_count': expectedReceivedFixes,
          'interface_observation_limitation':
              'NOT TESTABLE during outage silence: Production GpsRecoveryStateMachine interface is sample-driven via processMeasurement(). No ticker or predict-only clock method exists in the absence of GPS fixes. FSM state during silence cannot be polled without altering production code.',
          'reacquisition_mechanism':
              'TESTABLE upon first post-outage fix: Delivered with timeDeltaSec=30.0s. FSM time-gap guard (dt >= 5.0s) triggers S2 Loss of Lock, rejects fix, and safe reset proceeds with 0.0m Euclidean jump.',
        },
        'configuration_results': configResults,
      };

      final artifactFile = File('test/artifacts/phase5_task5_supplemental_outage_report.json');
      artifactFile.parent.createSync(recursive: true);
      artifactFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
      print('\n[EVIDENCE] Phase 5 Task 5 Supplemental Outage JSON written to: ${artifactFile.path}');
    });
  });
}
