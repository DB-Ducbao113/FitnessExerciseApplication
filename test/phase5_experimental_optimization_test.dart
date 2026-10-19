// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/experimental_gps_recovery_state_machine.dart';
import 'helpers/metric_accumulator.dart';
import 'helpers/milestone_2a_release_gate.dart';

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
      // Detect turn if current segment bearing differs significantly from next or previous
      final prevBearing = i > 1 ? _distance.bearing(_route[i - 2], _route[i - 1]) : bearing;
      final turnAngle = (bearing - prevBearing).abs();
      final isTurn = turnAngle > 10.0 && turnAngle < 350.0;
      return (LatLng(lat, lng), bearing, isTurn);
    }
    remaining -= segLen;
  }
  return (_route.first, 0.0, false);
}

class ScenarioResult {
  final int id;
  final String description;
  final double truthDistance;
  final double accumDistance;
  final double rmse;
  final double p95;
  final double maxError;

  double get signedBiasPercent => (accumDistance - truthDistance) / truthDistance * 100.0;

  ScenarioResult({
    required this.id,
    required this.description,
    required this.truthDistance,
    required this.accumDistance,
    required this.rmse,
    required this.p95,
    required this.maxError,
  });
}

class ConfigBenchmarkSummary {
  final String name;
  final double rmse;
  final double p95;
  final double availability;
  final double grossOvercountPercent;
  final double grossUndercountPercent;
  final double signedBiasPercent;
  final double latencyP95;
  final double maxTransientError;
  final double psdPercent;
  final String outputHash;
  final List<ScenarioResult> scenarioResults;

  ConfigBenchmarkSummary({
    required this.name,
    required this.rmse,
    required this.p95,
    required this.availability,
    required this.grossOvercountPercent,
    required this.grossUndercountPercent,
    required this.signedBiasPercent,
    required this.latencyP95,
    required this.maxTransientError,
    required this.psdPercent,
    required this.outputHash,
    required this.scenarioResults,
  });
}

void main() {
  group('Phase 5 Milestone 2A — Experimental Optimization & Baseline Integrity', () {
    test('Tasks 1-4: 108-Scenario Comparative Benchmark across D, D+H1, D+H2, D+H1+H2, and Proposed D+Opt', () {
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

      // Configuration factories
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
        // Map to track total scheduled points per config for later checks
        final configScheduledPoints = <String, int>{};
      // Stratified accumulators for D+Opt using MetricAccumulator
      final Map<String, MetricAccumulator> noiseAcc = {};
      final Map<String, MetricAccumulator> speedAcc = {};
      final Map<String, MetricAccumulator> rateAcc = {};

// Removed unused *_RmseDOpt maps – no longer needed




      double turnSqErrDOpt = 0.0;
      int turnCountDOpt = 0;
      double straightSqErrDOpt = 0.0;
      int straightCountDOpt = 0;

      final configSummaries = <String, ConfigBenchmarkSummary>{};

      // Immutable snapshot of D+Opt global metrics captured inside its iteration
      ({
        double sse,
        int count,
        double truthDist,
        double estDist,
        double rmse,
        double signedBiasPercent,
      })? dOptSnapshot;

      for (final cfg in configs) {
        double sumSqErr = 0.0;
        final allErrors = <double>[];
        double totalTruthDist = 0.0;
        double totalAccum = 0.0;
        double grossOvercount = 0.0;
        double grossUndercount = 0.0;
        final latencies = <double>[];
        int totalScheduledPoints = 0;
        int availablePoints = 0;
        int psdPassCount = 0;
        double maxTransientErr = 0.0;
        final hashBuffer = StringBuffer();
        final scenarioResults = <ScenarioResult>[];

        int scenarioId = 0;

        for (final seed in seeds) {
          for (final noise in noiseProfiles) {
            for (final speed in speeds) {
              for (final rate in samplingRates) {
                scenarioId++;
                final rand = math.Random(seed);
                final stepCount = (600 / rate.dt).round();
                double scenarioDist = 0.0;
                final startTime = DateTime.utc(2026, 10, 15, 8, 0, 0);

                final fsm = cfg.factory();
                DateTime? lossTime;

                double scenSqErr = 0.0;
                final scenErrors = <double>[];
                double scenMaxErr = 0.0;

                for (int s = 0; s < stepCount; s++) {
                  final t = startTime.add(Duration(milliseconds: (s * rate.dt * 1000).round()));
                  scenarioDist += speed.speedMs * rate.dt;
                  final (truthPos, truthBearing, isTurn) = _interpolateRoute(scenarioDist, totalRouteDist);

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

                  if (out.state == GpsRecoveryState.s2LossOfLock) {
                    lossTime ??= t;
                  } else if (lossTime != null && out.state == GpsRecoveryState.s0NormalTracking) {
                    latencies.add(t.difference(lossTime).inMilliseconds / 1000.0);
                    lossTime = null;
                  }

                  if (out.state != GpsRecoveryState.s2LossOfLock) {
                    availablePoints++;
                  }
                  if (out.positionVariance >= 0.0) {
                    psdPassCount++;
                  }

                  final err = _distance.as(LengthUnit.Meter, out.estimatedPosition, truthPos);
                  sumSqErr += err * err;
                  scenSqErr += err * err;
                  allErrors.add(err);
                  scenErrors.add(err);

                  if (err > maxTransientErr) maxTransientErr = err;
                  if (err > scenMaxErr) scenMaxErr = err;

                  // Stratify turns for D+Opt
                  if (cfg.id == 'DOpt') {
                    if (isTurn) {
                      turnSqErrDOpt += err * err;
                      turnCountDOpt++;
                    } else {
                      straightSqErrDOpt += err * err;
                      straightCountDOpt++;
                    }
                  }

                  totalScheduledPoints++;

                  // Hash contribution
                  hashBuffer.write('${out.estimatedPosition.latitude.toStringAsFixed(5)},'
                      '${out.estimatedPosition.longitude.toStringAsFixed(5)};');
                }

                totalTruthDist += scenarioDist;
                final finalDist = fsm.accumulatedDistanceMeters;
                totalAccum += finalDist;

                if (finalDist > scenarioDist) grossOvercount += (finalDist - scenarioDist);
                if (finalDist < scenarioDist) grossUndercount += (scenarioDist - finalDist);

                hashBuffer.write('S$scenarioId:${finalDist.toStringAsFixed(2)};');

                scenErrors.sort();
                final scenP95 = scenErrors[(scenErrors.length * 0.95).floor()];
                final scenRmse = math.sqrt(scenSqErr / stepCount);

                scenarioResults.add(ScenarioResult(
                  id: scenarioId,
                  description: '${noise.name} | ${speed.name} | ${rate.name}',
                  truthDistance: scenarioDist,
                  accumDistance: finalDist,
                  rmse: scenRmse,
                  p95: scenP95,
                  maxError: scenMaxErr,
                ));

                // Accumulate per-category stats for D+Opt
                if (cfg.id == 'DOpt') {
                  final nKey = noise.name;
                  final nAcc = noiseAcc.putIfAbsent(nKey, () => MetricAccumulator());
                  nAcc.add(scenSqErr, scenarioDist, finalDist, stepCount);

                  final sKey = speed.name;
                  final sAcc = speedAcc.putIfAbsent(sKey, () => MetricAccumulator());
                  sAcc.add(scenSqErr, scenarioDist, finalDist, stepCount);

                  final rKey = rate.name;
                  final rAcc = rateAcc.putIfAbsent(rKey, () => MetricAccumulator());
                  rAcc.add(scenSqErr, scenarioDist, finalDist, stepCount);
                }
              }
            }
          }
        }

        allErrors.sort();
        latencies.sort();

        final p95 = allErrors[(allErrors.length * 0.95).floor()];
        final latP95 = latencies.isNotEmpty ? latencies[(latencies.length * 0.95).floor()] : 0.0;
        final rmse = math.sqrt(sumSqErr / totalScheduledPoints);
        // Compute metrics before constructing the summary
        final signedBias = (totalAccum - totalTruthDist) / totalTruthDist * 100.0;
        final overPercent = grossOvercount / totalTruthDist * 100.0;
        final underPercent = grossUndercount / totalTruthDist * 100.0;
        final availPercent = availablePoints / totalScheduledPoints * 100.0;
        final psdPercent = psdPassCount / totalScheduledPoints * 100.0;

        // Compute digest for verification
        final digest = sha256.convert(utf8.encode(hashBuffer.toString())).toString();

        // Store summary for this config
        configSummaries[cfg.id] = ConfigBenchmarkSummary(
          name: cfg.name,
          rmse: rmse,
          p95: p95,
          availability: availPercent,
          grossOvercountPercent: overPercent,
          grossUndercountPercent: underPercent,
          signedBiasPercent: signedBias,
          latencyP95: latP95,
          maxTransientError: maxTransientErr,
          psdPercent: psdPercent,
          outputHash: digest,
          scenarioResults: scenarioResults,
        );
        // Capture immutable snapshot for D+Opt only
        if (cfg.id == 'DOpt') {
          dOptSnapshot = (
            sse: sumSqErr,
            count: totalScheduledPoints,
            truthDist: totalTruthDist,
            estDist: totalAccum,
            rmse: rmse,
            signedBiasPercent: signedBias,
          );
        }

        // Track total scheduled points for later checks
        configScheduledPoints[cfg.id] = totalScheduledPoints;
      }

      final d = configSummaries['D']!;
      final dH1 = configSummaries['DH1']!;
      final dH2 = configSummaries['DH2']!;
      final dH1H2 = configSummaries['DH1H2']!;
      final dOpt = configSummaries['DOpt']!;

      print('\n=============================================================================================================================================================');
      print('AETRON PHASE 5 MILESTONE 2A — EXPERIMENTAL OPTIMIZATION COMPARATIVE BENCHMARK (108 SCENARIOS / 75,600 FIXES)');
      print('=============================================================================================================================================================');
      print('| Configuration | All-Sched RMSE | All-Sched P95 | Availability | Overcount | Undercount | Signed Bias | Recovery Lat P95 | Max Error | Output SHA-256 Hash (Prefix) |');
      print('|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|');
      print('| ${d.name} | ${d.rmse.toStringAsFixed(2)} m | ${d.p95.toStringAsFixed(2)} m | ${d.availability.toStringAsFixed(2)}% | +${d.grossOvercountPercent.toStringAsFixed(2)}% | -${d.grossUndercountPercent.toStringAsFixed(2)}% | +${d.signedBiasPercent.toStringAsFixed(2)}% | ${d.latencyP95.toStringAsFixed(1)} s | ${d.maxTransientError.toStringAsFixed(1)} m | `${d.outputHash.substring(0, 16)}...` |');
      print('| ${dH1.name} | ${dH1.rmse.toStringAsFixed(2)} m | ${dH1.p95.toStringAsFixed(2)} m | ${dH1.availability.toStringAsFixed(2)}% | +${dH1.grossOvercountPercent.toStringAsFixed(2)}% | -${dH1.grossUndercountPercent.toStringAsFixed(2)}% | +${dH1.signedBiasPercent.toStringAsFixed(2)}% | ${dH1.latencyP95.toStringAsFixed(1)} s | ${dH1.maxTransientError.toStringAsFixed(1)} m | `${dH1.outputHash.substring(0, 16)}...` |');
      print('| ${dH2.name} | ${dH2.rmse.toStringAsFixed(2)} m | ${dH2.p95.toStringAsFixed(2)} m | ${dH2.availability.toStringAsFixed(2)}% | +${dH2.grossOvercountPercent.toStringAsFixed(2)}% | -${dH2.grossUndercountPercent.toStringAsFixed(2)}% | +${dH2.signedBiasPercent.toStringAsFixed(2)}% | ${dH2.latencyP95.toStringAsFixed(1)} s | ${dH2.maxTransientError.toStringAsFixed(1)} m | `${dH2.outputHash.substring(0, 16)}...` |');
      print('| ${dH1H2.name} | ${dH1H2.rmse.toStringAsFixed(2)} m | ${dH1H2.p95.toStringAsFixed(2)} m | ${dH1H2.availability.toStringAsFixed(2)}% | +${dH1H2.grossOvercountPercent.toStringAsFixed(2)}% | -${dH1H2.grossUndercountPercent.toStringAsFixed(2)}% | +${dH1H2.signedBiasPercent.toStringAsFixed(2)}% | ${dH1H2.latencyP95.toStringAsFixed(1)} s | ${dH1H2.maxTransientError.toStringAsFixed(1)} m | `${dH1H2.outputHash.substring(0, 16)}...` |');
      print('| **${dOpt.name}** | **${dOpt.rmse.toStringAsFixed(2)} m** | **${dOpt.p95.toStringAsFixed(2)} m** | **${dOpt.availability.toStringAsFixed(2)}%** | **+${dOpt.grossOvercountPercent.toStringAsFixed(2)}%** | **-${dOpt.grossUndercountPercent.toStringAsFixed(2)}%** | **+${dOpt.signedBiasPercent.toStringAsFixed(2)}%** | **${dOpt.latencyP95.toStringAsFixed(1)} s** | **${dOpt.maxTransientError.toStringAsFixed(1)} m** | `${dOpt.outputHash.substring(0, 16)}...` |');
      print('=============================================================================================================================================================\n');

      print('-----------------------------------------------------------------------------------------------------------------------------');
      print('STRATIFIED PERFORMANCE BREAKDOWN — PROPOSED D+OPT');
      print('-----------------------------------------------------------------------------------------------------------------------------');
      print('1. BY NOISE PROFILE:');
      for (final n in noiseProfiles) {
        final sqErr = noiseAcc[n.name]?.sumSqErr ?? 0.0;
        final count = noiseAcc[n.name]?.sumCount ?? 0;
        final rmse = count > 0 ? math.sqrt(sqErr / count) : 0.0;
        final truthDist = noiseAcc[n.name]?.sumTruthDist ?? 0.0;
        final bias = truthDist > 0 ? ((noiseAcc[n.name]?.sumEstDist ?? 0.0) - truthDist) / truthDist * 100.0 : 0.0;
        print('   - ${n.name.padRight(32)}: RMSE = ${rmse.toStringAsFixed(2)} m | Signed Bias = ${bias >= 0 ? "+" : ""}${bias.toStringAsFixed(2)}%');
      }

      print('\n2. BY USER SPEED:');
      for (final sp in speeds) {
        final acc = speedAcc[sp.name];
        final sqErr = acc?.sumSqErr ?? 0.0;
        final count = acc?.sumCount ?? 0;
        final rmse = count > 0 ? math.sqrt(sqErr / count) : 0.0;
        final truthDist = acc?.sumTruthDist ?? 0.0;
        final bias = truthDist > 0 ? ((acc?.sumEstDist ?? 0.0) - truthDist) / truthDist * 100.0 : 0.0;
        print('   - ${sp.name.padRight(32)}: RMSE = ${rmse.toStringAsFixed(2)} m | Signed Bias = ${bias >= 0 ? "+" : ""}${bias.toStringAsFixed(2)}%');
      }

      print('\n3. BY SAMPLING RATE:');
      for (final sr in samplingRates) {
        final acc = rateAcc[sr.name];
        final sqErr = acc?.sumSqErr ?? 0.0;
        final count = acc?.sumCount ?? 0;
        final rmse = count > 0 ? math.sqrt(sqErr / count) : 0.0;
        final truthDist = acc?.sumTruthDist ?? 0.0;
        final bias = truthDist > 0 ? ((acc?.sumEstDist ?? 0.0) - truthDist) / truthDist * 100.0 : 0.0;
        print('   - ${sr.name.padRight(32)}: RMSE = ${rmse.toStringAsFixed(2)} m | Signed Bias = ${bias >= 0 ? "+" : ""}${bias.toStringAsFixed(2)}%');
      }

      final turnRmseDOpt = math.sqrt(turnSqErrDOpt / math.max(1, turnCountDOpt));
      final straightRmseDOpt = math.sqrt(straightSqErrDOpt / math.max(1, straightCountDOpt));
      print('\n4. BY ROUTE GEOMETRY (TURNS VS STRAIGHTS):');
      print('   - Sharp Turn Sections ($turnCountDOpt fixes)   : RMSE = ${turnRmseDOpt.toStringAsFixed(2)} m');
      print('   - Straight Sections   ($straightCountDOpt fixes) : RMSE = ${straightRmseDOpt.toStringAsFixed(2)} m');

      // Sort scenarios to identify worst-case
      final sortedByRmse = List<ScenarioResult>.from(dOpt.scenarioResults)..sort((a, b) => b.rmse.compareTo(a.rmse));
      final sortedByBias = List<ScenarioResult>.from(dOpt.scenarioResults)..sort((a, b) => b.signedBiasPercent.abs().compareTo(a.signedBiasPercent.abs()));

      print('\n5. WORST-CASE SCENARIOS (PROPOSED D+OPT):');
      print('   Top 3 by RMSE:');
      for (int i = 0; i < 3; i++) {
        final sc = sortedByRmse[i];
        print('     #${sc.id} (${sc.description}): RMSE = ${sc.rmse.toStringAsFixed(2)} m | P95 = ${sc.p95.toStringAsFixed(2)} m | Max = ${sc.maxError.toStringAsFixed(1)} m | Bias = ${sc.signedBiasPercent >= 0 ? "+" : ""}${sc.signedBiasPercent.toStringAsFixed(2)}%');
      }
      print('   Top 3 by Absolute Distance Error:');
      for (int i = 0; i < 3; i++) {
        final sc = sortedByBias[i];
        print('     #${sc.id} (${sc.description}): Bias = ${sc.signedBiasPercent >= 0 ? "+" : ""}${sc.signedBiasPercent.toStringAsFixed(2)}% | Truth = ${sc.truthDistance.toStringAsFixed(1)}m | Accum = ${sc.accumDistance.toStringAsFixed(1)}m | Diff = ${(sc.accumDistance - sc.truthDistance).toStringAsFixed(1)}m');
      }
      print('-----------------------------------------------------------------------------------------------------------------------------\n');

      // Evaluate formal release gate on Proposed D+Opt
      final gateEvaluation = Milestone2AReleaseGate.evaluateFromMetrics(
        allScheduledRmse: dOpt.rmse,
        allScheduledP95: dOpt.p95,
        availabilityPercent: dOpt.availability,
        overcountPercent: dOpt.grossOvercountPercent,
        aggregateDistanceBiasPercent: dOpt.signedBiasPercent,
        recoveryLatencyP95: dOpt.latencyP95,
        maxTransientError: dOpt.maxTransientError,
        psdPercent: dOpt.psdPercent,
      );
      gateEvaluation.printReport();

      // ---------- Stratification verification & JSON evidence ----------
      expect(dOptSnapshot, isNotNull, reason: 'D+Opt metrics snapshot must be captured during benchmark iteration');
      final dOptMetrics = dOptSnapshot!;

      final double globalSse = dOptMetrics.sse;
      final int globalCount = dOptMetrics.count;
      final double globalTruth = dOptMetrics.truthDist;
      final double globalEst = dOptMetrics.estDist;
      final double globalRmse = dOptMetrics.rmse;
      final double globalRmseSq = globalSse / globalCount;
      final double globalBias = dOptMetrics.signedBiasPercent;

      // Aggregate per‑group metrics for each stratification.
      double noiseSse = 0.0;
      int noiseCount = 0;
      double noiseTruth = 0.0;
      double noiseEst = 0.0;
      final noiseGroups = <String, Map<String, dynamic>>{};
      for (final n in noiseProfiles) {
        final acc = noiseAcc[n.name] ?? MetricAccumulator();
        noiseSse += acc.sumSqErr;
        noiseCount += acc.sumCount;
        noiseTruth += acc.sumTruthDist;
        noiseEst += acc.sumEstDist;
        noiseGroups[n.name] = {
          'sse': acc.sumSqErr,
          'count': acc.sumCount,
          'truthDist': acc.sumTruthDist,
          'estDist': acc.sumEstDist,
          'scenarioCount': acc.scenarioCount,
          'sampleWeightedRmse': acc.sampleWeightedRMSE(),
          'scenarioWeightedRmse': acc.scenarioWeightedRMSE(),
          'biasPercent': acc.biasPercent(totalRouteDist),
        };
      }

      double speedSse = 0.0;
      int speedCount = 0;
      double speedTruth = 0.0;
      double speedEst = 0.0;
      final speedGroups = <String, Map<String, dynamic>>{};
      for (final sp in speeds) {
        final acc = speedAcc[sp.name] ?? MetricAccumulator();
        speedSse += acc.sumSqErr;
        speedCount += acc.sumCount;
        speedTruth += acc.sumTruthDist;
        speedEst += acc.sumEstDist;
        speedGroups[sp.name] = {
          'sse': acc.sumSqErr,
          'count': acc.sumCount,
          'truthDist': acc.sumTruthDist,
          'estDist': acc.sumEstDist,
          'scenarioCount': acc.scenarioCount,
          'sampleWeightedRmse': acc.sampleWeightedRMSE(),
          'scenarioWeightedRmse': acc.scenarioWeightedRMSE(),
          'biasPercent': acc.biasPercent(totalRouteDist),
        };
      }

      double rateSse = 0.0;
      int rateCount = 0;
      double rateTruth = 0.0;
      double rateEst = 0.0;
      final rateGroups = <String, Map<String, dynamic>>{};
      for (final sr in samplingRates) {
        final acc = rateAcc[sr.name] ?? MetricAccumulator();
        rateSse += acc.sumSqErr;
        rateCount += acc.sumCount;
        rateTruth += acc.sumTruthDist;
        rateEst += acc.sumEstDist;
        rateGroups[sr.name] = {
          'sse': acc.sumSqErr,
          'count': acc.sumCount,
          'truthDist': acc.sumTruthDist,
          'estDist': acc.sumEstDist,
          'scenarioCount': acc.scenarioCount,
          'sampleWeightedRmse': acc.sampleWeightedRMSE(),
          'scenarioWeightedRmse': acc.scenarioWeightedRMSE(),
          'biasPercent': acc.biasPercent(totalRouteDist),
        };
      }

      final double noiseRecomputedRmseSq = noiseSse / noiseCount;
      final double noiseRecomputedBias = (noiseEst - noiseTruth) / noiseTruth * 100.0;
      final double speedRecomputedRmseSq = speedSse / speedCount;
      final double speedRecomputedBias = (speedEst - speedTruth) / speedTruth * 100.0;
      final double rateRecomputedRmseSq = rateSse / rateCount;
      final double rateRecomputedBias = (rateEst - rateTruth) / rateTruth * 100.0;

      // Mathematical invariants evaluation
      const double tol = 1e-4;
      final bool noiseMatch = (noiseSse - globalSse).abs() < tol &&
          noiseCount == globalCount &&
          (noiseTruth - globalTruth).abs() < tol &&
          (noiseEst - globalEst).abs() < tol;

      final bool speedMatch = (speedSse - globalSse).abs() < tol &&
          speedCount == globalCount &&
          (speedTruth - globalTruth).abs() < tol &&
          (speedEst - globalEst).abs() < tol;

      final bool rateMatch = (rateSse - globalSse).abs() < tol &&
          rateCount == globalCount &&
          (rateTruth - globalTruth).abs() < tol &&
          (rateEst - globalEst).abs() < tol;

      final bool rmseMatch = (noiseRecomputedRmseSq - globalRmseSq).abs() < 1e-6 &&
          (speedRecomputedRmseSq - globalRmseSq).abs() < 1e-6 &&
          (rateRecomputedRmseSq - globalRmseSq).abs() < 1e-6;

      final bool biasMatch = (noiseRecomputedBias - globalBias).abs() < 1e-6 &&
          (speedRecomputedBias - globalBias).abs() < 1e-6 &&
          (rateRecomputedBias - globalBias).abs() < 1e-6;

      // Residuals calculation
      final residuals = {
        'noise': {
          'sseResidual': (noiseSse - globalSse).abs(),
          'countResidual': (noiseCount - globalCount).abs(),
          'truthDistResidual': (noiseTruth - globalTruth).abs(),
          'estDistResidual': (noiseEst - globalEst).abs(),
          'rmseSqResidual': (noiseRecomputedRmseSq - globalRmseSq).abs(),
          'biasResidual': (noiseRecomputedBias - globalBias).abs(),
        },
        'speed': {
          'sseResidual': (speedSse - globalSse).abs(),
          'countResidual': (speedCount - globalCount).abs(),
          'truthDistResidual': (speedTruth - globalTruth).abs(),
          'estDistResidual': (speedEst - globalEst).abs(),
          'rmseSqResidual': (speedRecomputedRmseSq - globalRmseSq).abs(),
          'biasResidual': (speedRecomputedBias - globalBias).abs(),
        },
        'rate': {
          'sseResidual': (rateSse - globalSse).abs(),
          'countResidual': (rateCount - globalCount).abs(),
          'truthDistResidual': (rateTruth - globalTruth).abs(),
          'estDistResidual': (rateEst - globalEst).abs(),
          'rmseSqResidual': (rateRecomputedRmseSq - globalRmseSq).abs(),
          'biasResidual': (rateRecomputedBias - globalBias).abs(),
        },
      };

      // Gather JSON report.
      String commitSha;
      try {
        final result = Process.runSync('git', ['rev-parse', 'HEAD']);
        if (result.exitCode == 0) {
          commitSha = result.stdout.toString().trim();
        } else {
          commitSha = Platform.environment['GITHUB_SHA'] ?? 'unknown';
        }
      } catch (_) {
        commitSha = Platform.environment['GITHUB_SHA'] ?? 'unknown';
      }

      final report = {
        'schemaVersion': '1.0',
        'commitSha': commitSha,
        'global': {
          'sse': globalSse,
          'count': globalCount,
          'truthDist': globalTruth,
          'estDist': globalEst,
          'rmse': globalRmse,
          'rmseSq': globalRmseSq,
          'biasPercent': globalBias,
        },
        'stratifications': {
          'noise': {
            'sse': noiseSse,
            'count': noiseCount,
            'truthDist': noiseTruth,
            'estDist': noiseEst,
            'recomputedRmseSq': noiseRecomputedRmseSq,
            'recomputedBiasPercent': noiseRecomputedBias,
            'groups': noiseGroups,
          },
          'speed': {
            'sse': speedSse,
            'count': speedCount,
            'truthDist': speedTruth,
            'estDist': speedEst,
            'recomputedRmseSq': speedRecomputedRmseSq,
            'recomputedBiasPercent': speedRecomputedBias,
            'groups': speedGroups,
          },
          'rate': {
            'sse': rateSse,
            'count': rateCount,
            'truthDist': rateTruth,
            'estDist': rateEst,
            'recomputedRmseSq': rateRecomputedRmseSq,
            'recomputedBiasPercent': rateRecomputedBias,
            'groups': rateGroups,
          },
        },
        'residuals': residuals,
        'invariants': {
          'noiseMatch': noiseMatch,
          'speedMatch': speedMatch,
          'rateMatch': rateMatch,
          'rmseMatch': rmseMatch,
          'biasMatch': biasMatch,
        },
      };

      // Ensure artifact directory exists.
      final artifactDir = Directory('test/artifacts');
      if (!artifactDir.existsSync()) artifactDir.createSync(recursive: true);
      File('test/artifacts/metric_accumulator_report.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));

      // Emit summary for debugging.
      print('--- MetricAccumulator verification completed. Invariants: noise=$noiseMatch, speed=$speedMatch, rate=$rateMatch, rmse=$rmseMatch, bias=$biasMatch');

      // Assert Mathematical Invariants (Task 2)
      // 1. Group scheduled count must equal 75,600 and match D+Opt global count
      expect(globalCount, equals(75600), reason: 'D+Opt total scheduled points must equal 75,600');
      expect(noiseCount, equals(75600), reason: 'Noise group scheduled count must equal 75,600');
      expect(speedCount, equals(75600), reason: 'Speed group scheduled count must equal 75,600');
      expect(rateCount, equals(75600), reason: 'Sampling rate group scheduled count must equal 75,600');

      // 2. Group SSE must equal D+Opt global SSE
      expect(noiseSse, closeTo(globalSse, tol), reason: 'Noise group SSE must equal D+Opt global SSE');
      expect(speedSse, closeTo(globalSse, tol), reason: 'Speed group SSE must equal D+Opt global SSE');
      expect(rateSse, closeTo(globalSse, tol), reason: 'Sampling rate group SSE must equal D+Opt global SSE');

      // 3. Group truth and estimated distance totals must equal D+Opt totals
      expect(noiseTruth, closeTo(globalTruth, tol), reason: 'Noise group truth distance must equal D+Opt global truth distance');
      expect(speedTruth, closeTo(globalTruth, tol), reason: 'Speed group truth distance must equal D+Opt total truth distance');
      expect(rateTruth, closeTo(globalTruth, tol), reason: 'Sampling rate group truth distance must equal D+Opt global truth distance');

      expect(noiseEst, closeTo(globalEst, tol), reason: 'Noise group estimated distance must equal D+Opt total estimated distance');
      expect(speedEst, closeTo(globalEst, tol), reason: 'Speed group estimated distance must equal D+Opt total estimated distance');
      expect(rateEst, closeTo(globalEst, tol), reason: 'Sampling rate group estimated distance must equal D+Opt total estimated distance');

      // 4. Recomputed RMSE² and signed bias must agree with direct global calculations
      expect(noiseRecomputedRmseSq, closeTo(globalRmseSq, 1e-6), reason: 'Noise recomputed RMSE² must agree with global RMSE²');
      expect(speedRecomputedRmseSq, closeTo(globalRmseSq, 1e-6), reason: 'Speed recomputed RMSE² must agree with global RMSE²');
      expect(rateRecomputedRmseSq, closeTo(globalRmseSq, 1e-6), reason: 'Sampling rate recomputed RMSE² must agree with global RMSE²');

      expect(noiseRecomputedBias, closeTo(globalBias, 1e-6), reason: 'Noise recomputed signed bias must agree with global bias');
      expect(speedRecomputedBias, closeTo(globalBias, 1e-6), reason: 'Speed recomputed signed bias must agree with global bias');
      expect(rateRecomputedBias, closeTo(globalBias, 1e-6), reason: 'Sampling rate recomputed signed bias must agree with global bias');

      // 5. Invariant flags must be true
      expect(noiseMatch, isTrue, reason: 'Noise stratification invariant must be true');
      expect(speedMatch, isTrue, reason: 'Speed stratification invariant must be true');
      expect(rateMatch, isTrue, reason: 'Sampling rate stratification invariant must be true');
      expect(rmseMatch, isTrue, reason: 'RMSE recomposition invariant must be true');
      expect(biasMatch, isTrue, reason: 'Signed bias recomposition invariant must be true');


      // Assert Frozen Baselines Integrity (Task 1)
      expect((d.rmse - 16.37).abs(), lessThan(0.2), reason: 'Config D baseline RMSE must remain 16.37m');
      expect((d.signedBiasPercent - 14.07).abs(), lessThan(0.3), reason: 'Config D baseline distance bias must remain +14.07%');
      expect((dH1H2.rmse - 12.96).abs(), lessThan(0.2), reason: 'Config D+H1+H2 baseline RMSE must remain 12.96m');
      expect((dH1H2.signedBiasPercent - 1.39).abs(), lessThan(0.3), reason: 'Config D+H1+H2 baseline distance bias must remain +1.39%');

      // Assert Mandatory Acceptance Targets for Proposed D+Opt (Task 4)
      expect(dOpt.rmse, lessThan(8.00), reason: 'Proposed D+Opt RMSE must meet < 8.00m');
      expect(dOpt.p95, lessThan(15.00), reason: 'Proposed D+Opt P95 must meet < 15.00m');
      expect(dOpt.availability, greaterThanOrEqualTo(99.00), reason: 'Proposed D+Opt availability must meet >= 99.00%');
      expect(dOpt.grossOvercountPercent, lessThanOrEqualTo(1.00), reason: 'Proposed D+Opt gross overcount must meet <= 1.00%');
      expect(dOpt.grossUndercountPercent, lessThanOrEqualTo(1.00), reason: 'Proposed D+Opt gross undercount must meet <= 1.00%');
      expect(dOpt.signedBiasPercent.abs(), lessThanOrEqualTo(1.00), reason: 'Proposed D+Opt absolute signed bias must meet <= 1.00%');
      expect(dOpt.latencyP95, lessThanOrEqualTo(30.0), reason: 'Proposed D+Opt recovery latency P95 must meet <= 30.0s');
      expect(dOpt.psdPercent, equals(100.0), reason: 'Proposed D+Opt PSD stability must be 100%');
      expect(gateEvaluation.isReleaseAuthorized, isTrue, reason: 'Proposed D+Opt meets all 7 release gate targets');
    });

    test('Task 2: Empirical Analysis of Along-Track Undercount on Turns and Deficit Restoration', () {
      // 1. Single Step on Sharp Turn with Heading Lag / Dropout
      // Vehicle travels 10.0m North-East (bearing 45 deg), while filter heading is North (0 deg)
      final pOrigin = const LatLng(10.738082, 106.625303);
      final pStep = _distance.offset(pOrigin, 10.0, 45.0); // 10.0m at 45 degrees

      final fsmUnrestored = ExperimentalGpsRecoveryStateMachine(
        ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
        enableAlongTrackProjection: true,
        enableBoundedHybridDistance: false,
      );

      final fsmRestored = ExperimentalGpsRecoveryStateMachine(
        ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
        enableAlongTrackProjection: false,
        enableBoundedHybridDistance: true,
      );

      final t0 = DateTime.utc(2026, 10, 15, 8, 0, 0);
      fsmUnrestored.processMeasurement(point: pOrigin, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t0, headingDeg: 0.0, speedMs: 10.0);
      fsmRestored.processMeasurement(point: pOrigin, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t0, headingDeg: 0.0, speedMs: 10.0);

      // Now move 10m at 45 deg, but heading sensor reports 0 deg (45-degree lag)
      final t1 = t0.add(const Duration(seconds: 1));
      fsmUnrestored.processMeasurement(point: pStep, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t1, headingDeg: 0.0, speedMs: 10.0);
      fsmRestored.processMeasurement(point: pStep, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t1, headingDeg: 0.0, speedMs: 10.0);

      final stepUnrestored = fsmUnrestored.accumulatedDistanceMeters;
      final stepRestored = fsmRestored.accumulatedDistanceMeters;

      print('\nSharp 45-Degree Turn Single-Step Evaluation:');
      print('  True Step Displacement: 10.00 m');
      print('  Along-Track Unrestored: ${stepUnrestored.toStringAsFixed(2)} m (Lost ~2.93m due to cos(45°)=0.707)');
      print('  Bounded Hybrid Restored: ${stepRestored.toStringAsFixed(2)} m (Turn deficit restored via curvature weighting)');

      expect(stepUnrestored, lessThan(9.0), reason: 'Unrestored along-track projection suffers severe undercount on 45° turn');
      expect(stepRestored, greaterThan(9.5), reason: 'Bounded hybrid restores geometric turn deficit');

      // 2. Outage Re-Anchor on a Turn (Gap Overlap vs Eradication)
      // Vehicle entered outage heading North (0 deg), re-anchors 40m away South-East (120 deg)
      final fsmGapLegacy = ExperimentalGpsRecoveryStateMachine(
        ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
        enableAlongTrackProjection: true,
        enableGapOverlapCorrection: true,
        enableBoundedHybridDistance: false,
      );

      final fsmGapBounded = ExperimentalGpsRecoveryStateMachine(
        ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
        enableAlongTrackProjection: false,
        enableBoundedHybridDistance: true,
        enableGapOverlapCorrection: true,
        enableAlternativeRollbackRecovery: true,
      );

      fsmGapLegacy.processMeasurement(point: pOrigin, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t0, headingDeg: 0.0, speedMs: 5.0);
      fsmGapBounded.processMeasurement(point: pOrigin, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t0, headingDeg: 0.0, speedMs: 5.0);

      // Force into S2 Loss of Lock
      final outlier = _distance.offset(pOrigin, 500.0, 0.0);
      for (int i = 1; i <= 5; i++) {
        final t = t0.add(Duration(seconds: i));
        fsmGapLegacy.processMeasurement(point: outlier, accuracyMeters: 50.0, timeDeltaSec: 1.0, timestamp: t, headingDeg: 0.0, speedMs: 5.0);
        fsmGapBounded.processMeasurement(point: outlier, accuracyMeters: 50.0, timeDeltaSec: 1.0, timestamp: t, headingDeg: 0.0, speedMs: 5.0);
      }

      // Re-anchor 40m away at bearing 120 deg (cos(120) = -0.5 < 0)
      final reAnchorBase = _distance.offset(pOrigin, 40.0, 120.0);
      for (int i = 6; i <= 8; i++) {
        final t = t0.add(Duration(seconds: i));
        final cand = _distance.offset(reAnchorBase, (i - 6) * 5.0, 120.0);
        fsmGapLegacy.processMeasurement(point: cand, accuracyMeters: 4.0, timeDeltaSec: 1.0, timestamp: t, headingDeg: 120.0, speedMs: 5.0);
        fsmGapBounded.processMeasurement(point: cand, accuracyMeters: 4.0, timeDeltaSec: 1.0, timestamp: t, headingDeg: 120.0, speedMs: 5.0);
      }

      print('\nOutage Re-Anchor across Turn (Bearing 120°, Pre-heading 0°):');
      print('  True Chord Distance: ~40.0 m');
      print('  Legacy H1 Gap Escrow: ${fsmGapLegacy.escrowDistanceMeters.toStringAsFixed(2)} m (Cap cos < 0 completely wiped gap escrow)');
      print('  Bounded Hybrid Gap Escrow: ${fsmGapBounded.escrowDistanceMeters.toStringAsFixed(2)} m (Preserves bridged chord minus S1 inertial)');

      expect(fsmGapLegacy.escrowDistanceMeters, equals(0.0), reason: 'Legacy H1 drops entire gap escrow when re-anchoring behind previous heading');
      expect(fsmGapBounded.escrowDistanceMeters, greaterThan(30.0), reason: 'Bounded hybrid safely escrows gap distance while deducting inertial overlap');
    });

    test('Task 3: S5 Probation Consecutive Rejections Prevents False Rejection Thrashing', () {
      final fsmNoHysteresis = ExperimentalGpsRecoveryStateMachine(
        ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
        enableAlternativeRollbackRecovery: true,
        enableProbationVarianceInflation: true,
        enableProbationConsecutiveRejections: false,
      );

      final fsmWithHysteresis = ExperimentalGpsRecoveryStateMachine(
        ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0),
        enableAlternativeRollbackRecovery: true,
        enableProbationVarianceInflation: true,
        enableProbationConsecutiveRejections: true,
      );

      final t0 = DateTime.utc(2026, 10, 15, 8, 0, 0);
      final p0 = const LatLng(10.738082, 106.625303);

      // Initialize both
      fsmNoHysteresis.processMeasurement(point: p0, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t0, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);
      fsmWithHysteresis.processMeasurement(point: p0, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t0, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);

      // Force into S2 Loss of Lock via 5 consecutive extreme outliers (kRejectionLimitS2 = 5)
      final outlier = _distance.offset(p0, 500.0, 0.0);
      for (int i = 1; i <= 5; i++) {
        final t = t0.add(Duration(seconds: i));
        fsmNoHysteresis.processMeasurement(point: outlier, accuracyMeters: 50.0, timeDeltaSec: 1.0, timestamp: t, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);
        fsmWithHysteresis.processMeasurement(point: outlier, accuracyMeters: 50.0, timeDeltaSec: 1.0, timestamp: t, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);
      }

      expect(fsmNoHysteresis.state, equals(GpsRecoveryState.s2LossOfLock));
      expect(fsmWithHysteresis.state, equals(GpsRecoveryState.s2LossOfLock));

      // Feed 3 coherent candidates to trigger Re-Anchor into S5 probation
      final newLoc = _distance.offset(p0, 30.0, 0.0);
      for (int i = 6; i <= 8; i++) {
        final t = t0.add(Duration(seconds: i));
        final cand = _distance.offset(newLoc, (i - 6) * 5.0, 0.0);
        fsmNoHysteresis.processMeasurement(point: cand, accuracyMeters: 4.0, timeDeltaSec: 1.0, timestamp: t, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);
        fsmWithHysteresis.processMeasurement(point: cand, accuracyMeters: 4.0, timeDeltaSec: 1.0, timestamp: t, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);
      }

      expect(fsmNoHysteresis.state, equals(GpsRecoveryState.s5SafeReset));
      expect(fsmWithHysteresis.state, equals(GpsRecoveryState.s5SafeReset));

      // Inject a single extreme noisy fix during probation (60m offset -> NIS >> G2 and Speed >> 15m/s)
      final t9 = t0.add(const Duration(seconds: 9));
      final noisyFix = _distance.offset(newLoc, 60.0, 90.0); // 60m perpendicular noise
      fsmNoHysteresis.processMeasurement(point: noisyFix, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t9, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);
      fsmWithHysteresis.processMeasurement(point: noisyFix, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t9, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);

      // Without hysteresis, a single NIS rejection instantly executes rollback to S2
      expect(fsmNoHysteresis.state, equals(GpsRecoveryState.s2LossOfLock), reason: 'Single NIS spike triggers instant rollback without hysteresis');
      // With hysteresis, state remains in S5 probation (tolerating 1 isolated spike)
      expect(fsmWithHysteresis.state, equals(GpsRecoveryState.s5SafeReset), reason: '2-rejection hysteresis tolerates single noise spike in S5 probation');

      // Next 3 clean fixes complete probation into S0 (M=3 window)
      final t10 = t0.add(const Duration(seconds: 10));
      final cleanFix = _distance.offset(newLoc, 15.0, 0.0);
      fsmWithHysteresis.processMeasurement(point: cleanFix, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t10, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);
      final t11 = t0.add(const Duration(seconds: 11));
      final cleanFix2 = _distance.offset(newLoc, 20.0, 0.0);
      fsmWithHysteresis.processMeasurement(point: cleanFix2, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t11, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);
      final t12 = t0.add(const Duration(seconds: 12));
      final cleanFix3 = _distance.offset(newLoc, 25.0, 0.0);
      fsmWithHysteresis.processMeasurement(point: cleanFix3, accuracyMeters: 3.0, timeDeltaSec: 1.0, timestamp: t12, headingDeg: 0.0, speedMs: 5.0, hasAuxiliarySensors: true);

      expect(fsmWithHysteresis.state, equals(GpsRecoveryState.s0NormalTracking));
    });
  });
}
