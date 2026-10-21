/// Research-grade quality classification for field-recorded GPS sessions.
enum SessionQualityClassification {
  /// Regular ~1Hz sampling, minimal jitter, no large outages, high accuracy (P95 < 10m).
  excellent,

  /// Regular sampling with minor gaps (<15s) and acceptable accuracy (P95 < 20m).
  good,

  /// Elevated multipath noise, frequent dropouts, or gaps exceeding 15s.
  degraded,

  /// Severe data loss, corruption, massive outages, or insufficient samples (<10 points).
  unusable;

  String get value => name;
}

/// Statistical profile of GPS sampling intervals (delta-t between successive points).
class SamplingIntervalStats {
  final double meanIntervalSeconds;
  final double medianIntervalSeconds;
  final double p95IntervalSeconds;
  final double minIntervalSeconds;
  final double maxIntervalSeconds;
  final double stdDevSeconds;

  const SamplingIntervalStats({
    required this.meanIntervalSeconds,
    required this.medianIntervalSeconds,
    required this.p95IntervalSeconds,
    required this.minIntervalSeconds,
    required this.maxIntervalSeconds,
    required this.stdDevSeconds,
  });

  Map<String, dynamic> toJson() => {
        'mean_interval_seconds': double.parse(meanIntervalSeconds.toStringAsFixed(3)),
        'median_interval_seconds': double.parse(medianIntervalSeconds.toStringAsFixed(3)),
        'p95_interval_seconds': double.parse(p95IntervalSeconds.toStringAsFixed(3)),
        'min_interval_seconds': double.parse(minIntervalSeconds.toStringAsFixed(3)),
        'max_interval_seconds': double.parse(maxIntervalSeconds.toStringAsFixed(3)),
        'std_dev_seconds': double.parse(stdDevSeconds.toStringAsFixed(3)),
      };
}

/// Statistical profile of speed observations across a GPS session.
class SpeedProfileStats {
  final double minSpeedMps;
  final double maxSpeedMps;
  final double meanSpeedMps;
  final double medianSpeedMps;
  final int implausibleSpeedCount;

  const SpeedProfileStats({
    required this.minSpeedMps,
    required this.maxSpeedMps,
    required this.meanSpeedMps,
    required this.medianSpeedMps,
    required this.implausibleSpeedCount,
  });

  Map<String, dynamic> toJson() => {
        'min_speed_mps': double.parse(minSpeedMps.toStringAsFixed(2)),
        'max_speed_mps': double.parse(maxSpeedMps.toStringAsFixed(2)),
        'mean_speed_mps': double.parse(meanSpeedMps.toStringAsFixed(2)),
        'median_speed_mps': double.parse(medianSpeedMps.toStringAsFixed(2)),
        'implausible_speed_count': implausibleSpeedCount,
      };
}

/// Statistical profile of reported horizontal accuracy across a GPS session.
class AccuracyProfileStats {
  final double minAccuracyMeters;
  final double maxAccuracyMeters;
  final double meanAccuracyMeters;
  final double medianAccuracyMeters;
  final double p95AccuracyMeters;
  final int lowAccuracyCount; // > 25 meters

  const AccuracyProfileStats({
    required this.minAccuracyMeters,
    required this.maxAccuracyMeters,
    required this.meanAccuracyMeters,
    required this.medianAccuracyMeters,
    required this.p95AccuracyMeters,
    required this.lowAccuracyCount,
  });

  Map<String, dynamic> toJson() => {
        'min_accuracy_meters': double.parse(minAccuracyMeters.toStringAsFixed(2)),
        'max_accuracy_meters': double.parse(maxAccuracyMeters.toStringAsFixed(2)),
        'mean_accuracy_meters': double.parse(meanAccuracyMeters.toStringAsFixed(2)),
        'median_accuracy_meters': double.parse(medianAccuracyMeters.toStringAsFixed(2)),
        'p95_accuracy_meters': double.parse(p95AccuracyMeters.toStringAsFixed(2)),
        'low_accuracy_count': lowAccuracyCount,
      };
}

/// Quantitative measure of stationary drift while user is dwelling / stopped.
class StationaryDriftStats {
  final int stationaryPointsCount;
  final double maxDriftRadiusMeters;
  final double meanDriftRadiusMeters;

  const StationaryDriftStats({
    required this.stationaryPointsCount,
    required this.maxDriftRadiusMeters,
    required this.meanDriftRadiusMeters,
  });

  Map<String, dynamic> toJson() => {
        'stationary_points_count': stationaryPointsCount,
        'max_drift_radius_meters': double.parse(maxDriftRadiusMeters.toStringAsFixed(2)),
        'mean_drift_radius_meters': double.parse(meanDriftRadiusMeters.toStringAsFixed(2)),
      };
}

/// Outage gap statistics for a raw GPS session.
class RawGpsGapSummary {
  final int gapCount;
  final int gapCountOver15s;
  final int gapCountOver30s;
  final double totalGapDurationSeconds;
  final double maxGapDurationSeconds;

  const RawGpsGapSummary({
    required this.gapCount,
    required this.gapCountOver15s,
    required this.gapCountOver30s,
    required this.totalGapDurationSeconds,
    required this.maxGapDurationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'gap_count': gapCount,
        'gap_count_over_15s': gapCountOver15s,
        'gap_count_over_30s': gapCountOver30s,
        'total_gap_duration_seconds':
            double.parse(totalGapDurationSeconds.toStringAsFixed(2)),
        'max_gap_duration_seconds':
            double.parse(maxGapDurationSeconds.toStringAsFixed(2)),
      };
}

/// Detailed counts of missing optional/extended telemetry values across points.
class MissingTelemetryCounts {
  final int missingAltitudeCount;
  final int missingSpeedCount;
  final int missingAccuracyCount;
  final int missingHeadingCount;
  final int missingDeviceSourceCount;

  const MissingTelemetryCounts({
    required this.missingAltitudeCount,
    required this.missingSpeedCount,
    required this.missingAccuracyCount,
    required this.missingHeadingCount,
    required this.missingDeviceSourceCount,
  });

  Map<String, dynamic> toJson() => {
        'missing_altitude_count': missingAltitudeCount,
        'missing_speed_count': missingSpeedCount,
        'missing_accuracy_count': missingAccuracyCount,
        'missing_heading_count': missingHeadingCount,
        'missing_device_source_count': missingDeviceSourceCount,
      };
}

/// Audit tracking for authenticated historical discovery (ALG-0.1).
class RawGpsDiscoveryAudit {
  final int totalDiscovered;
  final int sessionsWithGps;
  final int successfullyExported;
  final int missingSessions;
  final int deniedSessions;
  final int failureCount;
  final List<String> failures;

  const RawGpsDiscoveryAudit({
    required this.totalDiscovered,
    required this.sessionsWithGps,
    required this.successfullyExported,
    required this.missingSessions,
    required this.deniedSessions,
    required this.failureCount,
    required this.failures,
  });

  Map<String, dynamic> toJson() => {
        'total_discovered': totalDiscovered,
        'sessions_with_gps': sessionsWithGps,
        'successfully_exported': successfullyExported,
        'missing_sessions': missingSessions,
        'denied_sessions': deniedSessions,
        'failure_count': failureCount,
        'failures': failures,
      };
}

/// Comprehensive, sanitized research quality report for a single GPS session.
class RawGpsSessionQualityReport {
  final String workoutId;
  final String? activityType;
  final String sourceKind;
  final bool isSyntheticFixture;
  final bool isAlgorithmFiltered;
  final int totalPoints;
  final Duration duration;
  final DateTime? startUtc;
  final DateTime? endUtc;
  final SamplingIntervalStats samplingStats;
  final int duplicateIdentitiesCount;
  final int nonMonotonicTimestampsCount;
  final RawGpsGapSummary gapSummary;
  final SpeedProfileStats speedStats;
  final AccuracyProfileStats accuracyStats;
  final StationaryDriftStats stationaryStats;
  final double rawCumulativeDistanceMeters;
  final MissingTelemetryCounts missingTelemetry;
  final SessionQualityClassification classification;
  final List<String> qualityIssues;

  /// Anti-fabrication flag: explicitly prohibits claiming ground-truth RMSE/P95
  /// positional error without a known survey-grade ground-truth reference trace.
  final bool groundTruthErrorDisallowed;
  final String groundTruthRefusalReason;

  const RawGpsSessionQualityReport({
    required this.workoutId,
    this.activityType,
    required this.sourceKind,
    required this.isSyntheticFixture,
    required this.isAlgorithmFiltered,
    required this.totalPoints,
    required this.duration,
    this.startUtc,
    this.endUtc,
    required this.samplingStats,
    required this.duplicateIdentitiesCount,
    required this.nonMonotonicTimestampsCount,
    required this.gapSummary,
    required this.speedStats,
    required this.accuracyStats,
    required this.stationaryStats,
    required this.rawCumulativeDistanceMeters,
    required this.missingTelemetry,
    required this.classification,
    required this.qualityIssues,
    this.groundTruthErrorDisallowed = true,
    this.groundTruthRefusalReason =
        'Never claim RMSE/P95 ground-truth positional error without independent survey-grade reference measurements.',
  });

  Map<String, dynamic> toJson() => {
        'workout_id': workoutId,
        if (activityType != null) 'activity_type': activityType,
        'source_kind': sourceKind,
        'is_synthetic_fixture': isSyntheticFixture,
        'is_algorithm_filtered': isAlgorithmFiltered,
        'total_points': totalPoints,
        'duration_seconds': duration.inSeconds,
        if (startUtc != null) 'start_utc': startUtc!.toIso8601String(),
        if (endUtc != null) 'end_utc': endUtc!.toIso8601String(),
        'sampling_stats': samplingStats.toJson(),
        'duplicate_identities_count': duplicateIdentitiesCount,
        'non_monotonic_timestamps_count': nonMonotonicTimestampsCount,
        'gap_summary': gapSummary.toJson(),
        'speed_stats': speedStats.toJson(),
        'accuracy_stats': accuracyStats.toJson(),
        'stationary_stats': stationaryStats.toJson(),
        'raw_cumulative_distance_meters':
            double.parse(rawCumulativeDistanceMeters.toStringAsFixed(2)),
        'missing_telemetry': missingTelemetry.toJson(),
        'classification': classification.value,
        'quality_issues': qualityIssues,
        'ground_truth_error_disallowed': groundTruthErrorDisallowed,
        'ground_truth_refusal_reason': groundTruthRefusalReason,
      };
}

/// Aggregate inventory report across multiple inventoried workout sessions.
class RawGpsAggregateInventoryReport {
  final int totalSessions;
  final int totalRawPoints;
  final int realWorldSessions;
  final int syntheticFixtureSessions;
  final int algorithmFilteredSessions;
  final Map<String, int> sessionsByProvenance;
  final Map<String, int> sessionsByQuality;
  final Map<String, int> sessionsByActivity;
  final double aggregateMeanSamplingIntervalSeconds;
  final double aggregateMeanAccuracyMeters;
  final int totalGapsDetected;
  final double aggregateTotalGapDurationSeconds;
  final RawGpsDiscoveryAudit discoveryAudit;
  final List<RawGpsSessionQualityReport> sessionReports;
  final DateTime generatedAtUtc;
  final String? appCommit;

  const RawGpsAggregateInventoryReport({
    required this.totalSessions,
    required this.totalRawPoints,
    required this.realWorldSessions,
    required this.syntheticFixtureSessions,
    required this.algorithmFilteredSessions,
    required this.sessionsByProvenance,
    required this.sessionsByQuality,
    required this.sessionsByActivity,
    required this.aggregateMeanSamplingIntervalSeconds,
    required this.aggregateMeanAccuracyMeters,
    required this.totalGapsDetected,
    required this.aggregateTotalGapDurationSeconds,
    required this.discoveryAudit,
    required this.sessionReports,
    required this.generatedAtUtc,
    this.appCommit,
  });

  Map<String, dynamic> toJson() => {
        'total_sessions': totalSessions,
        'total_raw_points': totalRawPoints,
        'real_world_sessions': realWorldSessions,
        'synthetic_fixture_sessions': syntheticFixtureSessions,
        'algorithm_filtered_sessions': algorithmFilteredSessions,
        'sessions_by_provenance': sessionsByProvenance,
        'sessions_by_quality': sessionsByQuality,
        'sessions_by_activity': sessionsByActivity,
        'aggregate_mean_sampling_interval_seconds':
            double.parse(aggregateMeanSamplingIntervalSeconds.toStringAsFixed(3)),
        'aggregate_mean_accuracy_meters':
            double.parse(aggregateMeanAccuracyMeters.toStringAsFixed(2)),
        'total_gaps_detected': totalGapsDetected,
        'aggregate_total_gap_duration_seconds':
            double.parse(aggregateTotalGapDurationSeconds.toStringAsFixed(2)),
        'discovery_audit': discoveryAudit.toJson(),
        'session_reports': sessionReports.map((r) => r.toJson()).toList(),
        'generated_at_utc': generatedAtUtc.toIso8601String(),
        if (appCommit != null) 'app_commit': appCommit,
      };
}
