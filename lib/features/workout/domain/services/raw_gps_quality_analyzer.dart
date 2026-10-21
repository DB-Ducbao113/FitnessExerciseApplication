import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_export_bundle.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_session_quality.dart';
import 'package:latlong2/latlong.dart';

/// Research-grade quality analyzer for raw GPS traces.
///
/// Computes quantitative telemetry metrics, profiles sampling intervals,
/// evaluates multipath/outage degradation, stationary drift, and assigns
/// strict quality classifications without making unfounded ground-truth claims.
class RawGpsQualityAnalyzer {
  static const double defaultGapThresholdSeconds = 15.0;
  static const double stationarySpeedThresholdMps = 0.4; // < 1.44 km/h
  static const double implausibleSpeedThresholdMps = 45.0; // > 162 km/h
  static const double lowAccuracyThresholdMeters = 25.0;

  static const _distanceCalculator = Distance();

  /// Analyzes a list of raw GPS points for a workout session.
  static RawGpsSessionQualityReport analyzeSession({
    required String workoutId,
    required List<RawGpsExportPoint> points,
    RawGpsExportSourceKind sourceKind = RawGpsExportSourceKind.cloudOnlyUnverified,
    String? activityType,
    double gapThresholdSeconds = defaultGapThresholdSeconds,
  }) {
    final issues = <String>[];

    // 1. Detect synthetic fixtures and algorithm-filtered positions
    final isSynthetic = _detectSyntheticFixture(workoutId, points);
    final isAlgorithmFiltered = _detectAlgorithmFiltered(points);

    if (isSynthetic) {
      issues.add('Synthetic fixture detected: generated/simulated dataset.');
    }
    if (isAlgorithmFiltered) {
      issues.add('Algorithm-filtered coordinates detected: not raw sensor telemetry.');
    }

    if (points.isEmpty) {
      return RawGpsSessionQualityReport(
        workoutId: workoutId,
        activityType: activityType,
        sourceKind: sourceKind.value,
        isSyntheticFixture: isSynthetic,
        isAlgorithmFiltered: isAlgorithmFiltered,
        totalPoints: 0,
        duration: Duration.zero,
        samplingStats: const SamplingIntervalStats(
          meanIntervalSeconds: 0,
          medianIntervalSeconds: 0,
          p95IntervalSeconds: 0,
          minIntervalSeconds: 0,
          maxIntervalSeconds: 0,
          stdDevSeconds: 0,
        ),
        duplicateIdentitiesCount: 0,
        nonMonotonicTimestampsCount: 0,
        gapSummary: const RawGpsGapSummary(
          gapCount: 0,
          gapCountOver15s: 0,
          gapCountOver30s: 0,
          totalGapDurationSeconds: 0,
          maxGapDurationSeconds: 0,
        ),
        speedStats: const SpeedProfileStats(
          minSpeedMps: 0,
          maxSpeedMps: 0,
          meanSpeedMps: 0,
          medianSpeedMps: 0,
          implausibleSpeedCount: 0,
        ),
        accuracyStats: const AccuracyProfileStats(
          minAccuracyMeters: 0,
          maxAccuracyMeters: 0,
          meanAccuracyMeters: 0,
          medianAccuracyMeters: 0,
          p95AccuracyMeters: 0,
          lowAccuracyCount: 0,
        ),
        stationaryStats: const StationaryDriftStats(
          stationaryPointsCount: 0,
          maxDriftRadiusMeters: 0,
          meanDriftRadiusMeters: 0,
        ),
        rawCumulativeDistanceMeters: 0.0,
        missingTelemetry: const MissingTelemetryCounts(
          missingAltitudeCount: 0,
          missingSpeedCount: 0,
          missingAccuracyCount: 0,
          missingHeadingCount: 0,
          missingDeviceSourceCount: 0,
        ),
        classification: SessionQualityClassification.unusable,
        qualityIssues: ['Session contains 0 GPS points.'],
      );
    }

    // 2. Chronological sequence check, duplicates & monotonicity
    var nonMonotonicCount = 0;
    var duplicateCount = 0;
    final seenTimestamps = <int>{};

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final millis = p.timestamp.millisecondsSinceEpoch;
      if (seenTimestamps.contains(millis)) {
        duplicateCount++;
      } else {
        seenTimestamps.add(millis);
      }

      if (i > 0 && p.timestamp.isBefore(points[i - 1].timestamp)) {
        nonMonotonicCount++;
      }
    }

    if (duplicateCount > 0) {
      issues.add('$duplicateCount duplicate timestamp observations detected.');
    }
    if (nonMonotonicCount > 0) {
      issues.add('$nonMonotonicCount non-monotonic (out-of-order) timestamps detected.');
    }

    // Sort stably for statistical metrics
    final sorted = List<RawGpsExportPoint>.from(points)
      ..sort((a, b) {
        final c = a.timestamp.compareTo(b.timestamp);
        if (c != 0) return c;
        final latC = a.latitude.compareTo(b.latitude);
        if (latC != 0) return latC;
        return a.longitude.compareTo(b.longitude);
      });

    final startUtc = sorted.first.timestamp.toUtc();
    final endUtc = sorted.last.timestamp.toUtc();
    final duration = endUtc.difference(startUtc);

    // 3. Sampling intervals
    final intervals = <double>[];
    for (var i = 1; i < sorted.length; i++) {
      final dt = sorted[i].timestamp.difference(sorted[i - 1].timestamp).inMicroseconds /
          1000000.0;
      if (dt > 0) {
        intervals.add(dt);
      }
    }

    final samplingStats = _computeSamplingStats(intervals);

    // 4. Outage gaps (>15s and >30s)
    var gapCount = 0;
    var gapCountOver15s = 0;
    var gapCountOver30s = 0;
    var maxGapSec = 0.0;
    var totalGapSec = 0.0;

    for (var i = 1; i < sorted.length; i++) {
      final deltaSec = sorted[i]
              .timestamp
              .difference(sorted[i - 1].timestamp)
              .inMicroseconds /
          1000000.0;
      if (deltaSec > 15.0) {
        gapCountOver15s += 1;
      }
      if (deltaSec > 30.0) {
        gapCountOver30s += 1;
      }
      if (deltaSec > gapThresholdSeconds) {
        gapCount += 1;
        totalGapSec += deltaSec;
        if (deltaSec > maxGapSec) {
          maxGapSec = deltaSec;
        }
      }
    }
    final gapSummary = RawGpsGapSummary(
      gapCount: gapCount,
      gapCountOver15s: gapCountOver15s,
      gapCountOver30s: gapCountOver30s,
      totalGapDurationSeconds: totalGapSec,
      maxGapDurationSeconds: maxGapSec,
    );
    if (gapSummary.gapCount > 0) {
      issues.add(
        '${gapSummary.gapCount} signal outage gaps >${gapThresholdSeconds}s detected (max gap: ${gapSummary.maxGapDurationSeconds.toStringAsFixed(1)}s, >30s: $gapCountOver30s).',
      );
    }

    // 5. Speed profile
    final speeds = sorted.where((p) => p.speed != null).map((p) => p.speed!).toList();
    var implausibleSpeedCount = 0;
    for (final s in speeds) {
      if (s < 0 || s > implausibleSpeedThresholdMps) {
        implausibleSpeedCount++;
      }
    }
    if (implausibleSpeedCount > 0) {
      issues.add('$implausibleSpeedCount implausible speed observations detected.');
    }
    final speedStats = _computeSpeedStats(speeds, implausibleSpeedCount);

    // 6. Accuracy profile
    final accuracies =
        sorted.where((p) => p.accuracy != null).map((p) => p.accuracy!).toList();
    var lowAccuracyCount = 0;
    for (final a in accuracies) {
      if (a > lowAccuracyThresholdMeters) {
        lowAccuracyCount++;
      }
    }
    if (lowAccuracyCount > 0) {
      issues.add('$lowAccuracyCount points with degraded accuracy (>25m).');
    }
    final accuracyStats = _computeAccuracyStats(accuracies, lowAccuracyCount);

    // 7. Stationary drift profile
    final stationaryStats = _computeStationaryDrift(sorted);
    if (stationaryStats.stationaryPointsCount > 5 &&
        stationaryStats.maxDriftRadiusMeters > 15.0) {
      issues.add(
        'Elevated stationary drift: ${stationaryStats.maxDriftRadiusMeters.toStringAsFixed(1)}m spread during dwelling.',
      );
    }

    // 8. Cumulative route distance (Haversine on raw points)
    var cumulativeDistanceMeters = 0.0;
    for (var i = 1; i < sorted.length; i++) {
      cumulativeDistanceMeters += _distanceCalculator.as(
        LengthUnit.Meter,
        LatLng(sorted[i - 1].latitude, sorted[i - 1].longitude),
        LatLng(sorted[i].latitude, sorted[i].longitude),
      );
    }

    // 9. Missing telemetry field counts
    var missingAltitude = 0;
    var missingSpeed = 0;
    var missingAccuracy = 0;
    var missingHeading = 0;
    var missingDeviceSource = 0;

    for (final p in sorted) {
      if (p.altitude == null) missingAltitude++;
      if (p.speed == null) missingSpeed++;
      if (p.accuracy == null) missingAccuracy++;
      if (p.heading == null) missingHeading++;
      if (p.deviceSource == null || p.deviceSource!.isEmpty) {
        missingDeviceSource++;
      }
    }
    final missingTelemetry = MissingTelemetryCounts(
      missingAltitudeCount: missingAltitude,
      missingSpeedCount: missingSpeed,
      missingAccuracyCount: missingAccuracy,
      missingHeadingCount: missingHeading,
      missingDeviceSourceCount: missingDeviceSource,
    );

    // 10. Quality classification
    final classification = _determineClassification(
      totalPoints: sorted.length,
      gapSummary: gapSummary,
      samplingStats: samplingStats,
      accuracyStats: accuracyStats,
      duplicateCount: duplicateCount,
      nonMonotonicCount: nonMonotonicCount,
      implausibleSpeedCount: implausibleSpeedCount,
    );

    return RawGpsSessionQualityReport(
      workoutId: workoutId,
      activityType: activityType,
      sourceKind: sourceKind.value,
      isSyntheticFixture: isSynthetic,
      isAlgorithmFiltered: isAlgorithmFiltered,
      totalPoints: sorted.length,
      duration: duration,
      startUtc: startUtc,
      endUtc: endUtc,
      samplingStats: samplingStats,
      duplicateIdentitiesCount: duplicateCount,
      nonMonotonicTimestampsCount: nonMonotonicCount,
      gapSummary: gapSummary,
      speedStats: speedStats,
      accuracyStats: accuracyStats,
      stationaryStats: stationaryStats,
      rawCumulativeDistanceMeters: cumulativeDistanceMeters,
      missingTelemetry: missingTelemetry,
      classification: classification,
      qualityIssues: issues,
      groundTruthErrorDisallowed: true,
    );
  }

  /// Aggregates multiple session reports into an inventory summary.
  ///
  /// Strictly isolates real-world field sessions from synthetic fixtures and algorithm-filtered tracks.
  /// Aggregate statistics (sampling interval, accuracy, outages) reflect ONLY real field sessions.
  static RawGpsAggregateInventoryReport aggregateReports(
    List<RawGpsSessionQualityReport> reports, {
    String? appCommit,
    RawGpsDiscoveryAudit? discoveryAudit,
  }) {
    var totalPoints = 0;
    var realWorldSessions = 0;
    var syntheticSessions = 0;
    var filteredSessions = 0;
    final provenanceMap = <String, int>{};
    final qualityMap = <String, int>{};
    final activityMap = <String, int>{};
    var totalGaps = 0;
    var totalGapDuration = 0.0;
    var samplingSum = 0.0;
    var accuracySum = 0.0;
    var validSamplingCount = 0;
    var validAccuracyCount = 0;

    for (final r in reports) {
      totalPoints += r.totalPoints;
      if (r.isSyntheticFixture) {
        syntheticSessions++;
      } else if (r.isAlgorithmFiltered) {
        filteredSessions++;
      } else {
        realWorldSessions++;
        // Exclude fixtures from field-research statistics: aggregate strictly on real sessions
        totalGaps += r.gapSummary.gapCount;
        totalGapDuration += r.gapSummary.totalGapDurationSeconds;

        if (r.samplingStats.meanIntervalSeconds > 0) {
          samplingSum += r.samplingStats.meanIntervalSeconds;
          validSamplingCount++;
        }
        if (r.accuracyStats.meanAccuracyMeters > 0) {
          accuracySum += r.accuracyStats.meanAccuracyMeters;
          validAccuracyCount++;
        }
      }

      provenanceMap[r.sourceKind] = (provenanceMap[r.sourceKind] ?? 0) + 1;
      qualityMap[r.classification.value] =
          (qualityMap[r.classification.value] ?? 0) + 1;

      final activity = r.activityType ?? 'unspecified';
      activityMap[activity] = (activityMap[activity] ?? 0) + 1;
    }

    final meanInterval =
        validSamplingCount > 0 ? samplingSum / validSamplingCount : 0.0;
    final meanAccuracy =
        validAccuracyCount > 0 ? accuracySum / validAccuracyCount : 0.0;

    final audit = discoveryAudit ??
        RawGpsDiscoveryAudit(
          totalDiscovered: reports.length,
          sessionsWithGps: reports.where((r) => r.totalPoints > 0).length,
          successfullyExported: reports.length,
          missingSessions: 0,
          deniedSessions: 0,
          failureCount: 0,
          failures: const [],
        );

    return RawGpsAggregateInventoryReport(
      totalSessions: reports.length,
      totalRawPoints: totalPoints,
      realWorldSessions: realWorldSessions,
      syntheticFixtureSessions: syntheticSessions,
      algorithmFilteredSessions: filteredSessions,
      sessionsByProvenance: provenanceMap,
      sessionsByQuality: qualityMap,
      sessionsByActivity: activityMap,
      aggregateMeanSamplingIntervalSeconds: meanInterval,
      aggregateMeanAccuracyMeters: meanAccuracy,
      totalGapsDetected: totalGaps,
      aggregateTotalGapDurationSeconds: totalGapDuration,
      discoveryAudit: audit,
      sessionReports: reports,
      generatedAtUtc: DateTime.now().toUtc(),
      appCommit: appCommit,
    );
  }

  static bool _detectSyntheticFixture(
    String workoutId,
    List<RawGpsExportPoint> points,
  ) {
    final lowerId = workoutId.toLowerCase();
    if (lowerId.contains('fixture') ||
        lowerId.contains('synthetic') ||
        lowerId.contains('sim_') ||
        lowerId.contains('mock') ||
        lowerId.contains('benchmark_')) {
      return true;
    }

    for (final p in points) {
      final src = (p.deviceSource ?? '').toLowerCase();
      if (src.contains('synthetic') ||
          src.contains('simulator') ||
          src.contains('fixture')) {
        return true;
      }
    }
    return false;
  }

  static bool _detectAlgorithmFiltered(List<RawGpsExportPoint> points) {
    for (final p in points) {
      final src = (p.deviceSource ?? '').toLowerCase();
      if (src.contains('ekf') ||
          src.contains('dbscan') ||
          src.contains('kalman') ||
          src.contains('filtered') ||
          src.contains('smoothed') ||
          src.contains('client_route_snapshot') ||
          src.contains('downsampled')) {
        return true;
      }
    }
    return false;
  }

  static SamplingIntervalStats _computeSamplingStats(List<double> intervals) {
    if (intervals.isEmpty) {
      return const SamplingIntervalStats(
        meanIntervalSeconds: 0,
        medianIntervalSeconds: 0,
        p95IntervalSeconds: 0,
        minIntervalSeconds: 0,
        maxIntervalSeconds: 0,
        stdDevSeconds: 0,
      );
    }

    final sorted = List<double>.from(intervals)..sort();
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final median = sorted[sorted.length ~/ 2];
    final p95 = sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];
    final min = sorted.first;
    final max = sorted.last;

    var varianceSum = 0.0;
    for (final v in intervals) {
      varianceSum += (v - mean) * (v - mean);
    }
    final stdDev = math.sqrt(varianceSum / intervals.length);

    return SamplingIntervalStats(
      meanIntervalSeconds: mean,
      medianIntervalSeconds: median,
      p95IntervalSeconds: p95,
      minIntervalSeconds: min,
      maxIntervalSeconds: max,
      stdDevSeconds: stdDev,
    );
  }

  static SpeedProfileStats _computeSpeedStats(
    List<double> speeds,
    int implausibleCount,
  ) {
    if (speeds.isEmpty) {
      return SpeedProfileStats(
        minSpeedMps: 0,
        maxSpeedMps: 0,
        meanSpeedMps: 0,
        medianSpeedMps: 0,
        implausibleSpeedCount: implausibleCount,
      );
    }

    final sorted = List<double>.from(speeds)..sort();
    final mean = speeds.reduce((a, b) => a + b) / speeds.length;
    final median = sorted[sorted.length ~/ 2];

    return SpeedProfileStats(
      minSpeedMps: sorted.first,
      maxSpeedMps: sorted.last,
      meanSpeedMps: mean,
      medianSpeedMps: median,
      implausibleSpeedCount: implausibleCount,
    );
  }

  static AccuracyProfileStats _computeAccuracyStats(
    List<double> accuracies,
    int lowAccuracyCount,
  ) {
    if (accuracies.isEmpty) {
      return AccuracyProfileStats(
        minAccuracyMeters: 0,
        maxAccuracyMeters: 0,
        meanAccuracyMeters: 0,
        medianAccuracyMeters: 0,
        p95AccuracyMeters: 0,
        lowAccuracyCount: lowAccuracyCount,
      );
    }

    final sorted = List<double>.from(accuracies)..sort();
    final mean = accuracies.reduce((a, b) => a + b) / accuracies.length;
    final median = sorted[sorted.length ~/ 2];
    final p95 = sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];

    return AccuracyProfileStats(
      minAccuracyMeters: sorted.first,
      maxAccuracyMeters: sorted.last,
      meanAccuracyMeters: mean,
      medianAccuracyMeters: median,
      p95AccuracyMeters: p95,
      lowAccuracyCount: lowAccuracyCount,
    );
  }

  static StationaryDriftStats _computeStationaryDrift(
    List<RawGpsExportPoint> points,
  ) {
    final stationaryPoints = points
        .where(
          (p) =>
              p.speed != null && p.speed! <= stationarySpeedThresholdMps,
        )
        .toList(growable: false);

    if (stationaryPoints.length < 2) {
      return StationaryDriftStats(
        stationaryPointsCount: stationaryPoints.length,
        maxDriftRadiusMeters: 0,
        meanDriftRadiusMeters: 0,
      );
    }

    // Centroid of stationary positions
    var latSum = 0.0;
    var lonSum = 0.0;
    for (final p in stationaryPoints) {
      latSum += p.latitude;
      lonSum += p.longitude;
    }
    final centroid = LatLng(
      latSum / stationaryPoints.length,
      lonSum / stationaryPoints.length,
    );

    var maxDisplacement = 0.0;
    var displacementSum = 0.0;

    for (final p in stationaryPoints) {
      final d = _distanceCalculator.as(
        LengthUnit.Meter,
        centroid,
        LatLng(p.latitude, p.longitude),
      );
      displacementSum += d;
      if (d > maxDisplacement) {
        maxDisplacement = d;
      }
    }

    return StationaryDriftStats(
      stationaryPointsCount: stationaryPoints.length,
      maxDriftRadiusMeters: maxDisplacement,
      meanDriftRadiusMeters: displacementSum / stationaryPoints.length,
    );
  }

  static SessionQualityClassification _determineClassification({
    required int totalPoints,
    required RawGpsGapSummary gapSummary,
    required SamplingIntervalStats samplingStats,
    required AccuracyProfileStats accuracyStats,
    required int duplicateCount,
    required int nonMonotonicCount,
    required int implausibleSpeedCount,
  }) {
    if (totalPoints < 10 ||
        gapSummary.maxGapDurationSeconds > 300.0 ||
        nonMonotonicCount > totalPoints * 0.20) {
      return SessionQualityClassification.unusable;
    }

    if (gapSummary.maxGapDurationSeconds > 30.0 ||
        accuracyStats.p95AccuracyMeters > lowAccuracyThresholdMeters ||
        duplicateCount > totalPoints * 0.10 ||
        implausibleSpeedCount > 2) {
      return SessionQualityClassification.degraded;
    }

    if (gapSummary.gapCount == 0 &&
        accuracyStats.p95AccuracyMeters < 10.0 &&
        samplingStats.meanIntervalSeconds >= 0.85 &&
        samplingStats.meanIntervalSeconds <= 1.25 &&
        duplicateCount == 0 &&
        nonMonotonicCount == 0 &&
        implausibleSpeedCount == 0) {
      return SessionQualityClassification.excellent;
    }

    return SessionQualityClassification.good;
  }
}
