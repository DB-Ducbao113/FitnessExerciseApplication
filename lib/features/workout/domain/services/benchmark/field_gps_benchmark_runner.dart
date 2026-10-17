import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_trace.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/dbscan/gps_dbscan_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:latlong2/latlong.dart';

enum GpsPipelineVariant { current, ekf, dbscan, ekfThenDbscan }

enum GpsBenchmarkEvidenceKind { fieldNoGroundTruth }

class EkfBenchmarkConfig {
  final double processPosStd;
  final double processSpeedStd;
  final double processHeadingStd;
  final double positionAccuracyScale;
  final double maxTurnHeadingNoiseScale;

  const EkfBenchmarkConfig({
    this.processPosStd = 0.75,
    this.processSpeedStd = 1.2,
    this.processHeadingStd = 0.5,
    this.positionAccuracyScale = 0.75,
    this.maxTurnHeadingNoiseScale = 14.0,
  });
}

class ReportedAccuracyMetrics {
  final double meanMeters;
  final double p50Meters;
  final double p95Meters;

  const ReportedAccuracyMetrics({
    required this.meanMeters,
    required this.p50Meters,
    required this.p95Meters,
  });
}

class BenchmarkGpsPoint {
  final DateTime timestamp;
  final LatLng position;
  final double speedMetersPerSecond;
  final double reportedAccuracyMeters;
  final double? headingDegrees;
  final bool startsNewSegment;
  final EkfUpdateDiagnostics? ekfDiagnostics;

  const BenchmarkGpsPoint({
    required this.timestamp,
    required this.position,
    required this.speedMetersPerSecond,
    required this.reportedAccuracyMeters,
    required this.headingDegrees,
    this.startsNewSegment = false,
    this.ekfDiagnostics,
  });
}

class FieldGpsVariantResult {
  final GpsPipelineVariant variant;
  final int acceptedPointCount;
  final int displayPointCount;
  final int rejectedPointCount;
  final double acceptedAvailabilityPercent;
  final double appDistanceMeters;
  final double displayDistanceMeters;
  final double processingMicrosecondsPerPoint;
  final Map<String, int> rejectionCounts;
  final List<BenchmarkGpsPoint> outputPoints;
  final List<BenchmarkGpsPoint> validatedInputPoints;
  final int detectedDwellClusterCount;
  final int collapsedDwellPointCount;
  final double phantomDriftRemovedMeters;
  final Map<DateTime, String> rejectionReasonByTimestamp;

  const FieldGpsVariantResult({
    required this.variant,
    required this.acceptedPointCount,
    required this.displayPointCount,
    required this.rejectedPointCount,
    required this.acceptedAvailabilityPercent,
    required this.appDistanceMeters,
    required this.displayDistanceMeters,
    required this.processingMicrosecondsPerPoint,
    required this.rejectionCounts,
    required this.outputPoints,
    this.validatedInputPoints = const [],
    this.detectedDwellClusterCount = 0,
    this.collapsedDwellPointCount = 0,
    this.phantomDriftRemovedMeters = 0,
    this.rejectionReasonByTimestamp = const {},
  });
}

class FieldGpsBenchmarkReport {
  final GpsBenchmarkEvidenceKind evidenceKind;
  final String workoutId;
  final int sourceLineCount;
  final int inputPointCount;
  final int duplicateTimestampCount;
  final double rawSamplingAvailabilityPercent;
  final int gapsOverTwoSeconds;
  final int gapsOverFiveSeconds;
  final double maximumGapSeconds;
  final ReportedAccuracyMetrics reportedAccuracy;
  final Map<GpsPipelineVariant, FieldGpsVariantResult> results;

  const FieldGpsBenchmarkReport({
    required this.evidenceKind,
    required this.workoutId,
    required this.sourceLineCount,
    required this.inputPointCount,
    required this.duplicateTimestampCount,
    required this.rawSamplingAvailabilityPercent,
    required this.gapsOverTwoSeconds,
    required this.gapsOverFiveSeconds,
    required this.maximumGapSeconds,
    required this.reportedAccuracy,
    required this.results,
  });
}

/// Pure-Dart field replay. Field logs are never treated as ground truth.
class FieldGpsBenchmarkRunner {
  static const Distance _distance = Distance(roundResult: false);
  static const Distance _smoothingDistance = Distance();
  static const GpsDbscanService _dbscan = GpsDbscanService();

  final EkfBenchmarkConfig ekfConfig;

  const FieldGpsBenchmarkRunner({this.ekfConfig = const EkfBenchmarkConfig()});

  FieldGpsBenchmarkReport run(
    FieldGpsTrace trace, {
    Set<GpsPipelineVariant> variants = const {GpsPipelineVariant.current},
  }) {
    final results = <GpsPipelineVariant, FieldGpsVariantResult>{};
    for (final variant in variants) {
      results[variant] = switch (variant) {
        GpsPipelineVariant.current => _runCurrentPipeline(trace),
        GpsPipelineVariant.ekf => _runEkfPipeline(trace),
        GpsPipelineVariant.dbscan => _runDbscanOnly(trace),
        GpsPipelineVariant.ekfThenDbscan => _runEkfThenDbscan(trace),
      };
    }
    final gaps = _gapMetrics(trace.samples);
    return FieldGpsBenchmarkReport(
      evidenceKind: GpsBenchmarkEvidenceKind.fieldNoGroundTruth,
      workoutId: trace.workoutId,
      sourceLineCount: trace.sourceLineCount,
      inputPointCount: trace.samples.length,
      duplicateTimestampCount: trace.duplicateTimestampCount,
      rawSamplingAvailabilityPercent: _rawSamplingAvailability(trace.samples),
      gapsOverTwoSeconds: gaps.overTwoSeconds,
      gapsOverFiveSeconds: gaps.overFiveSeconds,
      maximumGapSeconds: gaps.maximumSeconds,
      reportedAccuracy: _reportedAccuracy(trace.samples),
      results: Map.unmodifiable(results),
    );
  }

  FieldGpsVariantResult _runCurrentPipeline(FieldGpsTrace trace) {
    final validated = _validateCyclingTrace(trace);
    final output = <BenchmarkGpsPoint>[];
    LatLng? previousAccepted;
    LatLng? previousSmoothed;
    LatLng? lastSmoothedRoutePoint;
    DateTime? previousTimestamp;
    var displayPointCount = 0;
    var displayDistanceMeters = 0.0;
    final stopwatch = Stopwatch()..start();

    for (final point in validated.points) {
      final sample = point.sample;
      if (output.isEmpty) {
        output.add(
          _benchmarkPoint(sample, sample.position, startsNewSegment: true),
        );
        previousAccepted = sample.position;
        previousSmoothed = sample.position;
        lastSmoothedRoutePoint = sample.position;
        previousTimestamp = sample.timestamp;
        displayPointCount = 1;
        continue;
      }
      final elapsed =
          sample.timestamp.difference(previousTimestamp!).inMilliseconds /
          Duration.millisecondsPerSecond;
      final update = _smoothCurrentCyclingPoint(
        acceptedPoint: sample.position,
        previousAcceptedPoint: previousAccepted,
        previousSmoothedPoint: previousSmoothed,
        lastSmoothedRoutePoint: lastSmoothedRoutePoint,
        accuracyMeters: sample.reportedAccuracyMeters,
        speedMs: sample.speedMetersPerSecond,
        timeDeltaSec: elapsed,
        gpsGapDurationSec: point.startsNewSegment ? elapsed : 0,
      );
      final display = point.startsNewSegment
          ? sample.position
          : update.smoothedPoint;
      if (!point.startsNewSegment) {
        displayDistanceMeters += _distance.distance(
          output.last.position,
          display,
        );
      }
      if (point.startsNewSegment || update.shouldAppendRoutePoint) {
        lastSmoothedRoutePoint = display;
        displayPointCount += 1;
      }
      output.add(
        _benchmarkPoint(
          sample,
          display,
          startsNewSegment: point.startsNewSegment,
        ),
      );
      previousAccepted = sample.position;
      previousSmoothed = display;
      previousTimestamp = sample.timestamp;
    }
    stopwatch.stop();
    return _resultFromValidated(
      trace: trace,
      validated: validated,
      variant: GpsPipelineVariant.current,
      output: output,
      displayPointCount: displayPointCount,
      appDistanceMeters: validated.appDistanceMeters,
      displayDistanceMeters: displayDistanceMeters,
      transformMicroseconds: stopwatch.elapsedMicroseconds,
    );
  }

  FieldGpsVariantResult _runEkfPipeline(FieldGpsTrace trace) {
    final validated = _validateCyclingTrace(trace);
    final ekf = ExtendedKalmanFilter(
      processPosStd: ekfConfig.processPosStd,
      processSpeedStd: ekfConfig.processSpeedStd,
      processHeadingStd: ekfConfig.processHeadingStd,
      positionAccuracyScale: ekfConfig.positionAccuracyScale,
      maxTurnHeadingNoiseScale: ekfConfig.maxTurnHeadingNoiseScale,
    );
    final output = <BenchmarkGpsPoint>[];
    DateTime? previousTimestamp;
    var recoveryWarmupRemaining = 0;
    var displayDistanceMeters = 0.0;
    final stopwatch = Stopwatch()..start();
    for (final point in validated.points) {
      final sample = point.sample;
      final elapsed = previousTimestamp == null
          ? 1.0
          : sample.timestamp.difference(previousTimestamp).inMilliseconds /
                Duration.millisecondsPerSecond;
      if (output.isEmpty || point.startsNewSegment) {
        ekf.reset();
        recoveryWarmupRemaining = output.isEmpty ? 0 : 1;
      }
      final canUseMotionMeasurement = recoveryWarmupRemaining == 0;
      final estimate = ekf.update(
        measurementPoint: sample.position,
        accuracyMeters: sample.reportedAccuracyMeters,
        timeDeltaSec: elapsed,
        speedMs: canUseMotionMeasurement && sample.speedMetersPerSecond >= 0
            ? sample.speedMetersPerSecond
            : null,
        headingDeg: canUseMotionMeasurement
            ? _validHeading(sample.headingDegrees)
            : null,
      );
      if (recoveryWarmupRemaining > 0) recoveryWarmupRemaining -= 1;
      if (!point.startsNewSegment && output.isNotEmpty) {
        displayDistanceMeters += _distance.distance(
          output.last.position,
          estimate.position,
        );
      }
      output.add(
        _benchmarkPoint(
          sample,
          estimate.position,
          startsNewSegment: point.startsNewSegment,
          ekfDiagnostics: estimate.diagnostics,
        ),
      );
      previousTimestamp = sample.timestamp;
    }
    stopwatch.stop();
    return _resultFromValidated(
      trace: trace,
      validated: validated,
      variant: GpsPipelineVariant.ekf,
      output: output,
      displayPointCount: output.length,
      appDistanceMeters: validated.appDistanceMeters,
      displayDistanceMeters: displayDistanceMeters,
      transformMicroseconds: stopwatch.elapsedMicroseconds,
    );
  }

  FieldGpsVariantResult _runDbscanOnly(FieldGpsTrace trace) {
    final validated = _validateCyclingTrace(trace);
    final raw = _resultFromValidated(
      trace: trace,
      validated: validated,
      variant: GpsPipelineVariant.dbscan,
      output: validated.benchmarkPoints,
      displayPointCount: validated.points.length,
      appDistanceMeters: validated.appDistanceMeters,
      displayDistanceMeters: _segmentedDistance(validated.benchmarkPoints),
      transformMicroseconds: 0,
    );
    return _applyDbscan(
      base: raw,
      inputPoints: raw.outputPoints,
      variant: GpsPipelineVariant.dbscan,
    );
  }

  FieldGpsVariantResult _runEkfThenDbscan(FieldGpsTrace trace) {
    final ekf = _runEkfPipeline(trace);
    return _applyDbscan(
      base: ekf,
      inputPoints: ekf.outputPoints,
      variant: GpsPipelineVariant.ekfThenDbscan,
    );
  }

  FieldGpsVariantResult _applyDbscan({
    required FieldGpsVariantResult base,
    required List<BenchmarkGpsPoint> inputPoints,
    required GpsPipelineVariant variant,
  }) {
    final output = <BenchmarkGpsPoint>[];
    var clusterCount = 0;
    var phantomDriftMeters = 0.0;
    var distanceMeters = 0.0;
    final stopwatch = Stopwatch()..start();
    for (final segment in _continuousSegments(inputPoints)) {
      final timed = segment
          .map(
            (point) => TimedGpsPoint(
              point: point.position,
              timestamp: point.timestamp,
              speedMs: point.speedMetersPerSecond,
              accuracyMeters: point.reportedAccuracyMeters,
            ),
          )
          .toList(growable: false);
      final clusters = _dbscan.findDwellClusters(timed);
      clusterCount += clusters.length;
      final simplified = <BenchmarkGpsPoint>[];
      var cursor = 0;
      for (final cluster in clusters) {
        while (cursor < cluster.startIndex) {
          simplified.add(segment[cursor]);
          cursor += 1;
        }
        for (
          var index = cluster.startIndex + 1;
          index <= cluster.endIndex;
          index += 1
        ) {
          phantomDriftMeters += _distance.distance(
            segment[index - 1].position,
            segment[index].position,
          );
        }
        final source = segment[cluster.startIndex];
        simplified.add(
          BenchmarkGpsPoint(
            timestamp: source.timestamp,
            position: cluster.centroid,
            speedMetersPerSecond: 0,
            reportedAccuracyMeters: source.reportedAccuracyMeters,
            headingDegrees: null,
            startsNewSegment: source.startsNewSegment,
          ),
        );
        cursor = cluster.endIndex + 1;
      }
      while (cursor < segment.length) {
        simplified.add(segment[cursor]);
        cursor += 1;
      }
      for (var index = 1; index < simplified.length; index += 1) {
        distanceMeters += _distance.distance(
          simplified[index - 1].position,
          simplified[index].position,
        );
      }
      output.addAll(simplified);
    }
    stopwatch.stop();
    return FieldGpsVariantResult(
      variant: variant,
      acceptedPointCount: base.acceptedPointCount,
      displayPointCount: output.length,
      rejectedPointCount: base.rejectedPointCount,
      acceptedAvailabilityPercent: base.acceptedAvailabilityPercent,
      appDistanceMeters: distanceMeters,
      displayDistanceMeters: distanceMeters,
      processingMicrosecondsPerPoint:
          base.processingMicrosecondsPerPoint +
          (inputPoints.isEmpty
              ? 0
              : stopwatch.elapsedMicroseconds / inputPoints.length),
      rejectionCounts: base.rejectionCounts,
      outputPoints: List.unmodifiable(output),
      validatedInputPoints: base.validatedInputPoints,
      detectedDwellClusterCount: clusterCount,
      collapsedDwellPointCount: inputPoints.length - output.length,
      phantomDriftRemovedMeters: phantomDriftMeters,
      rejectionReasonByTimestamp: base.rejectionReasonByTimestamp,
    );
  }

  _ValidatedTrace _validateCyclingTrace(FieldGpsTrace trace) {
    final accepted = <_ValidatedPoint>[];
    final route = <LatLng>[];
    final rejections = <String, int>{};
    final rejectionReasons = <DateTime, String>{};
    LatLng? distanceAnchor;
    DateTime? lastAcceptedTime;
    var wasWeak = false;
    var appDistanceMeters = 0.0;
    final stopwatch = Stopwatch()..start();
    for (final sample in trace.samples) {
      if (route.isEmpty) {
        if (sample.reportedAccuracyMeters > 20) {
          _reject(
            rejections,
            rejectionReasons,
            sample.timestamp,
            'waitingForBetterFirstFix',
          );
          continue;
        }
        route.add(sample.position);
        distanceAnchor = sample.position;
        lastAcceptedTime = sample.timestamp;
        accepted.add(_ValidatedPoint(sample: sample, startsNewSegment: true));
        continue;
      }
      final last = route.last;
      final rawSegment = _distance.distance(
        distanceAnchor ?? last,
        sample.position,
      );
      final routeSegment = _distance.distance(last, sample.position);
      if (rawSegment < 1.5) {
        _reject(rejections, rejectionReasons, sample.timestamp, 'tinySegment');
        continue;
      }
      if (sample.reportedAccuracyMeters > 32) {
        _reject(rejections, rejectionReasons, sample.timestamp, 'lowAccuracy');
        wasWeak = true;
        continue;
      }
      if (sample.speedMetersPerSecond > 80) {
        _reject(
          rejections,
          rejectionReasons,
          sample.timestamp,
          'gpsSpeedHardSpike',
        );
        continue;
      }
      final elapsed =
          sample.timestamp.difference(lastAcceptedTime!).inMilliseconds /
          Duration.millisecondsPerSecond;
      final impliedSpeed = elapsed > 0 ? rawSegment / elapsed : 0.0;
      var startsNewSegment = elapsed > 5;
      startsNewSegment =
          startsNewSegment ||
          (wasWeak && routeSegment >= 45.5) ||
          (sample.reportedAccuracyMeters >= 28 && routeSegment >= 70) ||
          (elapsed >= 2 && routeSegment >= 70 && impliedSpeed > 15);
      if (!startsNewSegment && elapsed > 0 && impliedSpeed > 96) {
        _reject(
          rejections,
          rejectionReasons,
          sample.timestamp,
          'impliedSpeedHardSpike',
        );
        continue;
      }
      if (!startsNewSegment && route.length >= 2) {
        final previousBearing = _bearing(route[route.length - 2], last);
        final currentBearing = _bearing(last, sample.position);
        if (_bearingDelta(previousBearing, currentBearing) > 120 &&
            rawSegment < 20) {
          _reject(
            rejections,
            rejectionReasons,
            sample.timestamp,
            'headingSpike',
          );
          continue;
        }
      }
      route.add(sample.position);
      accepted.add(
        _ValidatedPoint(sample: sample, startsNewSegment: startsNewSegment),
      );
      if (!startsNewSegment) appDistanceMeters += rawSegment;
      distanceAnchor = sample.position;
      lastAcceptedTime = sample.timestamp;
      wasWeak = false;
    }
    stopwatch.stop();
    return _ValidatedTrace(
      points: List.unmodifiable(accepted),
      rejectionCounts: Map.unmodifiable(rejections),
      rejectionReasonByTimestamp: Map.unmodifiable(rejectionReasons),
      appDistanceMeters: appDistanceMeters,
      processingMicroseconds: stopwatch.elapsedMicroseconds,
    );
  }

  FieldGpsVariantResult _resultFromValidated({
    required FieldGpsTrace trace,
    required _ValidatedTrace validated,
    required GpsPipelineVariant variant,
    required List<BenchmarkGpsPoint> output,
    required int displayPointCount,
    required double appDistanceMeters,
    required double displayDistanceMeters,
    required int transformMicroseconds,
  }) {
    final acceptedCount = validated.points.length;
    return FieldGpsVariantResult(
      variant: variant,
      acceptedPointCount: acceptedCount,
      displayPointCount: displayPointCount,
      rejectedPointCount: trace.samples.length - acceptedCount,
      acceptedAvailabilityPercent: trace.samples.isEmpty
          ? 0
          : acceptedCount / trace.samples.length * 100,
      appDistanceMeters: appDistanceMeters,
      displayDistanceMeters: displayDistanceMeters,
      processingMicrosecondsPerPoint: trace.samples.isEmpty
          ? 0
          : (validated.processingMicroseconds + transformMicroseconds) /
                trace.samples.length,
      rejectionCounts: validated.rejectionCounts,
      rejectionReasonByTimestamp: validated.rejectionReasonByTimestamp,
      outputPoints: List.unmodifiable(output),
      validatedInputPoints: validated.benchmarkPoints,
    );
  }

  void _reject(
    Map<String, int> counts,
    Map<DateTime, String> reasons,
    DateTime timestamp,
    String reason,
  ) {
    counts.update(reason, (count) => count + 1, ifAbsent: () => 1);
    reasons[timestamp] = reason;
  }

  _CurrentSmoothingUpdate _smoothCurrentCyclingPoint({
    required LatLng acceptedPoint,
    required LatLng? previousAcceptedPoint,
    required LatLng? previousSmoothedPoint,
    required LatLng? lastSmoothedRoutePoint,
    required double accuracyMeters,
    required double speedMs,
    required double timeDeltaSec,
    required double gpsGapDurationSec,
  }) {
    final confidence = gpsGapDurationSec > 5 || accuracyMeters > 30
        ? _BenchmarkConfidence.low
        : accuracyMeters > 15 || timeDeltaSec > 2.5 || speedMs <= 0.4
        ? _BenchmarkConfidence.medium
        : _BenchmarkConfidence.high;
    final acceptedDelta = previousAcceptedPoint == null
        ? 0.0
        : _smoothingDistance.distance(previousAcceptedPoint, acceptedPoint);
    final isStationary =
        previousAcceptedPoint != null &&
        gpsGapDurationSec <= 0 &&
        acceptedDelta <= 3.5 &&
        (speedMs <= 0.8 || timeDeltaSec >= 1);

    LatLng smoothedPoint;
    if (previousSmoothedPoint == null) {
      smoothedPoint = acceptedPoint;
    } else if (isStationary && acceptedDelta < 2.5) {
      smoothedPoint = previousSmoothedPoint;
    } else {
      var alpha = switch (confidence) {
        _BenchmarkConfidence.high => 0.72,
        _BenchmarkConfidence.medium => 0.52,
        _BenchmarkConfidence.low => 0.34,
      };
      if (previousAcceptedPoint != null) {
        final turnDelta = _bearingDelta(
          _bearing(previousAcceptedPoint, acceptedPoint),
          _bearing(previousSmoothedPoint, acceptedPoint),
        );
        if (turnDelta > 28 && acceptedDelta > 4) {
          alpha = math.max(alpha, 0.82);
        }
      }
      smoothedPoint = LatLng(
        previousSmoothedPoint.latitude * (1 - alpha) +
            acceptedPoint.latitude * alpha,
        previousSmoothedPoint.longitude * (1 - alpha) +
            acceptedPoint.longitude * alpha,
      );
    }

    final routeDelta = lastSmoothedRoutePoint == null
        ? double.infinity
        : _smoothingDistance.distance(lastSmoothedRoutePoint, smoothedPoint);
    final shouldAppend =
        gpsGapDurationSec > 5 ||
        lastSmoothedRoutePoint == null ||
        (!isStationary &&
            routeDelta >= 4 &&
            confidence != _BenchmarkConfidence.low);
    return _CurrentSmoothingUpdate(
      smoothedPoint: smoothedPoint,
      shouldAppendRoutePoint: shouldAppend,
    );
  }

  List<List<BenchmarkGpsPoint>> _continuousSegments(
    List<BenchmarkGpsPoint> points,
  ) {
    if (points.isEmpty) return const [];
    final segments = <List<BenchmarkGpsPoint>>[
      [points.first],
    ];
    for (var index = 1; index < points.length; index += 1) {
      if (points[index].startsNewSegment) {
        segments.add([points[index]]);
      } else {
        segments.last.add(points[index]);
      }
    }
    return segments;
  }

  double _segmentedDistance(List<BenchmarkGpsPoint> points) {
    var total = 0.0;
    for (final segment in _continuousSegments(points)) {
      for (var index = 1; index < segment.length; index += 1) {
        total += _distance.distance(
          segment[index - 1].position,
          segment[index].position,
        );
      }
    }
    return total;
  }

  BenchmarkGpsPoint _benchmarkPoint(
    FieldGpsSample sample,
    LatLng position, {
    bool startsNewSegment = false,
    EkfUpdateDiagnostics? ekfDiagnostics,
  }) {
    return BenchmarkGpsPoint(
      timestamp: sample.timestamp,
      position: position,
      speedMetersPerSecond: sample.speedMetersPerSecond,
      reportedAccuracyMeters: sample.reportedAccuracyMeters,
      headingDegrees: sample.headingDegrees,
      startsNewSegment: startsNewSegment,
      ekfDiagnostics: ekfDiagnostics,
    );
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final deltaLongitude = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(deltaLongitude) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _bearingDelta(double first, double second) {
    final delta = (first - second).abs();
    return delta > 180 ? 360 - delta : delta;
  }

  double? _validHeading(double? headingDegrees) {
    if (headingDegrees == null || headingDegrees < 0 || headingDegrees >= 360) {
      return null;
    }
    return headingDegrees;
  }

  ReportedAccuracyMetrics _reportedAccuracy(List<FieldGpsSample> samples) {
    final values =
        samples
            .map((sample) => sample.reportedAccuracyMeters)
            .toList(growable: false)
          ..sort();
    final mean =
        values.fold<double>(0, (sum, value) => sum + value) / values.length;
    return ReportedAccuracyMetrics(
      meanMeters: mean,
      p50Meters: _percentile(values, 0.50),
      p95Meters: _percentile(values, 0.95),
    );
  }

  _GapMetrics _gapMetrics(List<FieldGpsSample> samples) {
    var overTwo = 0;
    var overFive = 0;
    var maximum = 0.0;
    for (var index = 1; index < samples.length; index += 1) {
      final seconds =
          samples[index].timestamp
              .difference(samples[index - 1].timestamp)
              .inMicroseconds /
          Duration.microsecondsPerSecond;
      if (seconds > 2) overTwo += 1;
      if (seconds > 5) overFive += 1;
      maximum = math.max(maximum, seconds);
    }
    return _GapMetrics(
      overTwoSeconds: overTwo,
      overFiveSeconds: overFive,
      maximumSeconds: maximum,
    );
  }

  double _rawSamplingAvailability(List<FieldGpsSample> samples) {
    if (samples.length < 2) return samples.isEmpty ? 0 : 100;
    final spanSeconds =
        samples.last.timestamp
            .difference(samples.first.timestamp)
            .inMicroseconds /
        Duration.microsecondsPerSecond;
    final expectedSamples = spanSeconds.floor() + 1;
    return (samples.length / expectedSamples * 100).clamp(0, 100).toDouble();
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

class _ValidatedPoint {
  final FieldGpsSample sample;
  final bool startsNewSegment;

  const _ValidatedPoint({required this.sample, required this.startsNewSegment});
}

class _ValidatedTrace {
  final List<_ValidatedPoint> points;
  final Map<String, int> rejectionCounts;
  final double appDistanceMeters;
  final int processingMicroseconds;
  final Map<DateTime, String> rejectionReasonByTimestamp;

  const _ValidatedTrace({
    required this.points,
    required this.rejectionCounts,
    required this.appDistanceMeters,
    required this.processingMicroseconds,
    required this.rejectionReasonByTimestamp,
  });

  List<BenchmarkGpsPoint> get benchmarkPoints => List.unmodifiable(
    points.map(
      (point) => BenchmarkGpsPoint(
        timestamp: point.sample.timestamp,
        position: point.sample.position,
        speedMetersPerSecond: point.sample.speedMetersPerSecond,
        reportedAccuracyMeters: point.sample.reportedAccuracyMeters,
        headingDegrees: point.sample.headingDegrees,
        startsNewSegment: point.startsNewSegment,
      ),
    ),
  );
}

class _GapMetrics {
  final int overTwoSeconds;
  final int overFiveSeconds;
  final double maximumSeconds;

  const _GapMetrics({
    required this.overTwoSeconds,
    required this.overFiveSeconds,
    required this.maximumSeconds,
  });
}

enum _BenchmarkConfidence { high, medium, low }

class _CurrentSmoothingUpdate {
  final LatLng smoothedPoint;
  final bool shouldAppendRoutePoint;

  const _CurrentSmoothingUpdate({
    required this.smoothedPoint,
    required this.shouldAppendRoutePoint,
  });
}
