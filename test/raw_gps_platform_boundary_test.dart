import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_platform_boundary.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class _FakeTrackingDataSource implements RawTrackingRemoteDataSource {
  final List<RawGpsPointPayload> points = [];

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> pts) async {
    points.addAll(pts);
  }

  @override
  Future<List<RawGpsPointPayload>> fetchAllRawGpsPoints(
    String workoutId, {
    int pageSize = 1000,
  }) async {
    return points.where((p) => p.workoutId == workoutId).toList();
  }

  @override
  Future<List<RawGpsPointPayload>> fetchRawGpsPointsPaged(
    String workoutId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    final filtered = points.where((p) => p.workoutId == workoutId).toList();
    if (offset >= filtered.length) return const [];
    final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
    return filtered.sublist(offset, end);
  }

  @override
  Future<int> countRawGpsPointsForWorkout(String workoutId) async {
    return points.where((p) => p.workoutId == workoutId).length;
  }

  @override
  Future<void> saveRawStepIntervals(List<RawStepIntervalPayload> intervals) async {}
}

class _FakeWorkoutRemote implements WorkoutRemoteDataSource {
  final List<Map<String, dynamic>> routeSnapshots = [];

  @override
  Future<void> createSessionShell({
    required String id,
    required String userId,
    required String activityType,
    required String mode,
    required DateTime startedAt,
    required DateTime createdAt,
  }) async {}

  @override
  Future<void> saveLiveRouteSnapshot({
    required String sessionId,
    required List<List<LatLng>> routeSegments,
    bool shouldRequestRouteCorrection = false,
    double? lastGpsGapDurationSec,
    bool isGpsSignalWeak = false,
  }) async {
    routeSnapshots.add({
      'sessionId': sessionId,
      'segmentCount': routeSegments.length,
      'pointCount': routeSegments.fold<int>(0, (sum, seg) => sum + seg.length),
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProcessingRemote implements WorkoutProcessingRemoteDataSource {
  final List<Map<String, dynamic>> loggedEvents = [];

  @override
  Future<void> insertLog({
    required String workoutId,
    String? jobId,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
    String logLevel = 'info',
  }) async {
    loggedEvents.add({
      'workoutId': workoutId,
      'eventType': eventType,
      'message': message,
      'payload': payload,
      'logLevel': logLevel,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Position _position(int index, {required DateTime time}) => Position(
  latitude: 10.7380 + (index * 0.0001),
  longitude: 106.6250 + (index * 0.0001),
  timestamp: time,
  altitude: 12.0,
  altitudeAccuracy: 1.0,
  accuracy: 3.5,
  heading: 90.0,
  headingAccuracy: 1.0,
  speed: 4.2,
  speedAccuracy: 0.5,
);

void main() {
  group('AETRON RG-F2 Platform Capability Audit (RG-F2.1)', () {
    test('RG-F2.1-1: Platform support matrix correctly specifies iOS as primary research target', () {
      final ios = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.ios);
      expect(ios.platform, RawGpsTargetPlatform.ios);
      expect(ios.isResearchGradeCaptureSupported, isTrue);
      expect(ios.supportsDurableIsar, isTrue);
      expect(ios.supportsRecoveryJournal, isTrue);
      expect(ios.supportsBackgroundLocation, isTrue);
      expect(ios.supportsCloudOutbox, isTrue);
      expect(ios.supportsLocalRecovery, isTrue);
      expect(ios.description, contains('iOS: Primary target'));
    });

    test('RG-F2.1-2: Platform support matrix correctly specifies Android as secondary native target', () {
      final android = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.android);
      expect(android.platform, RawGpsTargetPlatform.android);
      expect(android.isResearchGradeCaptureSupported, isTrue);
      expect(android.supportsDurableIsar, isTrue);
      expect(android.supportsRecoveryJournal, isTrue);
      expect(android.supportsBackgroundLocation, isTrue);
      expect(android.supportsCloudOutbox, isTrue);
      expect(android.supportsLocalRecovery, isTrue);
      expect(android.description, contains('Android: Secondary native target'));
    });

    test('RG-F2.1-3: Platform support matrix explicitly descopes Flutter Web', () {
      final web = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.web);
      expect(web.platform, RawGpsTargetPlatform.web);
      expect(web.isResearchGradeCaptureSupported, isFalse);
      expect(web.supportsDurableIsar, isFalse);
      expect(web.supportsRecoveryJournal, isFalse);
      expect(web.supportsBackgroundLocation, isFalse);
      expect(web.supportsCloudOutbox, isFalse);
      expect(web.supportsLocalRecovery, isFalse);
      expect(web.description, contains('Flutter Web: Explicitly descoped'));
    });

    test('RG-F2.1-4: Platform support matrix audits all target platforms and serializes cleanly', () {
      final matrix = RawGpsPlatformCapability.supportMatrix;
      expect(matrix.keys, containsAll([
        RawGpsTargetPlatform.ios,
        RawGpsTargetPlatform.android,
        RawGpsTargetPlatform.web,
        RawGpsTargetPlatform.other,
      ]));

      for (final entry in matrix.entries) {
        final json = entry.value.toJson();
        expect(json['platform'], entry.key.name);
        expect(json['label'], isNotEmpty);
        expect(json['description'], isNotEmpty);
      }
    });
  });

  group('AETRON RG-F2 Fail-safe Web Behavior (RG-F2.2)', () {
    test('RG-F2.2-1: RawGpsVerificationState.unsupported exists with proper label and isVerified=false', () {
      const state = RawGpsVerificationState.unsupported;
      expect(state.label, 'UNSUPPORTED');

      final report = RawGpsCanonicalVerification.unsupportedPlatform(
        workoutId: 'w-test-1',
        platform: 'web',
      );
      expect(report.state, RawGpsVerificationState.unsupported);
      expect(report.isVerified, isFalse);
      expect(report.localCount, 0);
      expect(report.cloudCount, 0);
      expect(report.message, contains('Unsupported on web'));
    });

    test('RG-F2.2-2: RawTrackingDiagnostics detects Web environment and marks complete/retained as false', () {
      const diagnostics = RawTrackingDiagnostics(
        capturedGpsPoints: 100,
        expectedUniqueGpsPoints: 100,
        localSavedGpsPoints: 0,
        localFailedGpsPoints: 0,
        isarSavedGpsPoints: 0,
        recoverySavedGpsPoints: 0,
        recoveryFailedGpsPoints: 0,
        uploadedGpsPoints: 0,
        remoteUploadFailures: 0,
        pendingGpsPoints: 0,
        serverConfirmedGpsPoints: null,
      );

      final json = diagnostics.toJson();
      expect(json, containsPair('raw_gps_captured_points', 100));
      // Never reports complete without local persistence and server confirmation
      expect(diagnostics.isComplete, isFalse);
      expect(json['raw_gps_complete'], isFalse);
    });

    test('RG-F2.2-3: Web workout coordinator logs processing event on stop and skips outbox/journal checkpoint on web', () async {
      final tracking = _FakeTrackingDataSource();
      final workoutRemote = _FakeWorkoutRemote();
      final processingRemote = _FakeProcessingRemote();

      final coordinator = WorkoutRecordingCoordinator(
        rawTracking: tracking,
        workoutRemote: workoutRemote,
        processingRemote: processingRemote,
        currentUserId: () => 'test-web-user',
      );

      final sessionId = 'web-session-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      await coordinator.createRemoteWorkoutShell(
        sessionId: sessionId,
        startedAt: now,
        activityType: 'running',
        mode: 'outdoor',
      );

      coordinator.queueLiveRouteSnapshot(
        workoutId: sessionId,
        routeSegments: [
          [const LatLng(10.762622, 106.660172)],
        ],
        lastGpsGapDurationSec: 0,
        isGpsSignalWeak: false,
      );

      // Finalize session
      final diag = await coordinator.finalizeRawTracking(workoutId: sessionId);
      expect(diag.isComplete, isFalse);

      expect(processingRemote.loggedEvents, isNotEmpty);
      final stopEvent = processingRemote.loggedEvents.first;
      expect(stopEvent['workoutId'], sessionId);
    });

    test('RG-F2.2-4: Web route snapshots continue to function for standard UI display without raw GPS claims', () async {
      final workoutRemote = _FakeWorkoutRemote();
      final coordinator = WorkoutRecordingCoordinator(
        rawTracking: _FakeTrackingDataSource(),
        workoutRemote: workoutRemote,
        processingRemote: _FakeProcessingRemote(),
        currentUserId: () => 'test-web-user',
      );

      const sessionId = 'web-route-display-session';
      final now = DateTime.now();
      await coordinator.createRemoteWorkoutShell(
        sessionId: sessionId,
        startedAt: now,
        activityType: 'walking',
        mode: 'outdoor',
      );

      coordinator.queueLiveRouteSnapshot(
        workoutId: sessionId,
        routeSegments: [
          [const LatLng(10.770, 106.670), const LatLng(10.771, 106.671)],
        ],
        lastGpsGapDurationSec: 0,
        isGpsSignalWeak: false,
      );

      await coordinator.syncLiveRouteSnapshot(force: true);

      expect(workoutRemote.routeSnapshots, hasLength(1));
      expect(workoutRemote.routeSnapshots.first['sessionId'], sessionId);
      expect(workoutRemote.routeSnapshots.first['pointCount'], 2);
    });
  });

  group('AETRON RG-F2 Native Contract Verification (RG-F2.3)', () {
    test('RG-F2.3-1: Native capture acknowledges durability only after local persistence succeeds', () async {
      final pointsSaved = <LocalGPSPoint>[];
      final coordinator = WorkoutRecordingCoordinator(
        rawTracking: _FakeTrackingDataSource(),
        workoutRemote: _FakeWorkoutRemote(),
        processingRemote: _FakeProcessingRemote(),
        currentUserId: () => 'test-user',
        saveLocalGpsPoint: (p) async => pointsSaved.add(p),
        saveRecoveryGpsPoint: (p) async {},
      );

      const sessionId = 'native-durable-ack-session';
      final now = DateTime.now();
      await coordinator.createRemoteWorkoutShell(
        sessionId: sessionId,
        startedAt: now,
        activityType: 'running',
        mode: 'outdoor',
      );

      final pos = _position(0, time: now);
      coordinator.bufferRawGpsPoint(pos, workoutId: sessionId);

      // Await in-flight write tail
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final diag = coordinator.rawTrackingDiagnostics;
      expect(diag.capturedGpsPoints, 1);
      expect(diag.localSavedGpsPoints, 1);
      expect(diag.localFailedGpsPoints, 0);
      expect(pointsSaved, hasLength(1));
    });

    test('RG-F2.3-2: Cross-account isolation prevents unauthorized user from accessing or deleting raw GPS', () async {
      final tempDir = Directory.systemTemp.createTempSync('aetron_rg_f2_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final journal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
      );

      const sessionA = 'session-user-a';
      const userA = 'user-a-123';
      const userB = 'user-b-456';

      final p = LocalGPSPoint()
        ..sessionId = sessionA
        ..timestamp = DateTime.utc(2026, 10, 20, 12, 0, 0)
        ..latitude = 10.770
        ..longitude = 106.670
        ..accuracy = 5.0
        ..confidence = 'high';

      final appendResult = await journal.appendPoint(p, userId: userA);
      expect(appendResult.success, isTrue);
      await journal.flushSession(sessionA);
      await journal.checkpoint(sessionA, isFinalized: true);

      // User B attempts to read User A's session -> accountMismatch
      final readResult = await journal.readJournal(sessionA, activeUserId: userB);
      expect(readResult.status, RawGpsRecoveryStatus.accountMismatch);
      expect(readResult.points, isEmpty);

      // User B attempts to delete User A's journal -> throws StateError
      expect(
        () => journal.delete(sessionA, force: true, authorizedUserId: userB),
        throwsA(isA<StateError>()),
      );

      // User A can safely read own session
      final readResultA = await journal.readJournal(sessionA, activeUserId: userA);
      expect(readResultA.status, RawGpsRecoveryStatus.verifiedIntact);
      expect(readResultA.points, hasLength(1));
    });

    test('RG-F2.3-3: Failed uploads remain retryable with backoff preserved in manifest', () async {
      final tempDir = Directory.systemTemp.createTempSync('aetron_rg_f2_retry_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final journal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
      );

      const sessionId = 'session-retry-test';
      const user = 'user-retry-123';

      final p = LocalGPSPoint()
        ..sessionId = sessionId
        ..timestamp = DateTime.utc(2026, 10, 20, 12, 0, 0)
        ..latitude = 10.770
        ..longitude = 106.670
        ..accuracy = 5.0
        ..confidence = 'high';

      await journal.appendPoint(p, userId: user);
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // Record a failed upload attempt
      final beforeFail = DateTime.now().toUtc();
      await journal.recordRetryAttempt(
        sessionId,
        success: false,
        nextBackoff: const Duration(minutes: 5),
      );

      final manifest = await journal.readManifest(sessionId);
      expect(manifest, isNotNull);
      expect(manifest!.retryCount, 1);
      expect(manifest.lastRetryTimestampUtc, isNotNull);
      expect(manifest.nextRetryTimestampUtc, isNotNull);
      expect(
        manifest.nextRetryTimestampUtc!.isAfter(beforeFail.add(const Duration(minutes: 4))),
        isTrue,
      );

      // Subsequent readJournal still preserves the data and marks it intact
      final readResult = await journal.readJournal(sessionId, activeUserId: user);
      expect(readResult.status, RawGpsRecoveryStatus.verifiedIntact);
      expect(readResult.points, hasLength(1));
    });

    test('RG-F2.3-4: Recovery journal integrity protection detects file tampering', () async {
      final tempDir = Directory.systemTemp.createTempSync('aetron_rg_f2_integrity_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final journal = RawGpsRecoveryJournal(
        documentsDirectory: () async => tempDir,
      );

      const sessionId = 'session-tamper-test';
      const user = 'user-tamper-123';

      final p1 = LocalGPSPoint()
        ..sessionId = sessionId
        ..timestamp = DateTime.utc(2026, 10, 20, 12, 0, 0)
        ..latitude = 10.770
        ..longitude = 106.670
        ..accuracy = 5.0
        ..confidence = 'high';

      final p2 = LocalGPSPoint()
        ..sessionId = sessionId
        ..timestamp = DateTime.utc(2026, 10, 20, 12, 0, 1)
        ..latitude = 10.771
        ..longitude = 106.671
        ..accuracy = 5.0
        ..confidence = 'high';

      await journal.appendPoint(p1, userId: user);
      await journal.appendPoint(p2, userId: user);
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // Tamper with coordinates in the journal file without manifest update
      final file = await journal.fileForSession(sessionId);
      final content = await file.readAsString();
      expect(content, contains('10.77'));
      final tampered = content.replaceFirst('10.77', '19.99');
      await file.writeAsString(tampered, flush: true);

      final readResult = await journal.readJournal(sessionId, activeUserId: user);
      expect(readResult.status, RawGpsRecoveryStatus.corrupted);
    });

    test('RG-F2.3-5: Unsupported background execution is not represented as guaranteed', () {
      final web = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.web);
      expect(web.supportsBackgroundLocation, isFalse);

      final other = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.other);
      expect(other.supportsBackgroundLocation, isFalse);

      final ios = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.ios);
      expect(ios.supportsBackgroundLocation, isTrue);
      expect(ios.description, contains('AppleSettings background tracking'));

      final android = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.android);
      expect(android.supportsBackgroundLocation, isTrue);
      expect(android.description, contains('foreground notification wakelock'));
    });
  });
}
