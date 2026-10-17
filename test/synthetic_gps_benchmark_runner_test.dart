import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_trace_factory.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
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

  test(
    'distinguishes pre-validation lowAccuracy rejection from EKF NIS gating rejection on ground-truth outliers',
    () {
      // 1. High-uncertainty outlier (accuracy = 45m):
      // Intercepted by Stage 1 pre-validation filter before reaching EKF
      final traceWithHighNoise = factory.urbanCycling(
        startedAt: DateTime.utc(2026, 10, 12),
        duration: const Duration(minutes: 6),
      );
      final report1 = runner.run(traceWithHighNoise);
      final outlier1 = report1.samples.singleWhere((s) => s.isInjectedOutlier);
      expect(outlier1.variantSamples[GpsPipelineVariant.ekf]!.rejectionReason, 'lowAccuracy');

      // 2. Deceptive outlier (reported accuracy = 8m <= 32m, but true jump is 55m):
      // Passes Stage 1 pre-validation, reaches Stage 2 EKF, and is rejected by NIS Gating (NIS > 13.816)
      const distance = Distance();
      const origin = LatLng(10.7380, 106.6253);
      final deceptivePoints = <SyntheticGpsPoint>[];
      final startTime = DateTime.utc(2026, 10, 15);

      for (var s = 0; s < 20; s++) {
        final truth = distance.offset(origin, s * 5.0, 90.0);
        final isDeceptiveOutlier = s == 10;
        final raw = isDeceptiveOutlier
            ? distance.offset(truth, 55.0, 0.0) // 55m lateral jump
            : distance.offset(truth, 1.0, 0.0);
        deceptivePoints.add(
          SyntheticGpsPoint(
            timestamp: startTime.add(Duration(seconds: s)),
            groundTruth: truth,
            rawMeasurement: raw,
            accuracyMeters: 8.0, // Reported as normal good accuracy (<= 32m)
            speedMs: 5.0,
            headingDeg: 90.0,
            isInjectedOutlier: isDeceptiveOutlier,
          ),
        );
      }

      final deceptiveTrace = SyntheticGpsTrace(
        id: 'deceptive-outlier-test',
        scenario: SyntheticGpsScenario.urbanCycling,
        points: deceptivePoints,
      );

      final report2 = runner.run(deceptiveTrace);
      final deceptiveSample = report2.samples.singleWhere((s) => s.isInjectedOutlier);

      // Verify that pre-validation DID NOT reject it for lowAccuracy (rejectionReason is null)
      expect(deceptiveSample.variantSamples[GpsPipelineVariant.ekf]!.rejectionReason, isNull);

      // Verify that EKF NIS Gating successfully intercepted and REJECTED it
      final ekfDiag = deceptiveSample.variantSamples[GpsPipelineVariant.ekf]!.diagnostics;
      expect(ekfDiag.positionDecision, EkfMeasurementDecision.rejected);
      expect(ekfDiag.positionNis, greaterThan(13.816));

      // Verify EKF filter position remained on ground truth corridor (< 1.5m) despite 55m raw jump
      final ekfPos = deceptiveSample.variantSamples[GpsPipelineVariant.ekf]!.estimatedPosition;
      expect(ekfPos, isNotNull);
      final errorFromTruth = distance.distance(ekfPos!, deceptiveSample.groundTruth);
      expect(errorFromTruth, lessThan(1.5));
    },
  );
}
