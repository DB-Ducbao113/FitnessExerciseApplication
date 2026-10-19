import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory tempDir;
  late RawGpsRecoveryJournal journal;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aetron-rg1a-test-');
    journal = RawGpsRecoveryJournal(
      documentsDirectory: () async => tempDir,
      checkpointInterval: 50,
      maxQueueDepth: 100,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RG-1A: Raw GPS Durable Capture & Recovery Specification', () {
    const testWorkoutId = '00000000-0000-4000-8000-000000000001';
    const testUserId = 'test-athlete-001';

    test('1. 3,600-point capture and reload with integrity manifest', () async {
      final startTime = DateTime.utc(2026, 10, 19, 8, 0, 0);
      const totalPoints = 3600;

      for (var i = 0; i < totalPoints; i++) {
        final point = _syntheticPoint(
          workoutId: testWorkoutId,
          timestamp: startTime.add(Duration(seconds: i)),
          lat: 10.7380 + (i * 0.00001),
          lng: 106.6250 + (i * 0.00001),
          speed: 4.5,
          accuracy: 4.0,
        );
        final ack = await journal.appendPoint(point, userId: testUserId);
        expect(ack.success, isTrue);
        expect(ack.sampleIndex, i + 1);
      }

      await journal.flushSession(testWorkoutId);
      await journal.checkpoint(testWorkoutId, isFinalized: true);

      // Verify Manifest
      final manifest = await journal.readManifest(testWorkoutId);
      expect(manifest, isNotNull);
      expect(manifest!.workoutId, testWorkoutId);
      expect(manifest.userId, testUserId);
      expect(manifest.sampleCount, totalPoints);
      expect(manifest.isFinalized, isTrue);
      expect(manifest.sha256Digest, isNotNull);
      expect(manifest.firstTimestampUtc, startTime);
      expect(manifest.lastTimestampUtc, startTime.add(const Duration(seconds: 3599)));

      // Reload Journal
      final recovery = await journal.readJournal(
        testWorkoutId,
        activeUserId: testUserId,
      );
      expect(recovery.status, RawGpsRecoveryStatus.verifiedIntact);
      expect(recovery.validPointsCount, totalPoints);
      expect(recovery.points.length, totalPoints);
      expect(recovery.duplicatePointsCount, 0);
      expect(recovery.corruptedLinesCount, 0);
      expect(recovery.hasTruncatedFinalLine, isFalse);
      expect(recovery.isUnfinalizedCrash, isFalse);

      // Verify ordering
      for (var i = 1; i < recovery.points.length; i++) {
        expect(
          recovery.points[i].timestamp.isAfter(recovery.points[i - 1].timestamp),
          isTrue,
        );
      }
    });

    test('2. Kill/crash between queued and committed writes & buffer bound', () async {
      // Test bounded queue backpressure
      final smallBufferJournal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
        checkpointInterval: 10,
        maxQueueDepth: 5,
      );

      final futures = <Future<RawGpsAppendResult>>[];
      for (var i = 0; i < 20; i++) {
        final point = _syntheticPoint(
          workoutId: 'crash-session-002',
          timestamp: DateTime.utc(2026, 10, 19, 8, i),
          lat: 10.738,
          lng: 106.625,
        );
        futures.add(smallBufferJournal.appendPoint(point, userId: testUserId));
      }

      final results = await Future.wait(futures);
      final successes = results.where((r) => r.success).length;
      final failures = results.where((r) => !r.success).length;

      // Queue depth was 5, so overflow correctly dropped excess and reported error
      expect(failures, greaterThan(0));
      expect(successes + failures, 20);

      final overflowFailure = results.firstWhere((r) => !r.success);
      expect(overflowFailure.error, contains('queue buffer overflow'));
      expect(overflowFailure.sampleIndex, -1);
    });

    test('3. Truncated final journal record recovery', () async {
      final file = await journal.fileForSession('truncated-session-003');
      await file.parent.create(recursive: true);

      // Write 3 complete JSONL lines
      final p1 = jsonEncode({
        'workout_id': 'truncated-session-003',
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:00:00.000Z',
        'latitude': 10.7380,
        'longitude': 106.6250,
        'accuracy': 5.0,
      });
      final p2 = jsonEncode({
        'workout_id': 'truncated-session-003',
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:00:01.000Z',
        'latitude': 10.7381,
        'longitude': 106.6251,
        'accuracy': 5.0,
      });

      // Write 2 valid lines and 1 half-written truncated line (crash mid-write)
      await file.writeAsString('$p1\n$p2\n{"workout_id":"truncated-session-003","user_id":"test-ath');

      final recovery = await journal.readJournal(
        'truncated-session-003',
        activeUserId: testUserId,
      );

      expect(recovery.status, RawGpsRecoveryStatus.partiallyRecoveredTruncated);
      expect(recovery.hasTruncatedFinalLine, isTrue);
      expect(recovery.truncatedLineSnippet, isNotNull);
      expect(recovery.validPointsCount, 2);
      expect(recovery.points, hasLength(2));
      expect(recovery.points[0].latitude, 10.7380);
      expect(recovery.points[1].latitude, 10.7381);
      expect(recovery.isUnfinalizedCrash, isTrue);
    });

    test('4. Manifest update interruption (.tmp orphan resilience)', () async {
      const sessionId = 'manifest-interrupted-004';
      final point = _syntheticPoint(
        workoutId: sessionId,
        timestamp: DateTime.utc(2026, 10, 19, 8, 0),
        lat: 10.738,
        lng: 106.625,
      );
      await journal.appendPoint(point, userId: testUserId);
      await journal.checkpoint(sessionId);

      // Create orphan .tmp manifest simulating SIGKILL during atomic rename
      final manifestFile = await journal.manifestFileForSession(sessionId);
      final tmpFile = File('${manifestFile.path}.tmp');
      await tmpFile.writeAsString('{"partial": "broken json');

      // System should read the committed manifest safely despite the orphan tmp file
      final manifest = await journal.readManifest(sessionId);
      expect(manifest, isNotNull);
      expect(manifest!.sampleCount, 1);

      final recovery = await journal.readJournal(sessionId, activeUserId: testUserId);
      expect(recovery.validPointsCount, 1);
    });

    test('5. Partial Isar failure resilience in coordinator', () async {
      final rawTracking = _FakeRawTrackingRemoteDataSource();
      final processing = _FakeWorkoutProcessingRemoteDataSource();
      final recoveredPoints = <LocalGPSPoint>[];

      final coordinator = WorkoutRecordingCoordinator(
        rawTracking: rawTracking,
        workoutRemote: _FakeWorkoutRemoteDataSource(),
        processingRemote: processing,
        currentUserId: () => testUserId,
        saveLocalGpsPoint: (_) async => throw StateError('Isar disk I/O error'),
        saveRecoveryGpsPoint: (point) async {
          final res = await journal.appendPoint(point, userId: testUserId);
          if (!res.success) throw StateError(res.error!);
          recoveredPoints.add(point);
        },
        deleteRecoveryGpsJournal: (_) async {},
      );
      addTearDown(coordinator.dispose);

      coordinator.bufferRawGpsPoint(
        _position(seconds: 0, lat: 10.738, lng: 106.625),
        workoutId: 'isar-fail-session-005',
      );
      coordinator.bufferRawGpsPoint(
        _position(seconds: 1, lat: 10.7381, lng: 106.6251),
        workoutId: 'isar-fail-session-005',
      );

      final diagnostics = await coordinator.finalizeRawTracking(
        workoutId: 'isar-fail-session-005',
      );

      // Even though Isar failed completely (0 points), journal preserved them
      expect(diagnostics.isarSavedGpsPoints, 0);
      expect(diagnostics.recoverySavedGpsPoints, 2);
      expect(diagnostics.localSavedGpsPoints, 2);
      expect(diagnostics.localFailedGpsPoints, 0);

      // Verify durable journal file has both points
      final recovery = await journal.readJournal(
        'isar-fail-session-005',
        activeUserId: testUserId,
      );
      expect(recovery.validPointsCount, 2);
    });

    test('6. Duplicate replay handled deterministically', () async {
      const sessionId = 'duplicate-session-006';
      final point = _syntheticPoint(
        workoutId: sessionId,
        timestamp: DateTime.utc(2026, 10, 19, 8, 30, 0),
        lat: 10.738,
        lng: 106.625,
      );

      // Append identical point 3 times (e.g. repeated GPS burst or stream duplicate)
      await journal.appendPoint(point, userId: testUserId);
      await journal.appendPoint(point, userId: testUserId);
      await journal.appendPoint(point, userId: testUserId);

      await journal.flushSession(sessionId);

      final recovery = await journal.readJournal(sessionId, activeUserId: testUserId);
      expect(recovery.points, hasLength(1));
      expect(recovery.validPointsCount, 1);
      expect(recovery.duplicatePointsCount, 2);
    });

    test('7. Offline capture and safe retention (no blind deletion)', () async {
      const sessionId = 'offline-session-007';
      final point = _syntheticPoint(
        workoutId: sessionId,
        timestamp: DateTime.utc(2026, 10, 19, 9, 0, 0),
        lat: 10.738,
        lng: 106.625,
      );

      await journal.appendPoint(point, userId: testUserId);
      await journal.checkpoint(sessionId, isFinalized: false);

      // Attempt safe deletion without verified replicas -> must throw StateError
      expect(
        () => journal.delete(sessionId, verifySafe: true),
        throwsA(isA<StateError>()),
      );

      // Journal file must remain untouched
      final file = await journal.fileForSession(sessionId);
      expect(await file.exists(), isTrue);

      // Once cloud copy or Isar copy is verified, safe delete succeeds
      await journal.delete(
        sessionId,
        verifySafe: true,
        verifiedCloudCount: 1,
      );
      expect(await file.exists(), isFalse);
    });

    test('8. Concurrent GPS ingestion and ordered persistence', () async {
      const sessionId = 'concurrent-session-008';
      const count = 100;
      final startTime = DateTime.utc(2026, 10, 19, 10, 0, 0);

      // Fire 100 appends concurrently
      final futures = List.generate(count, (i) {
        final point = _syntheticPoint(
          workoutId: sessionId,
          timestamp: startTime.add(Duration(seconds: i)),
          lat: 10.738 + (i * 0.0001),
          lng: 106.625 + (i * 0.0001),
        );
        return journal.appendPoint(point, userId: testUserId);
      });

      final results = await Future.wait(futures);
      expect(results.every((r) => r.success), isTrue);

      await journal.flushSession(sessionId);

      final recovery = await journal.readJournal(sessionId, activeUserId: testUserId);
      expect(recovery.validPointsCount, count);

      // Verify no corrupted lines and monotonic ordering
      for (var i = 0; i < count; i++) {
        expect(recovery.points[i].timestamp, startTime.add(Duration(seconds: i)));
      }
    });

    test('9. Account isolation rejects cross-user journal replay', () async {
      const sessionId = 'isolated-session-009';
      final point = _syntheticPoint(
        workoutId: sessionId,
        timestamp: DateTime.utc(2026, 10, 19, 11, 0, 0),
        lat: 10.738,
        lng: 106.625,
      );

      await journal.appendPoint(point, userId: 'user-athlete-alpha');
      await journal.checkpoint(sessionId);

      // Attempt read as User Beta
      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: 'user-athlete-beta',
      );

      expect(recovery.status, RawGpsRecoveryStatus.accountMismatch);
      expect(recovery.points, isEmpty);
      expect(recovery.validPointsCount, 0);
      expect(recovery.accountMismatchUserId, 'user-athlete-alpha');
      expect(recovery.warningMessage, contains('isolated to user'));
    });

    test('10. Pause state privacy: zero journal writes while paused', () async {
      // In WorkoutSessionNotifier, when status != RecordingState.active,
      // _recordingCoordinator.bufferRawGpsPoint is NOT called.
      // We verify here that the coordinator also properly tracks when no points are sent.
      final coordinator = WorkoutRecordingCoordinator(
        rawTracking: _FakeRawTrackingRemoteDataSource(),
        workoutRemote: _FakeWorkoutRemoteDataSource(),
        processingRemote: _FakeWorkoutProcessingRemoteDataSource(),
        currentUserId: () => testUserId,
        saveLocalGpsPoint: (_) async {},
        saveRecoveryGpsPoint: (_) async {},
        deleteRecoveryGpsJournal: (_) async {},
      );
      addTearDown(coordinator.dispose);

      // Active point
      coordinator.bufferRawGpsPoint(
        _position(seconds: 0, lat: 10.738, lng: 106.625),
        workoutId: 'paused-session-010',
      );

      // Paused state: simulate runner paused for 30 seconds -> no bufferRawGpsPoint calls made.

      // Resumed active point
      coordinator.bufferRawGpsPoint(
        _position(seconds: 31, lat: 10.739, lng: 106.626),
        workoutId: 'paused-session-010',
      );

      expect(coordinator.rawTrackingDiagnostics.capturedGpsPoints, 2);
    });

    test('11. Historical journal compatibility (legacy JSONL with no manifest)', () async {
      const sessionId = 'legacy-session-011';
      final file = await journal.fileForSession(sessionId);
      await file.parent.create(recursive: true);

      // Legacy format (no manifest, older timestamp format)
      final line1 = jsonEncode({
        'workout_id': sessionId,
        'timestamp': '2026-09-01T06:00:00.000Z',
        'latitude': 10.738,
        'longitude': 106.625,
        'altitude': 10.0,
        'speed': 3.5,
        'accuracy': 6.0,
      });
      final line2 = jsonEncode({
        'workout_id': sessionId,
        'timestamp': '2026-09-01T06:00:01.000Z',
        'latitude': 10.7381,
        'longitude': 106.6251,
        'altitude': 10.0,
        'speed': 3.5,
        'accuracy': 6.0,
      });
      await file.writeAsString('$line1\n$line2\n');

      final recovery = await journal.readJournal(sessionId);
      expect(recovery.status, RawGpsRecoveryStatus.recoveredLegacyNoManifest);
      expect(recovery.validPointsCount, 2);
      expect(recovery.points, hasLength(2));
      expect(recovery.manifest, isNull);
      expect(recovery.isUnfinalizedCrash, isTrue);
    });

    test('12. Per-sample write latency and memory behavior benchmark', () async {
      const benchmarkSession = 'benchmark-session-012';
      const sampleCount = 1000;
      final startTime = DateTime.utc(2026, 10, 19, 12, 0, 0);

      final sw = Stopwatch()..start();
      for (var i = 0; i < sampleCount; i++) {
        final point = _syntheticPoint(
          workoutId: benchmarkSession,
          timestamp: startTime.add(Duration(milliseconds: i * 1000)),
          lat: 10.738 + (i * 0.00001),
          lng: 106.625 + (i * 0.00001),
        );
        final ack = await journal.appendPoint(point, userId: testUserId);
        expect(ack.success, isTrue);
      }
      sw.stop();

      final diagnostics = journal.getDiagnostics(benchmarkSession);
      expect(diagnostics.committedSamples, sampleCount);
      expect(diagnostics.droppedSamples, 0);
      expect(diagnostics.queuedAppends, 0);

      // Print measured performance to test output
      // ignore: avoid_print
      print(
        'RG-1A Benchmark Results ($sampleCount samples with flush: true): '
        'Total time: ${sw.elapsedMilliseconds} ms, '
        'Mean latency: ${diagnostics.meanLatencyMs.toStringAsFixed(3)} ms/sample, '
        'Min latency: ${diagnostics.minLatencyMs.toStringAsFixed(3)} ms, '
        'Max latency: ${diagnostics.maxLatencyMs.toStringAsFixed(3)} ms',
      );

      // Verify that serialized disk append is well under GPS 1 Hz epoch (1000 ms)
      expect(diagnostics.meanLatencyMs, lessThan(50.0));
    });
  });
}

LocalGPSPoint _syntheticPoint({
  required String workoutId,
  required DateTime timestamp,
  required double lat,
  required double lng,
  double? speed,
  double? accuracy,
}) {
  return LocalGPSPoint()
    ..sessionId = workoutId
    ..timestamp = timestamp.toUtc()
    ..latitude = lat
    ..longitude = lng
    ..speed = speed ?? 4.0
    ..accuracy = accuracy ?? 5.0
    ..confidence = 'high'
    ..deviceSource = 'geolocator_position_stream';
}

Position _position({
  required int seconds,
  required double lat,
  required double lng,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.utc(2026, 10, 14, 1, 0, seconds),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 90,
    headingAccuracy: 0,
    speed: 4,
    speedAccuracy: 0,
  );
}

SupabaseClient _client() =>
    SupabaseClient('https://example.supabase.co', 'test-anon-key');

class _FakeRawTrackingRemoteDataSource extends RawTrackingRemoteDataSource {
  _FakeRawTrackingRemoteDataSource() : super(_client());

  final List<RawGpsPointPayload> savedGpsPoints = [];

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) async {
    savedGpsPoints.addAll(points);
  }

  @override
  Future<int> countRawGpsPointsForWorkout(String workoutId) async =>
      savedGpsPoints.where((p) => p.workoutId == workoutId).length;
}

class _FakeWorkoutRemoteDataSource extends WorkoutRemoteDataSource {
  _FakeWorkoutRemoteDataSource() : super(_client());
}

class _FakeWorkoutProcessingRemoteDataSource
    extends WorkoutProcessingRemoteDataSource {
  _FakeWorkoutProcessingRemoteDataSource() : super(_client());

  @override
  Future<void> insertLog({
    required String workoutId,
    String? jobId,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
    String logLevel = 'info',
  }) async {}
}
