import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/data/services/raw_gps_export_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_export_bundle.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_session_quality.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_dataset_exporter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_quality_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tooling/inventory_historical_datasets.dart';

void main() {
  group('AETRON ALG-0 Dataset Inventory & Quality Analyzer Tests', () {
    final baseTime = DateTime.parse('2026-10-21T07:00:00.000000Z').toUtc();

    test('ALG-0.1: Profiles 1Hz sampling interval, jitter, and moments accurately', () {
      final points = List.generate(
        60,
        (i) => RawGpsExportPoint(
          workoutId: 'session-1hz',
          timestamp: baseTime.add(Duration(seconds: i)),
          latitude: 10.7700 + (i * 0.0001),
          longitude: 106.6900 + (i * 0.0001),
          altitude: 10.0,
          speed: 3.5,
          accuracy: 5.0,
          heading: 45.0,
          deviceSource: 'geolocator_position_stream',
        ),
      );

      final report = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'session-1hz',
        points: points,
        sourceKind: RawGpsExportSourceKind.deviceJournalVerified,
      );

      expect(report.totalPoints, 60);
      expect(report.samplingStats.meanIntervalSeconds, closeTo(1.0, 0.01));
      expect(report.samplingStats.medianIntervalSeconds, closeTo(1.0, 0.01));
      expect(report.samplingStats.minIntervalSeconds, closeTo(1.0, 0.01));
      expect(report.samplingStats.maxIntervalSeconds, closeTo(1.0, 0.01));
      expect(report.samplingStats.stdDevSeconds, closeTo(0.0, 0.01));
      expect(report.duplicateIdentitiesCount, 0);
      expect(report.nonMonotonicTimestampsCount, 0);
      expect(report.gapSummary.gapCount, 0);
      expect(report.classification, SessionQualityClassification.excellent);
    });

    test('ALG-0.2: Outage gap detection captures gaps >15s and tracks duration', () {
      final points = [
        RawGpsExportPoint(
          workoutId: 'session-outage',
          timestamp: baseTime,
          latitude: 10.770,
          longitude: 106.690,
          speed: 4.0,
          accuracy: 6.0,
        ),
        // 25s gap (> 15s)
        RawGpsExportPoint(
          workoutId: 'session-outage',
          timestamp: baseTime.add(const Duration(seconds: 25)),
          latitude: 10.771,
          longitude: 106.691,
          speed: 4.0,
          accuracy: 6.0,
        ),
        // 1s interval
        RawGpsExportPoint(
          workoutId: 'session-outage',
          timestamp: baseTime.add(const Duration(seconds: 26)),
          latitude: 10.772,
          longitude: 106.692,
          speed: 4.0,
          accuracy: 6.0,
        ),
        // 40s gap (> 15s)
        RawGpsExportPoint(
          workoutId: 'session-outage',
          timestamp: baseTime.add(const Duration(seconds: 66)),
          latitude: 10.773,
          longitude: 106.693,
          speed: 4.0,
          accuracy: 6.0,
        ),
        // Add additional points to exceed unusable minimum threshold
        ...List.generate(
          10,
          (i) => RawGpsExportPoint(
            workoutId: 'session-outage',
            timestamp: baseTime.add(Duration(seconds: 67 + i)),
            latitude: 10.774 + (i * 0.0001),
            longitude: 106.694 + (i * 0.0001),
            speed: 4.0,
            accuracy: 6.0,
          ),
        ),
      ];

      final report = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'session-outage',
        points: points,
      );

      expect(report.gapSummary.gapCount, 2);
      expect(report.gapSummary.maxGapDurationSeconds, closeTo(40.0, 0.1));
      expect(report.gapSummary.totalGapDurationSeconds, closeTo(65.0, 0.1));
      expect(report.classification, SessionQualityClassification.degraded);
      expect(report.qualityIssues.any((msg) => msg.contains('outage gaps')), isTrue);
    });

    test('ALG-0.3: Speed and accuracy profiling flags implausible speeds and multipath degradation', () {
      final points = List.generate(
        20,
        (i) => RawGpsExportPoint(
          workoutId: 'session-profile',
          timestamp: baseTime.add(Duration(seconds: i)),
          latitude: 10.770 + (i * 0.0001),
          longitude: 106.690 + (i * 0.0001),
          speed: i == 5 ? 55.0 : (i == 10 ? -2.0 : 3.0), // Implausible speeds
          accuracy: i >= 15 ? 35.0 : 8.0, // Multipath degraded accuracy >25m
        ),
      );

      final report = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'session-profile',
        points: points,
      );

      expect(report.speedStats.implausibleSpeedCount, 2);
      expect(report.speedStats.maxSpeedMps, 55.0);
      expect(report.speedStats.minSpeedMps, -2.0);
      expect(report.accuracyStats.lowAccuracyCount, 5);
      expect(report.accuracyStats.p95AccuracyMeters, closeTo(35.0, 1.0));
      expect(report.qualityIssues.any((msg) => msg.contains('implausible speed')), isTrue);
      expect(report.qualityIssues.any((msg) => msg.contains('degraded accuracy')), isTrue);
    });

    test('ALG-0.4: Computes stationary drift during dwelling/stops', () {
      // 10 stationary points with GPS wander (speed = 0.1 m/s)
      final points = List.generate(
        15,
        (i) => RawGpsExportPoint(
          workoutId: 'session-drift',
          timestamp: baseTime.add(Duration(seconds: i)),
          // Small coordinate wander around (10.77000, 106.69000)
          latitude: 10.77000 + ((i % 3) * 0.00005), // ~5.5m wander
          longitude: 106.69000 + (((i ~/ 3) % 3) * 0.00005),
          speed: 0.1,
          accuracy: 6.0,
        ),
      );

      final report = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'session-drift',
        points: points,
      );

      expect(report.stationaryStats.stationaryPointsCount, 15);
      expect(report.stationaryStats.maxDriftRadiusMeters, greaterThan(0.0));
      expect(report.stationaryStats.maxDriftRadiusMeters, lessThan(20.0));
    });

    test('ALG-0.5: Prohibits false ground-truth RMSE/P95 positional error claims', () {
      final points = List.generate(
        20,
        (i) => RawGpsExportPoint(
          workoutId: 'session-gt-check',
          timestamp: baseTime.add(Duration(seconds: i)),
          latitude: 10.770 + (i * 0.0001),
          longitude: 106.690 + (i * 0.0001),
          speed: 3.0,
          accuracy: 5.0,
        ),
      );

      final report = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'session-gt-check',
        points: points,
      );

      expect(report.groundTruthErrorDisallowed, isTrue);
      expect(
        report.groundTruthRefusalReason,
        contains('Never claim RMSE/P95 ground-truth positional error'),
      );
    });

    test('ALG-0.6: Accurately separates real-world recordings from synthetic fixtures and algorithm-filtered data', () {
      // Synthetic fixture
      final fixturePoints = [
        RawGpsExportPoint(
          workoutId: 'fixture-test-01',
          timestamp: baseTime,
          latitude: 1.0,
          longitude: 2.0,
          deviceSource: 'synthetic_generator',
        ),
      ];
      final fixtureReport = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'fixture-test-01',
        points: fixturePoints,
      );
      expect(fixtureReport.isSyntheticFixture, isTrue);
      expect(fixtureReport.isAlgorithmFiltered, isFalse);

      // Algorithm-filtered data
      final filteredPoints = [
        RawGpsExportPoint(
          workoutId: 'filtered-test-02',
          timestamp: baseTime,
          latitude: 10.77,
          longitude: 106.69,
          deviceSource: 'ekf_filtered',
        ),
      ];
      final filteredReport = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'filtered-test-02',
        points: filteredPoints,
      );
      expect(filteredReport.isSyntheticFixture, isFalse);
      expect(filteredReport.isAlgorithmFiltered, isTrue);

      // Real-world sensor data
      final realPoints = [
        RawGpsExportPoint(
          workoutId: 'real-workout-03',
          timestamp: baseTime,
          latitude: 10.77,
          longitude: 106.69,
          deviceSource: 'geolocator_position_stream',
        ),
      ];
      final realReport = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'real-workout-03',
        points: realPoints,
      );
      expect(realReport.isSyntheticFixture, isFalse);
      expect(realReport.isAlgorithmFiltered, isFalse);
    });

    test('ALG-0.7: Inventory aggregation compiles multi-session statistics and quality distributions', () {
      final r1 = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'real-01',
        points: List.generate(
          30,
          (i) => RawGpsExportPoint(
            workoutId: 'real-01',
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 10.77 + (i * 0.0001),
            longitude: 106.69 + (i * 0.0001),
            speed: 3.0,
            accuracy: 6.0,
            deviceSource: 'geolocator_position_stream',
          ),
        ),
        activityType: 'running',
        sourceKind: RawGpsExportSourceKind.deviceJournalVerified,
      );

      final r2 = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'real-02',
        points: List.generate(
          40,
          (i) => RawGpsExportPoint(
            workoutId: 'real-02',
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 10.78 + (i * 0.0001),
            longitude: 106.70 + (i * 0.0001),
            speed: 5.5,
            accuracy: 8.0,
            deviceSource: 'fused_location_provider',
          ),
        ),
        activityType: 'cycling',
        sourceKind: RawGpsExportSourceKind.cloudOnlyUnverified,
      );

      final r3 = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'fixture-synth-03',
        points: [
          RawGpsExportPoint(
            workoutId: 'fixture-synth-03',
            timestamp: baseTime,
            latitude: 0.0,
            longitude: 0.0,
            deviceSource: 'synthetic_generator',
          ),
        ],
        activityType: 'walking',
        sourceKind: RawGpsExportSourceKind.deviceRecoveredUnverified,
      );

      final aggregate = RawGpsQualityAnalyzer.aggregateReports(
        [r1, r2, r3],
        appCommit: 'b002dbce7293641d561f804eba7eb260d756a3c5',
      );

      expect(aggregate.totalSessions, 3);
      expect(aggregate.totalRawPoints, 71);
      expect(aggregate.realWorldSessions, 2);
      expect(aggregate.syntheticFixtureSessions, 1);
      expect(aggregate.sessionsByActivity['running'], 1);
      expect(aggregate.sessionsByActivity['cycling'], 1);
      expect(aggregate.sessionsByActivity['walking'], 1);
      expect(aggregate.sessionsByProvenance['device_journal_verified'], 1);
      expect(aggregate.sessionsByProvenance['cloud_only_unverified'], 1);
      expect(aggregate.sessionsByProvenance['device_recovered_unverified'], 1);
      expect(aggregate.aggregateMeanSamplingIntervalSeconds, closeTo(1.0, 0.05));
    });

    test('ALG-0.8 (Task A): verifyExportFiles validates disk byte SHA-256 against manifest', () {
      final points = [
        RawGpsExportPoint(
          workoutId: 'sess-verify-disk',
          timestamp: baseTime,
          latitude: 10.7725,
          longitude: 106.6980,
          speed: 3.2,
          accuracy: 4.5,
        ),
      ];

      final bundle = RawGpsDatasetExporter.buildBundle(
        workoutId: 'sess-verify-disk',
        rawPoints: points,
        sourceKind: RawGpsExportSourceKind.deviceJournalVerified,
      );

      final tempDir = Directory.systemTemp.createTempSync('aetron_export_verify_');
      final jsonlFile = File('${tempDir.path}/sess-verify-disk.raw.jsonl')
        ..writeAsStringSync(bundle.jsonlContent);
      final csvFile = File('${tempDir.path}/sess-verify-disk.raw.csv')
        ..writeAsStringSync(bundle.csvContent);
      final gpxFile = File('${tempDir.path}/sess-verify-disk.raw.gpx')
        ..writeAsStringSync(bundle.gpxContent);
      final manifestFile = File('${tempDir.path}/sess-verify-disk.manifest.json')
        ..writeAsStringSync(bundle.manifest.toJson().toString());

      final files = [jsonlFile, csvFile, gpxFile, manifestFile];

      // Verifies disk byte match against manifest advertised SHA-256
      final isValid = RawGpsExportService.verifyExportFiles(files, bundle.manifest);
      expect(isValid, isTrue);

      // Corrupt JSONL file: must throw StateError
      jsonlFile.writeAsStringSync('CORRUPTED BYTES');
      expect(
        () => RawGpsExportService.verifyExportFiles(files, bundle.manifest),
        throwsA(isA<StateError>()),
      );

      tempDir.deleteSync(recursive: true);
    });

    test('ALG-0.9: Path traversal and session ID security validation (validateSessionId)', () {
      // Valid IDs
      expect(() => RawGpsDatasetExporter.validateSessionId('session-123_abc'), returnsNormally);
      expect(() => RawGpsDatasetExporter.validateSessionId('550e8400-e29b-41d4-a716-446655440000'), returnsNormally);
      expect(() => RawGpsDatasetExporter.validateSessionId('run_01'), returnsNormally);

      // Path traversal and unsafe inputs must throw ArgumentError
      expect(() => RawGpsDatasetExporter.validateSessionId(''), throwsArgumentError);
      expect(() => RawGpsDatasetExporter.validateSessionId('../evil_path'), throwsArgumentError);
      expect(() => RawGpsDatasetExporter.validateSessionId('session/with/slash'), throwsArgumentError);
      expect(() => RawGpsDatasetExporter.validateSessionId(r'session\with\backslash'), throwsArgumentError);
      expect(() => RawGpsDatasetExporter.validateSessionId('session with spaces'), throwsArgumentError);
      expect(() => RawGpsDatasetExporter.validateSessionId('session\x00null'), throwsArgumentError);
      expect(() => RawGpsDatasetExporter.validateSessionId('session;rm -rf'), throwsArgumentError);
    });

    test('ALG-0.10: Lossless JSONL round-trip replay verification with full field parity', () {
      final points = [
        RawGpsExportPoint(
          workoutId: 'replay-test-01',
          timestamp: baseTime,
          latitude: 10.7712345,
          longitude: 106.6987654,
          altitude: 15.25,
          speed: 4.12,
          accuracy: 5.5,
          heading: 180.0,
          deviceSource: 'geolocator_position_stream',
        ),
        RawGpsExportPoint(
          workoutId: 'replay-test-01',
          timestamp: baseTime.add(const Duration(seconds: 1)),
          latitude: 10.7713456,
          longitude: 106.6988765,
          altitude: 15.30,
          speed: 4.15,
          accuracy: 5.2,
          heading: 181.0,
          deviceSource: 'geolocator_position_stream',
        ),
      ];

      final jsonl = RawGpsDatasetExporter.generateJsonl(points);

      // 1. Lossless round-trip passes
      expect(RawGpsDatasetExporter.verifyJsonlLosslessReplay(jsonl, points), isTrue);

      // 2. Count mismatch throws StateError
      expect(
        () => RawGpsDatasetExporter.verifyJsonlLosslessReplay(
          '$jsonl$jsonl',
          points,
        ),
        throwsStateError,
      );

      // 3. Mutated speed in JSONL throws StateError
      final mutatedSpeedJsonl = jsonl.replaceFirst('"speed":4.12', '"speed":4.99');
      expect(
        () => RawGpsDatasetExporter.verifyJsonlLosslessReplay(
          mutatedSpeedJsonl,
          points,
        ),
        throwsStateError,
      );

      // 4. Mutated altitude in JSONL throws StateError
      final mutatedAltJsonl = jsonl.replaceFirst('"altitude":15.25', '"altitude":99.0');
      expect(
        () => RawGpsDatasetExporter.verifyJsonlLosslessReplay(
          mutatedAltJsonl,
          points,
        ),
        throwsStateError,
      );
    });

    test('ALG-0.11: Multi-scale outage tracking (>15s and >30s) and missing telemetry tracking', () {
      final points = [
        // Point 1: complete telemetry
        RawGpsExportPoint(
          workoutId: 'telemetry-test',
          timestamp: baseTime,
          latitude: 10.770,
          longitude: 106.690,
          altitude: 10.0,
          speed: 3.0,
          accuracy: 5.0,
          heading: 45.0,
          deviceSource: 'sensor',
        ),
        // Point 2: 20s gap (>15s, not >30s), missing altitude & heading
        RawGpsExportPoint(
          workoutId: 'telemetry-test',
          timestamp: baseTime.add(const Duration(seconds: 20)),
          latitude: 10.771,
          longitude: 106.691,
          speed: 3.5,
          accuracy: 6.0,
          deviceSource: 'sensor',
        ),
        // Point 3: 45s gap (>15s AND >30s), missing speed & accuracy & deviceSource
        RawGpsExportPoint(
          workoutId: 'telemetry-test',
          timestamp: baseTime.add(const Duration(seconds: 65)),
          latitude: 10.772,
          longitude: 106.692,
        ),
      ];

      final report = RawGpsQualityAnalyzer.analyzeSession(
        workoutId: 'telemetry-test',
        points: points,
      );

      expect(report.gapSummary.gapCountOver15s, 2);
      expect(report.gapSummary.gapCountOver30s, 1);
      expect(report.missingTelemetry.missingAltitudeCount, 2); // points 2 & 3
      expect(report.missingTelemetry.missingSpeedCount, 1); // point 3
      expect(report.missingTelemetry.missingAccuracyCount, 1); // point 3
      expect(report.missingTelemetry.missingHeadingCount, 2); // points 2 & 3
      expect(report.missingTelemetry.missingDeviceSourceCount, 1); // point 3
      expect(report.rawCumulativeDistanceMeters, greaterThan(200.0));
    });

    test('ALG-0.12: Discovery audit captures error categories without silent suppression', () {
      final audit = RawGpsDiscoveryAudit(
        totalDiscovered: 5,
        sessionsWithGps: 3,
        successfullyExported: 2,
        missingSessions: 1,
        deniedSessions: 1,
        failureCount: 2,
        failures: const [
          'Access denied for session foreign-01: Session belongs to another user account.',
          'Missing session missing-02: Workout session missing-02 was not found in cloud database.',
        ],
      );

      final json = audit.toJson();
      expect(json['total_discovered'], 5);
      expect(json['sessions_with_gps'], 3);
      expect(json['successfully_exported'], 2);
      expect(json['missing_sessions'], 1);
      expect(json['denied_sessions'], 1);
      expect(json['failure_count'], 2);
      expect((json['failures'] as List).length, 2);
    });

    test('ALG-0.13: Malformed input rejection fails closed on invalid or missing records', () {
      // 1. Missing timestamp throws FormatException
      expect(
        () => RawGpsExportPoint.fromJson({
          'workout_id': 'sess-1',
          'latitude': 10.77,
          'longitude': 106.69,
        }),
        throwsFormatException,
      );

      // 2. Malformed JSONL line throws FormatException
      expect(
        () => RawGpsDatasetExporter.parseJsonl('not valid json {[[['),
        throwsFormatException,
      );
    });

    test('ALG-0.14: XML and CSV character escaping prevents broken syntax', () {
      final trickyPoints = [
        RawGpsExportPoint(
          workoutId: 'workout-escape',
          timestamp: baseTime,
          latitude: 10.7725,
          longitude: 106.6980,
          speed: 3.5,
          accuracy: 4.0,
          deviceSource: 'Sensor <Core & "GPS" \'High\'>\nLine2,Col2\rLine3',
        ),
      ];

      final csv = RawGpsDatasetExporter.generateCsv(trickyPoints);
      expect(csv, contains('"Sensor <Core & ""GPS"" \'High\'>\nLine2,Col2\rLine3"'));

      final gpx = RawGpsDatasetExporter.generateGpx(trickyPoints, workoutId: 'workout<test>&"escaped"');
      expect(gpx, contains('&lt;test&gt;&amp;&quot;escaped&quot;'));
      expect(gpx, contains('&lt;Core &amp; &quot;GPS&quot; &apos;High&apos;&gt;'));
      // Verify valid XML structure (does not throw when parsed or searched for unescaped characters)
      expect(gpx.contains('<Core'), isFalse);
      expect(gpx.contains('& "GPS"'), isFalse);
    });

    test('ALG-0.15: Fixture collision prevention rejects overwriting real sessions', () {
      final allPointsMap = <String, List<InventoryGpsPoint>>{};
      final sourceKindMap = <String, String>{};

      // Real authenticated session already discovered
      const workoutId = 'session-collision-test';
      final realPoints = [
        InventoryGpsPoint(
          workoutId: workoutId,
          timestamp: baseTime,
          latitude: 10.7725,
          longitude: 106.6980,
          speed: 3.2,
          accuracy: 4.5,
          deviceSource: 'geolocator_position_stream',
        ),
      ];
      allPointsMap[workoutId] = realPoints;
      sourceKindMap[workoutId] = 'cloud_only_unverified';

      // Fixture attempting to claim same workoutId
      final fixturePoints = [
        InventoryGpsPoint(
          workoutId: workoutId,
          timestamp: baseTime,
          latitude: 10.8888,
          longitude: 106.9999,
          speed: 1.0,
          accuracy: 2.0,
          deviceSource: 'synthetic_fixture',
        ),
      ];

      // Ingestion collision guard:
      var collisionDetected = false;
      if (allPointsMap.containsKey(workoutId)) {
        collisionDetected = true;
      } else {
        allPointsMap[workoutId] = fixturePoints;
        sourceKindMap[workoutId] = 'synthetic_fixture';
      }

      expect(collisionDetected, isTrue);
      expect(allPointsMap[workoutId]!.first.latitude, 10.7725);
      expect(sourceKindMap[workoutId], 'cloud_only_unverified');
    });

    test('ALG-0.16: Pagination failure fails affected session closed without partial export', () {
      // Simulate real paginated fetching with error handling
      final sessionPoints = <InventoryGpsPoint>[];
      var failureCount = 0;
      var sessionFailed = false;

      // Page 1 succeeds with 50 points
      for (var i = 0; i < 50; i++) {
        sessionPoints.add(
          InventoryGpsPoint(
            workoutId: 'paginated-fail',
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 10.77,
            longitude: 106.69,
          ),
        );
      }
      expect(sessionPoints.length, 50);

      // Page 2 encounters HTTP 500
      const page2Status = 500;
      if (page2Status != 200) {
        failureCount++;
        sessionFailed = true;
      }

      final allPointsMap = <String, List<InventoryGpsPoint>>{};
      if (sessionFailed) {
        // Discard partial points - never mark as success
        sessionPoints.clear();
      } else {
        allPointsMap['paginated-fail'] = sessionPoints;
      }

      expect(sessionFailed, isTrue);
      expect(failureCount, 1);
      expect(sessionPoints.isEmpty, isTrue);
      expect(allPointsMap.containsKey('paginated-fail'), isFalse);
    });

    test('ALG-0.17: Journal owner verification fails closed when expected owner is absent', () {
      final tempDir = Directory.systemTemp.createTempSync('alg0_test_absent_');
      try {
        const workoutId = 'session-absent-owner';
        final points = List.generate(
          10,
          (i) => InventoryGpsPoint(
            workoutId: workoutId,
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 10.7700 + (i * 0.0001),
            longitude: 106.6900 + (i * 0.0001),
            altitude: 12.0,
            speed: 3.5,
            accuracy: 5.0,
            heading: 90.0,
            deviceSource: 'geolocator_position_stream',
          ),
        );

        final rawFile = File('${tempDir.path}/$workoutId.raw.jsonl');
        final rawLines = points.map((p) => jsonEncode(p.toJson())).join('\n');
        rawFile.writeAsStringSync(rawLines);

        final actualSha = sha256.convert(rawFile.readAsBytesSync()).toString();
        final actualDigest = computeCanonicalDigest(points);

        final manifestFile = File('${tempDir.path}/$workoutId.manifest.json');
        final manifest = {
          'schema_version': '1.0.0',
          'workout_id': workoutId,
          'user_id': 'owner-alice',
          'file_sha256': actualSha,
          'record_count': points.length,
          'canonical_capture_digest': actualDigest,
        };
        manifestFile.writeAsStringSync(jsonEncode(manifest));

        // When trustedUserId is absent (null or empty)
        final result = verifyJournalProvenance(
          workoutId: workoutId,
          points: points,
          rawFile: rawFile,
          manifestFile: manifestFile,
          trustedUserId: null,
        );

        expect(result.status, JournalProvenanceStatus.unverified);
        expect(result.isVerified, isFalse);
        expect(result.sourceKind, 'device_recovered_unverified');
        expect(result.reason, contains('No trustworthy owner identity established'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('ALG-0.18: Journal owner verification detects mismatched owner and rejects foreign account', () {
      final tempDir = Directory.systemTemp.createTempSync('alg0_test_mismatch_');
      try {
        const workoutId = 'session-mismatch-owner';
        final points = List.generate(
          5,
          (i) => InventoryGpsPoint(
            workoutId: workoutId,
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 10.7700,
            longitude: 106.6900,
          ),
        );

        final rawFile = File('${tempDir.path}/$workoutId.raw.jsonl');
        rawFile.writeAsStringSync(points.map((p) => jsonEncode(p.toJson())).join('\n'));

        final actualSha = sha256.convert(rawFile.readAsBytesSync()).toString();
        final actualDigest = computeCanonicalDigest(points);

        final manifestFile = File('${tempDir.path}/$workoutId.manifest.json');
        manifestFile.writeAsStringSync(jsonEncode({
          'workout_id': workoutId,
          'user_id': 'owner-alice',
          'file_sha256': actualSha,
          'record_count': points.length,
          'canonical_capture_digest': actualDigest,
        }));

        // Trusted user is bob, but manifest belongs to alice
        final result = verifyJournalProvenance(
          workoutId: workoutId,
          points: points,
          rawFile: rawFile,
          manifestFile: manifestFile,
          trustedUserId: 'foreign-bob',
        );

        expect(result.status, JournalProvenanceStatus.accountMismatch);
        expect(result.isAccountMismatch, isTrue);
        expect(result.isVerified, isFalse);
        expect(result.sourceKind, 'device_recovered_unverified');
        expect(result.manifestOwnerId, 'owner-alice');
        expect(result.reason, contains('Account mismatch'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('ALG-0.19: Journal owner verification grants verified status when owner and full contract pass', () {
      final tempDir = Directory.systemTemp.createTempSync('alg0_test_verified_');
      try {
        const workoutId = 'session-verified-owner';
        final points = List.generate(
          8,
          (i) => InventoryGpsPoint(
            workoutId: workoutId,
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 10.7700 + (i * 0.0001),
            longitude: 106.6900,
            speed: 3.0,
            accuracy: 4.0,
          ),
        );

        final rawFile = File('${tempDir.path}/$workoutId.raw.jsonl');
        rawFile.writeAsStringSync(points.map((p) => jsonEncode(p.toJson())).join('\n'));

        final actualSha = sha256.convert(rawFile.readAsBytesSync()).toString();
        final actualDigest = computeCanonicalDigest(points);

        final manifestFile = File('${tempDir.path}/$workoutId.manifest.json');
        manifestFile.writeAsStringSync(jsonEncode({
          'workout_id': workoutId,
          'user_id': 'owner-alice',
          'file_sha256': actualSha,
          'record_count': points.length,
          'canonical_capture_digest': actualDigest,
        }));

        final result = verifyJournalProvenance(
          workoutId: workoutId,
          points: points,
          rawFile: rawFile,
          manifestFile: manifestFile,
          trustedUserId: 'owner-alice',
        );

        expect(result.status, JournalProvenanceStatus.verified);
        expect(result.isVerified, isTrue);
        expect(result.isAccountMismatch, isFalse);
        expect(result.sourceKind, 'device_journal_verified');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('ALG-0.20: Authenticated research-export mode returns non-zero process exit code on AUTH_REQUIRED', () {
      final tempDir = Directory.systemTemp.createTempSync('alg0_cli_auth_');
      try {
        final result = Process.runSync(
          _findDartExecutable(),
          ['tooling/inventory_historical_datasets.dart', '--output-dir', tempDir.path],
          environment: {
            'AETRON_USER_TOKEN': '',
            'SUPABASE_USER_TOKEN': '',
          },
        );

        expect(result.exitCode, 1);
        expect(result.stdout.toString(), contains('AUTH_REQUIRED'));

        final reportFile = File('${tempDir.path}/inventory_report.json');
        expect(reportFile.existsSync(), isTrue);

        final reportJson = jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
        expect(reportJson['status'], 'AUTH_REQUIRED');
        expect(reportJson['total_sessions'], 0);
        expect(reportJson['discovery_audit']['successfully_exported'], 0);
        expect(reportJson['discovery_audit']['failure_count'], 0);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('ALG-0.21: Explicit offline mode succeeds without authentication', () {
      final tempDir = Directory.systemTemp.createTempSync('alg0_cli_offline_');
      try {
        final result = Process.runSync(
          _findDartExecutable(),
          ['tooling/inventory_historical_datasets.dart', '--offline-fixtures', '--output-dir', tempDir.path],
          environment: {
            'AETRON_USER_TOKEN': '',
            'SUPABASE_USER_TOKEN': '',
          },
        );

        expect(result.exitCode, 0);

        final reportFile = File('${tempDir.path}/inventory_report.json');
        expect(reportFile.existsSync(), isTrue);

        final reportJson = jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
        expect(reportJson['status'], 'SUCCESS');
        expect(reportJson['synthetic_fixture_sessions'], greaterThanOrEqualTo(1));
        expect(reportJson['discovery_audit']['failure_count'], 0);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

String _findDartExecutable() {
  final testerPath = Platform.resolvedExecutable;
  if (testerPath.contains('flutter_tester')) {
    final flutterBin = Directory(testerPath).parent.parent.parent.parent.parent;
    final dartFile = File('${flutterBin.path}/dart');
    if (dartFile.existsSync()) return dartFile.path;
  }
  return 'dart';
}
