import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_trace_factory.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 || arguments.first != '--output') {
    stderr.writeln(
      'Usage: dart run tool/gps_ekf_parameter_search.dart --output <scores.json>',
    );
    exitCode = 64;
    return;
  }

  const factory = SyntheticGpsTraceFactory();
  final trace = factory.urbanCycling(
    startedAt: DateTime.utc(2026, 10, 15),
    duration: const Duration(minutes: 30),
  );
  final candidates = <Map<String, Object?>>[];
  for (final positionAccuracyScale in const [0.6, 0.75, 0.9, 1.0]) {
    for (final processPosStd in const [0.35, 0.5, 0.75]) {
      for (final processSpeedStd in const [0.8, 1.2]) {
        for (final processHeadingStd in const [0.25, 0.35, 0.5]) {
          for (final turnScale in const [6.0, 10.0, 14.0]) {
            final config = EkfBenchmarkConfig(
              processPosStd: processPosStd,
              processSpeedStd: processSpeedStd,
              processHeadingStd: processHeadingStd,
              positionAccuracyScale: positionAccuracyScale,
              maxTurnHeadingNoiseScale: turnScale,
            );
            final report = SyntheticGpsBenchmarkRunner(ekfConfig: config).run(
              trace,
              variantsToRun: const {
                GpsPipelineVariant.current,
                GpsPipelineVariant.ekf,
              },
            );
            final baseline = report.currentSmoothing;
            final candidate = report.variants[GpsPipelineVariant.ekf]!;
            final metrics = candidate.metrics;
            final baselineTurn = report
                .variants[GpsPipelineVariant.current]!
                .metricsByPhase[SyntheticSamplePhase.turn]!;
            final candidateTurn =
                candidate.metricsByPhase[SyntheticSamplePhase.turn]!;
            final baselineGap = report
                .variants[GpsPipelineVariant.current]!
                .metricsByPhase[SyntheticSamplePhase.gapRecovery]!;
            final candidateGap =
                candidate.metricsByPhase[SyntheticSamplePhase.gapRecovery]!;
            final passesGate =
                metrics.p95ErrorMeters <= baseline.p95ErrorMeters * 0.85 &&
                metrics.rmseMeters <= baseline.rmseMeters * 0.90 &&
                metrics.distanceErrorMeters.abs() <=
                    baseline.distanceErrorMeters.abs() &&
                metrics.availabilityPercent >=
                    baseline.availabilityPercent - 2.0 &&
                candidateTurn.p95ErrorMeters <=
                    baselineTurn.p95ErrorMeters * 1.05 &&
                candidateGap.p95ErrorMeters <=
                    baselineGap.p95ErrorMeters * 1.05;
            candidates.add({
              'config': {
                'position_accuracy_scale': positionAccuracyScale,
                'process_pos_std': processPosStd,
                'process_speed_std': processSpeedStd,
                'process_heading_std': processHeadingStd,
                'max_turn_heading_noise_scale': turnScale,
              },
              'passes_gate': passesGate,
              'p95_meters': metrics.p95ErrorMeters,
              'rmse_meters': metrics.rmseMeters,
              'distance_error_meters': metrics.distanceErrorMeters,
              'availability_percent': metrics.availabilityPercent,
              'turn_p95_meters': candidateTurn.p95ErrorMeters,
              'gap_recovery_p95_meters': candidateGap.p95ErrorMeters,
            });
          }
        }
      }
    }
  }
  candidates.sort((first, second) {
    final p95Comparison = (first['p95_meters']! as double).compareTo(
      second['p95_meters']! as double,
    );
    if (p95Comparison != 0) return p95Comparison;
    return (first['rmse_meters']! as double).compareTo(
      second['rmse_meters']! as double,
    );
  });

  final output = File(arguments.last);
  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'schema_version': 1,
      'evidence_kind': 'synthetic_development_parameter_search',
      'candidate_count': candidates.length,
      'passing_candidate_count': candidates
          .where((candidate) => candidate['passes_gate'] == true)
          .length,
      'candidates': candidates,
    }),
    flush: true,
  );
  stdout.writeln('EKF parameter search written to ${output.path}');
}
