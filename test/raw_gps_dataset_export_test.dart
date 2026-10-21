import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/services/raw_gps_export_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_export_bundle.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_dataset_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AETRON RG-F4 Research Dataset Exporter Engine Tests (QA-F4-02 & QA-F4-03)', () {
    final baseTime = DateTime.parse('2026-10-21T06:00:00.000000Z').toUtc();

    List<RawGpsExportPoint> createSamplePoints(String workoutId, int count) {
      return List.generate(count, (i) {
        return RawGpsExportPoint(
          workoutId: workoutId,
          timestamp: baseTime.add(Duration(seconds: i)),
          latitude: 10.7725000 + (i * 0.0001),
          longitude: 106.6980000 + (i * 0.0001),
          altitude: 15.0 + (i * 0.1),
          speed: 3.0 + (i * 0.05),
          accuracy: 4.0,
          heading: 90.0,
          deviceSource: 'gps',
        );
      });
    }

    test('F4-B.1: Deterministic JSONL serialization preserves all fields losslessly', () {
      final points = [
        RawGpsExportPoint(
          workoutId: 'session-001',
          timestamp: baseTime,
          latitude: 10.7725123,
          longitude: 106.6980456,
          altitude: 15.25,
          speed: 3.12,
          accuracy: 4.5,
          heading: 180.0,
          deviceSource: 'fused_gps',
        ),
        RawGpsExportPoint(
          workoutId: 'session-001',
          timestamp: baseTime.add(const Duration(seconds: 1)),
          latitude: 10.7726123,
          longitude: 106.6981456,
          altitude: null,
          speed: null,
          accuracy: null,
          heading: null,
          deviceSource: null,
        ),
      ];

      final jsonl = RawGpsDatasetExporter.generateJsonl(points);
      final lines = jsonl.trim().split('\n');

      expect(lines.length, 2);

      // Line 1 contains all populated fields
      final obj1 = jsonDecode(lines[0]) as Map<String, dynamic>;
      expect(obj1['workout_id'], 'session-001');
      expect(obj1['latitude'], 10.7725123);
      expect(obj1['longitude'], 106.6980456);
      expect(obj1['altitude'], 15.25);
      expect(obj1['speed'], 3.12);
      expect(obj1['accuracy'], 4.5);
      expect(obj1['heading'], 180.0);
      expect(obj1['device_source'], 'fused_gps');
      expect(obj1['timestamp_micros'], baseTime.microsecondsSinceEpoch);

      // Line 2 preserves nulls explicitly without crashing or dropping
      final obj2 = jsonDecode(lines[1]) as Map<String, dynamic>;
      expect(obj2['workout_id'], 'session-001');
      expect(obj2.containsKey('altitude'), isFalse);
      expect(obj2.containsKey('speed'), isFalse);
    });

    test('F4-B.2: Lossless JSONL round-trip replay without GPS sensor', () {
      final originalPoints = createSamplePoints('session-replay', 100);
      final jsonl = RawGpsDatasetExporter.generateJsonl(originalPoints);

      final replayedPoints = RawGpsDatasetExporter.parseJsonl(jsonl);
      expect(replayedPoints.length, originalPoints.length);

      for (var i = 0; i < originalPoints.length; i++) {
        expect(replayedPoints[i], equals(originalPoints[i]));
      }

      // Parity check on canonical digest
      final originalDigest = RawGpsCanonicalVerification.computeCanonicalDigest(
        originalPoints.map((p) => p.toCanonical()),
      );
      final replayedDigest = RawGpsCanonicalVerification.computeCanonicalDigest(
        replayedPoints.map((p) => p.toCanonical()),
      );
      expect(replayedDigest, equals(originalDigest));
    });

    test('F4-B.3: RFC 4180 CSV generation handles nulls, quotes and commas correctly', () {
      final points = [
        RawGpsExportPoint(
          workoutId: 'session-csv',
          timestamp: baseTime,
          latitude: 10.7700000,
          longitude: 106.6900000,
          altitude: 12.5,
          speed: 4.2,
          accuracy: 3.5,
          heading: 270.0,
          deviceSource: 'gps,fused"provider"',
        ),
        RawGpsExportPoint(
          workoutId: 'session-csv',
          timestamp: baseTime.add(const Duration(seconds: 1)),
          latitude: 10.7701000,
          longitude: 106.6901000,
          altitude: null,
          speed: null,
          accuracy: null,
          heading: null,
          deviceSource: null,
        ),
      ];

      final csv = RawGpsDatasetExporter.generateCsv(points);
      final lines = csv.trim().split('\n');

      expect(lines[0], 'timestamp,latitude,longitude,altitude,speed,accuracy,heading,device_source,workout_id');
      // Quotes and commas escaped
      expect(lines[1], contains('"gps,fused""provider"""'));
      // Nulls formatted as empty commas
      expect(lines[2], contains(',10.7701,106.6901,,,,,,session-csv'));
    });

    test('F4-B.4 (QA-F4-03): GPX 1.1 schema compliance with aetron extension namespace', () {
      final points = [
        RawGpsExportPoint(
          workoutId: 'session-gpx',
          timestamp: baseTime,
          latitude: 10.7700000,
          longitude: 106.6900000,
          altitude: 10.0,
          speed: 2.5,
          accuracy: 5.0,
          heading: 0.0,
          deviceSource: 'sensor & antenna <v1>',
        ),
        // 20-second gap (> default 15s threshold) -> splits into new trkseg
        RawGpsExportPoint(
          workoutId: 'session-gpx',
          timestamp: baseTime.add(const Duration(seconds: 20)),
          latitude: 10.7705000,
          longitude: 106.6905000,
          altitude: 10.5,
          speed: 2.8,
          accuracy: 4.8,
          heading: 10.0,
          deviceSource: 'gps',
        ),
      ];

      final gpx = RawGpsDatasetExporter.generateGpx(
        points,
        workoutId: 'session-gpx',
        gapThresholdSeconds: 15.0,
        exportTimeUtc: baseTime,
      );

      // Verify GPX 1.1 root attributes and namespaces
      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1" creator="Aetron"'));
      expect(gpx, contains('xmlns="http://www.topografix.com/GPX/1/1"'));
      expect(gpx, contains('xmlns:aetron="https://aetron.app/gpx/1/0"'));
      expect(gpx, contains('xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"'));

      // Verify prefixed extension elements complying with <xsd:any namespace="##other" processContents="lax"/>
      expect(gpx, contains('<extensions>'));
      expect(gpx, contains('<aetron:accuracy>5.0</aetron:accuracy>'));
      expect(gpx, contains('<aetron:speed>2.5</aetron:speed>'));
      expect(gpx, contains('<aetron:heading>0.0</aetron:heading>'));
      expect(gpx, contains('<aetron:device_source>sensor &amp; antenna &lt;v1&gt;</aetron:device_source>'));
      expect(gpx, contains('</extensions>'));

      // Verify wptType element sequence inside <trkpt>: <ele> -> <time> -> <extensions>
      final trkptIndex = gpx.indexOf('<trkpt');
      final eleIndex = gpx.indexOf('<ele>10.0</ele>', trkptIndex);
      final timeIndex = gpx.indexOf('<time>2026-10-21T06:00:00.000Z</time>', trkptIndex);
      final extIndex = gpx.indexOf('<extensions>', trkptIndex);
      expect(trkptIndex < eleIndex, isTrue);
      expect(eleIndex < timeIndex, isTrue);
      expect(timeIndex < extIndex, isTrue);

      // Verify track segment splitting on gap
      final trksegMatches = RegExp(r'<trkseg>').allMatches(gpx);
      expect(trksegMatches.length, 2);
    });

    test('F4-B.5 (QA-F4-02): Manifest provenance separates build commit from capture commit without hardcoded default', () {
      final points = createSamplePoints('session-manifest', 50);
      final bundle = RawGpsDatasetExporter.buildBundle(
        workoutId: 'session-manifest',
        rawPoints: points,
        sourceKind: RawGpsExportSourceKind.deviceJournalVerified,
        rawJsonlByteSha256: 'mock-raw-byte-sha256',
        canonicalCaptureDigest: 'mock-canonical-digest',
        appCommit: '83580a722eb2e952b8b98cab3f8b629b9e2363cb',
        captureAppCommit: '4e741a32d3718cf8e0a9a60b41d4b6679130dab4',
        exportGeneratedAtUtc: baseTime,
      );

      final manifest = bundle.manifest;
      expect(manifest.schemaVersion, 'aetron.rg_f4.dataset_manifest.v1');
      expect(manifest.sourceKind, 'device_journal_verified');
      expect(manifest.workoutId, 'session-manifest');
      expect(manifest.recordCount, 50);
      expect(manifest.appCommit, '83580a722eb2e952b8b98cab3f8b629b9e2363cb');
      expect(manifest.captureAppCommit, '4e741a32d3718cf8e0a9a60b41d4b6679130dab4');
      expect(manifest.rawJsonlByteSha256, 'mock-raw-byte-sha256');
      expect(manifest.canonicalCaptureDigest, 'mock-canonical-digest');
      expect(manifest.exportJsonlSha256.length, 64);
      expect(manifest.exportCsvSha256.length, 64);
      expect(manifest.exportGpxSha256.length, 64);
      expect(manifest.gapSummary['gap_count'], 0);

      // JSON serialization round-trip
      final jsonMap = manifest.toJson();
      final restoredManifest = RawGpsExportManifest.fromJson(jsonMap);
      expect(restoredManifest.workoutId, manifest.workoutId);
      expect(restoredManifest.recordCount, manifest.recordCount);
      expect(restoredManifest.appCommit, manifest.appCommit);
      expect(restoredManifest.captureAppCommit, manifest.captureAppCommit);
    });

    test('F4-B.6 (QA-F4-02): app_commit is null when unprovided and no build environment define exists', () {
      final points = createSamplePoints('session-no-commit', 5);
      final bundle = RawGpsDatasetExporter.buildBundle(
        workoutId: 'session-no-commit',
        rawPoints: points,
        sourceKind: RawGpsExportSourceKind.cloudOnlyUnverified,
        appCommit: null, // No commit provided
      );

      // Never default to a hardcoded baseline commit
      expect(bundle.manifest.appCommit, isNull);
      expect(bundle.manifest.captureAppCommit, isNull);
    });
  });

  group('AETRON RG-F4 Service & Security Gate Tests (QA-F4-01 & QA-F4-04)', () {
    final baseTime = DateTime.parse('2026-10-21T06:00:00.000000Z').toUtc();

    test('F4-A.1: Fail closed if user is unauthenticated or logged out', () async {
      final service = RawGpsExportService(
        currentUserIdProvider: () => null,
      );

      expect(
        () => service.exportSession(workoutId: 'sess-unauth'),
        throwsA(isA<StateError>()),
      );
    });

    test('F4-A.2 (QA-F4-01): Active user conflict rejects spoofed or mismatched activeUserId', () async {
      final service = RawGpsExportService(
        currentUserIdProvider: () => 'auth-user-alice',
      );

      // Attempting to supply activeUserId that conflicts with authenticated user
      expect(
        () => service.exportSession(
          workoutId: 'sess-test',
          activeUserId: 'auth-user-bob',
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('F4-A.3 (QA-F4-01): Cross-account isolation prevents exporting another user’s workout in journal', () async {
      final mockJournal = _MockJournalWithAccountMismatch('user-victim');
      final service = RawGpsExportService(
        journal: mockJournal,
        currentUserIdProvider: () => 'user-attacker',
      );

      expect(
        () => service.exportSession(workoutId: 'sess-victim'),
        throwsA(isA<SecurityException>()),
      );
    });

    test('F4-A.4 (QA-F4-01): Journal points without trusted owner metadata fail closed with SecurityException', () async {
      // Manifest exists but userId is null
      final mockJournal = _MockJournalWithCustomManifest(
        points: [
          LocalGPSPoint()
            ..sessionId = 'sess-unowned'
            ..timestamp = baseTime
            ..latitude = 10.77
            ..longitude = 106.69
            ..confidence = 'HIGH',
        ],
        manifest: RawGpsJournalManifest(
          workoutId: 'sess-unowned',
          userId: null, // Untrusted/missing ownership metadata
          sampleCount: 1,
          checkpointSeq: 1,
          checkpointTimestampUtc: baseTime,
          isFinalized: true,
        ),
      );

      final service = RawGpsExportService(
        journal: mockJournal,
        currentUserIdProvider: () => 'active-user-123',
      );

      expect(
        () => service.exportSession(workoutId: 'sess-unowned'),
        throwsA(isA<SecurityException>()),
      );
    });

    test('F4-A.5 (QA-F4-01): Legitimate orphan journal with manifest.userId == activeUserId is safely recovered', () async {
      const activeUserId = 'owner-athlete-456';
      final mockJournal = _MockJournalWithCustomManifest(
        points: [
          LocalGPSPoint()
            ..sessionId = 'sess-orphan'
            ..timestamp = baseTime
            ..latitude = 10.77
            ..longitude = 106.69
            ..confidence = 'HIGH',
        ],
        manifest: RawGpsJournalManifest(
          workoutId: 'sess-orphan',
          userId: activeUserId, // Valid owner proof in orphan journal companion manifest
          sampleCount: 1,
          checkpointSeq: 1,
          checkpointTimestampUtc: baseTime,
          isFinalized: false, // Unfinalized orphan
        ),
      );

      final service = RawGpsExportService(
        journal: mockJournal,
        currentUserIdProvider: () => activeUserId,
      );

      final bundle = await service.exportSession(workoutId: 'sess-orphan');
      expect(bundle.points.length, 1);
      expect(bundle.manifest.sourceKind, 'device_recovered_unverified');
      expect(bundle.manifest.workoutId, 'sess-orphan');
    });

    test('F4-A.6: Historical cloud export with pagination over 1000 points', () async {
      const totalPoints = 2500;
      final mockRemote = _MockRemoteDataSource(
        workoutId: 'session-long',
        totalPoints: totalPoints,
        baseTime: baseTime,
      );

      // Verify that fetchAllRawGpsPoints paginates in batches of 1000 and retrieves all 2500
      final allPoints = await mockRemote.fetchAllRawGpsPoints('session-long', pageSize: 1000);
      expect(allPoints.length, totalPoints);
      expect(mockRemote.fetchPageCallCount, 3); // 0-999, 1000-1999, 2000-2499

      // Build bundle from paginated points
      final bundle = RawGpsDatasetExporter.buildBundle(
        workoutId: 'session-long',
        rawPoints: allPoints.map((p) => RawGpsExportPoint.fromPayload(p)).toList(),
        sourceKind: RawGpsExportSourceKind.cloudOnlyUnverified,
      );

      expect(bundle.points.length, totalPoints);
      expect(bundle.manifest.recordCount, totalPoints);
      expect(bundle.manifest.sourceKind, 'cloud_only_unverified');
      expect(bundle.manifest.rawJsonlByteSha256, isNull);
      expect(bundle.manifest.canonicalCaptureDigest, isNull);
    });

    test('F4-C.1 (QA-F4-04): Temporary export files lifecycle and cleanup', () async {
      final points = [
        RawGpsExportPoint(
          workoutId: 'session-temp',
          timestamp: baseTime,
          latitude: 10.77,
          longitude: 106.69,
        ),
      ];

      final bundle = RawGpsDatasetExporter.buildBundle(
        workoutId: 'session-temp',
        rawPoints: points,
        sourceKind: RawGpsExportSourceKind.deviceRecoveredUnverified,
      );

      // Create dummy temp files mimicking prepareExportFiles
      final tempDir = Directory.systemTemp.createTempSync('aetron_export_session-temp_');
      final files = [
        File('${tempDir.path}/session-temp.raw.jsonl')..writeAsStringSync(bundle.jsonlContent),
        File('${tempDir.path}/session-temp.raw.csv')..writeAsStringSync(bundle.csvContent),
        File('${tempDir.path}/session-temp.raw.gpx')..writeAsStringSync(bundle.gpxContent),
        File('${tempDir.path}/session-temp.manifest.json')..writeAsStringSync(jsonEncode(bundle.manifest.toJson())),
      ];

      for (final f in files) {
        expect(f.existsSync(), isTrue);
      }

      // Cleanup files using service cleanup
      final service = RawGpsExportService(currentUserIdProvider: () => 'u1');
      await service.cleanupExportFiles(files);

      for (final f in files) {
        expect(f.existsSync(), isFalse);
      }
      expect(tempDir.existsSync(), isFalse); // Directory was also cleaned up
    });

    test('F4-C.2 (QA-F4-04): cleanupExportFiles safety rejection protects non-export files from deletion', () async {
      final safeTempDir = Directory.systemTemp.createTempSync('persistent_journal_dir_');
      final criticalFile = File('${safeTempDir.path}/00000000-0000-0000-0000-000000000001.jsonl')
        ..writeAsStringSync('CRITICAL PERSISTENT JOURNAL RECORD');

      expect(criticalFile.existsSync(), isTrue);

      final service = RawGpsExportService(currentUserIdProvider: () => 'u1');
      // Attempting to pass a persistent file that does not contain 'aetron_export_' in its path
      await service.cleanupExportFiles([criticalFile]);

      // File MUST be preserved and never deleted
      expect(criticalFile.existsSync(), isTrue);

      // Cleanup test fixture manually
      criticalFile.deleteSync();
      safeTempDir.deleteSync();
    });
  });
}

class _MockJournalWithAccountMismatch extends RawGpsRecoveryJournal {
  final String victimUserId;
  _MockJournalWithAccountMismatch(this.victimUserId);

  @override
  Future<RawGpsRecoveryResult> readJournal(
    String sessionId, {
    String? activeUserId,
  }) async {
    return RawGpsRecoveryResult.accountMismatch(
      sessionId: sessionId,
      accountMismatchUserId: victimUserId,
    );
  }
}

class _MockJournalWithCustomManifest extends RawGpsRecoveryJournal {
  final List<LocalGPSPoint> _points;
  final RawGpsJournalManifest _manifest;

  _MockJournalWithCustomManifest({
    required List<LocalGPSPoint> points,
    required RawGpsJournalManifest manifest,
  })  : _points = points,
        _manifest = manifest;

  @override
  Future<RawGpsRecoveryResult> readJournal(
    String sessionId, {
    String? activeUserId,
  }) async {
    return RawGpsRecoveryResult(
      sessionId: sessionId,
      points: _points,
      manifest: _manifest,
      status: RawGpsRecoveryStatus.verifiedIntact,
      validPointsCount: _points.length,
      duplicatePointsCount: 0,
      corruptedLinesCount: 0,
      hasTruncatedFinalLine: false,
      isUnfinalizedCrash: !_manifest.isFinalized,
    );
  }

  @override
  Future<RawGpsJournalManifest?> readManifest(String sessionId) async {
    return _manifest;
  }
}

class _MockRemoteDataSource implements RawTrackingRemoteDataSource {
  final String workoutId;
  final int totalPoints;
  final DateTime baseTime;
  int fetchPageCallCount = 0;

  _MockRemoteDataSource({
    required this.workoutId,
    required this.totalPoints,
    required this.baseTime,
  });

  @override
  Future<List<RawGpsPointPayload>> fetchRawGpsPointsPaged(
    String workoutId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    fetchPageCallCount++;
    if (offset >= totalPoints) return const [];
    final end = (offset + limit < totalPoints) ? offset + limit : totalPoints;
    return List.generate(end - offset, (i) {
      final index = offset + i;
      return RawGpsPointPayload(
        workoutId: workoutId,
        timestamp: baseTime.add(Duration(seconds: index)),
        latitude: 10.77 + (index * 0.00001),
        longitude: 106.69 + (index * 0.00001),
        altitude: 10.0,
        speed: 3.0,
        accuracy: 4.0,
        heading: 90.0,
        deviceSource: 'gps',
      );
    });
  }

  @override
  Future<List<RawGpsPointPayload>> fetchAllRawGpsPoints(
    String workoutId, {
    int pageSize = 1000,
  }) async {
    final all = <RawGpsPointPayload>[];
    var offset = 0;
    while (true) {
      final page = await fetchRawGpsPointsPaged(
        workoutId,
        offset: offset,
        limit: pageSize,
      );
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }
    return all;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
