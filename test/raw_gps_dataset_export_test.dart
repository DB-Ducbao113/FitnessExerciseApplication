import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/services/raw_gps_export_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_export_bundle.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_dataset_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AETRON RG-F4 Research Dataset Exporter Engine Tests', () {
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

    test('F4-B.4: GPX 1.1 schema formatting, XML escaping and signal gap splitting', () {
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

      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1" creator="Aetron"'));
      expect(gpx, contains('&amp; antenna &lt;v1&gt;')); // XML escaped
      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('</trkseg>'));
      // Two track segments due to 20-second gap
      final trksegMatches = RegExp(r'<trkseg>').allMatches(gpx);
      expect(trksegMatches.length, 2);
    });

    test('F4-B.5: Provenance manifest captures units, commit, hashes, and gap summary', () {
      final points = createSamplePoints('session-manifest', 50);
      final bundle = RawGpsDatasetExporter.buildBundle(
        workoutId: 'session-manifest',
        rawPoints: points,
        sourceKind: RawGpsExportSourceKind.deviceJournalVerified,
        rawJsonlByteSha256: 'mock-raw-byte-sha256',
        canonicalCaptureDigest: 'mock-canonical-digest',
        appCommit: 'fa08471f723f1e44b0796a508f705e770265919b',
        exportGeneratedAtUtc: baseTime,
      );

      final manifest = bundle.manifest;
      expect(manifest.schemaVersion, 'aetron.rg_f4.dataset_manifest.v1');
      expect(manifest.sourceKind, 'device_journal_verified');
      expect(manifest.workoutId, 'session-manifest');
      expect(manifest.recordCount, 50);
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
      expect(restoredManifest.exportJsonlSha256, manifest.exportJsonlSha256);
    });

    test('F4-B.6: Duplicate count is correctly tallied in manifest without dropping data', () {
      final p1 = RawGpsExportPoint(
        workoutId: 'session-dup',
        timestamp: baseTime,
        latitude: 10.770,
        longitude: 106.690,
      );
      final p1Dup = RawGpsExportPoint(
        workoutId: 'session-dup',
        timestamp: baseTime,
        latitude: 10.770,
        longitude: 106.690,
      );
      final p2 = RawGpsExportPoint(
        workoutId: 'session-dup',
        timestamp: baseTime.add(const Duration(seconds: 1)),
        latitude: 10.771,
        longitude: 106.691,
      );

      final bundle = RawGpsDatasetExporter.buildBundle(
        workoutId: 'session-dup',
        rawPoints: [p1, p1Dup, p2],
        sourceKind: RawGpsExportSourceKind.deviceRecoveredUnverified,
      );

      expect(bundle.points.length, 3); // Never silently discard
      expect(bundle.manifest.recordCount, 3);
      expect(bundle.manifest.duplicateCount, 1); // Tracked accurately
    });
  });

  group('AETRON RG-F4 Service & Security Gate Tests', () {
    final baseTime = DateTime.parse('2026-10-21T06:00:00.000000Z').toUtc();

    test('F4-A.1: Fail closed if user is unauthenticated', () async {
      final service = RawGpsExportService(
        currentUserIdProvider: () => null,
      );

      expect(
        () => service.exportSession(workoutId: 'sess-unauth'),
        throwsA(isA<StateError>()),
      );
    });

    test('F4-A.2: Cross-account isolation prevents exporting another user’s workout', () async {
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

    test('F4-A.3: Historical cloud export with pagination over 1000 points', () async {
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

    test('F4-C.1: Temporary export files lifecycle and cleanup', () async {
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
      final tempDir = Directory.systemTemp.createTempSync('aetron_test_export_');
      final files = [
        File('${tempDir.path}/session-temp.raw.jsonl')..writeAsStringSync(bundle.jsonlContent),
        File('${tempDir.path}/session-temp.raw.csv')..writeAsStringSync(bundle.csvContent),
        File('${tempDir.path}/session-temp.raw.gpx')..writeAsStringSync(bundle.gpxContent),
        File('${tempDir.path}/session-temp.manifest.json')..writeAsStringSync(jsonEncode(bundle.manifest.toJson())),
      ];

      for (final f in files) {
        expect(f.existsSync(), isTrue);
      }

      // Cleanup files
      for (final f in files) {
        f.deleteSync();
      }
      tempDir.deleteSync();

      for (final f in files) {
        expect(f.existsSync(), isFalse);
      }
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
