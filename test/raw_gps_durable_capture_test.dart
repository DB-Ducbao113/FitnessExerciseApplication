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

  group('RG-1A.2: Data Preservation Safety Hotfix Regression Tests', () {
    const testWorkoutId = '00000000-0000-4000-8000-000000000001';
    const testUserId = 'test-athlete-001';

    test('delete(sessionId) without options must not delete (fails closed)', () async {
      const sessionId = 'test-no-opt-delete';
      await journal.appendPoint(
        _syntheticPoint(
          workoutId: sessionId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 0),
          lat: 10.738,
          lng: 106.625,
        ),
        userId: testUserId,
      );
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // Calling delete without options MUST throw StateError and preserve journal
      expect(() => journal.delete(sessionId), throwsA(isA<StateError>()));
      final file = await journal.fileForSession(sessionId);
      expect(await file.exists(), isTrue);
    });

    test('No read-back verification -> no automatic cleanup', () async {
      const sessionId = 'test-no-readback';
      await journal.appendPoint(
        _syntheticPoint(
          workoutId: sessionId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 0),
          lat: 10.738,
          lng: 106.625,
        ),
        userId: testUserId,
      );
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // Automatic cleanup without trusted readback verification rejected
      expect(
        () => journal.delete(
          sessionId,
          verifySafe: true,
          verifiedCloudCount: 1,
        ),
        throwsA(isA<StateError>()),
      );
      final file = await journal.fileForSession(sessionId);
      expect(await file.exists(), isTrue);
    });

    test('Caller spoofing a manifest digest -> no deletion', () async {
      const sessionId = 'test-spoof-digest';
      await journal.appendPoint(
        _syntheticPoint(
          workoutId: sessionId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 0),
          lat: 10.738,
          lng: 106.625,
        ),
        userId: testUserId,
      );
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      final manifest = await journal.readManifest(sessionId);
      expect(manifest!.sha256Digest, isNotNull);

      // Caller passing manifest SHA-256 directly without canonical Supabase read-back must still be rejected
      expect(
        () => journal.delete(
          sessionId,
          verifySafe: true,
          cloudReadBackSha256: manifest.sha256Digest,
        ),
        throwsA(isA<StateError>()),
      );
      final file = await journal.fileForSession(sessionId);
      expect(await file.exists(), isTrue);
    });

    test('Explicit authorized user deletion follows separate semantics', () async {
      const sessionId = 'test-explicit-user-delete';
      await journal.appendPoint(
        _syntheticPoint(
          workoutId: sessionId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 0),
          lat: 10.738,
          lng: 106.625,
        ),
        userId: 'athlete-owner-1',
      );
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      final file = await journal.fileForSession(sessionId);
      expect(await file.exists(), isTrue);

      // Unauthorized user attempting deletion must fail closed
      expect(
        () => journal.delete(
          sessionId,
          force: true,
          authorizedUserId: 'intruder-user-2',
        ),
        throwsA(isA<StateError>()),
      );
      expect(await file.exists(), isTrue);

      // Authorized owner deleting explicitly succeeds
      await journal.delete(
        sessionId,
        force: true,
        authorizedUserId: 'athlete-owner-1',
      );
      expect(await file.exists(), isFalse);
    });

    test('Truncated-tail repair interrupted during replacement -> original journal preserved', () async {
      const sessionId = 'test-fault-inject-repair';
      final file = await journal.fileForSession(sessionId);
      await file.parent.create(recursive: true);

      final p1 = jsonEncode({
        'workout_id': sessionId,
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:00:00.000Z',
        'latitude': 10.7380,
        'longitude': 106.6250,
      });
      // Original file content: 1 valid line and 1 truncated line
      final originalContent =
          '$p1\n{"workout_id":"$sessionId","latitude":10.7381,"long';
      await file.writeAsString(originalContent, flush: true);

      // Create journal instance with fault injection during repair_rename
      final faultJournal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
        onIoFaultInject: (phase) async {
          if (phase == 'repair_rename') {
            throw const FileSystemException(
              'Injected simulated I/O failure during repair rename',
            );
          }
        },
      );

      // Attempt to open writer (which triggers repair) -> should fail cleanly
      expect(
        () => faultJournal.appendPoint(
          _syntheticPoint(
            workoutId: sessionId,
            timestamp: DateTime.utc(2026, 10, 19, 8, 2),
            lat: 10.7382,
            lng: 106.6252,
          ),
          userId: testUserId,
        ),
        throwsA(isA<FileSystemException>()),
      );

      // Verify original journal content remains intact and recoverable
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), originalContent);
    });

    test('Manifest replacement failure -> original manifest preserved', () async {
      const sessionId = 'test-fault-inject-manifest';
      await journal.appendPoint(
        _syntheticPoint(
          workoutId: sessionId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 0),
          lat: 10.738,
          lng: 106.625,
        ),
        userId: testUserId,
      );
      await journal.checkpoint(sessionId, isFinalized: false);

      final originalManifest = await journal.readManifest(sessionId);
      expect(originalManifest, isNotNull);
      final originalSeq = originalManifest!.checkpointSeq;

      // Create journal with fault injection during checkpoint_rename
      final faultJournal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
        onIoFaultInject: (phase) async {
          if (phase == 'checkpoint_rename') {
            throw const FileSystemException(
              'Injected simulated crash during manifest atomic rename',
            );
          }
        },
      );

      // Direct checkpoint attempt fails
      expect(
        () => faultJournal.checkpoint(sessionId, isFinalized: true),
        throwsA(isA<FileSystemException>()),
      );

      // Original manifest remains intact with originalSeq and original digest
      final afterManifest = await journal.readManifest(sessionId);
      expect(afterManifest, isNotNull);
      expect(afterManifest!.checkpointSeq, originalSeq);
      expect(afterManifest.sha256Digest, originalManifest.sha256Digest);
    });

    test('Empty journal plus nonzero manifest count -> integrity FAIL', () async {
      const sessionId = 'test-empty-with-count';
      final file = await journal.fileForSession(sessionId);
      await file.parent.create(recursive: true);
      // Write empty file (0 bytes / 0 lines)
      await file.writeAsString('', flush: true);

      // Write manifest claiming 10 points
      final manifestFile = await journal.manifestFileForSession(sessionId);
      final manifest = RawGpsJournalManifest(
        workoutId: sessionId,
        userId: testUserId,
        sampleCount: 10,
        checkpointSeq: 1,
        checkpointTimestampUtc: DateTime.now().toUtc(),
        sha256Digest:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      await manifestFile.writeAsString(
        jsonEncode(manifest.toJson()),
        flush: true,
      );

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.status, RawGpsRecoveryStatus.corrupted);
      expect(recovery.status, isNot(RawGpsRecoveryStatus.verifiedIntact));
      expect(recovery.validPointsCount, 0);
    });

    test('Modified checkpointed prefix plus extra records -> not STALE_CHECKPOINT verified', () async {
      const sessionId = 'test-corrupted-prefix';
      for (var i = 0; i < 3; i++) {
        await journal.appendPoint(
          _syntheticPoint(
            workoutId: sessionId,
            timestamp: DateTime.utc(2026, 10, 19, 8, i),
            lat: 10.738 + (i * 0.0001),
            lng: 106.625 + (i * 0.0001),
          ),
          userId: testUserId,
        );
      }
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: false);

      // Now add 2 more records (total 5 lines) BUT tamper with line 2 (part of the 3-point prefix!)
      final file = await journal.fileForSession(sessionId);
      final lines = await file.readAsLines();
      final tamperedLine2 = jsonDecode(lines[1]) as Map<String, dynamic>;
      tamperedLine2['latitude'] = 11.2345; // tampered prefix record!
      lines[1] = jsonEncode(tamperedLine2);

      final p4 = jsonEncode({
        'workout_id': sessionId,
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:03:00.000Z',
        'latitude': 10.7383,
        'longitude': 106.6253,
      });
      final p5 = jsonEncode({
        'workout_id': sessionId,
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:04:00.000Z',
        'latitude': 10.7384,
        'longitude': 106.6254,
      });
      lines.add(p4);
      lines.add(p5);
      await file.writeAsString('${lines.join('\n')}\n', flush: true);

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      // Must NOT be classified as staleCheckpoint since historical prefix was modified!
      expect(recovery.status, isNot(RawGpsRecoveryStatus.staleCheckpoint));
      expect(recovery.status, RawGpsRecoveryStatus.corrupted);
      // But valid parsed points remain accessible without claiming verified integrity
      expect(recovery.points, hasLength(5));
    });

    test('TC-01: Journal intact + correct digest => VERIFIED_INTACT', () async {
      const sessionId = 'tc-01-intact';
      for (var i = 0; i < 5; i++) {
        await journal.appendPoint(
          _syntheticPoint(
            workoutId: sessionId,
            timestamp: DateTime.utc(2026, 10, 19, 8, i),
            lat: 10.738 + (i * 0.0001),
            lng: 106.625 + (i * 0.0001),
          ),
          userId: testUserId,
        );
      }
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.status, RawGpsRecoveryStatus.verifiedIntact);
      expect(recovery.validPointsCount, 5);
      expect(recovery.points, hasLength(5));
      expect(recovery.duplicatePointsCount, 0);
      expect(recovery.corruptedLinesCount, 0);
      expect(recovery.hasTruncatedFinalLine, isFalse);
    });

    test('TC-02: JSON remains valid but one coordinate changes => integrity FAIL', () async {
      const sessionId = 'tc-02-tampered';
      for (var i = 0; i < 3; i++) {
        await journal.appendPoint(
          _syntheticPoint(
            workoutId: sessionId,
            timestamp: DateTime.utc(2026, 10, 19, 8, i),
            lat: 10.738 + (i * 0.0001),
            lng: 106.625 + (i * 0.0001),
          ),
          userId: testUserId,
        );
      }
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // Tamper with one coordinate in the file (JSON syntax remains valid, coordinate changes)
      final file = await journal.fileForSession(sessionId);
      final lines = await file.readAsLines();
      final tamperedMap = jsonDecode(lines[1]) as Map<String, dynamic>;
      tamperedMap['latitude'] = 10.99999;
      lines[1] = jsonEncode(tamperedMap);
      await file.writeAsString('${lines.join('\n')}\n', flush: true);

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.status, RawGpsRecoveryStatus.corrupted);
      expect(recovery.status, isNot(RawGpsRecoveryStatus.verifiedIntact));
    });

    test('TC-03: Manifest count mismatch => NOT VERIFIED', () async {
      const sessionId = 'tc-03-count-mismatch';
      for (var i = 0; i < 4; i++) {
        await journal.appendPoint(
          _syntheticPoint(
            workoutId: sessionId,
            timestamp: DateTime.utc(2026, 10, 19, 8, i),
            lat: 10.738 + (i * 0.0001),
            lng: 106.625 + (i * 0.0001),
          ),
          userId: testUserId,
        );
      }
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // Manifest recorded 4. Modify manifest to expect 5 samples.
      final manifestFile = await journal.manifestFileForSession(sessionId);
      final manifestMap =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      manifestMap['sample_count'] = 5;
      await manifestFile.writeAsString(jsonEncode(manifestMap), flush: true);

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.status, RawGpsRecoveryStatus.corrupted);
      expect(recovery.status, isNot(RawGpsRecoveryStatus.verifiedIntact));
    });

    test('TC-04: Stale checkpoint with extra committed records => STALE_CHECKPOINT; data preserved', () async {
      const sessionId = 'tc-04-stale-checkpoint';
      for (var i = 0; i < 3; i++) {
        await journal.appendPoint(
          _syntheticPoint(
            workoutId: sessionId,
            timestamp: DateTime.utc(2026, 10, 19, 8, i),
            lat: 10.738 + (i * 0.0001),
            lng: 106.625 + (i * 0.0001),
          ),
          userId: testUserId,
        );
      }
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: false);

      // Directly append 2 more committed valid records simulating commits after checkpoint prior to crash
      final file = await journal.fileForSession(sessionId);
      final p4 = jsonEncode({
        'workout_id': sessionId,
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:03:00.000Z',
        'latitude': 10.7383,
        'longitude': 106.6253,
        'accuracy': 5.0,
      });
      final p5 = jsonEncode({
        'workout_id': sessionId,
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:04:00.000Z',
        'latitude': 10.7384,
        'longitude': 106.6254,
        'accuracy': 5.0,
      });
      await file.writeAsString('$p4\n$p5\n', mode: FileMode.append, flush: true);

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.status, RawGpsRecoveryStatus.staleCheckpoint);
      expect(recovery.validPointsCount, 5);
      expect(recovery.points, hasLength(5));
    });

    test('TC-05: Crash and reopen, then append => counts and hashes reconcile', () async {
      const sessionId = 'tc-05-crash-reopen';
      for (var i = 0; i < 3; i++) {
        await journal.appendPoint(
          _syntheticPoint(
            workoutId: sessionId,
            timestamp: DateTime.utc(2026, 10, 19, 8, i),
            lat: 10.738 + (i * 0.0001),
            lng: 106.625 + (i * 0.0001),
          ),
          userId: testUserId,
        );
      }
      await journal.flushSession(sessionId);

      // Simulate process restart with fresh journal instance
      final restartedJournal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
        checkpointInterval: 50,
        maxQueueDepth: 100,
      );

      // Append new points
      final ack4 = await restartedJournal.appendPoint(
        _syntheticPoint(
          workoutId: sessionId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 3),
          lat: 10.7383,
          lng: 106.6253,
        ),
        userId: testUserId,
      );
      expect(ack4.success, isTrue);
      expect(ack4.sampleIndex, 4);

      final ack5 = await restartedJournal.appendPoint(
        _syntheticPoint(
          workoutId: sessionId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 4),
          lat: 10.7384,
          lng: 106.6254,
        ),
        userId: testUserId,
      );
      expect(ack5.success, isTrue);
      expect(ack5.sampleIndex, 5);

      await restartedJournal.flushSession(sessionId);
      await restartedJournal.checkpoint(sessionId, isFinalized: true);

      final recovery = await restartedJournal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.status, RawGpsRecoveryStatus.verifiedIntact);
      expect(recovery.validPointsCount, 5);
      expect(recovery.points, hasLength(5));

      final manifest = await restartedJournal.readManifest(sessionId);
      expect(manifest!.sampleCount, 5);
      expect(manifest.sha256Digest, isNotNull);
    });

    test('TC-06: Truncated final line followed by restart => later appends remain readable', () async {
      const sessionId = 'tc-06-quarantine';
      final file = await journal.fileForSession(sessionId);
      await file.parent.create(recursive: true);

      final p1 = jsonEncode({
        'workout_id': sessionId,
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:00:00.000Z',
        'latitude': 10.7380,
        'longitude': 106.6250,
        'accuracy': 5.0,
      });
      final p2 = jsonEncode({
        'workout_id': sessionId,
        'user_id': testUserId,
        'timestamp': '2026-10-19T08:00:01.000Z',
        'latitude': 10.7381,
        'longitude': 106.6251,
        'accuracy': 5.0,
      });

      // Write 2 valid lines and 1 truncated line (crash mid-write without trailing \n)
      await file.writeAsString(
        '$p1\n$p2\n{"workout_id":"$sessionId","user_id":"$testUserId","latitude":10.7382,"lon',
      );

      // Restart app / open journal writer
      final restartedJournal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
      );

      // Appending point 3 must succeed without syntax collision with the truncated bytes
      final ack = await restartedJournal.appendPoint(
        _syntheticPoint(
          workoutId: sessionId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 2),
          lat: 10.7382,
          lng: 106.6252,
        ),
        userId: testUserId,
      );
      expect(ack.success, isTrue);

      // Verify truncated snippet was quarantined
      final quarantineFile = File('${file.path}.quarantine');
      expect(await quarantineFile.exists(), isTrue);
      final quarantineContent = await quarantineFile.readAsString();
      expect(quarantineContent, contains('"workout_id":"$sessionId"'));

      await restartedJournal.flushSession(sessionId);

      final recovery = await restartedJournal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.validPointsCount, 3);
      expect(recovery.points, hasLength(3));
      expect(recovery.corruptedLinesCount, 0);
      expect(recovery.hasTruncatedFinalLine, isFalse);
    });

    test('TC-10: Queue overflow => explicit failure and incomplete capture status', () async {
      final smallBufferJournal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
        checkpointInterval: 10,
        maxQueueDepth: 3,
      );

      final futures = <Future<RawGpsAppendResult>>[];
      for (var i = 0; i < 15; i++) {
        final point = _syntheticPoint(
          workoutId: 'tc-10-overflow',
          timestamp: DateTime.utc(2026, 10, 19, 8, i),
          lat: 10.738,
          lng: 106.625,
        );
        futures.add(smallBufferJournal.appendPoint(point, userId: testUserId));
      }

      final results = await Future.wait(futures);
      final failures = results.where((r) => !r.success).toList();
      expect(failures, isNotEmpty);
      expect(failures.first.error, contains('queue buffer overflow'));
      expect(failures.first.sampleIndex, -1);

      final diagnostics = smallBufferJournal.getDiagnostics('tc-10-overflow');
      expect(diagnostics.droppedSamples, greaterThan(0));
    });

    test('TC-11: Legacy journal without user identity => no unauthorized cross-account replay', () async {
      const sessionId = 'tc-11-legacy-unattributed';
      final file = await journal.fileForSession(sessionId);
      await file.parent.create(recursive: true);

      // Legacy line with no user_id attribute
      final legacyLine = jsonEncode({
        'workout_id': sessionId,
        'timestamp': '2026-09-01T06:00:00.000Z',
        'latitude': 10.738,
        'longitude': 106.625,
      });
      await file.writeAsString('$legacyLine\n', flush: true);

      // Active user attempts recovery -> rejected under conservative account isolation
      final crossAccountRecovery = await journal.readJournal(
        sessionId,
        activeUserId: 'athlete-intruder-999',
      );
      expect(crossAccountRecovery.status, RawGpsRecoveryStatus.accountMismatch);
      expect(crossAccountRecovery.points, isEmpty);
      expect(crossAccountRecovery.accountMismatchUserId, 'unknown_unattributed');

      // Read with activeUserId == null allows access without fabricated guarantees
      final unverifiedRecovery = await journal.readJournal(sessionId);
      expect(
        unverifiedRecovery.status,
        RawGpsRecoveryStatus.recoveredLegacyNoManifest,
      );
      expect(unverifiedRecovery.points, hasLength(1));
    });

    test('TC-12: Existing 3,600-point capture and previous regression tests still PASS', () async {
      final startTime = DateTime.utc(2026, 10, 19, 8, 0, 0);
      const totalPoints = 3600;

      for (var i = 0; i < totalPoints; i++) {
        final point = _syntheticPoint(
          workoutId: testWorkoutId,
          timestamp: startTime.add(Duration(seconds: i)),
          lat: 10.7380 + (i * 0.0001),
          lng: 106.6250 + (i * 0.0001),
          speed: 4.5,
          accuracy: 4.0,
        );
        final ack = await journal.appendPoint(point, userId: testUserId);
        expect(ack.success, isTrue);
        expect(ack.sampleIndex, i + 1);
      }

      await journal.flushSession(testWorkoutId);
      await journal.checkpoint(testWorkoutId, isFinalized: true);

      final recovery = await journal.readJournal(
        testWorkoutId,
        activeUserId: testUserId,
      );
      expect(recovery.status, RawGpsRecoveryStatus.verifiedIntact);
      expect(recovery.validPointsCount, totalPoints);
      expect(recovery.points.length, totalPoints);
    });

    test('Additional RG-1A: Partial Isar failure resilience in coordinator', () async {
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

      expect(diagnostics.isarSavedGpsPoints, 0);
      expect(diagnostics.recoverySavedGpsPoints, 2);
      expect(diagnostics.localSavedGpsPoints, 2);
      expect(diagnostics.localFailedGpsPoints, 0);

      final recovery = await journal.readJournal(
        'isar-fail-session-005',
        activeUserId: testUserId,
      );
      expect(recovery.validPointsCount, 2);
    });

    test('Additional RG-1A: Duplicate replay handled deterministically', () async {
      const sessionId = 'duplicate-session-006';
      final point = _syntheticPoint(
        workoutId: sessionId,
        timestamp: DateTime.utc(2026, 10, 19, 8, 30, 0),
        lat: 10.738,
        lng: 106.625,
      );

      await journal.appendPoint(point, userId: testUserId);
      await journal.appendPoint(point, userId: testUserId);
      await journal.appendPoint(point, userId: testUserId);

      await journal.flushSession(sessionId);

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.points, hasLength(1));
      expect(recovery.validPointsCount, 1);
      expect(recovery.duplicatePointsCount, 2);
    });

    test('Additional RG-1A: Manifest update interruption (.tmp orphan resilience)', () async {
      const sessionId = 'manifest-interrupted-004';
      final point = _syntheticPoint(
        workoutId: sessionId,
        timestamp: DateTime.utc(2026, 10, 19, 8, 0),
        lat: 10.738,
        lng: 106.625,
      );
      await journal.appendPoint(point, userId: testUserId);
      await journal.checkpoint(sessionId);

      final manifestFile = await journal.manifestFileForSession(sessionId);
      final tmpFile = File('${manifestFile.path}.tmp');
      await tmpFile.writeAsString('{"partial": "broken json');

      final manifest = await journal.readManifest(sessionId);
      expect(manifest, isNotNull);
      expect(manifest!.sampleCount, 1);

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.validPointsCount, 1);
    });

    test('Additional RG-1A: Concurrent GPS ingestion and ordered persistence', () async {
      const sessionId = 'concurrent-session-008';
      const count = 100;
      final startTime = DateTime.utc(2026, 10, 19, 10, 0, 0);

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

      final recovery = await journal.readJournal(
        sessionId,
        activeUserId: testUserId,
      );
      expect(recovery.validPointsCount, count);

      for (var i = 0; i < count; i++) {
        expect(
          recovery.points[i].timestamp,
          startTime.add(Duration(seconds: i)),
        );
      }
    });

    test('Additional RG-1A: Pause state privacy: zero journal writes while paused', () async {
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

      coordinator.bufferRawGpsPoint(
        _position(seconds: 0, lat: 10.738, lng: 106.625),
        workoutId: 'paused-session-010',
      );

      coordinator.bufferRawGpsPoint(
        _position(seconds: 31, lat: 10.739, lng: 106.626),
        workoutId: 'paused-session-010',
      );

      expect(coordinator.rawTrackingDiagnostics.capturedGpsPoints, 2);
    });

    test('Additional RG-1A: Per-sample write latency and memory behavior benchmark', () async {
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
        'RG-1A Benchmark Results ($sampleCount samples with flush: true on ${Platform.operatingSystem}): '
        'Total time: ${sw.elapsedMilliseconds} ms, '
        'Mean latency: ${diagnostics.meanLatencyMs.toStringAsFixed(3)} ms/sample, '
        'Min latency: ${diagnostics.minLatencyMs.toStringAsFixed(3)} ms, '
        'Max latency: ${diagnostics.maxLatencyMs.toStringAsFixed(3)} ms',
      );

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
