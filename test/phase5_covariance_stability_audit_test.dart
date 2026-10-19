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
  group('TASK 3: Covariance PSD & Numerical Stability Verification', () {
    test('108-scenario covariance audit across 5 frozen configurations', () {
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

      final Map<String, dynamic> evidenceConfigurations = {};

      for (final cfg in configs) {
        final globalCovAcc = CovarianceStratifiedAccumulator();
        final Map<String, CovarianceStratifiedAccumulator> noiseCovAcc = {};
        final Map<String, CovarianceStratifiedAccumulator> speedCovAcc = {};
        final Map<String, CovarianceStratifiedAccumulator> rateCovAcc = {};
        final Map<String, CovarianceStratifiedAccumulator> dropoutCovAcc = {
          'Heading Present': CovarianceStratifiedAccumulator(),
          'Heading Dropout': CovarianceStratifiedAccumulator(),
        };

        final List<Map<String, dynamic>> scenarioSummaries = [];
        int scenarioId = 0;

        for (final seed in seeds) {
          for (final noise in noiseProfiles) {
            for (final speed in speeds) {
              for (final rate in samplingRates) {
                scenarioId++;
                final scenCovAcc = CovarianceStratifiedAccumulator();

                final rand = math.Random(seed);
                final stepCount = (600 / rate.dt).round();
                double scenarioDist = 0.0;
                final startTime = DateTime.utc(2026, 10, 15, 8, 0, 0);

                final (fsm, ekf) = cfg.factory();
                fsm.setScenario('Scenario_$scenarioId');

                int postReAnchorCountdown = 0;

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

                  final isResetEvent = out.wasResetApplied;
                  if (out.wasResetApplied) {
                    postReAnchorCountdown = 5;
                  }

                  final isInitialized = ekf.isInitialized;
                  final currentCov = fsm.covariance;

                  final validationResult = CovarianceStabilityValidator.validate(currentCov);

                  final isReAnchorStep = out.wasResetApplied ||
                      out.state == GpsRecoveryState.s5SafeReset ||
                      postReAnchorCountdown > 0;

                  scenCovAcc.recordObservation(
                    isInitialized: isInitialized,
                    state: out.state,
                    result: validationResult,
                    isResetEvent: isResetEvent,
                    isReAnchorOrProbation: isReAnchorStep,
                  );

                  globalCovAcc.recordObservation(
                    isInitialized: isInitialized,
                    state: out.state,
                    result: validationResult,
                    isResetEvent: isResetEvent,
                    isReAnchorOrProbation: isReAnchorStep,
                  );

                  noiseCovAcc.putIfAbsent(noise.name, () => CovarianceStratifiedAccumulator()).recordObservation(
                        isInitialized: isInitialized,
                        state: out.state,
                        result: validationResult,
                        isResetEvent: isResetEvent,
                        isReAnchorOrProbation: isReAnchorStep,
                      );

                  speedCovAcc.putIfAbsent(speed.name, () => CovarianceStratifiedAccumulator()).recordObservation(
                        isInitialized: isInitialized,
                        state: out.state,
                        result: validationResult,
                        isResetEvent: isResetEvent,
                        isReAnchorOrProbation: isReAnchorStep,
                      );

                  rateCovAcc.putIfAbsent(rate.name, () => CovarianceStratifiedAccumulator()).recordObservation(
                        isInitialized: isInitialized,
                        state: out.state,
                        result: validationResult,
                        isResetEvent: isResetEvent,
                        isReAnchorOrProbation: isReAnchorStep,
                      );

                  if (noise.dropout) {
                    dropoutCovAcc['Heading Dropout']!.recordObservation(
                      isInitialized: isInitialized,
                      state: out.state,
                      result: validationResult,
                      isResetEvent: isResetEvent,
                      isReAnchorOrProbation: isReAnchorStep,
                    );
                  } else {
                    dropoutCovAcc['Heading Present']!.recordObservation(
                      isInitialized: isInitialized,
                      state: out.state,
                      result: validationResult,
                      isResetEvent: isResetEvent,
                      isReAnchorOrProbation: isReAnchorStep,
                    );
                  }

                  if (postReAnchorCountdown > 0) {
                    postReAnchorCountdown--;
                  }
                }

                scenarioSummaries.add({
                  'scenarioId': scenarioId,
                  'seed': seed,
                  'noise': noise.name,
                  'speed': speed.name,
                  'rate': rate.name,
                  'dropout': noise.dropout,
                  'scheduled_samples': scenCovAcc.totalScheduledObservations,
                  'initialized_observations': scenCovAcc.initializedObservations,
                  'uninitialized_observations': scenCovAcc.uninitializedObservations,
                  'finite_percentage': scenCovAcc.finitePercentage,
                  'symmetry_pass_percentage': scenCovAcc.symmetryPassPercentage,
                  'psd_pass_percentage': scenCovAcc.psdPassPercentage,
                  'overall_valid_percentage': scenCovAcc.overallValidPercentage,
                  'overall_valid_count': scenCovAcc.overallValidCount,
                  'overall_invalid_count': scenCovAcc.overallInvalidCount,
                  'jacobi_convergence_percentage': scenCovAcc.jacobiConvergencePercentage,
                  'worst_jacobi_residual': scenCovAcc.worstJacobiResidual,
                  'ldlt_disagreement_count': scenCovAcc.ldltDisagreementCount,
                  'min_eigenvalue': scenCovAcc.minObservedEigenvalue,
                  'worst_symmetry_residual': scenCovAcc.worstSymmetryResidual,
                  'max_trace': scenCovAcc.maxObservedTrace,
                  'psd_fail_count': scenCovAcc.psdFailCount,
                });
              }
            }
          }
        }

        // Configuration verification assertions
        expect(globalCovAcc.totalScheduledObservations, equals(75600),
            reason: '${cfg.id} total scheduled samples must be 75600');
        expect(globalCovAcc.initializedObservations + globalCovAcc.uninitializedObservations, equals(75600),
            reason: '${cfg.id} initialized + uninitialized must equal total scheduled samples');
        expect(globalCovAcc.initializedObservations, greaterThan(70000),
            reason: '${cfg.id} initialized observations must dominate benchmark');
        expect(globalCovAcc.finitePercentage, equals(100.0),
            reason: '${cfg.id} all initialized covariance matrices must be finite');
        expect(globalCovAcc.symmetryPassPercentage, equals(100.0),
            reason: '${cfg.id} all initialized covariance matrices must be symmetric within tolerance');
        expect(globalCovAcc.psdPassPercentage, equals(100.0),
            reason: '${cfg.id} all initialized covariance matrices must be positive semi-definite');
        expect(globalCovAcc.overallValidPercentage, equals(100.0),
            reason: '${cfg.id} all initialized covariance matrices must have overallValid = true');
        expect(globalCovAcc.jacobiConvergencePercentage, equals(100.0),
            reason: '${cfg.id} all Jacobi decompositions must converge');
        expect(globalCovAcc.jacobiConvergenceFailures, equals(0),
            reason: '${cfg.id} Jacobi convergence failures must be 0');
        expect(globalCovAcc.ldltDisagreementCount, equals(0),
            reason: '${cfg.id} LDLT disagreements must be 0');
        expect(globalCovAcc.ldltAgreementPercentage, equals(100.0),
            reason: '${cfg.id} LDLT agreement must be 100%');
        expect(globalCovAcc.minObservedEigenvalue, greaterThan(-1e-6),
            reason: '${cfg.id} minimum eigenvalue must not exceed negative tolerance');
        expect(globalCovAcc.worstSymmetryResidual, lessThanOrEqualTo(1e-4),
            reason: '${cfg.id} worst symmetry residual must be within tolerance');
        expect(globalCovAcc.worstJacobiResidual, lessThanOrEqualTo(1e-10),
            reason: '${cfg.id} worst Jacobi off-diagonal residual must be near machine precision');

        evidenceConfigurations[cfg.id] = {
          'id': cfg.id,
          'name': cfg.name,
          'global': globalCovAcc.toJson(),
          'stratifications': {
            'noise': noiseCovAcc.map((k, v) => MapEntry(k, v.toJson())),
            'speed': speedCovAcc.map((k, v) => MapEntry(k, v.toJson())),
            'sampling_rate': rateCovAcc.map((k, v) => MapEntry(k, v.toJson())),
            'heading_dropout': dropoutCovAcc.map((k, v) => MapEntry(k, v.toJson())),
          },
          'worst_scenarios': scenarioSummaries
            ..sort((a, b) => (a['min_eigenvalue'] as double).compareTo(b['min_eigenvalue'] as double)),
        };

        print('\n======================================================');
        print('TASK 3 CONFIGURATION: ${cfg.name} (${cfg.id})');
        print('Total Scheduled: ${globalCovAcc.totalScheduledObservations}');
        print('Initialized: ${globalCovAcc.initializedObservations}');
        print('Uninitialized: ${globalCovAcc.uninitializedObservations}');
        print('Finite Pass %: ${globalCovAcc.finitePercentage.toStringAsFixed(4)}%');
        print('Symmetry Pass %: ${globalCovAcc.symmetryPassPercentage.toStringAsFixed(4)}%');
        print('PSD Pass %: ${globalCovAcc.psdPassPercentage.toStringAsFixed(4)}%');
        print('Overall Valid %: ${globalCovAcc.overallValidPercentage.toStringAsFixed(4)}% (${globalCovAcc.overallValidCount}/${globalCovAcc.initializedObservations})');
        print('Jacobi Converged %: ${globalCovAcc.jacobiConvergencePercentage.toStringAsFixed(4)}% (Failures: ${globalCovAcc.jacobiConvergenceFailures})');
        print('Worst Jacobi Residual: ${globalCovAcc.worstJacobiResidual}');
        print('LDLT Agreement %: ${globalCovAcc.ldltAgreementPercentage.toStringAsFixed(4)}% (Disagreements: ${globalCovAcc.ldltDisagreementCount})');
        print('Min Eigenvalue: ${globalCovAcc.minObservedEigenvalue}');
        print('Worst Symmetry Residual: ${globalCovAcc.worstSymmetryResidual}');
        print('Max Trace: ${globalCovAcc.maxObservedTrace}');
        print('Re-anchor Stability:');
        print('  Reset Events: ${globalCovAcc.resetEventCount}');
        print('  Re-anchor Observations: ${globalCovAcc.reAnchorObservations}');
        print('  Re-anchor Overall Valid %: ${globalCovAcc.toJson()['re_anchor_stability']['overall_valid_percentage']}%');
        print('  Re-anchor PSD Pass %: ${globalCovAcc.toJson()['re_anchor_stability']['psd_pass_percentage']}%');
        print('======================================================');
      }

      // Final report generation
      final report = {
        'schema_version': 'aetron.phase5.task3.covariance_stability.v2',
        'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source_provenance': {
          'branch': 'EKF+DBSCAN',
          'base_commit': _getGitCommit(),
          'working_tree_state': 'task3_hotfix_complete',
          'generator': 'test/phase5_covariance_stability_audit_test.dart',
          'note': 'Generated during Task 3 verification prior to commit creation; base_commit indicates parent HEAD.'
        },
        'git_commit': _getGitCommit(),
        'branch': 'EKF+DBSCAN',
        'matrix_dimensions': [4, 4],
        'state_vector': ['px (East, m)', 'py (North, m)', 'v (speed, m/s)', 'theta (heading, rad)'],
        'validation_methodology': {
          'finiteness_check': 'All 16 elements must be finite and not NaN',
          'symmetry_check': 'r_sym = max_{i < j} |P_ij - P_ji| <= 1e-6 * max(1.0, max_k |P_kk|)',
          'psd_check': 'Cyclic Jacobi eigenvalue decomposition on sym(P): min_lambda >= -1e-7 * max(1.0, trace(P))',
          'dual_check': 'LDLT decomposition confirming non-negative pivots with zero-pivot defect detection',
          'overall_validity': 'Composite condition: isFinite && isSymmetric && isPositiveSemiDefinite && jacobiConverged',
        },
        'tolerances': {
          'relative_symmetry_tolerance': 1e-6,
          'relative_psd_tolerance': 1e-7,
          'ldlt_pivot_tolerance': -1e-9,
        },
        'benchmark_dataset': {
          'total_scenarios': 108,
          'scheduled_samples_per_config': 75600,
          'seeds': seeds,
          'noise_profiles': noiseProfiles.map((n) => n.name).toList(),
          'speeds': speeds.map((s) => s.name).toList(),
          'sampling_rates': samplingRates.map((r) => r.name).toList(),
        },
        'configurations': evidenceConfigurations,
        'overall_decision': {
          'config_D': 'TECHNICAL PASS',
          'config_DH1': 'TECHNICAL PASS',
          'config_DH2': 'TECHNICAL PASS',
          'config_DH1H2': 'TECHNICAL PASS',
          'config_DOpt': 'TECHNICAL PASS',
          'covariance_psd_stability': 'TECHNICAL PASS',
          'milestone_2b_authorization': 'NOT AUTHORIZED (Owner Hold)',
          'production_merge_authorization': 'NOT AUTHORIZED (Owner Hold)',
        },
      };

      final artifactFile = File('test/artifacts/phase5_task3_covariance_report.json');
      artifactFile.parent.createSync(recursive: true);
      artifactFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(report),
      );
      print('\n[EVIDENCE] Phase 5 Task 3 JSON successfully written to: ${artifactFile.path}');
    });
  });
}
