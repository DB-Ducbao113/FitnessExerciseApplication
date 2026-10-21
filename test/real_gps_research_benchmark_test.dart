import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_trace.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/experimental_gps_recovery_state_machine.dart';

/// Proper, fail-closed CSV parser for Aetron raw GPS recordings.
List<FieldGpsSample> parseGpsCsvFile(File file) {
  final lines = file.readAsLinesSync();
  if (lines.isEmpty) {
    throw const FormatException('GPS CSV file is empty');
  }

  final header = lines.first.split(',').map((c) => c.trim()).toList();
  const expectedHeader = [
    'workout_id',
    'timestamp',
    'latitude',
    'longitude',
    'altitude',
    'speed',
    'accuracy',
    'heading',
    'device_source',
    'confidence',
  ];

  if (header.length != expectedHeader.length) {
    throw FormatException(
      'Invalid CSV header column count: expected ${expectedHeader.length}, got ${header.length}',
    );
  }
  for (var i = 0; i < expectedHeader.length; i++) {
    if (header[i] != expectedHeader[i]) {
      throw FormatException(
        'Invalid CSV column at index $i: expected "${expectedHeader[i]}", got "${header[i]}"',
      );
    }
  }

  final samples = <FieldGpsSample>[];
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final cols = line.split(',');
    if (cols.length != 10) {
      throw FormatException(
        'Line ${i + 1} has ${cols.length} columns, expected 10: "$line"',
      );
    }

    final workoutId = cols[0].trim();
    if (workoutId.isEmpty) {
      throw FormatException('Line ${i + 1} has empty workout_id');
    }

    final timestamp = DateTime.tryParse(cols[1].trim())?.toUtc();
    if (timestamp == null) {
      throw FormatException('Line ${i + 1} has invalid timestamp: "${cols[1]}"');
    }

    final lat = double.tryParse(cols[2].trim());
    if (lat == null || !lat.isFinite || lat < -90.0 || lat > 90.0) {
      throw FormatException('Line ${i + 1} has invalid latitude: "${cols[2]}"');
    }

    final lng = double.tryParse(cols[3].trim());
    if (lng == null || !lng.isFinite || lng < -180.0 || lng > 180.0) {
      throw FormatException('Line ${i + 1} has invalid longitude: "${cols[3]}"');
    }

    final alt = cols[4].trim().isNotEmpty ? double.tryParse(cols[4].trim()) : null;
    if (cols[4].trim().isNotEmpty && (alt == null || !alt.isFinite)) {
      throw FormatException('Line ${i + 1} has invalid altitude: "${cols[4]}"');
    }

    final spd = cols[5].trim().isNotEmpty ? double.tryParse(cols[5].trim()) : 0.0;
    if (spd == null || !spd.isFinite || spd < 0.0) {
      throw FormatException('Line ${i + 1} has invalid speed: "${cols[5]}"');
    }

    final acc = cols[6].trim().isNotEmpty ? double.tryParse(cols[6].trim()) : 10.0;
    if (acc == null || !acc.isFinite || acc < 0.0) {
      throw FormatException('Line ${i + 1} has invalid accuracy: "${cols[6]}"');
    }

    final hdg = cols[7].trim().isNotEmpty ? double.tryParse(cols[7].trim()) : null;
    if (cols[7].trim().isNotEmpty && (hdg == null || !hdg.isFinite || hdg < 0.0 || hdg > 360.0)) {
      throw FormatException('Line ${i + 1} has invalid heading: "${cols[7]}"');
    }

    final src = cols[8].trim().isNotEmpty ? cols[8].trim() : null;
    final conf = cols[9].trim().isNotEmpty ? cols[9].trim() : null;

    samples.add(FieldGpsSample(
      workoutId: workoutId,
      timestamp: timestamp,
      position: LatLng(lat, lng),
      altitudeMeters: alt,
      speedMetersPerSecond: spd,
      reportedAccuracyMeters: acc,
      headingDegrees: hdg,
      deviceSource: src,
      confidence: conf,
    ));
  }
  return samples;
}

void main() {
  const expectedCsvPath = 'exports/historical/aetron_raw_gps_combined.csv';
  const expectedSha256 =
      '4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5';

  final bool hasPrivateDataset = File(expectedCsvPath).existsSync();

  group('AETRON Real GPS Research Benchmark Suite (Opt-in Local Research)', () {
    late File csvFile;
    late List<FieldGpsSample> allParsedSamples;
    late Map<String, List<FieldGpsSample>> rawSessions;

    setUpAll(() {
      if (!hasPrivateDataset) return;

      csvFile = File(expectedCsvPath);
      final bytes = csvFile.readAsBytesSync();
      final actualHash = sha256.convert(bytes).toString();
      expect(
        actualHash,
        equals(expectedSha256),
        reason: 'CSV SHA-256 hash must match verified baseline',
      );

      allParsedSamples = parseGpsCsvFile(csvFile);
      expect(
        allParsedSamples.length,
        equals(10779),
        reason: 'CSV must contain exactly 10,779 valid data points',
      );

      rawSessions = <String, List<FieldGpsSample>>{};
      for (final sample in allParsedSamples) {
        rawSessions.putIfAbsent(sample.workoutId, () => []).add(sample);
      }
    });

    test('BENCH-01: Discovered CSV contains 7 sessions and 10,779 points with valid schema', () {
      expect(rawSessions.length, equals(7));
      final totalParsed = rawSessions.values.fold<int>(0, (sum, list) => sum + list.length);
      expect(totalParsed, equals(10779));

      for (final entry in rawSessions.entries) {
        expect(entry.value.length, greaterThan(0));
        for (final s in entry.value) {
          expect(s.workoutId, equals(entry.key));
          expect(s.position.latitude.isFinite, isTrue);
          expect(s.position.longitude.isFinite, isTrue);
          expect(s.reportedAccuracyMeters, greaterThan(0));
          expect(s.speedMetersPerSecond, greaterThanOrEqualTo(0));
          expect(s.altitudeMeters, isNotNull);
        }
      }
    });

    test('BENCH-02: Dataset audit verifies original timestamp ordering before sorting, nominal 1Hz rate, and outage counts', () {
      var totalOriginalInversions = 0;
      var totalDups = 0;
      var totalGapsOver2s = 0;
      var totalGapsOver5s = 0;
      var totalGapsOver15s = 0;
      var totalGapsOver30s = 0;

      for (final entry in rawSessions.entries) {
        final originalSequence = entry.value;

        // Requirement QA: Validate original sequence ordering BEFORE sorting
        for (var i = 1; i < originalSequence.length; i++) {
          if (originalSequence[i].timestamp.isBefore(originalSequence[i - 1].timestamp)) {
            totalOriginalInversions++;
          }
        }

        final sorted = List<FieldGpsSample>.from(originalSequence)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        for (var i = 1; i < sorted.length; i++) {
          final dt = sorted[i].timestamp.difference(sorted[i - 1].timestamp).inMilliseconds / 1000.0;
          expect(dt, greaterThanOrEqualTo(0.0), reason: 'Sorted timestamps must be non-decreasing');
          if (dt == 0.0) totalDups++;
          if (dt > 2.0) totalGapsOver2s++;
          if (dt > 5.0) totalGapsOver5s++;
          if (dt > 15.0) totalGapsOver15s++;
          if (dt > 30.0) totalGapsOver30s++;
        }
      }

      // Assert zero original inversions before sorting
      expect(
        totalOriginalInversions,
        equals(0),
        reason: 'Original raw CSV rows must be strictly chronological before any sort operation',
      );
      expect(totalDups, equals(49));
      expect(totalGapsOver15s, equals(1)); // exactly 1 true outage >15s (17.0s)
      expect(totalGapsOver30s, equals(0)); // 0 severe outages >30s
      expect(totalGapsOver5s, equals(89));
      expect(totalGapsOver2s, equals(149));
    });

    test('BENCH-03: Production-baseline replay equivalence test against GpsSmoothingService', () {
      const smoothingService = GpsSmoothingService();
      final p1 = LatLng(10.7700, 106.6900);
      final p2 = LatLng(10.7705, 106.6905);

      final update = smoothingService.smoothAcceptedPoint(
        activityType: 'cycling',
        acceptedPoint: p2,
        previousAcceptedPoint: p1,
        previousSmoothedPoint: p1,
        lastSmoothedRoutePoint: p1,
        accuracyMeters: 5.0,
        speedMs: 5.0,
        timeDeltaSec: 1.0,
        gpsGapDurationSec: 0.0,
      );

      // High confidence alpha is 0.72 in production GpsSmoothingService
      expect(update.confidence, GpsConfidence.high);
      expect(update.smoothedPoint.latitude, closeTo(p1.latitude * 0.28 + p2.latitude * 0.72, 1e-6));
      expect(update.smoothedPoint.longitude, closeTo(p1.longitude * 0.28 + p2.longitude * 0.72, 1e-6));
    });

    test('BENCH-04: Replays all 5 pipelines deterministically and produces sanitized, coordinate-free benchmark & manifest', () async {
      const runner = FieldGpsBenchmarkRunner();
      final benchmarkResults = <String, dynamic>{};
      final workoutSummary = <Map<String, dynamic>>[];

      var totalAppBaselineDistance = 0.0;
      var totalCurrentDisplayDistance = 0.0;
      var totalEkfDisplayDistance = 0.0;
      var totalDbscanDisplayDistance = 0.0;
      var totalEkfDbscanDisplayDistance = 0.0;
      var totalDOptDistance = 0.0;
      var totalValidatedPointsCount = 0;

      for (final entry in rawSessions.entries) {
        final wid = entry.key;
        final samples = List<FieldGpsSample>.from(entry.value)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final deduped = <FieldGpsSample>[];
        var dupCount = 0;
        for (final s in samples) {
          if (deduped.isNotEmpty && deduped.last.timestamp == s.timestamp) {
            dupCount++;
            continue;
          }
          deduped.add(s);
        }

        final trace = FieldGpsTrace(
          workoutId: wid,
          samples: List.unmodifiable(deduped),
          sourceLineCount: samples.length,
          duplicateTimestampCount: dupCount,
        );

        final report = runner.run(
          trace,
          variants: {
            GpsPipelineVariant.current,
            GpsPipelineVariant.ekf,
            GpsPipelineVariant.dbscan,
            GpsPipelineVariant.ekfThenDbscan,
          },
        );

        final cur = report.results[GpsPipelineVariant.current]!;
        final ekf = report.results[GpsPipelineVariant.ekf]!;
        final dbscan = report.results[GpsPipelineVariant.dbscan]!;
        final ekfDbscan = report.results[GpsPipelineVariant.ekfThenDbscan]!;

        // Run D+Opt candidate on the exact same validated points
        final validatedPoints = cur.validatedInputPoints;
        totalValidatedPointsCount += validatedPoints.length;

        final dOptEkf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
        final dOptFsm = ExperimentalGpsRecoveryStateMachine(
          ekf: dOptEkf,
          enableAlongTrackProjection: false,
          enableBoundedHybridDistance: true,
          enableGapOverlapCorrection: true,
          enableProbationVarianceInflation: true,
          enableAlternativeRollbackRecovery: true,
          enableMultiFixHeadingEstimation: true,
          enableProbationConsecutiveRejections: true,
          enableAdaptiveTurnUncertainty: true,
          enableNoiseAwareKinematicScreening: true,
        );

        final dOptStopwatch = Stopwatch()..start();
        DateTime? prevT;
        final dOptStateCounts = <String, int>{};

        for (final pt in validatedPoints) {
          final t = pt.timestamp;
          final dt = prevT == null
              ? 1.0
              : t.difference(prevT).inMilliseconds / 1000.0;
          prevT = t;

          final out = dOptFsm.processMeasurement(
            point: pt.position,
            accuracyMeters: pt.reportedAccuracyMeters,
            timeDeltaSec: dt,
            timestamp: t,
            speedMs: pt.speedMetersPerSecond,
            headingDeg: pt.headingDegrees,
            hasAuxiliarySensors: pt.headingDegrees != null,
          );

          dOptStateCounts[out.state.name] = (dOptStateCounts[out.state.name] ?? 0) + 1;
        }
        dOptStopwatch.stop();

        final dOptDistance = dOptFsm.accumulatedDistanceMeters;
        final dOptCost = validatedPoints.isEmpty
            ? 0.0
            : dOptStopwatch.elapsedMicroseconds / validatedPoints.length;

        totalAppBaselineDistance += cur.appDistanceMeters;
        totalCurrentDisplayDistance += cur.displayDistanceMeters;
        totalEkfDisplayDistance += ekf.displayDistanceMeters;
        totalDbscanDisplayDistance += dbscan.displayDistanceMeters;
        totalEkfDbscanDisplayDistance += ekfDbscan.displayDistanceMeters;
        totalDOptDistance += dOptDistance;

        workoutSummary.add({
          'workout_id': wid,
          'raw_points': samples.length,
          'deduped_points': deduped.length,
          'duplicate_timestamps': dupCount,
          'validated_points': validatedPoints.length,
          'acceptance_rate_pct': double.parse((validatedPoints.length / deduped.length * 100.0).toStringAsFixed(2)),
          'rejection_counts': cur.rejectionCounts,
          'current_app_baseline_distance_m': double.parse(cur.appDistanceMeters.toStringAsFixed(2)),
          'current_display_distance_m': double.parse(cur.displayDistanceMeters.toStringAsFixed(2)),
          'ekf_display_distance_m': double.parse(ekf.displayDistanceMeters.toStringAsFixed(2)),
          'dbscan_display_distance_m': double.parse(dbscan.displayDistanceMeters.toStringAsFixed(2)),
          'ekf_dbscan_display_distance_m': double.parse(ekfDbscan.displayDistanceMeters.toStringAsFixed(2)),
          'dopt_distance_m': double.parse(dOptDistance.toStringAsFixed(2)),
          'deviations_vs_app_baseline': {
            'current_display_m': double.parse((cur.displayDistanceMeters - cur.appDistanceMeters).toStringAsFixed(2)),
            'current_display_pct': double.parse(((cur.displayDistanceMeters - cur.appDistanceMeters) / cur.appDistanceMeters * 100).toStringAsFixed(2)),
            'ekf_m': double.parse((ekf.displayDistanceMeters - cur.appDistanceMeters).toStringAsFixed(2)),
            'ekf_pct': double.parse(((ekf.displayDistanceMeters - cur.appDistanceMeters) / cur.appDistanceMeters * 100).toStringAsFixed(2)),
            'dbscan_m': double.parse((dbscan.displayDistanceMeters - cur.appDistanceMeters).toStringAsFixed(2)),
            'dbscan_pct': double.parse(((dbscan.displayDistanceMeters - cur.appDistanceMeters) / cur.appDistanceMeters * 100).toStringAsFixed(2)),
            'ekf_dbscan_m': double.parse((ekfDbscan.displayDistanceMeters - cur.appDistanceMeters).toStringAsFixed(2)),
            'ekf_dbscan_pct': double.parse(((ekfDbscan.displayDistanceMeters - cur.appDistanceMeters) / cur.appDistanceMeters * 100).toStringAsFixed(2)),
            'dopt_m': double.parse((dOptDistance - cur.appDistanceMeters).toStringAsFixed(2)),
            'dopt_pct': double.parse(((dOptDistance - cur.appDistanceMeters) / cur.appDistanceMeters * 100).toStringAsFixed(2)),
          },
          'dbscan_dwell_clusters': dbscan.detectedDwellClusterCount,
          'dbscan_phantom_drift_removed_m': double.parse(dbscan.phantomDriftRemovedMeters.toStringAsFixed(2)),
          'dopt_state_counts': dOptStateCounts,
          'dopt_escrow_m': double.parse(dOptFsm.escrowDistanceMeters.toStringAsFixed(2)),
          'latencies_us_per_point': {
            'current': double.parse(cur.processingMicrosecondsPerPoint.toStringAsFixed(2)),
            'ekf': double.parse(ekf.processingMicrosecondsPerPoint.toStringAsFixed(2)),
            'dbscan': double.parse(dbscan.processingMicrosecondsPerPoint.toStringAsFixed(2)),
            'ekf_dbscan': double.parse(ekfDbscan.processingMicrosecondsPerPoint.toStringAsFixed(2)),
            'dopt': double.parse(dOptCost.toStringAsFixed(2)),
          },
        });
      }

      benchmarkResults['dataset_summary'] = {
        'csv_path': expectedCsvPath,
        'csv_sha256': expectedSha256,
        'total_raw_points': 10779,
        'total_sessions': 7,
        'total_validated_points': totalValidatedPointsCount,
        'overall_acceptance_rate_pct': double.parse((totalValidatedPointsCount / (10779 - 49) * 100.0).toStringAsFixed(2)),
      };

      benchmarkResults['aggregate_totals'] = {
        'current_app_baseline_distance_m': double.parse(totalAppBaselineDistance.toStringAsFixed(2)),
        'current_display_distance_m': double.parse(totalCurrentDisplayDistance.toStringAsFixed(2)),
        'ekf_display_distance_m': double.parse(totalEkfDisplayDistance.toStringAsFixed(2)),
        'dbscan_display_distance_m': double.parse(totalDbscanDisplayDistance.toStringAsFixed(2)),
        'ekf_dbscan_display_distance_m': double.parse(totalEkfDbscanDisplayDistance.toStringAsFixed(2)),
        'dopt_distance_m': double.parse(totalDOptDistance.toStringAsFixed(2)),
        'deviations_vs_current_app_baseline': {
          'current_display_pct': double.parse(((totalCurrentDisplayDistance - totalAppBaselineDistance) / totalAppBaselineDistance * 100).toStringAsFixed(2)),
          'ekf_pct': double.parse(((totalEkfDisplayDistance - totalAppBaselineDistance) / totalAppBaselineDistance * 100).toStringAsFixed(2)),
          'dbscan_pct': double.parse(((totalDbscanDisplayDistance - totalAppBaselineDistance) / totalAppBaselineDistance * 100).toStringAsFixed(2)),
          'ekf_dbscan_pct': double.parse(((totalEkfDbscanDisplayDistance - totalAppBaselineDistance) / totalAppBaselineDistance * 100).toStringAsFixed(2)),
          'dopt_pct': double.parse(((totalDOptDistance - totalAppBaselineDistance) / totalAppBaselineDistance * 100).toStringAsFixed(2)),
        },
        'deviations_vs_current_display_distance': {
          'ekf_pct': double.parse(((totalEkfDisplayDistance - totalCurrentDisplayDistance) / totalCurrentDisplayDistance * 100).toStringAsFixed(2)),
          'dbscan_pct': double.parse(((totalDbscanDisplayDistance - totalCurrentDisplayDistance) / totalCurrentDisplayDistance * 100).toStringAsFixed(2)),
          'ekf_dbscan_pct': double.parse(((totalEkfDbscanDisplayDistance - totalCurrentDisplayDistance) / totalCurrentDisplayDistance * 100).toStringAsFixed(2)),
          'dopt_pct': double.parse(((totalDOptDistance - totalCurrentDisplayDistance) / totalCurrentDisplayDistance * 100).toStringAsFixed(2)),
        },
      };

      benchmarkResults['ground_truth_policy'] = {
        'ground_truth_available': false,
        'claim_prohibition': 'Never describe distance deviation from baseline as ground-truth error without survey-grade reference measurements.',
      };

      benchmarkResults['sessions'] = workoutSummary;

      // Write reproducible report to docs/benchmarks/real_gps_research_benchmark.json
      final outDir = Directory('docs/benchmarks');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final jsonFile = File('docs/benchmarks/real_gps_research_benchmark.json');
      await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(benchmarkResults));

      // Generate reproducibility manifest
      final manifestFile = File('docs/benchmarks/real_gps_research_benchmark_manifest.json');
      final manifestJson = {
        'schema_version': '1.0.0',
        'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
        'dataset_evidence': {
          'source_file': 'exports/historical/aetron_raw_gps_combined.csv',
          'file_sha256': expectedSha256,
          'total_raw_points': 10779,
          'deduped_points': 10730,
          'session_count': 7,
          'opt_in_execution_mode': 'local_authorized_research',
        },
        'benchmark_results_file': 'docs/benchmarks/real_gps_research_benchmark.json',
        'benchmark_results_sha256': sha256.convert(utf8.encode(jsonEncode(benchmarkResults))).toString(),
        'privacy_policy': {
          'coordinates_scrubbed': true,
          'personal_data_retained': false,
          'public_git_exposure_prohibited': true,
        },
        'scientific_governance': {
          'ground_truth_reference_present': false,
          'metric_nature': 'relative_algorithm_deviation_only',
          'production_decision': 'HOLD_EXISTING_PRODUCTION_ALGORITHM',
        },
      };
      await manifestFile.writeAsString(const JsonEncoder.withIndent('  ').convert(manifestJson));

      // Assert expected aggregate values
      expect(totalAppBaselineDistance, closeTo(57892.0, 1.0));
      expect(totalCurrentDisplayDistance, closeTo(57069.1, 1.0));
      expect(totalEkfDisplayDistance, closeTo(57662.6, 1.0));
      expect(totalDbscanDisplayDistance, closeTo(57883.6, 1.0));
      expect(totalDOptDistance, closeTo(58689.6, 1.0));
    });
  }, skip: !hasPrivateDataset ? 'Private real-device GPS dataset not present in public checkout (opt-in research benchmark)' : null);
}
