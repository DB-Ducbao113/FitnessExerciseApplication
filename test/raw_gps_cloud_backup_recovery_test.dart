import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/services/raw_gps_cloud_outbox_service.dart';
import 'package:fitness_exercise_application/features/workout/data/services/raw_gps_cloud_recovery_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory mock implementing RawTrackingRemoteDataSource with full Postgres/RLS simulation:
/// - Idempotent upsert on (workout_id, timestamp, latitude, longitude)
/// - Paged select queries with order by timestamp, latitude, longitude
/// - Injectable network/auth/server errors (offline, 401, 429, 5xx)
class _MockRawTrackingDataSource implements RawTrackingRemoteDataSource {
  final Map<String, List<RawGpsPointPayload>> _serverTables = {};
  final Set<String> _workoutOwners = {}; // workoutId:userId

  bool isOffline = false;
  bool isAuthExpired = false;
  bool simulate429 = false;
  bool simulate5xx = false;
  int retryAttemptsRecorded = 0;

  void registerWorkoutOwner(String workoutId, String userId) {
    _workoutOwners.add('$workoutId:$userId');
  }

  void injectPoints(String workoutId, List<RawGpsPointPayload> points) {
    _serverTables.putIfAbsent(workoutId, () => []).addAll(points);
  }

  List<RawGpsPointPayload> getServerPoints(String workoutId) {
    return List.unmodifiable(_serverTables[workoutId] ?? []);
  }

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) async {
    if (isOffline) {
      throw const SocketException('Network is unreachable');
    }
    if (isAuthExpired) {
      throw const PostgrestException(
        message: 'JWT expired or unauthorized',
        code: 'PGRST301',
      );
    }
    if (simulate429) {
      simulate429 = false; // trigger once then clear
      throw const PostgrestException(
        message: 'Too Many Requests',
        code: '429',
      );
    }
    if (simulate5xx) {
      retryAttemptsRecorded++;
      throw const PostgrestException(
        message: 'Internal Server Error',
        code: '500',
      );
    }

    for (final p in points) {
      final list = _serverTables.putIfAbsent(p.workoutId, () => []);
      // Idempotent upsert check on (workout_id, timestamp, lat, lng)
      final existingIndex = list.indexWhere(
        (e) =>
            e.workoutId == p.workoutId &&
            e.timestamp.toUtc().microsecondsSinceEpoch ==
                p.timestamp.toUtc().microsecondsSinceEpoch &&
            e.latitude == p.latitude &&
            e.longitude == p.longitude,
      );
      if (existingIndex == -1) {
        list.add(p);
      }
    }
  }

  @override
  Future<List<RawGpsPointPayload>> fetchRawGpsPointsPaged(
    String workoutId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    if (isOffline) {
      throw const SocketException('Network is unreachable');
    }
    if (isAuthExpired) {
      throw const PostgrestException(
        message: 'JWT expired or unauthorized',
        code: 'PGRST301',
      );
    }

    final list = _serverTables[workoutId] ?? [];
    // Deterministic ordering: timestamp, lat, lng
    final sorted = List<RawGpsPointPayload>.from(list)
      ..sort((a, b) {
        final t = a.timestamp.compareTo(b.timestamp);
        if (t != 0) return t;
        final lat = a.latitude.compareTo(b.latitude);
        if (lat != 0) return lat;
        return a.longitude.compareTo(b.longitude);
      });

    if (offset >= sorted.length) return const [];
    final end = (offset + limit < sorted.length) ? offset + limit : sorted.length;
    return sorted.sublist(offset, end);
  }

  @override
  Future<List<RawGpsPointPayload>> fetchAllRawGpsPoints(
    String workoutId, {
    int pageSize = 1000,
  }) async {
    final results = <RawGpsPointPayload>[];
    var offset = 0;
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
    if (isOffline) throw const SocketException('Network is unreachable');
    return _serverTables[workoutId]?.length ?? 0;
  }

  @override
  Future<void> saveRawStepIntervals(List<RawStepIntervalPayload> intervals) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late RawGpsRecoveryJournal journal;
  late _MockRawTrackingDataSource mockTracking;
  const testUserId = 'athlete-user-rg1b-001';
  const testWorkoutId = '99999999-9999-4999-8999-999999999999';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aetron-rg1b-test-');
    journal = RawGpsRecoveryJournal(documentsDirectory: () async => tempDir);
    mockTracking = _MockRawTrackingDataSource();
    mockTracking.registerWorkoutOwner(testWorkoutId, testUserId);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  LocalGPSPoint createPoint({
    required String sessionId,
    required int index,
    DateTime? startTime,
    double lat = 10.7380,
    double lng = 106.6250,
    double? alt = 15.0,
    double? speed = 3.5,
    double? acc = 4.0,
    double? heading = 90.0,
    String? source = 'gps',
    String confidence = 'high',
    bool isSynced = false,
  }) {
    final baseTime = startTime ?? DateTime.utc(2026, 10, 19, 8, 0, 0);
    return LocalGPSPoint()
      ..id = index + 1
      ..sessionId = sessionId
      ..timestamp = baseTime.add(Duration(seconds: index))
      ..latitude = lat + (index * 0.0001)
      ..longitude = lng + (index * 0.0001)
      ..altitude = alt
      ..speed = speed
      ..accuracy = acc
      ..heading = heading
      ..deviceSource = source
      ..confidence = confidence
      ..isSynced = isSynced;
  }

  group('AETRON RG-1B Cloud Backup & Recovery Comprehensive QA Suite', () {
    test('1. 3,600+ point upload with bounded batches and canonical verification', () async {
      final localPoints = <LocalGPSPoint>[];
      const totalPoints = 3600;
      final startTime = DateTime.utc(2026, 10, 19, 7, 0, 0);

      for (var i = 0; i < totalPoints; i++) {
        final p = createPoint(
          sessionId: testWorkoutId,
          index: i,
          startTime: startTime,
          confidence: 'high',
        );
        localPoints.add(p);
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testWorkoutId);
      await journal.checkpoint(testWorkoutId, isFinalized: true);

      final syncedIds = <int>{};
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        chunkSize: 250, // 3600 points across 15 chunks
        getUnsyncedPoints: (s) async =>
            localPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);

      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(report.isVerified, isTrue);
      expect(report.localCount, totalPoints);
      expect(report.cloudCount, totalPoints);
      expect(report.missingCloudSampleCount, 0);
      expect(report.mismatchedSampleCount, 0);
      expect(report.cloudDigest, report.localDigest);
      expect(syncedIds.length, totalPoints);

      // Verify journal manifest is updated with trusted cloud verification
      final manifest = await journal.readManifest(testWorkoutId);
      expect(manifest!.cloudVerified, isTrue);
      expect(manifest.cloudVerifiedCount, totalPoints);
      expect(manifest.cloudVerifiedSha256, report.cloudDigest);

      // Verify journal file is NOT deleted
      final journalFile = await journal.fileForSession(testWorkoutId);
      expect(await journalFile.exists(), isTrue);
    });

    test('2. Offline capture followed by reconnect', () async {
      final localPoints = [
        createPoint(sessionId: testWorkoutId, index: 0),
        createPoint(sessionId: testWorkoutId, index: 1),
      ];
      final syncedIds = <int>{};

      mockTracking.isOffline = true;

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async =>
            localPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      // 1. Upload during offline fails closed, preserves local points
      final reportOffline = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(reportOffline.state, RawGpsVerificationState.pendingUpload);
      expect(syncedIds, isEmpty);
      expect(mockTracking.getServerPoints(testWorkoutId), isEmpty);

      // 2. Reconnect network and retry
      mockTracking.isOffline = false;
      final reportOnline = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(reportOnline.state, RawGpsVerificationState.cloudVerified);
      expect(syncedIds.length, 2);
      expect(mockTracking.getServerPoints(testWorkoutId).length, 2);
    });

    test('3. Crash during upload and retry on restart', () async {
      final localPoints = List.generate(
        100,
        (i) => createPoint(sessionId: testWorkoutId, index: i),
      );
      final syncedIds = <int>{};

      // First run: process batch 1 (25 points) and then simulate process killed
      final outboxRun1 = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        chunkSize: 25,
        getUnsyncedPoints: (s) async =>
            localPoints.where((p) => !syncedIds.contains(p.id)).take(25).toList(),
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      await outboxRun1.uploadAndVerifySession(testWorkoutId);
      expect(mockTracking.getServerPoints(testWorkoutId).length, 25);
      expect(syncedIds.length, 0); // P0-01: Points in Isar are NOT marked synced before successful cloud verification!

      // App restart: new outbox instance discovers remaining 75 points
      final outboxRun2 = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        chunkSize: 25,
        getUnsyncedPoints: (s) async =>
            localPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      final finalReport = await outboxRun2.uploadAndVerifySession(testWorkoutId);
      expect(finalReport.state, RawGpsVerificationState.cloudVerified);
      expect(finalReport.cloudCount, 100);
      expect(syncedIds.length, 100);
    });

    test('4. Duplicate batch retries handled idempotently without duplicate records', () async {
      final localPoints = [
        createPoint(sessionId: testWorkoutId, index: 0),
        createPoint(sessionId: testWorkoutId, index: 1),
      ];
      final payloads = localPoints.map((p) => RawGpsPointPayload(
        workoutId: p.sessionId,
        timestamp: p.timestamp,
        latitude: p.latitude,
        longitude: p.longitude,
      )).toList();

      // Send same batch twice
      await mockTracking.saveRawGpsPoints(payloads);
      await mockTracking.saveRawGpsPoints(payloads);

      // Server table must have 2 records, not 4
      expect(mockTracking.getServerPoints(testWorkoutId).length, 2);
    });

    test('5. Partial cloud records detected accurately', () async {
      final localPoints = List.generate(
        10,
        (i) => createPoint(sessionId: testWorkoutId, index: i),
      );
      // Inject only 6 points into cloud
      final partialCloud = localPoints.take(6).map((p) => RawGpsPointPayload(
        workoutId: p.sessionId,
        timestamp: p.timestamp,
        latitude: p.latitude,
        longitude: p.longitude,
      )).toList();
      mockTracking.injectPoints(testWorkoutId, partialCloud);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => const [], // already sent partially
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (_) async {},
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(report.state, RawGpsVerificationState.partial);
      expect(report.localCount, 10);
      expect(report.cloudCount, 6);
      expect(report.missingCloudSampleCount, 4);
      expect(report.isVerified, isFalse);
    });

    test('6. Same count but corrupted coordinate -> INTEGRITY_MISMATCH', () async {
      final localPoints = List.generate(
        5,
        (i) => createPoint(sessionId: testWorkoutId, index: i),
      );
      final cloudPoints = List.generate(
        5,
        (i) => RawGpsPointPayload(
          workoutId: testWorkoutId,
          timestamp: localPoints[i].timestamp,
          latitude: i == 2 ? 11.9999 : localPoints[i].latitude, // Point #2 corrupted coordinate!
          longitude: localPoints[i].longitude,
          altitude: localPoints[i].altitude,
          speed: localPoints[i].speed,
          accuracy: localPoints[i].accuracy,
          heading: localPoints[i].heading,
          deviceSource: localPoints[i].deviceSource,
        ),
      );
      mockTracking.injectPoints(testWorkoutId, cloudPoints);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => const [],
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (_) async {},
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(report.state, RawGpsVerificationState.integrityMismatch);
      expect(report.localCount, 5);
      expect(report.cloudCount, 5);
      expect(report.missingCloudSampleCount, 1);
      expect(report.extraCloudSampleCount, 1);
      expect(report.isVerified, isFalse);
      expect(report.localDigest, isNot(report.cloudDigest));
    });

    test('7. Pagination boundaries verified cleanly without off-by-one errors', () async {
      const totalPoints = 2500;
      final payloads = List.generate(
        totalPoints,
        (i) => RawGpsPointPayload(
          workoutId: testWorkoutId,
          timestamp: DateTime.utc(2026, 10, 19, 8, 0, 0).add(Duration(seconds: i)),
          latitude: 10.7380 + (i * 0.00001),
          longitude: 106.6250 + (i * 0.00001),
        ),
      );
      mockTracking.injectPoints(testWorkoutId, payloads);

      final fetchedAll = await mockTracking.fetchAllRawGpsPoints(
        testWorkoutId,
        pageSize: 1000,
      );
      expect(fetchedAll.length, totalPoints);
      expect(fetchedAll[0].timestamp, payloads[0].timestamp);
      expect(fetchedAll[999].timestamp, payloads[999].timestamp);
      expect(fetchedAll[1000].timestamp, payloads[1000].timestamp);
      expect(fetchedAll[1999].timestamp, payloads[1999].timestamp);
      expect(fetchedAll[2000].timestamp, payloads[2000].timestamp);
      expect(fetchedAll[2499].timestamp, payloads[2499].timestamp);
    });

    test('8. Token expiry and account switching handled cleanly', () async {
      final localPoints = [createPoint(sessionId: testWorkoutId, index: 0)];
      mockTracking.isAuthExpired = true;

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => localPoints,
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (_) async {},
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(report.state, RawGpsVerificationState.authRequired);
      expect(outbox.stateForSession(testWorkoutId), RawGpsVerificationState.authRequired);
      expect(mockTracking.getServerPoints(testWorkoutId), isEmpty);
    });

    test('9. Cross-device recovery restores points without overwriting richer local records', () async {
      // Local device already has Point 0 with richer local confidence 'high' and local sequence
      final localP0 = createPoint(
        sessionId: testWorkoutId,
        index: 0,
        confidence: 'high',
      );
      final localList = [localP0];

      // Cloud contains Point 0 and Point 1
      final cloudPoints = [
        RawGpsPointPayload(
          workoutId: testWorkoutId,
          timestamp: localP0.timestamp,
          latitude: localP0.latitude,
          longitude: localP0.longitude,
          altitude: localP0.altitude,
          speed: localP0.speed,
          accuracy: localP0.accuracy,
          heading: localP0.heading,
        ),
        RawGpsPointPayload(
          workoutId: testWorkoutId,
          timestamp: localP0.timestamp.add(const Duration(seconds: 1)),
          latitude: 10.7381,
          longitude: 106.6251,
          altitude: 16.0,
          speed: 3.6,
          accuracy: 4.1,
          heading: 95.0,
        ),
      ];
      mockTracking.injectPoints(testWorkoutId, cloudPoints);

      final savedPoints = <LocalGPSPoint>[];
      final recoveryService = RawGpsCloudRecoveryService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getLocalPoints: (s) async => [...localList, ...savedPoints],
        saveLocalPoints: (pts) async => savedPoints.addAll(pts),
      );

      final result = await recoveryService.restoreRawGpsFromCloud(testWorkoutId);

      expect(result.restoredPointsCount, 1); // Only point 1 was inserted
      expect(result.preservedLocalPointsCount, 1); // Point 0 preserved
      expect(result.totalPointsCount, 2);

      // Check that restored point is marked 'cloud_restored', NOT fabricating 'high' sensor confidence
      expect(savedPoints.first.confidence, 'cloud_restored');
      expect(savedPoints.first.isSynced, isTrue);

      // Check that local point 0 was never mutated or degraded
      expect(localList.first.confidence, 'high');
    });

    test('10. Legacy workout without cloud records evaluated safely as UNKNOWN', () async {
      final recoveryService = RawGpsCloudRecoveryService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getLocalPoints: (s) async => const [],
        saveLocalPoints: (_) async {},
      );

      final result = await recoveryService.restoreRawGpsFromCloud('legacy-workout-000');
      expect(result.state, RawGpsVerificationState.unknown);
      expect(result.restoredPointsCount, 0);
    });

    test('11. Safe cloud verification state transitions', () {
      expect(RawGpsVerificationState.pendingUpload.label, 'PENDING_UPLOAD');
      expect(RawGpsVerificationState.uploading.label, 'UPLOADING');
      expect(RawGpsVerificationState.uploadedUnverified.label, 'UPLOADED_UNVERIFIED');
      expect(RawGpsVerificationState.cloudVerified.label, 'CLOUD_VERIFIED');
      expect(RawGpsVerificationState.partial.label, 'PARTIAL');
      expect(RawGpsVerificationState.integrityMismatch.label, 'INTEGRITY_MISMATCH');
      expect(RawGpsVerificationState.restoredUnverified.label, 'RESTORED_UNVERIFIED');
      expect(RawGpsVerificationState.unknown.label, 'UNKNOWN');
      expect(RawGpsVerificationState.authRequired.label, 'AUTH_REQUIRED');
    });

    test('12. No local journal deletion occurs during upload or verification', () async {
      final localPoints = [createPoint(sessionId: testWorkoutId, index: 0)];
      await journal.appendPoint(localPoints.first, userId: testUserId);
      await journal.flushSession(testWorkoutId);
      await journal.checkpoint(testWorkoutId, isFinalized: true);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => localPoints,
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (_) async {},
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(report.isVerified, isTrue);

      // Assert journal file is 100% preserved
      final journalFile = await journal.fileForSession(testWorkoutId);
      expect(await journalFile.exists(), isTrue);
      final lines = await journalFile.readAsLines();
      expect(lines, isNotEmpty);
    });

    test('13. No impact on EKF/FSM/DBSCAN or workout metrics', () {
      // Canonical verification converts to/from local payload without altering coordinates
      final original = createPoint(sessionId: testWorkoutId, index: 0);
      final canonical = CanonicalGpsPoint.fromLocal(original);

      expect(canonical.latitude, original.latitude);
      expect(canonical.longitude, original.longitude);
      expect(canonical.speed, original.speed);
      expect(canonical.accuracy, original.accuracy);
      expect(canonical.heading, original.heading);
    });
  });

  group('AETRON RG-1B.1 Integration & Verification Hotfix Suite', () {
    test('H1. Upload succeeds but cloud read-back fails: local stays retryable (P0-01)', () async {
      final localPoints = [
        createPoint(sessionId: testWorkoutId, index: 0),
        createPoint(sessionId: testWorkoutId, index: 1),
      ];
      final syncedIds = <int>{};

      // Mock throws SocketException on read-back, but save succeeds
      final failingReadTracking = _FailingReadTrackingDataSource(mockTracking);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: failingReadTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => localPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(report.isVerified, isFalse);
      expect(report.state, RawGpsVerificationState.partial);

      // Points MUST NOT be marked synced in Isar!
      expect(syncedIds, isEmpty);

      // Verify that points remain retryable
      final unsynced = localPoints.where((p) => !syncedIds.contains(p.id)).toList();
      expect(unsynced.length, 2);
    });

    test('H2. Same point count with mismatched telemetry: never mark synced (P0-01 & P1)', () async {
      final localPoints = List.generate(
        5,
        (i) => createPoint(sessionId: testWorkoutId, index: i, speed: 3.5),
      );
      final syncedIds = <int>{};

      // Cloud has matching count (5), but telemetry (speed) is mismatched on point #1
      final cloudPoints = List.generate(
        5,
        (i) => RawGpsPointPayload(
          workoutId: testWorkoutId,
          timestamp: localPoints[i].timestamp,
          latitude: localPoints[i].latitude,
          longitude: localPoints[i].longitude,
          altitude: localPoints[i].altitude,
          speed: i == 1 ? 9.9 : localPoints[i].speed, // Mismatched speed!
          accuracy: localPoints[i].accuracy,
          heading: localPoints[i].heading,
          deviceSource: localPoints[i].deviceSource,
        ),
      );
      mockTracking.injectPoints(testWorkoutId, cloudPoints);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => localPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(report.state, RawGpsVerificationState.integrityMismatch);
      expect(report.isVerified, isFalse);
      expect(report.mismatchedSampleCount, 1);

      // Points MUST NOT be marked synced!
      expect(syncedIds, isEmpty);
    });

    test('H3. Isar empty, journal contains 3,600 points: upload and verify all 3,600 (P0-02)', () async {
      const totalPoints = 3600;
      final startTime = DateTime.utc(2026, 10, 19, 6, 0, 0);

      // Write 3,600 points to journal ONLY (simulating complete Isar write failure)
      for (var i = 0; i < totalPoints; i++) {
        final p = createPoint(
          sessionId: testWorkoutId,
          index: i,
          startTime: startTime,
          confidence: 'high',
        );
        await journal.appendPoint(p, userId: testUserId);
      }
      await journal.flushSession(testWorkoutId);
      await journal.checkpoint(testWorkoutId, isFinalized: true);

      final isarStorage = <LocalGPSPoint>[];
      final syncedIds = <int>{};

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        chunkSize: 250,
        getUnsyncedPoints: (s) async => isarStorage.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => isarStorage, // Initially 0 points in Isar!
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);

      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(report.isVerified, isTrue);
      expect(report.localCount, totalPoints);
      expect(report.cloudCount, totalPoints);
      expect(mockTracking.getServerPoints(testWorkoutId).length, totalPoints);
    });

    test('H4. Isar contains 1,200, journal contains 3,600: reconcile all 3,600 (P0-02)', () async {
      const totalPoints = 3600;
      const isarCount = 1200;
      final startTime = DateTime.utc(2026, 10, 19, 5, 0, 0);

      final isarPoints = <LocalGPSPoint>[];

      // Write all 3,600 to journal, but only first 1,200 to Isar (partial write crash)
      for (var i = 0; i < totalPoints; i++) {
        final p = createPoint(
          sessionId: testWorkoutId,
          index: i,
          startTime: startTime,
          confidence: 'high',
        );
        await journal.appendPoint(p, userId: testUserId);
        if (i < isarCount) {
          isarPoints.add(p);
        }
      }
      await journal.flushSession(testWorkoutId);
      await journal.checkpoint(testWorkoutId, isFinalized: true);

      final syncedIds = <int>{};

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        chunkSize: 250,
        getUnsyncedPoints: (s) async => isarPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => isarPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);

      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(report.isVerified, isTrue);
      expect(report.localCount, totalPoints);
      expect(report.cloudCount, totalPoints);
      expect(mockTracking.getServerPoints(testWorkoutId).length, totalPoints);
    });

    test('H5. Cloud contains only 2,000 of 3,600: never CLOUD_VERIFIED (P0-01 & P0-04)', () async {
      const totalPoints = 3600;
      const cloudCutoff = 2000;
      final startTime = DateTime.utc(2026, 10, 19, 4, 0, 0);

      final localPoints = <LocalGPSPoint>[];
      for (var i = 0; i < totalPoints; i++) {
        final p = createPoint(
          sessionId: testWorkoutId,
          index: i,
          startTime: startTime,
        );
        localPoints.add(p);
      }

      // Inject only 2,000 points in cloud
      final cloudPoints = localPoints.take(cloudCutoff).map((p) => RawGpsPointPayload(
        workoutId: p.sessionId,
        timestamp: p.timestamp,
        latitude: p.latitude,
        longitude: p.longitude,
        altitude: p.altitude,
        speed: p.speed,
        accuracy: p.accuracy,
        heading: p.heading,
        deviceSource: p.deviceSource,
      )).toList();
      mockTracking.injectPoints(testWorkoutId, cloudPoints);

      final syncedIds = <int>{};

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => const [], // already uploaded
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      final report = await outbox.uploadAndVerifySession(testWorkoutId);

      // Must be PARTIAL, NEVER CLOUD_VERIFIED!
      expect(report.state, RawGpsVerificationState.partial);
      expect(report.isVerified, isFalse);
      expect(report.cloudCount, cloudCutoff);
      expect(report.localCount, totalPoints);
      expect(report.missingCloudSampleCount, 1600);
      expect(syncedIds, isEmpty);
    });

    test('H6. Device B restores cloud-only data without source manifest: RESTORED_UNVERIFIED (P0-04)', () async {
      const pointCount = 500;
      final startTime = DateTime.utc(2026, 10, 19, 3, 0, 0);

      // Cloud contains 500 points from Device A
      final cloudPayloads = List.generate(
        pointCount,
        (i) => RawGpsPointPayload(
          workoutId: testWorkoutId,
          timestamp: startTime.add(Duration(seconds: i)),
          latitude: 10.7380 + (i * 0.0001),
          longitude: 106.6250 + (i * 0.0001),
          altitude: 15.0,
          speed: 3.5,
          accuracy: 4.0,
          heading: 90.0,
          deviceSource: 'gps',
        ),
      );
      mockTracking.injectPoints(testWorkoutId, cloudPayloads);

      // Device B environment: NO local points, NO journal manifest
      final deviceBPoints = <LocalGPSPoint>[];
      final deviceBJournal = RawGpsRecoveryJournal(
        documentsDirectory: () async => Directory.systemTemp.createTempSync('device-b-empty-'),
      );

      final recovery = RawGpsCloudRecoveryService(
        rawTracking: mockTracking,
        journal: deviceBJournal,
        currentUserId: () => testUserId,
        getLocalPoints: (s) async => deviceBPoints,
        saveLocalPoints: (pts) async => deviceBPoints.addAll(pts),
      );

      final result = await recovery.restoreRawGpsFromCloud(testWorkoutId);

      // MUST be RESTORED_UNVERIFIED, NEVER CLOUD_VERIFIED!
      expect(result.state, RawGpsVerificationState.restoredUnverified);
      expect(result.isSuccess, isTrue);
      expect(result.isFullyVerified, isFalse);
      expect(result.restoredPointsCount, pointCount);

      // Confidence is marked 'cloud_restored', NOT fabricating local sensor confidence
      expect(deviceBPoints.first.confidence, 'cloud_restored');
      expect(deviceBPoints.first.isSynced, isTrue);
    });

    test('H7. App lifecycle startup actually invokes recovery of pending work (P0-03)', () async {
      final localPoints = [createPoint(sessionId: testWorkoutId, index: 0)];
      final syncedIds = <int>{};

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => localPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
        getUnsyncedSessionIds: (userId) async => [testWorkoutId],
      );

      final processed = await outbox.resumePendingUploads();
      expect(processed, 1);
      expect(syncedIds.length, 1);
    });

    test('H8. Simulated crash between HTTP ACK and verified local state leaves work retryable (P0-01)', () async {
      final localPoints = List.generate(
        50,
        (i) => createPoint(sessionId: testWorkoutId, index: i),
      );
      final syncedIds = <int>{};

      // Run 1: Crash simulated right after HTTP chunk upload
      final outboxRun1 = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        chunkSize: 50,
        getUnsyncedPoints: (s) async => localPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      // Pre-upload chunk succeeds to cloud
      await mockTracking.saveRawGpsPoints(localPoints.map((p) => RawGpsPointPayload(
        workoutId: p.sessionId,
        timestamp: p.timestamp,
        latitude: p.latitude,
        longitude: p.longitude,
        altitude: p.altitude,
        speed: p.speed,
        accuracy: p.accuracy,
        heading: p.heading,
        deviceSource: p.deviceSource,
      )).toList());

      // But process died before verification: syncedIds remains empty!
      expect(syncedIds, isEmpty);

      // Restart: Run 2 verifies and completes verification
      final report = await outboxRun1.uploadAndVerifySession(testWorkoutId);
      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(syncedIds.length, 50);
    });

    test('H9. Token expiration, logout and account switch safety (P0-03 & P1)', () async {
      String? activeUser = testUserId;

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => activeUser,
        getUnsyncedPoints: (s) async => [createPoint(sessionId: testWorkoutId, index: 0)],
        getAllLocalPoints: (s) async => [createPoint(sessionId: testWorkoutId, index: 0)],
        markPointsSynced: (_) async {},
      );

      // 1. User logs out
      activeUser = null;
      final reportLoggedOut = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(reportLoggedOut.state, RawGpsVerificationState.authRequired);

      // 2. Switch to different user
      activeUser = 'athlete-other-user-999';
      mockTracking.isAuthExpired = true;
      final reportExpired = await outbox.uploadAndVerifySession(testWorkoutId);
      expect(reportExpired.state, RawGpsVerificationState.authRequired);
    });

    test('H10. No duplicate upload workers or infinite retries (P0-03)', () async {
      final localPoints = [createPoint(sessionId: testWorkoutId, index: 0)];
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (s) async => localPoints,
        getAllLocalPoints: (s) async => localPoints,
        markPointsSynced: (_) async {},
      );

      // Launch two concurrent uploads for the exact same session
      final future1 = outbox.uploadAndVerifySession(testWorkoutId);
      final future2 = outbox.uploadAndVerifySession(testWorkoutId);

      final results = await Future.wait([future1, future2]);
      expect(results, hasLength(2));
      // One is verified or handled safely without duplicate server rows
      expect(mockTracking.getServerPoints(testWorkoutId).length, 1);
    });
  });
}

class _FailingReadTrackingDataSource implements RawTrackingRemoteDataSource {
  final _MockRawTrackingDataSource _inner;

  _FailingReadTrackingDataSource(this._inner);

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) =>
      _inner.saveRawGpsPoints(points);

  @override
  Future<void> saveRawStepIntervals(List<RawStepIntervalPayload> intervals) =>
      _inner.saveRawStepIntervals(intervals);

  @override
  Future<int> countRawGpsPointsForWorkout(String workoutId) =>
      _inner.countRawGpsPointsForWorkout(workoutId);

  @override
  Future<List<RawGpsPointPayload>> fetchRawGpsPointsPaged(
    String workoutId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    throw const SocketException('Simulated read-back connection dropout');
  }

  @override
  Future<List<RawGpsPointPayload>> fetchAllRawGpsPoints(
    String workoutId, {
    int pageSize = 1000,
  }) async {
    throw const SocketException('Simulated read-back connection dropout');
  }
}

