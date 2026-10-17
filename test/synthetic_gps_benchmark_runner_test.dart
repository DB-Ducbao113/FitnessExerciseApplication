import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_trace_factory.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const factory = SyntheticGpsTraceFactory();
  const runner = SyntheticGpsBenchmarkRunner();

  test(
    'scores raw and the current fixed-alpha smoothing against ground truth',
    () {
      final trace = factory.stationary(
        startedAt: DateTime.utc(2026, 10, 12),
        center: const LatLng(10.7769, 106.7009),
        duration: const Duration(minutes: 10),
      );

      final report = runner.run(trace);

      expect(report.isSynthetic, isTrue);
      expect(report.variants.keys.toSet(), GpsPipelineVariant.values.toSet());
      expect(report.raw.sampleCount, trace.points.length);
      expect(report.raw.p95ErrorMeters, greaterThan(0));
      expect(report.currentSmoothing.sampleCount, greaterThan(0));
      expect(
        report.currentSmoothing.sampleCount,
        lessThanOrEqualTo(trace.points.length),
      );
      expect(report.samples, hasLength(trace.points.length));
      expect(report.samples.first.isSynthetic, isTrue);
      expect(report.samples.first.currentErrorMeters, greaterThanOrEqualTo(0));
      expect(
        report.currentSmoothing.p95ErrorMeters,
        lessThan(report.raw.p95ErrorMeters),
      );
      expect(
        report.variants[GpsPipelineVariant.dbscan]!.detectedDwellClusterCount,
        greaterThan(0),
      );
    },
  );

  test(
    'scores the current smoothing on cycling including a gap and outlier',
    () {
      final trace = factory.urbanCycling(
        startedAt: DateTime.utc(2026, 10, 12),
        duration: const Duration(minutes: 6),
      );
      final report = runner.run(trace);

      expect(report.currentSmoothing.sampleCount, greaterThan(0));
      expect(
        report.currentSmoothing.sampleCount,
        lessThanOrEqualTo(trace.points.length),
      );
      for (final result in report.variants.values) {
        expect(result.metrics.rmseMeters.isFinite, isTrue);
        expect(result.metrics.p50ErrorMeters.isFinite, isTrue);
        expect(result.metrics.p95ErrorMeters.isFinite, isTrue);
        expect(result.metrics.distanceErrorPercent.isFinite, isTrue);
        expect(result.metricsByPhase[SyntheticSamplePhase.straight], isNotNull);
        expect(result.metricsByPhase[SyntheticSamplePhase.turn], isNotNull);
        expect(
          result.metricsByPhase[SyntheticSamplePhase.gapRecovery],
          isNotNull,
        );
        expect(result.topFivePercentErrors, isNotEmpty);
        expect(
          result.topFivePercentErrors.first.errorMeters,
          greaterThanOrEqualTo(result.topFivePercentErrors.last.errorMeters),
        );
      }

      final outlier = report.samples.singleWhere(
        (sample) => sample.isInjectedOutlier,
      );
      expect(outlier.phase, SyntheticSamplePhase.outlier);
      expect(
        outlier.variantSamples[GpsPipelineVariant.ekf]!.rejectionReason,
        'lowAccuracy',
      );

      final firstRecovery = report.samples.singleWhere(
        (sample) =>
            sample.timestamp.second == 40 && sample.timestamp.minute == 2,
      );
      expect(firstRecovery.phase, SyntheticSamplePhase.gapRecovery);
      final laterEkfSample = report.samples.firstWhere(
        (sample) =>
            sample
                .variantSamples[GpsPipelineVariant.ekf]
                ?.diagnostics
                .positionNis !=
            null,
      );
      expect(
        laterEkfSample
            .variantSamples[GpsPipelineVariant.ekf]!
            .diagnostics
            .positionInnovationMeters,
        greaterThanOrEqualTo(0),
      );
      expect(
        report.variants[GpsPipelineVariant.ekf]!.positionDecisionCounts.values
            .fold<int>(0, (total, count) => total + count),
        greaterThan(0),
      );
    },
  );
}
