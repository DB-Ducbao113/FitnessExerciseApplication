import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_trace.dart';

const _usage = '''Usage:
  dart run tool/gps_benchmark.dart --activity cycling --input <raw.jsonl> --output <report.json>
''';
const _algorithmVersion = 'phase4a-adaptive-q-turn-motion';
const _measuredLatencyRuns = 5;

Future<int> runGpsBenchmarkCli(
  List<String> arguments, {
  StringSink? stdoutSink,
  StringSink? stderrSink,
}) async {
  final out = stdoutSink ?? stdout;
  final err = stderrSink ?? stderr;

  try {
    final options = _GpsBenchmarkCliOptions.parse(arguments);
    if (options.showHelp) {
      out.write(_usage);
      return 0;
    }

    final inputFile = File(options.inputPath!);
    final trace = const FieldGpsTraceParser().parseLines(
      await inputFile.readAsLines(),
    );
    const runner = FieldGpsBenchmarkRunner();
    final variants = GpsPipelineVariant.values.toSet();
    runner.run(
      trace,
      variants: variants,
    ); // Warm-up is deliberately unmeasured.
    final measuredReports = List<FieldGpsBenchmarkReport>.generate(
      _measuredLatencyRuns,
      (_) => runner.run(trace, variants: variants),
      growable: false,
    );
    final report = measuredReports.last;
    final latencyByVariant = {
      for (final variant in GpsPipelineVariant.values)
        variant: _latencyMetrics(
          measuredReports
              .map(
                (measured) =>
                    measured.results[variant]!.processingMicrosecondsPerPoint,
              )
              .toList(growable: false),
        ),
    };
    final outputFile = File(options.outputPath!);
    final traceOutputFile = File('${outputFile.path}.trace.jsonl');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        _reportToJson(
          report,
          latencyByVariant: latencyByVariant,
          generatedAtUtc: DateTime.now().toUtc(),
        ),
      ),
      flush: true,
    );
    await traceOutputFile.writeAsString(
      _traceRows(trace, report).map(jsonEncode).join('\n'),
      flush: true,
    );
    out.writeln('GPS benchmark report written to ${outputFile.path}');
    out.writeln('Timestamp trace written to ${traceOutputFile.path}');
    return 0;
  } on _GpsBenchmarkUsageException catch (error) {
    err.writeln(error.message);
    err.write(_usage);
    return 64;
  } on FieldGpsTraceParseException catch (error) {
    err.writeln(error);
    return 65;
  } on FileSystemException catch (error) {
    err.writeln('File error: ${error.message} (${error.path ?? 'unknown'})');
    return 66;
  } catch (error) {
    err.writeln('Benchmark failed: $error');
    return 70;
  }
}

Map<String, Object?> _reportToJson(
  FieldGpsBenchmarkReport report, {
  required Map<GpsPipelineVariant, _LatencyMetrics> latencyByVariant,
  required DateTime generatedAtUtc,
}) {
  return {
    'schema_version': 2,
    'evidence_kind': 'field_development_no_ground_truth',
    'algorithm_version': _algorithmVersion,
    'config_fingerprint': _configFingerprint(),
    'dataset_id': report.workoutId,
    'generated_at_utc': generatedAtUtc.toIso8601String(),
    'workout_id': report.workoutId,
    'source_line_count': report.sourceLineCount,
    'input_point_count': report.inputPointCount,
    'duplicate_timestamp_count': report.duplicateTimestampCount,
    'raw_sampling_availability_percent': report.rawSamplingAvailabilityPercent,
    'gaps_over_2_seconds': report.gapsOverTwoSeconds,
    'gaps_over_5_seconds': report.gapsOverFiveSeconds,
    'maximum_gap_seconds': report.maximumGapSeconds,
    'reported_accuracy_meters': {
      'meaning': 'device_reported_uncertainty_not_ground_truth_error',
      'mean': report.reportedAccuracy.meanMeters,
      'p50': report.reportedAccuracy.p50Meters,
      'p95': report.reportedAccuracy.p95Meters,
    },
    'variants': {
      for (final entry in report.results.entries)
        _variantName(entry.key): _variantToJson(
          entry.value,
          latencyByVariant[entry.key]!,
        ),
    },
  };
}

Map<String, Object?> _variantToJson(
  FieldGpsVariantResult result,
  _LatencyMetrics latency,
) {
  return {
    'accepted_point_count': result.acceptedPointCount,
    'display_point_count': result.displayPointCount,
    'rejected_point_count': result.rejectedPointCount,
    'accepted_availability_percent': result.acceptedAvailabilityPercent,
    'app_distance_meters': result.appDistanceMeters,
    'display_distance_meters': result.displayDistanceMeters,
    'processing_microseconds_per_point': result.processingMicrosecondsPerPoint,
    'processing_latency': {
      'warm_up_run_count': 1,
      'measured_run_count': _measuredLatencyRuns,
      'median_microseconds_per_point': latency.medianMicrosecondsPerPoint,
      'p95_microseconds_per_point': latency.p95MicrosecondsPerPoint,
    },
    'rejection_counts': result.rejectionCounts,
    'detected_dwell_cluster_count': result.detectedDwellClusterCount,
    'collapsed_dwell_point_count': result.collapsedDwellPointCount,
    'phantom_drift_removed_meters': result.phantomDriftRemovedMeters,
    if (result.positionDecisionCounts.isNotEmpty)
      'position_decision_counts': {
        for (final entry in result.positionDecisionCounts.entries)
          entry.key.name: entry.value,
      },
  };
}

Iterable<Map<String, Object?>> _traceRows(
  FieldGpsTrace trace,
  FieldGpsBenchmarkReport report,
) sync* {
  final outputByVariant = {
    for (final entry in report.results.entries)
      entry.key: {
        for (final point in entry.value.outputPoints) point.timestamp: point,
      },
  };
  final validationRejections =
      report.results[GpsPipelineVariant.current]!.rejectionReasonByTimestamp;
  for (final sample in trace.samples) {
    final timestamp = sample.timestamp.toUtc();
    yield {
      'dataset_id': report.workoutId,
      'timestamp': timestamp.toIso8601String(),
      'rejection_reason': validationRejections[timestamp],
      'variants': {
        for (final variant in GpsPipelineVariant.values)
          _variantName(variant): _traceVariantRow(
            outputByVariant[variant]![timestamp],
          ),
      },
    };
  }
}

Map<String, Object?> _traceVariantRow(BenchmarkGpsPoint? point) {
  final diagnostics = point?.ekfDiagnostics;
  return {
    'output_present': point != null,
    'starts_new_segment': point?.startsNewSegment,
    'position_innovation_meters': diagnostics?.positionInnovationMeters,
    'position_nis': diagnostics?.positionNis,
    'position_decision': diagnostics?.positionDecision.name,
    'effective_position_variance': diagnostics?.effectivePositionVariance,
    'speed_innovation_ms': diagnostics?.speedInnovationMs,
    'heading_innovation_rad': diagnostics?.headingInnovationRad,
    'turn_detected': diagnostics?.turnDetected,
    'heading_delta_rad': diagnostics?.headingDeltaRad,
    'position_process_variance': diagnostics?.positionProcessVariance,
    'speed_process_variance': diagnostics?.speedProcessVariance,
    'heading_process_variance': diagnostics?.headingProcessVariance,
    'effective_time_delta_seconds': diagnostics?.effectiveTimeDeltaSec,
    'time_delta_was_sanitized': diagnostics?.timeDeltaWasSanitized,
    'covariance_correction_applied': diagnostics?.covarianceCorrectionApplied,
  };
}

_LatencyMetrics _latencyMetrics(List<double> values) {
  final sorted = List<double>.of(values)..sort();
  return _LatencyMetrics(
    medianMicrosecondsPerPoint: _percentile(sorted, 0.50),
    p95MicrosecondsPerPoint: _percentile(sorted, 0.95),
  );
}

double _percentile(List<double> sortedValues, double percentile) {
  final position = (sortedValues.length - 1) * percentile;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sortedValues[lower];
  final fraction = position - lower;
  return sortedValues[lower] * (1 - fraction) + sortedValues[upper] * fraction;
}

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

String _variantName(GpsPipelineVariant variant) {
  return switch (variant) {
    GpsPipelineVariant.current => 'current',
    GpsPipelineVariant.ekf => 'ekf',
    GpsPipelineVariant.dbscan => 'dbscan',
    GpsPipelineVariant.ekfThenDbscan => 'ekf_then_dbscan',
  };
}

class _GpsBenchmarkCliOptions {
  final String? inputPath;
  final String? outputPath;
  final bool showHelp;

  const _GpsBenchmarkCliOptions({
    required this.inputPath,
    required this.outputPath,
    required this.showHelp,
  });

  factory _GpsBenchmarkCliOptions.parse(List<String> arguments) {
    if (arguments.contains('--help') || arguments.contains('-h')) {
      return const _GpsBenchmarkCliOptions(
        inputPath: null,
        outputPath: null,
        showHelp: true,
      );
    }

    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      if (!const {'--activity', '--input', '--output'}.contains(argument)) {
        throw _GpsBenchmarkUsageException('Unknown argument: $argument');
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('-')) {
        throw _GpsBenchmarkUsageException('Missing value for $argument');
      }
      values[argument] = arguments[index + 1];
      index += 1;
    }

    if (values['--activity'] != 'cycling') {
      throw const _GpsBenchmarkUsageException(
        '--activity cycling is required in Chặng A',
      );
    }
    final inputPath = values['--input'];
    final outputPath = values['--output'];
    if (inputPath == null || outputPath == null) {
      throw const _GpsBenchmarkUsageException(
        '--input and --output are required',
      );
    }
    return _GpsBenchmarkCliOptions(
      inputPath: inputPath,
      outputPath: outputPath,
      showHelp: false,
    );
  }
}

class _GpsBenchmarkUsageException implements Exception {
  final String message;

  const _GpsBenchmarkUsageException(this.message);
}

class _LatencyMetrics {
  final double medianMicrosecondsPerPoint;
  final double p95MicrosecondsPerPoint;

  const _LatencyMetrics({
    required this.medianMicrosecondsPerPoint,
    required this.p95MicrosecondsPerPoint,
  });
}
