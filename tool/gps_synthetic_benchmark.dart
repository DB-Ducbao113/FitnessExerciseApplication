import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_trace_factory.dart';
import 'package:latlong2/latlong.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 || arguments.first != '--output') {
    stderr.writeln(
      'Usage: dart run tool/gps_synthetic_benchmark.dart --output <report.json>',
    );
    exitCode = 64;
    return;
  }

  const factory = SyntheticGpsTraceFactory();
  const runner = SyntheticGpsBenchmarkRunner();
  final startedAt = DateTime.utc(2026, 10, 15);
  final reports = {
    'stationary_10_minutes': runner.run(
      factory.stationary(
        startedAt: startedAt,
        center: const LatLng(10.7380, 106.6252),
        duration: const Duration(minutes: 10),
      ),
    ),
    'urban_cycling_30_minutes': runner.run(
      factory.urbanCycling(
        startedAt: startedAt,
        duration: const Duration(minutes: 30),
      ),
    ),
  };
  final output = File(arguments.last);
  final traceOutput = File('${output.path}.trace.jsonl');
  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'schema_version': 3,
      'evidence_kind': 'synthetic_development',
      'algorithm_version': 'phase3-nis-adaptive-covariance',
      'config_fingerprint': _configFingerprint(),
      'dataset_id': 'phase1-synthetic-suite-v1',
      'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'warning': 'simulation_result_not_field_accuracy',
      'scenarios': {
        for (final entry in reports.entries)
          entry.key: {
            'raw': _metrics(entry.value.raw),
            'variants': {
              for (final variant in entry.value.variants.entries)
                _variantName(variant.key): {
                  ..._metrics(variant.value.metrics),
                  'rejected_point_count': variant.value.rejectedPointCount,
                  'rejection_counts': variant.value.rejectionCounts,
                  'detected_dwell_cluster_count':
                      variant.value.detectedDwellClusterCount,
                  'collapsed_dwell_point_count':
                      variant.value.collapsedDwellPointCount,
                  'metrics_by_phase': {
                    for (final phase in variant.value.metricsByPhase.entries)
                      phase.key.name: {
                        'sample_count': phase.value.sampleCount,
                        'rmse_meters': phase.value.rmseMeters,
                        'p95_error_meters': phase.value.p95ErrorMeters,
                      },
                  },
                  'top_five_percent_errors': variant.value.topFivePercentErrors
                      .map(
                        (sample) => {
                          'timestamp': sample.timestamp.toIso8601String(),
                          'error_meters': sample.errorMeters,
                          'phase': sample.phase.name,
                        },
                      )
                      .toList(growable: false),
                  'position_decision_counts': {
                    for (final decision
                        in variant.value.positionDecisionCounts.entries)
                      decision.key.name: decision.value,
                  },
                },
            },
          },
      },
    }),
    flush: true,
  );
  await traceOutput.writeAsString(
    reports.entries
        .expand(
          (report) => report.value.samples.map(
            (sample) => jsonEncode({
              'scenario': report.key,
              'timestamp': sample.timestamp.toUtc().toIso8601String(),
              'phase': sample.phase.name,
              'heading_delta_degrees': sample.headingDeltaDegrees,
              'is_injected_outlier': sample.isInjectedOutlier,
              'variants': {
                for (final variant in sample.variantSamples.entries)
                  _variantName(variant.key): {
                    'error_meters': variant.value.errorMeters,
                    'rejection_reason': variant.value.rejectionReason,
                    'position_innovation_meters':
                        variant.value.diagnostics.positionInnovationMeters,
                    'position_nis': variant.value.diagnostics.positionNis,
                    'position_decision':
                        variant.value.diagnostics.positionDecision.name,
                    'effective_position_variance':
                        variant.value.diagnostics.effectivePositionVariance,
                    'speed_innovation_ms':
                        variant.value.diagnostics.speedInnovationMs,
                    'heading_innovation_rad':
                        variant.value.diagnostics.headingInnovationRad,
                    'turn_detected': variant.value.diagnostics.turnDetected,
                    'heading_delta_rad':
                        variant.value.diagnostics.headingDeltaRad,
                    'heading_process_variance':
                        variant.value.diagnostics.headingProcessVariance,
                    'speed_process_variance':
                        variant.value.diagnostics.speedProcessVariance,
                    'position_process_variance':
                        variant.value.diagnostics.positionProcessVariance,
                    'effective_time_delta_seconds':
                        variant.value.diagnostics.effectiveTimeDeltaSec,
                    'time_delta_was_sanitized':
                        variant.value.diagnostics.timeDeltaWasSanitized,
                    'covariance_correction_applied':
                        variant.value.diagnostics.covarianceCorrectionApplied,
                  },
              },
            }),
          ),
        )
        .join('\n'),
    flush: true,
  );
  stdout.writeln('Synthetic GPS benchmark written to ${output.path}');
  stdout.writeln('Detailed timestamp trace written to ${traceOutput.path}');
}

Map<String, Object> _metrics(SyntheticPositionMetrics metrics) => {
  'sample_count': metrics.sampleCount,
  'availability_percent': metrics.availabilityPercent,
  'rmse_meters': metrics.rmseMeters,
  'p50_error_meters': metrics.p50ErrorMeters,
  'p95_error_meters': metrics.p95ErrorMeters,
  'mean_east_bias_meters': metrics.meanEastBiasMeters,
  'mean_north_bias_meters': metrics.meanNorthBiasMeters,
  'estimated_distance_meters': metrics.estimatedDistanceMeters,
  'ground_truth_distance_meters': metrics.groundTruthDistanceMeters,
  'distance_error_meters': metrics.distanceErrorMeters,
  'distance_error_percent': metrics.distanceErrorPercent,
  'absolute_distance_error_meters': metrics.distanceErrorMeters.abs(),
  'absolute_distance_error_percent': metrics.distanceErrorPercent.abs(),
};

String _configFingerprint() {
  const config = EkfBenchmarkConfig();
  final canonical = [
    'baseline=live-cycling-v1',
    'processPosStd=${config.processPosStd}',
    'processSpeedStd=${config.processSpeedStd}',
    'processHeadingStd=${config.processHeadingStd}',
    'positionAccuracyScale=${config.positionAccuracyScale}',
    'maxTurnHeadingNoiseScale=${config.maxTurnHeadingNoiseScale}',
  ].join('|');
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(canonical)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 'fnv1a32-${hash.toRadixString(16).padLeft(8, '0')}';
}

String _variantName(GpsPipelineVariant variant) => switch (variant) {
  GpsPipelineVariant.current => 'current',
  GpsPipelineVariant.ekf => 'ekf',
  GpsPipelineVariant.dbscan => 'dbscan',
  GpsPipelineVariant.ekfThenDbscan => 'ekf_then_dbscan',
};
