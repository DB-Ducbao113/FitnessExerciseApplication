import 'dart:io';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/services/raw_gps_cloud_outbox_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_platform_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock remote data source implementing Postgres/Supabase semantics for RG-F3 scenarios:
/// - Idempotent upsert on (workout_id, timestamp, latitude, longitude)
/// - Paginated read-back with configurable page size
/// - Injectable network failure and partial upload states
class _MockSupabaseRawTrackingSource implements RawTrackingRemoteDataSource {
  final Map<String, List<RawGpsPointPayload>> _storage = {};
  final Set<String> _workoutOwners = {};
  bool isNetworkOnline = true;
  int? dropUploadAfterCount;
  int uploadCalls = 0;

  void registerWorkoutOwner(String workoutId, String userId) {
    _workoutOwners.add('$workoutId:$userId');
  }

  bool isOwner(String workoutId, String userId) {
    return _workoutOwners.contains('$workoutId:$userId');
  }

  List<RawGpsPointPayload> getRows(String workoutId) {
    return List.unmodifiable(_storage[workoutId] ?? []);
  }

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) async {
    uploadCalls++;
    if (!isNetworkOnline) {
      throw const SocketException('Network offline / unreachable');
    }

    for (final p in points) {
      if (dropUploadAfterCount != null && dropUploadAfterCount! <= 0) {
        throw const SocketException('Connection reset during batch upload');
      }
      final list = _storage.putIfAbsent(p.workoutId, () => []);
      // Idempotent constraint: unique on (workout_id, timestamp, lat, lng)
      final exists = list.any(
        (e) =>
            e.workoutId == p.workoutId &&
            e.timestamp.toUtc().microsecondsSinceEpoch ==
                p.timestamp.toUtc().microsecondsSinceEpoch &&
            e.latitude == p.latitude &&
            e.longitude == p.longitude,
      );
      if (!exists) {
        list.add(p);
      }
      if (dropUploadAfterCount != null) {
        dropUploadAfterCount = dropUploadAfterCount! - 1;
      }
    }
  }

  @override
  Future<List<RawGpsPointPayload>> fetchRawGpsPointsPaged(
    String workoutId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    if (!isNetworkOnline) {
      throw const SocketException('Network offline / unreachable');
    }
    final list = _storage[workoutId] ?? [];
    // Ordered deterministically by timestamp asc, lat asc, lng asc
    final sorted = List<RawGpsPointPayload>.from(list)
      ..sort((a, b) {
        final cmpTime = a.timestamp.compareTo(b.timestamp);
        if (cmpTime != 0) return cmpTime;
        final cmpLat = a.latitude.compareTo(b.latitude);
        if (cmpLat != 0) return cmpLat;
        return a.longitude.compareTo(b.longitude);
      });

    if (offset >= sorted.length) return [];
    final end = (offset + limit < sorted.length) ? offset + limit : sorted.length;
    return sorted.sublist(offset, end);
  }

  @override
  Future<List<RawGpsPointPayload>> fetchAllRawGpsPoints(
    String workoutId, {
    int pageSize = 1000,
  }) async {
    final results = <RawGpsPointPayload>[];
    int offset = 0;
    while (true) {
      final page = await fetchRawGpsPointsPaged(
        workoutId,
        offset: offset,
        limit: pageSize,
      );
      results.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }
    return results;
  }

  @override
  Future<int> countRawGpsPointsForWorkout(String workoutId) async {
    if (!isNetworkOnline) {
      throw const SocketException('Network offline / unreachable');
    }
    return _storage[workoutId]?.length ?? 0;
  }

  @override
  Future<void> saveRawStepIntervals(List<RawStepIntervalPayload> intervals) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late RawGpsRecoveryJournal journal;
  late _MockSupabaseRawTrackingSource remoteSource;
  const testUserId = '00000000-0000-4000-8000-000000000001';
  const otherUserId = '00000000-0000-4000-8000-000000000002';
  const testSessionId = '11111111-1111-4111-8111-111111111111';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aetron-rgf3-scenario-');
    journal = RawGpsRecoveryJournal(documentsDirectory: () async => tempDir);
    remoteSource = _MockSupabaseRawTrackingSource();
    remoteSource.registerWorkoutOwner(testSessionId, testUserId);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  LocalGPSPoint makePoint({
    required String sessionId,
    required int index,
    DateTime? startTime,
    double lat = 10.7769,
    double lng = 106.7009,
    double alt = 12.5,
    double speed = 2.8,
    double acc = 3.5,
    double heading = 180.0,
    String source = 'gps',
    String confidence = 'high',
    bool isSynced = false,
  }) {
    final t0 = startTime ?? DateTime.utc(2026, 10, 21, 6, 0, 0);
    return LocalGPSPoint()
      ..id = index + 1
      ..sessionId = sessionId
      ..timestamp = t0.add(Duration(seconds: index))
      ..latitude = lat + (index * 0.00005)
      ..longitude = lng + (index * 0.00005)
      ..altitude = alt
      ..speed = speed
      ..accuracy = acc
      ..heading = heading
      ..deviceSource = source
      ..confidence = confidence
      ..isSynced = isSynced;
  }

  group('AETRON RG-F3 Real-Device Scenario Invariants Matrix', () {
    test('RG-F3-01: Record GPS outdoors in foreground and complete workout with verified canonical digest', () async {
      final points = List.generate(60, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      final synced = <int>{};
      final outbox = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => points.where((p) => !synced.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => points,
        markPointsSynced: (ids) async => synced.addAll(ids),
      );

      final report = await outbox.uploadAndVerifySession(testSessionId);
      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(report.isVerified, isTrue);
      expect(report.localCount, 60);
      expect(report.cloudCount, 60);
      expect(report.missingCloudSampleCount, 0);
      expect(report.mismatchedSampleCount, 0);
      expect(report.cloudDigest, report.localDigest);
      expect(synced.length, 60);

      // Verify manifest integrity
      final manifest = await journal.readManifest(testSessionId);
      expect(manifest!.cloudVerified, isTrue);
      expect(manifest.cloudVerifiedSha256, report.cloudDigest);
    });

    test('RG-F3-02: Disable network access during recording, reconnect and recover pending uploads', () async {
      final points = List.generate(30, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      // Simulate network offline
      remoteSource.isNetworkOnline = false;

      final synced = <int>{};
      final outbox = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => points.where((p) => !synced.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => points,
        markPointsSynced: (ids) async => synced.addAll(ids),
      );

      final offlineReport = await outbox.uploadAndVerifySession(testSessionId);
      expect(offlineReport.state, RawGpsVerificationState.pendingUpload);
      expect(offlineReport.isVerified, isFalse);
      expect(synced, isEmpty, reason: 'No points marked synced when offline');

      // Reconnect network
      remoteSource.isNetworkOnline = true;
      final onlineReport = await outbox.uploadAndVerifySession(testSessionId);
      expect(onlineReport.state, RawGpsVerificationState.cloudVerified);
      expect(onlineReport.cloudCount, 30);
      expect(synced.length, 30);
    });

    test('RG-F3-03: Terminate and restart application after locally persisted data', () async {
      final points = List.generate(20, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      // Simulate process termination: recreate journal and outbox instances
      final restartedJournal = RawGpsRecoveryJournal(documentsDirectory: () async => tempDir);
      final synced = <int>{};
      final restartedOutbox = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: restartedJournal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => points.where((p) => !synced.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => points,
        markPointsSynced: (ids) async => synced.addAll(ids),
      );

      final pendingSessions = await restartedJournal.listPendingSessionIdsForUser(
        testUserId,
        ownedSessionIds: {testSessionId},
      );
      expect(pendingSessions, contains(testSessionId));

      final report = await restartedOutbox.uploadAndVerifySession(testSessionId);
      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(report.cloudCount, 20);
    });

    test('RG-F3-04: Background recording contract and capability descriptor enforcement', () {
      final currentCap = RawGpsPlatformCapability.current;
      expect(currentCap.backgroundExecutionContract, isNotEmpty);
      expect(currentCap.backgroundExecutionContract, contains('platform-dependent'));
      expect(currentCap.backgroundExecutionContract, contains('is NOT guaranteed if the app is swiped away'));
    });

    test('RG-F3-05: Supabase pagination/read-back with full canonical digest verification across multi-page batches', () async {
      // 1,200 points with batch size 250 -> 5 batches
      const count = 1200;
      final points = List.generate(count, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      final synced = <int>{};
      final outbox = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: journal,
        currentUserId: () => testUserId,
        chunkSize: 250,
        getUnsyncedPoints: (s) async => points.where((p) => !synced.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => points,
        markPointsSynced: (ids) async => synced.addAll(ids),
      );

      final report = await outbox.uploadAndVerifySession(testSessionId);
      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(report.cloudCount, count);
      expect(report.localCount, count);
      expect(report.cloudDigest, report.localDigest);

      // Verify read-back paginated rows match exact count
      final readBackRows = await remoteSource.fetchAllRawGpsPoints(testSessionId, pageSize: 300);
      expect(readBackRows.length, count);
    });

    test('RG-F3-06: Simulate partial cloud upload and retry without duplicate or missing GPS points', () async {
      const count = 50;
      final points = List.generate(count, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      // Drop connection after 25 points
      remoteSource.dropUploadAfterCount = 25;

      final synced = <int>{};
      final outbox = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: journal,
        currentUserId: () => testUserId,
        chunkSize: 10,
        getUnsyncedPoints: (s) async => points.where((p) => !synced.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => points,
        markPointsSynced: (ids) async => synced.addAll(ids),
      );

      final failedReport = await outbox.uploadAndVerifySession(testSessionId);
      expect(failedReport.isVerified, isFalse);

      // Re-enable and retry
      remoteSource.dropUploadAfterCount = null;
      final retryReport = await outbox.uploadAndVerifySession(testSessionId);
      expect(retryReport.state, RawGpsVerificationState.cloudVerified);
      expect(retryReport.cloudCount, count);
      expect(retryReport.missingCloudSampleCount, 0);
      expect(synced.length, count);

      // Ensure no duplicates exist in storage
      final storedPoints = remoteSource.getRows(testSessionId);
      expect(storedPoints.length, count);
    });

    test('RG-F3-07: Logout/account switch with pending uploads rejects unauthorized replay or ACK', () async {
      final points = List.generate(15, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      // User B checks pending sessions in journal
      final userBPending = await journal.listPendingSessionIdsForUser(
        otherUserId,
        ownedSessionIds: {},
      );
      expect(userBPending, isNot(contains(testSessionId)), reason: 'User B must not see User A session');

      // Outbox resumePendingUploads for User B processes 0 sessions
      final outboxUserB = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: journal,
        currentUserId: () => otherUserId,
        getOwnedSessionIds: (u) async => [],
        getPendingGpsSessionIds: (u) async => [],
        ownershipVerifier: (s, u) async => remoteSource.isOwner(s, u),
      );

      final processed = await outboxUserB.resumePendingUploads();
      expect(processed, 0, reason: 'Zero sessions uploaded under User B');
      expect(remoteSource.getRows(testSessionId), isEmpty);
    });

    test('RG-F3-08: Validate recovery using retained journal records when local workout metadata is unavailable', () async {
      final points = List.generate(25, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      // LocalDB has NO record of this workout (ownedSessionIds is empty)
      final pending = await journal.listPendingSessionIdsForUser(testUserId, ownedSessionIds: {});
      expect(pending, contains(testSessionId), reason: 'Orphan journal session matching manifest.userId must be discovered');

      final outbox = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => [], // Isar has 0 points
        getAllLocalPoints: (s) async => [],
        markPointsSynced: (ids) async {},
      );

      final report = await outbox.uploadAndVerifySession(testSessionId);
      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(report.cloudCount, 25);
    });

    test('RG-F3-09: Validate explicit-deletion safeguards and record retention', () async {
      final points = List.generate(10, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      // Outbox with pending deletion guard
      final outbox = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => points,
        getAllLocalPoints: (s) async => points,
        markPointsSynced: (ids) async {},
        isSessionPendingDeletion: (s, u) async => s == testSessionId,
      );

      // Running resumePendingUploads excludes session
      final processed = await outbox.resumePendingUploads();
      expect(processed, 0, reason: 'Pending deletion session must not be processed');

      // Journal file must remain retained
      final file = await journal.fileForSession(testSessionId);
      expect(await file.exists(), isTrue);
    });

    test('RG-F3-10: Validate app restart, network recovery and outbox rediscovery without data loss', () async {
      final points = List.generate(40, (i) => makePoint(sessionId: testSessionId, index: i));
      for (final p in points) {
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testSessionId);
      await journal.checkpoint(testSessionId, isFinalized: true);

      // 1. App killed while offline
      remoteSource.isNetworkOnline = false;

      // 2. Restart app while still offline
      final freshJournal = RawGpsRecoveryJournal(documentsDirectory: () async => tempDir);
      final synced = <int>{};
      final freshOutbox = RawGpsCloudOutboxService(
        rawTracking: remoteSource,
        journal: freshJournal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => points.where((p) => !synced.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => points,
        markPointsSynced: (ids) async => synced.addAll(ids),
      );

      final discoveredOffline = await freshJournal.listPendingSessionIdsForUser(
        testUserId,
        ownedSessionIds: {testSessionId},
      );
      expect(discoveredOffline, contains(testSessionId));

      final attemptOffline = await freshOutbox.uploadAndVerifySession(testSessionId);
      expect(attemptOffline.state, RawGpsVerificationState.pendingUpload);
      expect(attemptOffline.isVerified, isFalse);
      expect(synced, isEmpty);

      // 3. Network comes back online -> auto retry
      remoteSource.isNetworkOnline = true;
      final recoveredReport = await freshOutbox.uploadAndVerifySession(testSessionId);
      expect(recoveredReport.state, RawGpsVerificationState.cloudVerified);
      expect(recoveredReport.cloudCount, 40);
      expect(synced.length, 40);
    });
  });
}
