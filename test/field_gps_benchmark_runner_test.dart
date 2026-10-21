import 'dart:io';

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_trace.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const parser = FieldGpsTraceParser();
  const runner = FieldGpsBenchmarkRunner();

  test('the benchmark contract exposes only the four approved variants', () {
    expect(GpsPipelineVariant.values, const [
      GpsPipelineVariant.current,
      GpsPipelineVariant.ekf,
      GpsPipelineVariant.dbscan,
      GpsPipelineVariant.ekfThenDbscan,
    ]);
  });

  test('replays the current cycling pipeline as field evidence', () {
    final trace = parser.parseLines(
      File(
        'test/fixtures/gps/anonymized_raw_gps_trace.jsonl',
      ).readAsLinesSync(),
    );

    final report = runner.run(
      trace,
      variants: const {GpsPipelineVariant.current},
    );
    final current = report.results[GpsPipelineVariant.current]!;

    expect(report.evidenceKind, GpsBenchmarkEvidenceKind.fieldNoGroundTruth);
    expect(report.workoutId, 'fixture-workout');
    expect(report.inputPointCount, 3);
    expect(report.duplicateTimestampCount, 1);
    expect(report.rawSamplingAvailabilityPercent, 100);
    expect(report.reportedAccuracy.p50Meters, 8.0);
    expect(report.results.keys, {GpsPipelineVariant.current});
    expect(current.acceptedPointCount, 2);
    expect(current.rejectedPointCount, 1);
    expect(current.appDistanceMeters, greaterThan(0));
    expect(current.processingMicrosecondsPerPoint, greaterThanOrEqualTo(0));
    expect(current.rejectionCounts, {'tinySegment': 1});
  });

  test('EKF uses the same validation and reseeds after a long GPS gap', () {
    final trace = FieldGpsTrace(
      workoutId: 'gap-workout',
      sourceLineCount: 3,
      duplicateTimestampCount: 0,
      samples: [
        _sample(0, const LatLng(1, 2)),
        _sample(1, const LatLng(1.00003, 2)),
        _sample(10, const LatLng(1.00020, 2)),
        _sample(11, const LatLng(1.00023, 2)),
        _sample(12, const LatLng(1.00026, 2)),
      ],
    );

    final report = runner.run(
      trace,
      variants: const {GpsPipelineVariant.current, GpsPipelineVariant.ekf},
    );
    final current = report.results[GpsPipelineVariant.current]!;
    final ekf = report.results[GpsPipelineVariant.ekf]!;

    expect(ekf.acceptedPointCount, current.acceptedPointCount);
    expect(ekf.rejectionCounts, current.rejectionCounts);
    expect(ekf.outputPoints, hasLength(5));
    expect(
      const Distance().distance(
        ekf.outputPoints[2].position,
        trace.samples[2].position,
      ),
      lessThan(0.01),
    );
    expect(ekf.outputPoints[2].ekfDiagnostics!.usedSpeedMeasurement, isFalse);
    expect(ekf.outputPoints[3].ekfDiagnostics!.usedSpeedMeasurement, isTrue);
    expect(ekf.outputPoints[4].ekfDiagnostics!.usedSpeedMeasurement, isTrue);
  });

  test(
    'current replay matches live millisecond precision at the gap boundary',
    () {
      final startedAt = DateTime.utc(2026, 10, 15, 10, 30);
      final trace = FieldGpsTrace(
        workoutId: 'gap-boundary-workout',
        sourceLineCount: 2,
        duplicateTimestampCount: 0,
        samples: [
          _sampleAt(startedAt, const LatLng(1, 2)),
          _sampleAt(
            startedAt.add(const Duration(microseconds: 5000500)),
            const LatLng(1.00009, 2),
          ),
        ],
      );

      final current = runner
          .run(trace, variants: const {GpsPipelineVariant.current})
          .results[GpsPipelineVariant.current]!;
      final liveDecision = const WorkoutTrackingEngine().evaluateGpsUpdate(
        position: _asPosition(trace.samples.last),
        activityType: 'cycling',
        routePoints: [trace.samples.first.position],
        currentLatLng: trace.samples.first.position,
        distanceAnchorPoint: trace.samples.first.position,
        lastAcceptedPositionTime: startedAt,
        shouldResetAnchorOnResume: false,
      );

      expect(current.outputPoints, hasLength(2));
      expect(liveDecision.shouldBreakRouteForDisplay, isFalse);
      expect(
        current.outputPoints.last.startsNewSegment,
        liveDecision.shouldBreakRouteForDisplay,
      );
      expect(current.appDistanceMeters, greaterThan(0));
    },
  );

  test('current replay matches representative live validation decisions', () {
    final startedAt = DateTime.utc(2026, 10, 15, 10, 30);
    final trace = FieldGpsTrace(
      workoutId: 'live-equivalence-workout',
      sourceLineCount: 7,
      duplicateTimestampCount: 0,
      samples: [
        _sampleAt(startedAt, const LatLng(10, 106), accuracyMeters: 25),
        _sampleAt(
          startedAt.add(const Duration(seconds: 1)),
          const LatLng(10, 106),
        ),
        _sampleAt(
          startedAt.add(const Duration(seconds: 2)),
          const LatLng(10.000001, 106),
        ),
        _sampleAt(
          startedAt.add(const Duration(seconds: 3)),
          const LatLng(10.00010, 106),
          accuracyMeters: 40,
        ),
        _sampleAt(
          startedAt.add(const Duration(seconds: 4)),
          const LatLng(10.00050, 106),
        ),
        _sampleAt(
          startedAt.add(const Duration(seconds: 5)),
          const LatLng(10.00055, 106),
          speedMetersPerSecond: 90,
        ),
        _sampleAt(
          startedAt.add(const Duration(seconds: 11)),
          const LatLng(10.00060, 106),
        ),
      ],
    );

    final current = runner
        .run(trace, variants: const {GpsPipelineVariant.current})
        .results[GpsPipelineVariant.current]!;
    final live = _replayLiveValidation(trace);

    expect(current.rejectionReasonByTimestamp, live.rejections);
    expect({
      for (final point in current.validatedInputPoints)
        point.timestamp: point.startsNewSegment,
    }, live.acceptedSegmentStarts);
  });

  test(
    'full cycling trace matches production validation, smoothing and distance',
    () {
      final start = DateTime.utc(2026, 10, 15);
      final samples = <FieldGpsSample>[];
      for (var i = 0; i < 100; i++) {
        final north = i < 50 ? i : 50;
        final east = i < 50 ? 0 : i - 50;
        samples.add(
          _sampleAt(
            start.add(Duration(seconds: i + (i >= 70 ? 8 : 0))),
            LatLng(10 + north * 0.00005, 106 + east * 0.00005),
            accuracyMeters: i == 20 ? 40 : 8,
          ),
        );
      }
      final trace = FieldGpsTrace(
        workoutId: 'full-trace',
        sourceLineCount: samples.length,
        duplicateTimestampCount: 0,
        samples: samples,
      );
      final current = runner.run(trace).results[GpsPipelineVariant.current]!;
      final live = _replayLivePipeline(trace);

      expect(current.rejectionReasonByTimestamp, live.rejections);
      expect(current.acceptedPointCount, live.outputs.length);
      expect(current.displayPointCount, live.displayPointCount);
      expect(current.appDistanceMeters, closeTo(live.appDistanceMeters, 0.5));
      expect(
        current.displayDistanceMeters,
        closeTo(live.displayDistanceMeters, 0.5),
      );
      for (var i = 0; i < live.outputs.length; i++) {
        expect(
          current.outputPoints[i].startsNewSegment,
          live.outputs[i].startsNewSegment,
        );
        expect(
          const Distance(roundResult: false).distance(
            current.outputPoints[i].position,
            live.outputs[i].position,
          ),
          lessThan(0.01),
        );
      }
    },
  );

  test('runs DBSCAN only and EKF then DBSCAN after the same validation', () {
    final trace = parser.parseLines(
      File(
        'test/fixtures/gps/anonymized_raw_gps_trace.jsonl',
      ).readAsLinesSync(),
    );

    final report = runner.run(
      trace,
      variants: GpsPipelineVariant.values.toSet(),
    );
    final current = report.results[GpsPipelineVariant.current]!;
    final dbscan = report.results[GpsPipelineVariant.dbscan]!;
    final ekfThenDbscan = report.results[GpsPipelineVariant.ekfThenDbscan]!;

    expect(report.results, hasLength(4));
    expect(dbscan.acceptedPointCount, current.acceptedPointCount);
    expect(dbscan.rejectionCounts, current.rejectionCounts);
    expect(ekfThenDbscan.acceptedPointCount, current.acceptedPointCount);
    expect(ekfThenDbscan.rejectionCounts, current.rejectionCounts);
    expect(dbscan.detectedDwellClusterCount, greaterThanOrEqualTo(0));
    expect(ekfThenDbscan.collapsedDwellPointCount, greaterThanOrEqualTo(0));
  });
}

FieldGpsSample _sample(int second, LatLng position) {
  return _sampleAt(DateTime.utc(2026, 10, 15, 10, 30, second), position);
}

FieldGpsSample _sampleAt(
  DateTime timestamp,
  LatLng position, {
  double accuracyMeters = 8,
  double speedMetersPerSecond = 4,
}) {
  return FieldGpsSample(
    workoutId: 'gap-workout',
    timestamp: timestamp,
    position: position,
    altitudeMeters: 0,
    speedMetersPerSecond: speedMetersPerSecond,
    reportedAccuracyMeters: accuracyMeters,
    headingDegrees: 0,
    deviceSource: 'geolocator_position_stream',
    confidence: 'high',
  );
}

Position _asPosition(FieldGpsSample sample) => Position(
  latitude: sample.position.latitude,
  longitude: sample.position.longitude,
  timestamp: sample.timestamp,
  accuracy: sample.reportedAccuracyMeters,
  altitude: sample.altitudeMeters ?? 0,
  altitudeAccuracy: 0,
  heading: sample.headingDegrees ?? 0,
  headingAccuracy: 0,
  speed: sample.speedMetersPerSecond,
  speedAccuracy: 0,
);

({Map<DateTime, String> rejections, Map<DateTime, bool> acceptedSegmentStarts})
_replayLiveValidation(FieldGpsTrace trace) {
  const engine = WorkoutTrackingEngine();
  final route = <LatLng>[];
  final rejections = <DateTime, String>{};
  final acceptedSegmentStarts = <DateTime, bool>{};
  LatLng? distanceAnchor;
  DateTime? lastAcceptedTimestamp;
  var wasWeak = false;
  for (final sample in trace.samples) {
    final decision = engine.evaluateGpsUpdate(
      position: _asPosition(sample),
      activityType: 'cycling',
      routePoints: route,
      currentLatLng: route.isEmpty ? null : route.last,
      distanceAnchorPoint: distanceAnchor,
      lastAcceptedPositionTime: lastAcceptedTimestamp,
      shouldResetAnchorOnResume: false,
      wasGpsSignalWeak: wasWeak,
    );
    if (decision.type == TrackingGpsDecisionType.skip) {
      rejections[sample.timestamp] = decision.reason.name;
      if (decision.reason.name == 'lowAccuracy') wasWeak = true;
      continue;
    }
    acceptedSegmentStarts[sample.timestamp] =
        decision.type == TrackingGpsDecisionType.seedRoute ||
        decision.type == TrackingGpsDecisionType.resetAnchor ||
        decision.shouldBreakRouteForDisplay;
    route.add(decision.livePoint);
    distanceAnchor = decision.livePoint;
    lastAcceptedTimestamp = sample.timestamp;
    wasWeak = false;
  }
  return (rejections: rejections, acceptedSegmentStarts: acceptedSegmentStarts);
}

({
  Map<DateTime, String> rejections,
  List<BenchmarkGpsPoint> outputs,
  int displayPointCount,
  double appDistanceMeters,
  double displayDistanceMeters,
})
_replayLivePipeline(FieldGpsTrace trace) {
  const engine = WorkoutTrackingEngine();
  const smoother = GpsSmoothingService();
  const distance = Distance(roundResult: false);
  final route = <LatLng>[];
  final outputs = <BenchmarkGpsPoint>[];
  final rejections = <DateTime, String>{};
  LatLng? anchor;
  LatLng? previousAccepted;
  LatLng? previousSmoothed;
  LatLng? lastDisplayed;
  DateTime? lastAcceptedTime;
  var wasWeak = false;
  var displayPointCount = 0;
  var appDistanceMeters = 0.0;
  var displayDistanceMeters = 0.0;
  for (final sample in trace.samples) {
    final decision = engine.evaluateGpsUpdate(
      position: _asPosition(sample),
      activityType: 'cycling',
      routePoints: route,
      currentLatLng: route.isEmpty ? null : route.last,
      distanceAnchorPoint: anchor,
      lastAcceptedPositionTime: lastAcceptedTime,
      shouldResetAnchorOnResume: false,
      wasGpsSignalWeak: wasWeak,
    );
    if (decision.type == TrackingGpsDecisionType.skip) {
      rejections[sample.timestamp] = decision.reason.name;
      if (decision.reason.name == 'lowAccuracy') wasWeak = true;
      continue;
    }
    final startsSegment =
        route.isEmpty ||
        decision.shouldBreakRouteForDisplay ||
        decision.type == TrackingGpsDecisionType.resetAnchor;
    if (decision.shouldAddDistance) appDistanceMeters += decision.segmentMeters;
    final elapsed = lastAcceptedTime == null
        ? 0.0
        : sample.timestamp.difference(lastAcceptedTime).inMilliseconds / 1000.0;
    final update = route.isEmpty
        ? null
        : smoother.smoothAcceptedPoint(
            activityType: 'cycling',
            acceptedPoint: sample.position,
            previousAcceptedPoint: previousAccepted,
            previousSmoothedPoint: previousSmoothed,
            lastSmoothedRoutePoint: lastDisplayed,
            accuracyMeters: sample.reportedAccuracyMeters,
            speedMs: sample.speedMetersPerSecond,
            timeDeltaSec: elapsed,
            gpsGapDurationSec: startsSegment ? elapsed : 0,
          );
    final display = startsSegment ? sample.position : update!.smoothedPoint;
    if (!startsSegment && outputs.isNotEmpty) {
      displayDistanceMeters += distance.distance(
        outputs.last.position,
        display,
      );
    }
    if (startsSegment || update!.shouldAppendRoutePoint) {
      lastDisplayed = display;
      displayPointCount++;
    }
    outputs.add(
      BenchmarkGpsPoint(
        timestamp: sample.timestamp,
        position: display,
        speedMetersPerSecond: sample.speedMetersPerSecond,
        reportedAccuracyMeters: sample.reportedAccuracyMeters,
        headingDegrees: sample.headingDegrees,
        startsNewSegment: startsSegment,
      ),
    );
    route.add(sample.position);
    anchor = sample.position;
    previousAccepted = sample.position;
    previousSmoothed = display;
    lastAcceptedTime = sample.timestamp;
    wasWeak = false;
  }
  return (
    rejections: rejections,
    outputs: outputs,
    displayPointCount: displayPointCount,
    appDistanceMeters: appDistanceMeters,
    displayDistanceMeters: displayDistanceMeters,
  );
}
