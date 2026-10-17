import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_trace.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_trace_factory.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:latlong2/latlong.dart';

enum SyntheticSamplePhase { straight, turn, gapRecovery, outlier, dwell }

/// Horizontal position and distance metrics against synthetic ground truth.
class SyntheticPositionMetrics {
  final int sampleCount;
  final double availabilityPercent;
  final double rmseMeters;
  final double p50ErrorMeters;
  final double p95ErrorMeters;
  final double meanEastBiasMeters;
  final double meanNorthBiasMeters;
  final double estimatedDistanceMeters;
  final double groundTruthDistanceMeters;
  final double distanceErrorMeters;
  final double distanceErrorPercent;

  const SyntheticPositionMetrics({
    required this.sampleCount,
    required this.availabilityPercent,
    required this.rmseMeters,
    required this.p50ErrorMeters,
    required this.p95ErrorMeters,
    required this.meanEastBiasMeters,
    required this.meanNorthBiasMeters,
    required this.estimatedDistanceMeters,
    required this.groundTruthDistanceMeters,
    required this.distanceErrorMeters,
    required this.distanceErrorPercent,
  });
}

class SyntheticPipelineResult {
  final GpsPipelineVariant variant;
  final SyntheticPositionMetrics metrics;
  final int rejectedPointCount;
  final Map<String, int> rejectionCounts;
  final int detectedDwellClusterCount;
  final int collapsedDwellPointCount;
  final Map<SyntheticSamplePhase, SyntheticPhaseMetrics> metricsByPhase;
  final List<SyntheticTopErrorSample> topFivePercentErrors;
  final Map<EkfMeasurementDecision, int> positionDecisionCounts;

  const SyntheticPipelineResult({
    required this.variant,
    required this.metrics,
    required this.rejectedPointCount,
    required this.rejectionCounts,
    required this.detectedDwellClusterCount,
    required this.collapsedDwellPointCount,
    required this.metricsByPhase,
    required this.topFivePercentErrors,
    required this.positionDecisionCounts,
  });
}

class SyntheticPhaseMetrics {
  final int sampleCount;
  final double rmseMeters;
  final double p95ErrorMeters;

  const SyntheticPhaseMetrics({
    required this.sampleCount,
    required this.rmseMeters,
    required this.p95ErrorMeters,
  });
}

class SyntheticTopErrorSample {
  final DateTime timestamp;
  final double errorMeters;
  final SyntheticSamplePhase phase;
  final EkfUpdateDiagnostics diagnostics;

  const SyntheticTopErrorSample({
    required this.timestamp,
    required this.errorMeters,
    required this.phase,
    required this.diagnostics,
  });
}

class SyntheticVariantBenchmarkSample {
  final LatLng? estimatedPosition;
  final double? errorMeters;
  final String? rejectionReason;
  final EkfUpdateDiagnostics diagnostics;

  const SyntheticVariantBenchmarkSample({
    required this.estimatedPosition,
    required this.errorMeters,
    required this.rejectionReason,
    required this.diagnostics,
  });
}

/// One exportable row for auditing the current-pipeline synthetic result.
class SyntheticGpsBenchmarkSample {
  final DateTime timestamp;
  final LatLng groundTruth;
  final LatLng rawMeasurement;
  final LatLng currentSmoothedPosition;
  final double rawErrorMeters;
  final double currentErrorMeters;
  final double reportedAccuracyMeters;
  final double speedMs;
  final bool isInjectedOutlier;
  final SyntheticSamplePhase phase;
  final double headingDeltaDegrees;
  final Map<GpsPipelineVariant, SyntheticVariantBenchmarkSample> variantSamples;

  const SyntheticGpsBenchmarkSample({
    required this.timestamp,
    required this.groundTruth,
    required this.rawMeasurement,
    required this.currentSmoothedPosition,
    required this.rawErrorMeters,
    required this.currentErrorMeters,
    required this.reportedAccuracyMeters,
    required this.speedMs,
    required this.isInjectedOutlier,
    required this.phase,
    required this.headingDeltaDegrees,
    required this.variantSamples,
  });

  bool get isSynthetic => true;
}

/// A local-only result. It must not be presented as field evidence.
class SyntheticGpsBenchmarkReport {
  final SyntheticGpsScenario scenario;
  final SyntheticPositionMetrics raw;
  final Map<GpsPipelineVariant, SyntheticPipelineResult> variants;
  final List<SyntheticGpsBenchmarkSample> samples;

  const SyntheticGpsBenchmarkReport({
    required this.scenario,
    required this.raw,
    required this.variants,
    required this.samples,
  });

  bool get isSynthetic => true;

  SyntheticPositionMetrics get currentSmoothing =>
      variants[GpsPipelineVariant.current]!.metrics;
}

/// Replays all approved pipelines against deterministic synthetic ground truth.
class SyntheticGpsBenchmarkRunner {
  final EkfBenchmarkConfig ekfConfig;

  const SyntheticGpsBenchmarkRunner({
    this.ekfConfig = const EkfBenchmarkConfig(),
  });

  static const Distance _distance = Distance(roundResult: false);

  SyntheticGpsBenchmarkReport run(
    SyntheticGpsTrace trace, {
    Set<GpsPipelineVariant> variantsToRun = const {
      GpsPipelineVariant.current,
      GpsPipelineVariant.ekf,
      GpsPipelineVariant.dbscan,
      GpsPipelineVariant.ekfThenDbscan,
    },
  }) {
    final fieldTrace = _asFieldTrace(trace);
    final replay = FieldGpsBenchmarkRunner(
      ekfConfig: ekfConfig,
    ).run(fieldTrace, variants: variantsToRun);
    final truthByTimestamp = {
      for (final point in trace.points)
        point.timestamp.toUtc(): point.groundTruth,
    };
    final phases = _classifyPhases(trace.points);
    final headingDeltas = _headingDeltas(trace.points);
    final outputByVariant = {
      for (final entry in replay.results.entries)
        entry.key: {
          for (final point in entry.value.outputPoints) point.timestamp: point,
        },
    };
    final variants = <GpsPipelineVariant, SyntheticPipelineResult>{};
    for (final entry in replay.results.entries) {
      final errorSamples = entry.value.outputPoints
          .map((point) {
            final truth = truthByTimestamp[point.timestamp]!;
            return SyntheticTopErrorSample(
              timestamp: point.timestamp,
              errorMeters: _distance.distance(point.position, truth),
              phase: phases[point.timestamp]!,
              diagnostics: point.ekfDiagnostics ?? const EkfUpdateDiagnostics(),
            );
          })
          .toList(growable: false);
      variants[entry.key] = SyntheticPipelineResult(
        variant: entry.key,
        metrics: _metricsForOutput(
          output: entry.value.outputPoints,
          truthByTimestamp: truthByTimestamp,
          availabilityPercent:
              entry.value.acceptedPointCount /
              _expectedSampleCount(trace) *
              100,
        ),
        rejectedPointCount: entry.value.rejectedPointCount,
        rejectionCounts: entry.value.rejectionCounts,
        detectedDwellClusterCount: entry.value.detectedDwellClusterCount,
        collapsedDwellPointCount: entry.value.collapsedDwellPointCount,
        metricsByPhase: _metricsByPhase(errorSamples),
        topFivePercentErrors: _topFivePercent(errorSamples),
        positionDecisionCounts:
            entry.key == GpsPipelineVariant.ekf ||
                entry.key == GpsPipelineVariant.ekfThenDbscan
            ? _positionDecisionCounts(entry.value.outputPoints)
            : const {},
      );
    }

    final currentByTimestamp = {
      for (final point
          in replay.results[GpsPipelineVariant.current]!.outputPoints)
        point.timestamp: point.position,
    };
    final samples = trace.points
        .map((point) {
          final timestamp = point.timestamp.toUtc();
          final current = currentByTimestamp[timestamp] ?? point.rawMeasurement;
          final variantSamples =
              <GpsPipelineVariant, SyntheticVariantBenchmarkSample>{};
          for (final entry in replay.results.entries) {
            final output = outputByVariant[entry.key]![timestamp];
            variantSamples[entry.key] = SyntheticVariantBenchmarkSample(
              estimatedPosition: output?.position,
              errorMeters: output == null
                  ? null
                  : _distance.distance(output.position, point.groundTruth),
              rejectionReason:
                  entry.value.rejectionReasonByTimestamp[timestamp],
              diagnostics:
                  output?.ekfDiagnostics ?? const EkfUpdateDiagnostics(),
            );
          }
          return SyntheticGpsBenchmarkSample(
            timestamp: point.timestamp,
            groundTruth: point.groundTruth,
            rawMeasurement: point.rawMeasurement,
            currentSmoothedPosition: current,
            rawErrorMeters: _distance.distance(
              point.rawMeasurement,
              point.groundTruth,
            ),
            currentErrorMeters: _distance.distance(current, point.groundTruth),
            reportedAccuracyMeters: point.accuracyMeters,
            speedMs: point.speedMs,
            isInjectedOutlier: point.isInjectedOutlier,
            phase: phases[timestamp]!,
            headingDeltaDegrees: headingDeltas[timestamp]!,
            variantSamples: Map.unmodifiable(variantSamples),
          );
        })
        .toList(growable: false);

    final rawOutput = trace.points
        .map(
          (point) => BenchmarkGpsPoint(
            timestamp: point.timestamp.toUtc(),
            position: point.rawMeasurement,
            speedMetersPerSecond: point.speedMs,
            reportedAccuracyMeters: point.accuracyMeters,
            headingDegrees: point.headingDeg,
          ),
        )
        .toList(growable: false);
    return SyntheticGpsBenchmarkReport(
      scenario: trace.scenario,
      raw: _metricsForOutput(
        output: rawOutput,
        truthByTimestamp: truthByTimestamp,
        availabilityPercent:
            rawOutput.length / _expectedSampleCount(trace) * 100,
      ),
      variants: Map.unmodifiable(variants),
      samples: List.unmodifiable(samples),
    );
  }

  Map<DateTime, SyntheticSamplePhase> _classifyPhases(
    List<SyntheticGpsPoint> points,
  ) {
    final phases = <DateTime, SyntheticSamplePhase>{};
    DateTime? recoveryUntil;
    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final timestamp = point.timestamp.toUtc();
      if (index > 0 &&
          point.timestamp.difference(points[index - 1].timestamp).inSeconds >
              5) {
        recoveryUntil = timestamp.add(const Duration(seconds: 5));
      }
      final headingDelta = index == 0
          ? 0.0
          : _headingDelta(points[index - 1].headingDeg, point.headingDeg);
      phases[timestamp] = point.isInjectedOutlier
          ? SyntheticSamplePhase.outlier
          : point.speedMs <= 0.8
          ? SyntheticSamplePhase.dwell
          : recoveryUntil != null && !timestamp.isAfter(recoveryUntil)
          ? SyntheticSamplePhase.gapRecovery
          : headingDelta >= 12.0
          ? SyntheticSamplePhase.turn
          : SyntheticSamplePhase.straight;
    }
    return phases;
  }

  Map<DateTime, double> _headingDeltas(List<SyntheticGpsPoint> points) {
    final deltas = <DateTime, double>{};
    for (var index = 0; index < points.length; index += 1) {
      deltas[points[index].timestamp.toUtc()] = index == 0
          ? 0.0
          : _headingDelta(
              points[index - 1].headingDeg,
              points[index].headingDeg,
            );
    }
    return deltas;
  }

  double _headingDelta(double first, double second) {
    final difference = (first - second).abs() % 360.0;
    return difference > 180.0 ? 360.0 - difference : difference;
  }

  Map<SyntheticSamplePhase, SyntheticPhaseMetrics> _metricsByPhase(
    List<SyntheticTopErrorSample> samples,
  ) {
    final grouped = <SyntheticSamplePhase, List<double>>{};
    for (final sample in samples) {
      grouped
          .putIfAbsent(sample.phase, () => <double>[])
          .add(sample.errorMeters);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: _phaseMetrics(entry.value),
    });
  }

  SyntheticPhaseMetrics _phaseMetrics(List<double> errors) {
    final sorted = List<double>.of(errors)..sort();
    final squareTotal = sorted.fold<double>(
      0.0,
      (total, error) => total + error * error,
    );
    return SyntheticPhaseMetrics(
      sampleCount: sorted.length,
      rmseMeters: math.sqrt(squareTotal / sorted.length),
      p95ErrorMeters: _percentile(sorted, 0.95),
    );
  }

  List<SyntheticTopErrorSample> _topFivePercent(
    List<SyntheticTopErrorSample> samples,
  ) {
    if (samples.isEmpty) return const [];
    final sorted = List<SyntheticTopErrorSample>.of(
      samples,
    )..sort((first, second) => second.errorMeters.compareTo(first.errorMeters));
    final count = math.max(1, (sorted.length * 0.05).ceil());
    return List.unmodifiable(sorted.take(count));
  }

  Map<EkfMeasurementDecision, int> _positionDecisionCounts(
    List<BenchmarkGpsPoint> points,
  ) {
    final counts = <EkfMeasurementDecision, int>{};
    for (final point in points) {
      final diagnostics = point.ekfDiagnostics;
      if (diagnostics == null || diagnostics.positionInnovationMeters == null) {
        continue;
      }
      counts.update(
        diagnostics.positionDecision,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return Map.unmodifiable(counts);
  }

  FieldGpsTrace _asFieldTrace(SyntheticGpsTrace trace) {
    return FieldGpsTrace(
      workoutId: trace.id,
      sourceLineCount: trace.points.length,
      duplicateTimestampCount: 0,
      samples: List.unmodifiable(
        trace.points.map(
          (point) => FieldGpsSample(
            workoutId: trace.id,
            timestamp: point.timestamp.toUtc(),
            position: point.rawMeasurement,
            altitudeMeters: null,
            speedMetersPerSecond: point.speedMs,
            reportedAccuracyMeters: point.accuracyMeters,
            headingDegrees: point.headingDeg,
            deviceSource: 'synthetic',
            confidence: null,
          ),
        ),
      ),
    );
  }

  int _expectedSampleCount(SyntheticGpsTrace trace) {
    if (trace.points.length < 2) return trace.points.length;
    return trace.points.last.timestamp
            .difference(trace.points.first.timestamp)
            .inSeconds +
        1;
  }

  SyntheticPositionMetrics _metricsForOutput({
    required List<BenchmarkGpsPoint> output,
    required Map<DateTime, LatLng> truthByTimestamp,
    required double availabilityPercent,
  }) {
    if (output.isEmpty) {
      return const SyntheticPositionMetrics(
        sampleCount: 0,
        availabilityPercent: 0,
        rmseMeters: 0,
        p50ErrorMeters: 0,
        p95ErrorMeters: 0,
        meanEastBiasMeters: 0,
        meanNorthBiasMeters: 0,
        estimatedDistanceMeters: 0,
        groundTruthDistanceMeters: 0,
        distanceErrorMeters: 0,
        distanceErrorPercent: 0,
      );
    }

    final errors = <double>[];
    var squaredErrorTotal = 0.0;
    var eastBiasTotal = 0.0;
    var northBiasTotal = 0.0;
    var estimatedDistance = 0.0;
    var groundTruthDistance = 0.0;
    for (var index = 0; index < output.length; index += 1) {
      final estimate = output[index];
      final truth = truthByTimestamp[estimate.timestamp]!;
      final error = _distance.distance(estimate.position, truth);
      errors.add(error);
      squaredErrorTotal += error * error;
      eastBiasTotal += _signedEastMeters(truth, estimate.position);
      northBiasTotal += _signedNorthMeters(truth, estimate.position);
      if (index > 0 && !estimate.startsNewSegment) {
        final previous = output[index - 1];
        estimatedDistance += _distance.distance(
          previous.position,
          estimate.position,
        );
        groundTruthDistance += _distance.distance(
          truthByTimestamp[previous.timestamp]!,
          truth,
        );
      }
    }
    errors.sort();
    final distanceError = estimatedDistance - groundTruthDistance;
    return SyntheticPositionMetrics(
      sampleCount: output.length,
      availabilityPercent: availabilityPercent,
      rmseMeters: math.sqrt(squaredErrorTotal / output.length),
      p50ErrorMeters: _percentile(errors, 0.50),
      p95ErrorMeters: _percentile(errors, 0.95),
      meanEastBiasMeters: eastBiasTotal / output.length,
      meanNorthBiasMeters: northBiasTotal / output.length,
      estimatedDistanceMeters: estimatedDistance,
      groundTruthDistanceMeters: groundTruthDistance,
      distanceErrorMeters: distanceError,
      distanceErrorPercent: groundTruthDistance <= 0.001
          ? 0
          : distanceError / groundTruthDistance * 100,
    );
  }

  double _signedEastMeters(LatLng truth, LatLng estimate) {
    final magnitude = _distance.distance(
      LatLng(truth.latitude, truth.longitude),
      LatLng(truth.latitude, estimate.longitude),
    );
    return estimate.longitude >= truth.longitude ? magnitude : -magnitude;
  }

  double _signedNorthMeters(LatLng truth, LatLng estimate) {
    final magnitude = _distance.distance(
      LatLng(truth.latitude, truth.longitude),
      LatLng(estimate.latitude, truth.longitude),
    );
    return estimate.latitude >= truth.latitude ? magnitude : -magnitude;
  }

  double _percentile(List<double> sortedValues, double percentile) {
    final position = (sortedValues.length - 1) * percentile;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sortedValues[lower];
    final fraction = position - lower;
    return sortedValues[lower] * (1 - fraction) +
        sortedValues[upper] * fraction;
  }
}
