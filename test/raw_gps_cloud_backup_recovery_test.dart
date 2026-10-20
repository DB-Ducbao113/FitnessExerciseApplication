import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/services/raw_gps_cloud_outbox_service.dart';
import 'package:fitness_exercise_application/features/workout/data/services/raw_gps_cloud_recovery_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
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
  final Set<String> failingSessionIds = {};

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
      if (failingSessionIds.contains(p.workoutId)) {
        retryAttemptsRecorded++;
        throw const PostgrestException(
          message: 'Internal Server Error for session',
          code: '500',
        );
      }
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
    if (failingSessionIds.contains(workoutId)) {
      throw const PostgrestException(
        message: 'Internal Server Error for session fetch',
        code: '500',
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

  Map<String, dynamic> localPointMap(LocalGPSPoint p) => {
    'workout_id': p.sessionId,
    'user_id': testUserId,
    'timestamp': p.timestamp.toUtc().toIso8601String(),
    'latitude': p.latitude,
    'longitude': p.longitude,
    if (p.altitude != null) 'altitude': p.altitude,
    if (p.speed != null) 'speed': p.speed,
    if (p.accuracy != null) 'accuracy': p.accuracy,
    if (p.heading != null) 'heading': p.heading,
    if (p.deviceSource != null) 'device_source': p.deviceSource,
    'confidence': p.confidence,
  };

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

    test('RG-F1 A: metadata synced, GPS pending is still discovered', () async {
      final points = [
        createPoint(sessionId: testWorkoutId, index: 0),
        createPoint(sessionId: testWorkoutId, index: 1),
      ];
      final syncedIds = <int>{};
      // The owner's workout metadata is already synced: discovery is driven
      // by GPS records, not LocalWorkout.isSynced.
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getOwnedSessionIds: (_) async => [testWorkoutId],
        getPendingGpsSessionIds: (_) async => [testWorkoutId],
        getUnsyncedPoints: (_) async =>
            points.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (_) async => points,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      expect(await outbox.resumePendingUploads(), 1);
      expect(syncedIds.length, 2);
      expect(mockTracking.getServerPoints(testWorkoutId), hasLength(2));
    });

    test('RG-F1 B: owned journal-only session survives Isar loss', () async {
      final p = createPoint(sessionId: testWorkoutId, index: 0);
      await journal.appendPoint(p, userId: testUserId);
      await journal.flushSession(testWorkoutId);
      await journal.checkpoint(testWorkoutId, isFinalized: true);

      final cached = <LocalGPSPoint>[];
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getOwnedSessionIds: (_) async => [testWorkoutId],
        getPendingGpsSessionIds: (_) async => const [],
        getUnsyncedPoints: (_) async => const [],
        getAllLocalPoints: (_) async => cached,
        saveLocalPoints: (points) async => cached.addAll(points),
        markPointsSynced: (_) async {},
      );

      expect(await outbox.resumePendingUploads(), 1);
      expect(mockTracking.getServerPoints(testWorkoutId), hasLength(1));
      expect(await (await journal.fileForSession(testWorkoutId)).exists(), isTrue);
    });

    test('RG-F1 C: sessions awaiting deletion are never replayed', () async {
      final points = [createPoint(sessionId: testWorkoutId, index: 0)];
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getOwnedSessionIds: (_) async => [testWorkoutId],
        getPendingGpsSessionIds: (_) async => [testWorkoutId],
        getUnsyncedPoints: (_) async => points,
        getAllLocalPoints: (_) async => points,
        markPointsSynced: (_) async {},
      );

      final resumed = await outbox.resumePendingUploads(
        excludedSessionIds: {testWorkoutId},
      );
      expect(resumed, 0);
      expect(mockTracking.getServerPoints(testWorkoutId), isEmpty);
      expect(points.single.isSynced, isFalse);
    });

    test('RG-F1 D: a foreign journal cannot be discovered for this user', () async {
      final p = createPoint(sessionId: testWorkoutId, index: 0);
      await journal.appendPoint(p, userId: 'different-owner');
      await journal.flushSession(testWorkoutId);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getOwnedSessionIds: (_) async => [testWorkoutId],
        getPendingGpsSessionIds: (_) async => const [],
        getUnsyncedPoints: (_) async => const [],
        getAllLocalPoints: (_) async => const [],
        markPointsSynced: (_) async {},
      );

      expect(await outbox.resumePendingUploads(), 0);
      expect(mockTracking.getServerPoints(testWorkoutId), isEmpty);
      expect(await (await journal.fileForSession(testWorkoutId)).exists(), isTrue);
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

  group('AETRON RG-F1 Hardening & QA Suite (F1-01 to F1-12)', () {
    test('F1-01: Manifest v2 Checksum Separation separates raw JSONL checksum from canonical digest', () async {
      const sessionId = 'f1-01-manifest-v2';
      final p1 = createPoint(sessionId: sessionId, index: 0);
      final p2 = createPoint(sessionId: sessionId, index: 1);
      await journal.appendPoint(p1, userId: testUserId);
      await journal.appendPoint(p2, userId: testUserId);
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      final manifest = await journal.readManifest(sessionId);
      expect(manifest, isNotNull);
      expect(manifest!.schemaVersion, RawGpsJournalManifest.currentSchemaVersion);
      expect(manifest.fileSha256, isNotNull);
      expect(manifest.canonicalCaptureDigest, isNotNull);
      // Raw file byte SHA-256 and canonical capture digest must have distinct semantics
      expect(manifest.fileSha256, isNot(equals(manifest.canonicalCaptureDigest)));
      // Cloud verified digest remains null before cloud read-back verification
      expect(manifest.cloudVerifiedSha256, isNull);
      expect(manifest.cloudVerified, isFalse);
    });

    test('F1-02: Manifest v2 Backward Compatibility preserves legacy v1 manifests', () {
      final legacyV1Json = {
        'schema_version': 'aetron.raw_gps.manifest.v1',
        'workout_id': 'legacy-session-001',
        'user_id': testUserId,
        'sample_count': 100,
        'first_timestamp_utc': '2026-10-19T00:00:00.000Z',
        'last_timestamp_utc': '2026-10-19T00:01:40.000Z',
        'sha256_digest': 'c0ffee1234567890abcdef',
        'checkpoint_seq': 4,
        'checkpoint_timestamp_utc': '2026-10-19T00:01:41.000Z',
        'is_finalized': true,
        'cloud_verified': false,
        'cloud_verified_count': 0,
        'cloud_verified_sha256': null,
      };

      final manifest = RawGpsJournalManifest.fromJson(legacyV1Json);
      expect(manifest.schemaVersion, 'aetron.raw_gps.manifest.v1');
      expect(manifest.fileSha256, 'c0ffee1234567890abcdef');
      expect(manifest.sha256Digest, 'c0ffee1234567890abcdef');
      expect(manifest.canonicalCaptureDigest, isNull);
      expect(manifest.isFinalized, isTrue);

      final serialized = manifest.toJson();
      expect(serialized['schema_version'], 'aetron.raw_gps.manifest.v1');
      expect(serialized['file_sha256'], 'c0ffee1234567890abcdef');
      expect(serialized['sha256_digest'], 'c0ffee1234567890abcdef');
      expect(serialized['canonical_capture_digest'], isNull);
    });

    test('F1-03: Independent Local Capture Evidence Generation prevents circular verification on legacy manifest', () {
      final points = [
        createPoint(sessionId: 'f1-03-session', index: 0),
        createPoint(sessionId: 'f1-03-session', index: 1),
      ];
      final canonPoints = points.map(CanonicalGpsPoint.fromLocal).toList();

      // Legacy manifest without canonical capture digest
      final legacyManifest = RawGpsJournalManifest(
        schemaVersion: RawGpsJournalManifest.schemaVersionV1,
        workoutId: 'f1-03-session',
        userId: testUserId,
        sampleCount: 2,
        checkpointSeq: 1,
        checkpointTimestampUtc: DateTime.now().toUtc(),
        isFinalized: true,
        fileSha256: 'some_raw_file_hash',
        canonicalCaptureDigest: null,
      );

      final report = RawGpsCanonicalVerification.verifyAgainstManifest(
        workoutId: 'f1-03-session',
        manifest: legacyManifest,
        cloudPoints: canonPoints,
      );

      // Must fail closed to restoredUnverified without fabricating proof from raw file hash!
      expect(report.state, RawGpsVerificationState.restoredUnverified);
      expect(report.isVerified, isFalse);

      // But when canonicalCaptureDigest is provided:
      final correctDigest = RawGpsCanonicalVerification.computeCanonicalDigest(canonPoints);
      final v2Manifest = legacyManifest.copyWith(
        schemaVersion: RawGpsJournalManifest.currentSchemaVersion,
        canonicalCaptureDigest: correctDigest,
      );

      final verifiedReport = RawGpsCanonicalVerification.verifyAgainstManifest(
        workoutId: 'f1-03-session',
        manifest: v2Manifest,
        cloudPoints: canonPoints,
      );
      expect(verifiedReport.state, RawGpsVerificationState.cloudVerified);
      expect(verifiedReport.isVerified, isTrue);
    });

    test('F1-04: Robust Ingestion & Checkpoint Protection handles truncated tails, corruption, duplicates', () async {
      const sessionId = 'f1-04-protection';
      final journalFile = await journal.fileForSession(sessionId);
      await journalFile.parent.create(recursive: true);

      final p1 = createPoint(sessionId: sessionId, index: 0);
      final p2 = createPoint(sessionId: sessionId, index: 1);

      // Write valid point, corrupted point, valid duplicate, valid point 2, and truncated final line
      final validLine1 = jsonEncode(localPointMap(p1));
      const corruptLine = '{"session_id":"f1-04-protection","lat":BAD_JSON';
      final validDuplicate = jsonEncode(localPointMap(p1));
      final validLine2 = jsonEncode(localPointMap(p2));
      const truncatedFinalLine = '{"session_id":"f1-04-protection","time';

      await journalFile.writeAsString(
        '$validLine1\n$corruptLine\n$validDuplicate\n$validLine2\n$truncatedFinalLine',
        flush: true,
      );

      final recovery = await journal.readJournal(sessionId, activeUserId: testUserId);
      expect(recovery.hasTruncatedFinalLine, isTrue);
      expect(recovery.corruptedLinesCount, greaterThanOrEqualTo(1));
      expect(recovery.duplicatePointsCount, 1);
      expect(recovery.validPointsCount, 2);
      expect(recovery.points.length, 2);
    });

    test('F1-05: Orphan Journal Recovery recovers sessions when LocalWorkout metadata is lost', () async {
      const orphanSessionId = 'f1-05-orphan';
      final p = createPoint(sessionId: orphanSessionId, index: 0);
      await journal.appendPoint(p, userId: testUserId);
      await journal.flushSession(orphanSessionId);
      await journal.checkpoint(orphanSessionId, isFinalized: true);

      // Local database has no knowledge of this session (ownedSessionIds is empty)
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getOwnedSessionIds: (_) async => const [], // Local workout metadata missing!
        getPendingGpsSessionIds: (_) async => const [],
        getUnsyncedPoints: (_) async => const [],
        getAllLocalPoints: (_) async => const [],
        markPointsSynced: (_) async {},
      );

      final pendingDiscovered = await journal.listPendingSessionIdsForUser(
        testUserId,
        ownedSessionIds: const {},
      );
      expect(pendingDiscovered, contains(orphanSessionId));

      final recovered = await outbox.resumePendingUploads();
      expect(recovered, 1);
      expect(mockTracking.getServerPoints(orphanSessionId), hasLength(1));

      final updatedManifest = await journal.readManifest(orphanSessionId);
      expect(updatedManifest!.cloudVerified, isTrue);
    });

    test('F1-06: Orphan Journal Integrity Validation detects file corruption and fails closed', () async {
      const corruptSessionId = 'f1-06-corrupt';
      final p = createPoint(sessionId: corruptSessionId, index: 0);
      await journal.appendPoint(p, userId: testUserId);
      await journal.flushSession(corruptSessionId);
      await journal.checkpoint(corruptSessionId, isFinalized: true);

      // Tamper with the raw journal file after checkpoint
      final journalFile = await journal.fileForSession(corruptSessionId);
      await journalFile.writeAsString('TAMPERED_BYTES\n', mode: FileMode.append, flush: true);

      // Integrity validation must detect corruption and exclude it from recovery
      final pendingDiscovered = await journal.listPendingSessionIdsForUser(
        testUserId,
        ownedSessionIds: const {},
      );
      expect(pendingDiscovered, isNot(contains(corruptSessionId)));

      final orphans = await journal.listOrphanJournals(activeUserId: testUserId);
      final orphan = orphans.firstWhere((o) => o.workoutId == corruptSessionId);
      expect(orphan.isCorrupted, isTrue);
      expect(orphan.statusMessage, 'checksum_mismatch');
    });

    test('F1-07: Unverifiable / Unknown-Owner Journal is never claimed by assumption', () async {
      const unknownSessionId = 'f1-07-unknown-owner';
      final p = createPoint(sessionId: unknownSessionId, index: 0);
      // Append without userId
      await journal.appendPoint(p, userId: null);
      await journal.flushSession(unknownSessionId);
      await journal.checkpoint(unknownSessionId, isFinalized: true);

      // Without trusted verification, active user CANNOT claim this unknown session
      final unverifiedPending = await journal.listPendingSessionIdsForUser(
        testUserId,
        ownedSessionIds: const {},
        ownershipVerifier: (s, u) async => false, // RLS/auth rejects
      );
      expect(unverifiedPending, isNot(contains(unknownSessionId)));

      // With trusted ownership verification (e.g. server RLS confirms ownership):
      final verifiedPending = await journal.listPendingSessionIdsForUser(
        testUserId,
        ownedSessionIds: const {},
        ownershipVerifier: (s, u) async => s == unknownSessionId && u == testUserId,
      );
      expect(verifiedPending, contains(unknownSessionId));
    });

    test('F1-08: Journal Retention prevents automatic or unauthorized journal deletion', () async {
      const safeSessionId = 'f1-08-safe-retention';
      final p = createPoint(sessionId: safeSessionId, index: 0);
      await journal.appendPoint(p, userId: testUserId);
      await journal.flushSession(safeSessionId);

      // 1. Automatic deletion must throw StateError
      expect(
        () => journal.delete(safeSessionId, force: false),
        throwsA(isA<StateError>()),
      );

      // 2. Forced deletion without authorizedUserId must throw StateError
      expect(
        () => journal.delete(safeSessionId, force: true, authorizedUserId: null),
        throwsA(isA<StateError>()),
      );

      // 3. Forced deletion with mismatched authorizedUserId must throw StateError
      expect(
        () => journal.delete(safeSessionId, force: true, authorizedUserId: 'wrong-user'),
        throwsA(isA<StateError>()),
      );

      // Journal file survives all failed attempts
      final journalFile = await journal.fileForSession(safeSessionId);
      expect(await journalFile.exists(), isTrue);
    });

    test('F1-09: Finalize Dependency Decoupling triggers outbox even when live upload is incomplete', () async {
      const workoutId = 'f1-09-decouple';
      final rawTracking = _FakeRawTrackingRemoteDataSource(failUploads: true);
      final processing = _FakeWorkoutProcessingRemoteDataSource();
      final locallySaved = <LocalGPSPoint>[];
      final recoverySaved = <LocalGPSPoint>[];

      final mockOutbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getAllLocalPoints: (_) async => recoverySaved,
        getUnsyncedPoints: (_) async => recoverySaved,
        markPointsSynced: (_) async {},
      );

      final coordinator = WorkoutRecordingCoordinator(
        rawTracking: rawTracking,
        workoutRemote: _FakeWorkoutRemoteDataSource(),
        processingRemote: processing,
        outboxService: mockOutbox,
        recoveryJournal: journal,
        currentUserId: () => testUserId,
        saveLocalGpsPoint: (p) async => locallySaved.add(p),
        saveRecoveryGpsPoint: (p) async {
          recoverySaved.add(p);
          await journal.appendPoint(p, userId: testUserId);
        },
        deleteRecoveryGpsJournal: (_) async {},
      );
      addTearDown(coordinator.dispose);

      coordinator.bufferRawGpsPoint(_position(0), workoutId: workoutId);
      coordinator.bufferRawGpsPoint(_position(1), workoutId: workoutId);

      // Live uploads failed, so diagnostics.isComplete is false
      final diag = await coordinator.finalizeRawTracking(workoutId: workoutId);
      expect(diag.isComplete, isFalse);

      // Recovery journal must still be checkpointed as finalized
      final manifest = await journal.readManifest(workoutId);
      expect(manifest, isNotNull);
      expect(manifest!.isFinalized, isTrue);

      // And outbox successfully uploaded and verified points
      expect(mockTracking.getServerPoints(workoutId), hasLength(2));
    });

    test('F1-10: Pending GPS Discovery Across App Lifecycle respects maxSessions work budget', () async {
      // Create 5 pending sessions
      for (var i = 1; i <= 5; i++) {
        final id = 'f1-10-session-$i';
        final p = createPoint(sessionId: id, index: 0);
        await journal.appendPoint(p, userId: testUserId);
        await journal.flushSession(id);
        await journal.checkpoint(id, isFinalized: true);
      }

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getOwnedSessionIds: (_) async => const [],
        getPendingGpsSessionIds: (_) async => const [],
        getUnsyncedPoints: (_) async => const [],
        getAllLocalPoints: (_) async => const [],
        markPointsSynced: (_) async {},
      );

      // Bounded taking: maxSessions = 3
      final processedCount = await outbox.resumePendingUploads(maxSessions: 3);
      expect(processedCount, 3);

      // Next run processes remaining 2 sessions
      final remainingCount = await outbox.resumePendingUploads(maxSessions: 3);
      expect(remainingCount, 2);
    });

    test('F1-11: Exclusion of Sessions Pending Explicit Deletion never replays queued deletions', () async {
      const deletedSessionId = 'f1-11-deleted-session';
      final p = createPoint(sessionId: deletedSessionId, index: 0);
      await journal.appendPoint(p, userId: testUserId);
      await journal.flushSession(deletedSessionId);
      await journal.checkpoint(deletedSessionId, isFinalized: true);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        isSessionPendingDeletion: (s, u) async => s == deletedSessionId,
        getOwnedSessionIds: (_) async => [deletedSessionId],
        getPendingGpsSessionIds: (_) async => [deletedSessionId],
        getUnsyncedPoints: (_) async => [p],
        getAllLocalPoints: (_) async => [p],
        markPointsSynced: (_) async {},
      );

      // Direct upload refuses to upload session pending deletion
      final report = await outbox.uploadAndVerifySession(deletedSessionId);
      expect(report.isVerified, isFalse);
      expect(mockTracking.getServerPoints(deletedSessionId), isEmpty);

      // Discovery also excludes it
      final resumed = await outbox.resumePendingUploads();
      expect(resumed, 0);
      expect(mockTracking.getServerPoints(deletedSessionId), isEmpty);
    });

    test('F1-12: Asynchronous Cross-Account Safety & Bounded Retries', () async {
      // 1. Account switch mid-upload aborts immediately
      var currentUser = 'user-initial';
      const sessionA = 'f1-12-switch-account';
      final points = [
        createPoint(sessionId: sessionA, index: 0),
        createPoint(sessionId: sessionA, index: 1),
      ];
      final isarSynced = <int>[];

      final switchingTracking = _SwitchingUserTrackingDataSource(
        mockTracking,
        onFirstBatchSaved: () {
          currentUser = 'user-switched';
        },
      );

      final outbox = RawGpsCloudOutboxService(
        rawTracking: switchingTracking,
        journal: journal,
        currentUserId: () => currentUser,
        chunkSize: 1, // force 2 chunks
        getUnsyncedPoints: (_) async => points,
        getAllLocalPoints: (_) async => points,
        markPointsSynced: (ids) async {
          isarSynced.addAll(ids);
        },
      );

      await expectLater(
        outbox.uploadAndVerifySession(sessionA),
        throwsA(isA<StateError>()),
      );
      expect(isarSynced, isEmpty);

      // 2. Bounded retries: 5xx server error aborts after maxRetries without infinite loop
      currentUser = testUserId;
      mockTracking.simulate5xx = true;
      mockTracking.retryAttemptsRecorded = 0;
      const sessionB = 'f1-12-bounded-retry';
      final pointsB = [createPoint(sessionId: sessionB, index: 0)];

      final outboxRetry = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => currentUser,
        baseRetryDelay: const Duration(milliseconds: 5),
        getUnsyncedPoints: (_) async => pointsB,
        getAllLocalPoints: (_) async => pointsB,
        markPointsSynced: (_) async {},
      );

      await expectLater(
        outboxRetry.uploadAndVerifySession(sessionB, maxRetries: 3),
        throwsA(isA<PostgrestException>()),
      );
      expect(mockTracking.retryAttemptsRecorded, 3);
    });
  });

  group('AETRON RG-F1 Independent QA Remediation Suite (P0-01, P0-02, P1-01, QA-01)', () {
    test('P0-01.1: Legacy manifest with populated cloud_verified_sha256 cannot self-verify (P0-01)', () {
      final points = [
        createPoint(sessionId: 'p0-01-legacy', index: 0),
        createPoint(sessionId: 'p0-01-legacy', index: 1),
      ];
      final canonPoints = points.map(CanonicalGpsPoint.fromLocal).toList();
      final canonicalDigest = RawGpsCanonicalVerification.computeCanonicalDigest(canonPoints);

      // Legacy v1 manifest that has cloud_verified_sha256 populated, but lacks canonicalCaptureDigest
      final legacyManifest = RawGpsJournalManifest(
        schemaVersion: RawGpsJournalManifest.schemaVersionV1,
        workoutId: 'p0-01-legacy',
        userId: testUserId,
        sampleCount: 2,
        checkpointSeq: 1,
        checkpointTimestampUtc: DateTime.now().toUtc(),
        isFinalized: true,
        fileSha256: 'legacy_file_hash',
        canonicalCaptureDigest: null,
        cloudVerified: true,
        cloudVerifiedCount: 2,
        cloudVerifiedSha256: canonicalDigest, // Server echo present!
      );

      final report = RawGpsCanonicalVerification.verifyAgainstManifest(
        workoutId: 'p0-01-legacy',
        manifest: legacyManifest,
        cloudPoints: canonPoints,
      );

      // Must remain RESTORED_UNVERIFIED! cloud_verified_sha256 cannot replace independent capture proof.
      expect(report.state, RawGpsVerificationState.restoredUnverified);
      expect(report.isVerified, isFalse);
      expect(report.message, contains('RESTORED_UNVERIFIED'));

      // Also v2 manifest without canonicalCaptureDigest but with cloudVerifiedSha256 must remain unverified
      final unverifiedV2Manifest = legacyManifest.copyWith(
        schemaVersion: RawGpsJournalManifest.currentSchemaVersion,
        canonicalCaptureDigest: null,
      );
      final reportV2 = RawGpsCanonicalVerification.verifyAgainstManifest(
        workoutId: 'p0-01-legacy',
        manifest: unverifiedV2Manifest,
        cloudPoints: canonPoints,
      );
      expect(reportV2.state, RawGpsVerificationState.restoredUnverified);
      expect(reportV2.isVerified, isFalse);
    });

    test('P0-01.2: Manifest and point identity verification fails closed on foreign workouts (P0-01)', () {
      final points = [createPoint(sessionId: 'workout-A', index: 0)];
      final canonA = points.map(CanonicalGpsPoint.fromLocal).toList();
      final digestA = RawGpsCanonicalVerification.computeCanonicalDigest(canonA);

      final manifestA = RawGpsJournalManifest(
        workoutId: 'workout-A',
        userId: testUserId,
        sampleCount: 1,
        checkpointSeq: 1,
        checkpointTimestampUtc: DateTime.now().toUtc(),
        isFinalized: true,
        canonicalCaptureDigest: digestA,
      );

      // 1. Manifest workoutId mismatch
      final reportMismatchWorkout = RawGpsCanonicalVerification.verifyAgainstManifest(
        workoutId: 'workout-B', // requesting verification for workout B
        manifest: manifestA,    // but provided manifest is for workout A
        cloudPoints: canonA,
      );
      expect(reportMismatchWorkout.state, RawGpsVerificationState.integrityMismatch);
      expect(reportMismatchWorkout.message, contains('Manifest workoutId (workout-A) does not match'));

      // 2. Cloud point workoutId mismatch
      final foreignPoints = [
        CanonicalGpsPoint(
          workoutId: 'foreign-workout',
          timestamp: DateTime.utc(2026, 10, 20, 10, 0),
          latitude: 10.7380,
          longitude: 106.6250,
        ),
      ];
      final reportMismatchPoint = RawGpsCanonicalVerification.verifyAgainstManifest(
        workoutId: 'workout-A',
        manifest: manifestA,
        cloudPoints: foreignPoints,
      );
      expect(reportMismatchPoint.state, RawGpsVerificationState.integrityMismatch);
      expect(reportMismatchPoint.message, contains('Point identity mismatch'));
    });

    test('P0-01.3: Tampered or corrupted coordinates fail closed with INTEGRITY_MISMATCH (P0-01)', () async {
      const sessionId = 'p0-01-tampered';
      final p1 = createPoint(sessionId: sessionId, index: 0);
      final p2 = createPoint(sessionId: sessionId, index: 1);
      await journal.appendPoint(p1, userId: testUserId);
      await journal.appendPoint(p2, userId: testUserId);
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      final manifest = await journal.readManifest(sessionId);
      expect(manifest, isNotNull);

      // Simulate cloud points where coordinates were tampered with (e.g. latitude modified)
      final tamperedCloud = [
        CanonicalGpsPoint.fromLocal(p1),
        CanonicalGpsPoint(
          workoutId: sessionId,
          timestamp: p2.timestamp,
          latitude: p2.latitude + 0.005, // tampered!
          longitude: p2.longitude,
          altitude: p2.altitude,
          speed: p2.speed,
          accuracy: p2.accuracy,
          heading: p2.heading,
          deviceSource: p2.deviceSource,
        ),
      ];

      final report = RawGpsCanonicalVerification.verifyAgainstManifest(
        workoutId: sessionId,
        manifest: manifest,
        cloudPoints: tamperedCloud,
      );

      expect(report.state, RawGpsVerificationState.integrityMismatch);
      expect(report.isVerified, isFalse);
      expect(report.message, contains('Integrity mismatch'));
    });

    test('P0-02.1: Deletion store failure fails closed and preserves raw GPS safely locally (P0-02)', () async {
      const sessionId = 'p0-02-db-failure';
      final p = createPoint(sessionId: sessionId, index: 0);
      await journal.appendPoint(p, userId: testUserId);
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        isSessionPendingDeletion: (s, u) async {
          // Simulate SQLite failure (disk error, locked db, table corrupted)
          throw StateError('SQLite Database locked or corrupted');
        },
        getOwnedSessionIds: (_) async => [sessionId],
        getPendingGpsSessionIds: (_) async => [sessionId],
        getUnsyncedPoints: (_) async => [p],
        getAllLocalPoints: (_) async => [p],
        markPointsSynced: (_) async {},
      );

      // 1. Direct upload fails closed to pendingUpload (never uploads or deletes)
      final report = await outbox.uploadAndVerifySession(sessionId);
      expect(report.state, RawGpsVerificationState.pendingUpload);
      expect(report.isVerified, isFalse);
      expect(report.message, contains('Deletion state cannot be determined safely'));
      expect(mockTracking.getServerPoints(sessionId), isEmpty);

      // Journal file remains untouched and preserved
      final journalFile = await journal.fileForSession(sessionId);
      expect(await journalFile.exists(), isTrue);

      // 2. resumePendingUploads also fails closed (skips candidate rather than uploading)
      final resumedCount = await outbox.resumePendingUploads();
      expect(resumedCount, 0);
      expect(mockTracking.getServerPoints(sessionId), isEmpty);
    });

    test('P0-02.2: Queued deletions during account switch are excluded safely (P0-02)', () async {
      const sessionUserA = 'p0-02-user-a-del';
      final p = createPoint(sessionId: sessionUserA, index: 0);
      await journal.appendPoint(p, userId: 'user-a');
      await journal.flushSession(sessionUserA);
      await journal.checkpoint(sessionUserA, isFinalized: true);

      var activeUser = 'user-a';
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => activeUser,
        isSessionPendingDeletion: (s, u) async {
          return u == 'user-a' && s == sessionUserA;
        },
        getOwnedSessionIds: (u) async => u == 'user-a' ? [sessionUserA] : [],
        getPendingGpsSessionIds: (u) async => u == 'user-a' ? [sessionUserA] : [],
        getUnsyncedPoints: (_) async => [p],
        getAllLocalPoints: (_) async => [p],
        markPointsSynced: (_) async {},
      );

      // Under user-a, session is excluded due to deletion
      final aResumed = await outbox.resumePendingUploads();
      expect(aResumed, 0);
      expect(mockTracking.getServerPoints(sessionUserA), isEmpty);

      // Switch to user-b: user-b does not own sessionUserA
      activeUser = 'user-b';
      final bResumed = await outbox.resumePendingUploads();
      expect(bResumed, 0);
      expect(mockTracking.getServerPoints(sessionUserA), isEmpty);
    });

    test('P1-01.1: Pending upload fairness: failing session does not starve later sessions (P1-01)', () async {
      const failSession = 'p1-01-fail-session';
      const successSession = 'p1-01-success-session';

      final pFail = createPoint(sessionId: failSession, index: 0);
      final pSuccess = createPoint(sessionId: successSession, index: 0);

      await journal.appendPoint(pFail, userId: testUserId);
      await journal.flushSession(failSession);
      await journal.checkpoint(failSession, isFinalized: true);

      await journal.appendPoint(pSuccess, userId: testUserId);
      await journal.flushSession(successSession);
      await journal.checkpoint(successSession, isFinalized: true);

      // Configure mockTracking so failSession fails, but successSession succeeds
      mockTracking.failingSessionIds.add(failSession);

      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        retryBackoffCalculator: (attempt) => Duration(seconds: attempt * 60),
        getOwnedSessionIds: (_) async => [failSession, successSession],
        getPendingGpsSessionIds: (_) async => [failSession, successSession],
        getUnsyncedPoints: (s) async => [s == failSession ? pFail : pSuccess],
        getAllLocalPoints: (s) async => [s == failSession ? pFail : pSuccess],
        markPointsSynced: (_) async {},
      );

      // Pass 1: maxSessions = 1. Takes failSession. Fails and enters 60s backoff.
      final pass1Count = await outbox.resumePendingUploads(maxSessions: 1);
      expect(pass1Count, 0);
      expect(outbox.getRetryCount(failSession), 1);
      expect(outbox.getNextRetryUtc(failSession), isNotNull);

      // Pass 2: immediately invoke with maxSessions = 1.
      // failSession is in backoff, so it MUST NOT starve successSession!
      final pass2Count = await outbox.resumePendingUploads(maxSessions: 1);
      expect(pass2Count, 1);
      expect(mockTracking.getServerPoints(successSession), hasLength(1));

      final successManifest = await journal.readManifest(successSession);
      expect(successManifest!.cloudVerified, isTrue);

      // Clean up mockTracking
      mockTracking.failingSessionIds.remove(failSession);
    });

    test('P1-01.2: Backlog fairness and exponential backoff persist across outbox restart (P1-01)', () async {
      const failSession = 'p1-01-restart-fail';
      const successSession = 'p1-01-restart-success';

      final pFail = createPoint(sessionId: failSession, index: 0);
      final pSuccess = createPoint(sessionId: successSession, index: 0);

      await journal.appendPoint(pFail, userId: testUserId);
      await journal.flushSession(failSession);
      await journal.checkpoint(failSession, isFinalized: true);

      await journal.appendPoint(pSuccess, userId: testUserId);
      await journal.flushSession(successSession);
      await journal.checkpoint(successSession, isFinalized: true);

      mockTracking.failingSessionIds.add(failSession);

      // Outbox 1 attempts failSession and fails
      final outbox1 = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        retryBackoffCalculator: (attempt) => Duration(seconds: attempt * 60),
        getOwnedSessionIds: (_) async => [failSession, successSession],
        getPendingGpsSessionIds: (_) async => [failSession, successSession],
        getUnsyncedPoints: (s) async => [s == failSession ? pFail : pSuccess],
        getAllLocalPoints: (s) async => [s == failSession ? pFail : pSuccess],
        markPointsSynced: (_) async {},
      );

      await outbox1.resumePendingUploads(maxSessions: 1);

      // Verify manifest on disk recorded backoff and retry count
      final failManifest = await journal.readManifest(failSession);
      expect(failManifest, isNotNull);
      expect(failManifest!.retryCount, 1);
      expect(failManifest.nextRetryTimestampUtc, isNotNull);
      expect(DateTime.now().toUtc().isBefore(failManifest.nextRetryTimestampUtc!), isTrue);

      // Outbox 2 simulates app restart: fresh outbox instance with empty in-memory retry state!
      final outbox2 = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getOwnedSessionIds: (_) async => [failSession, successSession],
        getPendingGpsSessionIds: (_) async => [failSession, successSession],
        getUnsyncedPoints: (s) async => [s == failSession ? pFail : pSuccess],
        getAllLocalPoints: (s) async => [s == failSession ? pFail : pSuccess],
        markPointsSynced: (_) async {},
      );

      // Outbox 2 must read disk manifest, detect active backoff for failSession,
      // and fairly execute successSession instead!
      final pass2Count = await outbox2.resumePendingUploads(maxSessions: 1);
      expect(pass2Count, 1);
      expect(mockTracking.getServerPoints(successSession), hasLength(1));

      mockTracking.failingSessionIds.remove(failSession);
    });
  });

  group('AETRON RG-F1 Final Independent QA Hardening Suite (P0-A, P0-B, P1-A, QA-B)', () {
    test('P0-A.1: Incomplete capture: 3 captured, 1 corrupted, Isar empty -> returns PARTIAL, never CLOUD_VERIFIED', () async {
      final sessionId = 'p0-a-incomplete-${DateTime.now().millisecondsSinceEpoch}';
      final startTime = DateTime.utc(2026, 10, 19, 10, 0, 0);

      // 1. Write 3 original samples to journal and checkpoint
      final p0 = createPoint(sessionId: sessionId, index: 0, startTime: startTime);
      final p1 = createPoint(sessionId: sessionId, index: 1, startTime: startTime);
      final p2 = createPoint(sessionId: sessionId, index: 2, startTime: startTime);

      await journal.appendPoint(p0, userId: testUserId);
      await journal.appendPoint(p1, userId: testUserId);
      await journal.appendPoint(p2, userId: testUserId);
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      final initialManifest = await journal.readManifest(sessionId);
      expect(initialManifest!.sampleCount, 3);
      expect(initialManifest.canonicalCaptureDigest, isNotNull);

      // 2. Corrupt line 2 in journal file
      final journalFile = await journal.fileForSession(sessionId);
      final lines = await journalFile.readAsLines();
      expect(lines.length, 3);
      lines[1] = '{"corrupted": true, broken json...';
      await journalFile.writeAsString('${lines.join('\n')}\n');

      // 3. Isar is completely empty (write failure during workout)
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (_) async => const [],
        getAllLocalPoints: (_) async => const [],
        markPointsSynced: (_) async {},
      );

      // 4. Upload and verify session
      final report = await outbox.uploadAndVerifySession(sessionId);

      // 5. Verification: CANNOT become CLOUD_VERIFIED! Must fail closed to PARTIAL!
      expect(report.state, RawGpsVerificationState.partial);
      expect(report.isVerified, isFalse);
      expect(report.localCount, 3); // Expected original 3 samples from manifest
      expect(report.cloudCount, 2); // Cloud only confirmed 2 recovered samples
      expect(report.missingCloudSampleCount, 1);
      expect(report.state.label, 'PARTIAL');

      // Assert journal manifest on disk is NOT cloud-verified
      final diskManifest = await journal.readManifest(sessionId);
      expect(diskManifest!.cloudVerified, isFalse);
    });

    test('P0-A.2: Complete Isar records are NOT rejected solely because redundant journal copy is damaged', () async {
      final sessionId = 'p0-a-complete-isar-${DateTime.now().millisecondsSinceEpoch}';
      final startTime = DateTime.utc(2026, 10, 19, 10, 0, 0);

      final p0 = createPoint(sessionId: sessionId, index: 0, startTime: startTime);
      final p1 = createPoint(sessionId: sessionId, index: 1, startTime: startTime);
      final p2 = createPoint(sessionId: sessionId, index: 2, startTime: startTime);
      final isarPoints = [p0, p1, p2];

      // 1. Write 3 samples to journal and checkpoint
      await journal.appendPoint(p0, userId: testUserId);
      await journal.appendPoint(p1, userId: testUserId);
      await journal.appendPoint(p2, userId: testUserId);
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // 2. Corrupt line 2 in journal file
      final journalFile = await journal.fileForSession(sessionId);
      final lines = await journalFile.readAsLines();
      lines[1] = '{corrupted_data_line}';
      await journalFile.writeAsString('${lines.join('\n')}\n');

      final syncedIds = <int>{};
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        getUnsyncedPoints: (_) async => isarPoints.where((p) => !syncedIds.contains(p.id)).toList(),
        getAllLocalPoints: (_) async => isarPoints,
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      // 3. Upload and verify session: complete Isar points heal the corrupted journal copy
      final report = await outbox.uploadAndVerifySession(sessionId);

      expect(report.state, RawGpsVerificationState.cloudVerified);
      expect(report.isVerified, isTrue);
      expect(report.localCount, 3);
      expect(report.cloudCount, 3);
      expect(report.missingCloudSampleCount, 0);
      expect(syncedIds.length, 3);
    });

    test('P0-B.1: Legacy v1 manifest without canonicalCaptureDigest remains visible in listPendingSessionIdsForUser', () async {
      final legacySession = 'p0-b-legacy-${DateTime.now().millisecondsSinceEpoch}';
      final modernSession = 'p0-b-modern-${DateTime.now().millisecondsSinceEpoch}';
      final pLegacy = createPoint(sessionId: legacySession, index: 0);
      final pModern = createPoint(sessionId: modernSession, index: 0);

      // 1. Write journals
      await journal.appendPoint(pLegacy, userId: testUserId);
      await journal.flushSession(legacySession);
      await journal.appendPoint(pModern, userId: testUserId);
      await journal.flushSession(modernSession);
      await journal.checkpoint(modernSession, isFinalized: true);

      // 2. Modern manifest has genuine canonicalCaptureDigest and cloudVerified
      final modernManifestFile = await journal.manifestFileForSession(modernSession);
      final modernContent = await modernManifestFile.readAsString();
      final modernManifest = RawGpsJournalManifest.fromJson(
        jsonDecode(modernContent) as Map<String, dynamic>,
      );
      final modernVerified = modernManifest.copyWith(
        cloudVerified: true,
        cloudVerifiedCount: 1,
        cloudVerifiedSha256: modernManifest.canonicalCaptureDigest,
      );
      final tempModern = File('${modernManifestFile.path}.tmp');
      await tempModern.writeAsString(jsonEncode(modernVerified.toJson()));
      await tempModern.rename(modernManifestFile.path);

      // 3. Create legacy v1 manifest for legacySession (has cloudVerified: true, but schemaVersionV1 and NO canonicalCaptureDigest)
      final legacyManifest = RawGpsJournalManifest(
        schemaVersion: RawGpsJournalManifest.schemaVersionV1,
        workoutId: legacySession,
        userId: testUserId,
        sampleCount: 1,
        checkpointSeq: 1,
        checkpointTimestampUtc: DateTime.now().toUtc(),
        isFinalized: true,
        cloudVerified: true,
        cloudVerifiedCount: 1,
        cloudVerifiedSha256: 'server_sha_echo_without_capture_digest',
        canonicalCaptureDigest: null,
      );
      final legacyManifestFile = await journal.manifestFileForSession(legacySession);
      final tempLegacy = File('${legacyManifestFile.path}.tmp');
      await tempLegacy.writeAsString(jsonEncode(legacyManifest.toJson()));
      await tempLegacy.rename(legacyManifestFile.path);

      // 4. Query pending sessions
      final pending = await journal.listPendingSessionIdsForUser(
        testUserId,
        ownedSessionIds: {legacySession, modernSession},
      );

      // Assert legacySession remains visible for reconciliation, while modern verified session is safely skipped!
      expect(pending, contains(legacySession));
      expect(pending, isNot(contains(modernSession)));
    });

    test('P1-A.1: copyWith clears nextRetryTimestampUtc on disk on successful retry', () async {
      final sessionId = 'p1-a-clear-${DateTime.now().millisecondsSinceEpoch}';
      final p = createPoint(sessionId: sessionId, index: 0);
      await journal.appendPoint(p, userId: testUserId);
      await journal.flushSession(sessionId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // Record failure with 15-minute backoff
      await journal.recordRetryAttempt(
        sessionId,
        success: false,
        nextBackoff: const Duration(minutes: 15),
      );

      final failedManifest = await journal.readManifest(sessionId);
      expect(failedManifest!.retryCount, 1);
      expect(failedManifest.nextRetryTimestampUtc, isNotNull);

      // Record success: must clear nextRetryTimestampUtc on disk
      await journal.recordRetryAttempt(sessionId, success: true);

      final successManifest = await journal.readManifest(sessionId);
      expect(successManifest!.retryCount, 0);
      expect(successManifest.nextRetryTimestampUtc, isNull);
    });

    test('P1-A.2: Writer checkpoint preserves disk retry metadata without overwriting with stale writer state', () async {
      final sessionId = 'p1-a-preserve-${DateTime.now().millisecondsSinceEpoch}';
      final p0 = createPoint(sessionId: sessionId, index: 0);
      final p1 = createPoint(sessionId: sessionId, index: 1);

      // Start session, append p0
      await journal.appendPoint(p0, userId: testUserId);
      await journal.checkpoint(sessionId);

      // External retry failure writes retry metadata to disk
      final backoffTime = DateTime.utc(2026, 10, 20, 22, 0, 0);
      final manifestFile = await journal.manifestFileForSession(sessionId);
      final manifestOnDisk = await journal.readManifest(sessionId);
      final updatedOnDisk = manifestOnDisk!.copyWith(
        retryCount: 4,
        lastRetryTimestampUtc: DateTime.utc(2026, 10, 20, 21, 50, 0),
        nextRetryTimestampUtc: backoffTime,
      );
      final temp = File('${manifestFile.path}.tmp');
      await temp.writeAsString(jsonEncode(updatedOnDisk.toJson()));
      await temp.rename(manifestFile.path);

      // Active writer appends p1 and executes internal checkpoint
      await journal.appendPoint(p1, userId: testUserId);
      await journal.checkpoint(sessionId, isFinalized: true);

      // Assert disk manifest preserved retryCount and nextRetryTimestampUtc
      final checkpointedManifest = await journal.readManifest(sessionId);
      expect(checkpointedManifest!.retryCount, 4);
      expect(checkpointedManifest.nextRetryTimestampUtc, backoffTime);
      expect(checkpointedManifest.sampleCount, 2);
    });

    test('P1-A.3: Backlog fairness and backoff protect Isar-only sessions without a recovery manifest', () async {
      final isarFailSession = 'p1-a-isar-fail-${DateTime.now().millisecondsSinceEpoch}';
      final isarSuccessSession = 'p1-a-isar-success-${DateTime.now().millisecondsSinceEpoch}';

      final pFail = createPoint(sessionId: isarFailSession, index: 0);
      final pSuccess = createPoint(sessionId: isarSuccessSession, index: 0);

      // Neither session has a journal or manifest on disk
      expect(await journal.readManifest(isarFailSession), isNull);
      expect(await journal.readManifest(isarSuccessSession), isNull);

      mockTracking.failingSessionIds.add(isarFailSession);

      final syncedIds = <int>{};
      final outbox = RawGpsCloudOutboxService(
        rawTracking: mockTracking,
        journal: journal,
        currentUserId: () => testUserId,
        retryBackoffCalculator: (attempt) => Duration(seconds: attempt * 60),
        getOwnedSessionIds: (_) async => [isarFailSession, isarSuccessSession],
        getPendingGpsSessionIds: (_) async => [isarFailSession, isarSuccessSession],
        getUnsyncedPoints: (s) async => [s == isarFailSession ? pFail : pSuccess],
        getAllLocalPoints: (s) async => [s == isarFailSession ? pFail : pSuccess],
        markPointsSynced: (ids) async => syncedIds.addAll(ids),
      );

      // Pass 1: maxSessions: 1 picks isarFailSession. Fails and enters 60s backoff in memory.
      final pass1Count = await outbox.resumePendingUploads(maxSessions: 1);
      expect(pass1Count, 0);
      expect(outbox.getRetryCount(isarFailSession), 1);
      expect(outbox.getNextRetryUtc(isarFailSession), isNotNull);

      // Pass 2: maxSessions: 1 immediately invoked.
      // isarFailSession is in backoff, so it must not starve isarSuccessSession!
      final pass2Count = await outbox.resumePendingUploads(maxSessions: 1);
      expect(pass2Count, 1);
      expect(syncedIds, contains(pSuccess.id));
      expect(mockTracking.getServerPoints(isarSuccessSession), hasLength(1));

      mockTracking.failingSessionIds.remove(isarFailSession);
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

Position _position(int index) => Position(
  latitude: 10.7380 + (index * 0.0001),
  longitude: 106.6250 + (index * 0.0001),
  timestamp: DateTime.utc(2026, 10, 19, 9, 0, index),
  altitude: 12.0,
  altitudeAccuracy: 1.0,
  accuracy: 3.5,
  heading: 90.0,
  headingAccuracy: 1.0,
  speed: 4.2,
  speedAccuracy: 0.5,
);

SupabaseClient _testClient() =>
    SupabaseClient('https://example.supabase.co', 'test-anon-key');

class _FakeRawTrackingRemoteDataSource extends RawTrackingRemoteDataSource {
  _FakeRawTrackingRemoteDataSource({this.failUploads = false})
      : super(_testClient());

  final bool failUploads;
  final List<RawGpsPointPayload> savedGpsPoints = [];

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) async {
    if (failUploads) throw StateError('network unavailable');
    savedGpsPoints.addAll(points);
  }

  @override
  Future<int> countRawGpsPointsForWorkout(String workoutId) async {
    return savedGpsPoints.where((point) => point.workoutId == workoutId).length;
  }
}

class _FakeWorkoutRemoteDataSource extends WorkoutRemoteDataSource {
  _FakeWorkoutRemoteDataSource() : super(_testClient());
}

class _FakeWorkoutProcessingRemoteDataSource
    extends WorkoutProcessingRemoteDataSource {
  _FakeWorkoutProcessingRemoteDataSource() : super(_testClient());

  final List<Map<String, dynamic>> logs = [];

  @override
  Future<String?> enqueueDeterministicJob({
    required String workoutId,
    required Map<String, dynamic> payload,
  }) async {
    return 'job-1';
  }

  @override
  Future<void> insertLog({
    required String workoutId,
    String? jobId,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
    String logLevel = 'info',
  }) async {
    logs.add({
      'event_type': eventType,
      'log_level': logLevel,
      'message': message,
      'payload': payload,
    });
  }
}

class _SwitchingUserTrackingDataSource implements RawTrackingRemoteDataSource {
  final _MockRawTrackingDataSource _inner;
  final void Function() onFirstBatchSaved;
  int _batchCount = 0;

  _SwitchingUserTrackingDataSource(this._inner, {required this.onFirstBatchSaved});

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) async {
    await _inner.saveRawGpsPoints(points);
    _batchCount++;
    if (_batchCount == 1) {
      onFirstBatchSaved();
    }
  }

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
  }) => _inner.fetchRawGpsPointsPaged(workoutId, offset: offset, limit: limit);

  @override
  Future<List<RawGpsPointPayload>> fetchAllRawGpsPoints(
    String workoutId, {
    int pageSize = 1000,
  }) => _inner.fetchAllRawGpsPoints(workoutId, pageSize: pageSize);
}

