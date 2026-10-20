import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final rawGpsCloudOutboxServiceProvider =
    Provider<RawGpsCloudOutboxService>((ref) {
      return RawGpsCloudOutboxService(
        rawTracking: ref.watch(rawTrackingRemoteDataSourceProvider),
        currentUserId: () => ref.read(currentUserIdProvider),
      );
    });

/// Event emitted on outbox state transitions.
class RawGpsOutboxEvent {
  final String sessionId;
  final RawGpsVerificationState state;
  final int pointsProcessed;
  final int totalPoints;
  final String? error;

  const RawGpsOutboxEvent({
    required this.sessionId,
    required this.state,
    required this.pointsProcessed,
    required this.totalPoints,
    this.error,
  });
}

/// Reconciled ground truth from local sources (Isar + Recovery Journal).
class ReconciledLocalCapture {
  final List<CanonicalGpsPoint> canonicalPoints;
  final List<RawGpsPointPayload> payloadsToUpload;
  final List<int> isarPointIdsToMarkSynced;
  final bool hasCorruptedJournal;
  final int corruptedJournalLines;
  final int isarCount;
  final int journalCount;

  const ReconciledLocalCapture({
    required this.canonicalPoints,
    required this.payloadsToUpload,
    required this.isarPointIdsToMarkSynced,
    required this.hasCorruptedJournal,
    required this.corruptedJournalLines,
    required this.isarCount,
    required this.journalCount,
  });
}

/// Durable Cloud Upload Outbox service implementing RG-1B & RG-1B.1:
/// - Reconciles readable samples from BOTH Isar and recovery journal before upload (P0-02).
/// - Persists pending upload work across app restarts using Isar (`isSynced = false`).
/// - Recovers incomplete/in-flight chunks after crash or process restart.
/// - Uses bounded batches and exponential retry with jitter.
/// - Handles offline, network timeouts, 401/auth expiration, 429, and 5xx errors.
/// - Preserves raw GPS locally when uploads fail (never deletes unverified local points).
/// - Enforces idempotent ingestion without duplicate records.
/// - Executes canonical read-back verification after upload (P0-01).
/// - NEVER marks points as synced in Isar before successful cloud verification!
/// - Keeps failed/partial uploads retryable.
/// - Avoids duplicate upload workers and unbounded battery/polling usage (P0-03).
/// - Never deletes recovery journals automatically.
class RawGpsCloudOutboxService {
  final RawTrackingRemoteDataSource _rawTracking;
  final RawGpsRecoveryJournal _journal;
  final Future<List<LocalGPSPoint>> Function(String sessionId) _getUnsyncedPoints;
  final Future<List<LocalGPSPoint>> Function(String sessionId) _getAllLocalPoints;
  final Future<void> Function(List<int> ids) _markPointsSynced;
  final Future<void> Function(List<LocalGPSPoint> points)? _saveLocalPoints;
  final Future<List<String>> Function(String userId)? _getUnsyncedSessionIds;
  final Future<List<String>> Function(String userId) _getOwnedSessionIds;
  final Future<List<String>> Function(String userId) _getPendingGpsSessionIds;
  final String? Function() _currentUserId;
  final int chunkSize;
  final Duration baseRetryDelay;
  final Random _random;

  final Map<String, RawGpsVerificationState> _sessionStates = {};
  final Set<String> _inFlightSessions = {};
  bool _isProcessingOutbox = false;

  final StreamController<RawGpsOutboxEvent> _eventController =
      StreamController<RawGpsOutboxEvent>.broadcast();

  RawGpsCloudOutboxService({
    required RawTrackingRemoteDataSource rawTracking,
    RawGpsRecoveryJournal? journal,
    Future<List<LocalGPSPoint>> Function(String sessionId)? getUnsyncedPoints,
    Future<List<LocalGPSPoint>> Function(String sessionId)? getAllLocalPoints,
    Future<void> Function(List<int> ids)? markPointsSynced,
    Future<void> Function(List<LocalGPSPoint> points)? saveLocalPoints,
    Future<List<String>> Function(String userId)? getUnsyncedSessionIds,
    Future<List<String>> Function(String userId)? getOwnedSessionIds,
    Future<List<String>> Function(String userId)? getPendingGpsSessionIds,
    required String? Function() currentUserId,
    this.chunkSize = 250,
    this.baseRetryDelay = const Duration(milliseconds: 150),
    Random? random,
  }) : _rawTracking = rawTracking,
       _journal = journal ?? RawGpsRecoveryJournal.instance,
       _getUnsyncedPoints =
           getUnsyncedPoints ?? LocalDB.getUnsyncedGpsPointsForSession,
       _getAllLocalPoints = getAllLocalPoints ?? LocalDB.getPointsForSession,
       _markPointsSynced = markPointsSynced ?? LocalDB.markGpsPointsAsSynced,
       _saveLocalPoints = saveLocalPoints,
       _getUnsyncedSessionIds = getUnsyncedSessionIds,
       _getOwnedSessionIds =
           getOwnedSessionIds ?? LocalDB.getRawGpsOwnedSessionIdsForUser,
       _getPendingGpsSessionIds =
           getPendingGpsSessionIds ?? LocalDB.getPendingRawGpsSessionIdsForUser,
       _currentUserId = currentUserId,
       _random = random ?? Random();

  Stream<RawGpsOutboxEvent> get events => _eventController.stream;

  RawGpsVerificationState stateForSession(String sessionId) {
    return _sessionStates[sessionId] ?? RawGpsVerificationState.unknown;
  }

  void dispose() {
    _eventController.close();
  }

  /// Reconciles ground truth from both Isar and recovery journal (P0-02).
  ///
  /// Merges readable points from both sources using deterministic sample identities.
  /// If Isar was empty or partially populated (e.g. Isar write failure during recording),
  /// points from the recovery journal are incorporated into the upload set.
  Future<ReconciledLocalCapture> reconcileLocalSources(
    String sessionId, {
    required String activeUserId,
  }) async {
    final isarAll = await _getAllLocalPoints(sessionId);
    final isarUnsynced = await _getUnsyncedPoints(sessionId);
    final journalResult = await _journal.readJournal(
      sessionId,
      activeUserId: activeUserId,
    );

    final sampleMap = <String, CanonicalGpsPoint>{};
    final isarPointMap = <String, LocalGPSPoint>{};
    final unsyncedKeys = <String>{};

    // 1. Ingest Isar records
    for (final p in isarAll) {
      final canon = CanonicalGpsPoint.fromLocal(p);
      final key = canon.identityKey;
      sampleMap[key] = canon;
      isarPointMap[key] = p;
    }

    // 2. Unsynced points from Isar
    for (final p in isarUnsynced) {
      unsyncedKeys.add(CanonicalGpsPoint.fromLocal(p).identityKey);
    }

    // 2. Reconcile with journal records (heals Isar if journal has missing samples)
    final missingFromIsar = <LocalGPSPoint>[];
    for (final jp in journalResult.points) {
      final canon = CanonicalGpsPoint.fromLocal(jp);
      final key = canon.identityKey;
      if (!sampleMap.containsKey(key)) {
        sampleMap[key] = canon;
        unsyncedKeys.add(key);

        final newIsarPoint = LocalGPSPoint()
          ..sessionId = sessionId
          ..timestamp = jp.timestamp.toUtc()
          ..latitude = jp.latitude
          ..longitude = jp.longitude
          ..altitude = jp.altitude
          ..speed = jp.speed
          ..accuracy = jp.accuracy
          ..heading = jp.heading
          ..deviceSource = jp.deviceSource
          ..confidence = jp.confidence
          ..isSynced = false;
        missingFromIsar.add(newIsarPoint);
      }
    }

    if (missingFromIsar.isNotEmpty && !kIsWeb) {
      try {
        if (_saveLocalPoints != null) {
          await _saveLocalPoints(missingFromIsar);
        } else {
          await LocalDB.savePoints(missingFromIsar);
        }
        for (final mp in missingFromIsar) {
          isarPointMap[CanonicalGpsPoint.fromLocal(mp).identityKey] = mp;
        }
      } catch (e) {
        debugPrint('[Outbox] Failed to cache missing journal points into Isar: $e');
      }
    }

    final canonicalPoints = sampleMap.values.toList()..sort();
    final payloadsToUpload = <RawGpsPointPayload>[];
    final isarPointIds = <int>[];

    for (final cp in canonicalPoints) {
      if (unsyncedKeys.contains(cp.identityKey)) {
        payloadsToUpload.add(
          RawGpsPointPayload(
            workoutId: cp.workoutId,
            timestamp: cp.timestamp,
            latitude: cp.latitude,
            longitude: cp.longitude,
            altitude: cp.altitude,
            speed: cp.speed,
            accuracy: cp.accuracy,
            heading: cp.heading,
            deviceSource: cp.deviceSource,
          ),
        );
      }
      final isarPoint = isarPointMap[cp.identityKey];
      if (isarPoint != null && isarPoint.id > 0) {
        isarPointIds.add(isarPoint.id);
      }
    }

    final isJournalCorrupted =
        journalResult.corruptedLinesCount > 0 ||
        journalResult.status == RawGpsRecoveryStatus.corrupted;

    return ReconciledLocalCapture(
      canonicalPoints: canonicalPoints,
      payloadsToUpload: payloadsToUpload,
      isarPointIdsToMarkSynced: isarPointIds,
      hasCorruptedJournal: isJournalCorrupted,
      corruptedJournalLines: journalResult.corruptedLinesCount,
      isarCount: isarAll.length,
      journalCount: journalResult.points.length,
    );
  }

  /// Uploads all unsynced points for [sessionId] with bounded batches, exponential backoff,
  /// and post-upload canonical read-back verification (P0-01).
  ///
  /// INVARIANTS:
  /// - Points in Isar are NEVER marked synced before successful cloud read-back verification.
  /// - Transitions to [RawGpsVerificationState.uploadedUnverified] between HTTP ACK and verification.
  /// - A failed verification leaves points marked [isSynced = false] and retryable.
  Future<RawGpsVerificationReport> uploadAndVerifySession(
    String sessionId, {
    int maxRetries = 3,
  }) async {
    final activeUser = _currentUserId();
    if (activeUser == null || activeUser.trim().isEmpty) {
      _updateState(sessionId, RawGpsVerificationState.authRequired, 0, 0);
      return RawGpsVerificationReport(
        workoutId: sessionId,
        state: RawGpsVerificationState.authRequired,
        localCount: 0,
        cloudCount: 0,
        localDigest: RawGpsCanonicalVerification.emptyDigest,
        cloudDigest: null,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: 0,
        message: 'User authentication required for cloud upload.',
      );
    }

    // Prevent duplicate workers for the same session (P0-03)
    if (_inFlightSessions.contains(sessionId)) {
      return RawGpsVerificationReport(
        workoutId: sessionId,
        state: stateForSession(sessionId),
        localCount: 0,
        cloudCount: 0,
        localDigest: RawGpsCanonicalVerification.emptyDigest,
        cloudDigest: null,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: 0,
        message: 'Upload already in-flight for this session.',
      );
    }

    _inFlightSessions.add(sessionId);
    try {
      _updateState(sessionId, RawGpsVerificationState.uploading, 0, 0);

      // 1. Reconcile readable samples from both Isar and Recovery Journal (P0-02)
      final reconciled = await reconcileLocalSources(
        sessionId,
        activeUserId: activeUser,
      );

      final localCanon = reconciled.canonicalPoints;
      final payloads = reconciled.payloadsToUpload;

      if (localCanon.isEmpty) {
        _updateState(sessionId, RawGpsVerificationState.unknown, 0, 0);
        return RawGpsCanonicalVerification.verify(
          workoutId: sessionId,
          localPoints: const [],
          cloudPoints: const [],
        );
      }

      // 2. Upload unsynced points in bounded batches with retry and jitter
      if (payloads.isNotEmpty) {
        var uploadedCount = 0;

        for (var i = 0; i < payloads.length; i += chunkSize) {
          final end = (i + chunkSize < payloads.length)
              ? i + chunkSize
              : payloads.length;
          final batch = payloads.sublist(i, end);

          var attempt = 0;
          var batchSuccess = false;

          while (!batchSuccess && attempt < maxRetries) {
            try {
              await _rawTracking.saveRawGpsPoints(batch);
              batchSuccess = true;
              uploadedCount += batch.length;
              _updateState(
                sessionId,
                RawGpsVerificationState.uploading,
                uploadedCount,
                payloads.length,
              );
            } catch (e) {
              attempt++;
              if (_isAuthError(e)) {
                _updateState(
                  sessionId,
                  RawGpsVerificationState.authRequired,
                  uploadedCount,
                  payloads.length,
                  error: 'Authentication expired: $e',
                );
                return RawGpsVerificationReport(
                  workoutId: sessionId,
                  state: RawGpsVerificationState.authRequired,
                  localCount: localCanon.length,
                  cloudCount: 0,
                  localDigest:
                      RawGpsCanonicalVerification.computeCanonicalDigest(
                        localCanon,
                      ),
                  cloudDigest: null,
                  missingCloudSampleCount: localCanon.length,
                  extraCloudSampleCount: 0,
                  mismatchedSampleCount: 0,
                  message: 'Authentication failed during upload: $e',
                );
              }

              if (_isOfflineError(e)) {
                _updateState(
                  sessionId,
                  RawGpsVerificationState.pendingUpload,
                  uploadedCount,
                  payloads.length,
                  error: 'Offline/network unavailable: $e',
                );
                return RawGpsVerificationReport(
                  workoutId: sessionId,
                  state: RawGpsVerificationState.pendingUpload,
                  localCount: localCanon.length,
                  cloudCount: 0,
                  localDigest:
                      RawGpsCanonicalVerification.computeCanonicalDigest(
                        localCanon,
                      ),
                  cloudDigest: null,
                  missingCloudSampleCount: localCanon.length,
                  extraCloudSampleCount: 0,
                  mismatchedSampleCount: 0,
                  message:
                      'Device offline or network unavailable; raw GPS preserved locally.',
                );
              }

              if (attempt >= maxRetries) {
                _updateState(
                  sessionId,
                  RawGpsVerificationState.partial,
                  uploadedCount,
                  payloads.length,
                  error: 'Upload batch failed after $maxRetries attempts: $e',
                );
                rethrow;
              }

              final jitterMs = _random.nextInt(100);
              final backoffFactor = pow(2, attempt).toInt();
              final delay =
                  (baseRetryDelay * backoffFactor) +
                  Duration(milliseconds: jitterMs);
              await Future.delayed(delay);
            }
          }
        }

        // All chunks sent over HTTP: mark state UPLOADED_UNVERIFIED
        // CRITICAL P0-01: DO NOT call _markPointsSynced yet!
        _updateState(
          sessionId,
          RawGpsVerificationState.uploadedUnverified,
          uploadedCount,
          payloads.length,
        );
      }

      // 3. Post-Upload Canonical Read-Back Verification (P0-01)
      List<RawGpsPointPayload> cloudPoints;
      try {
        cloudPoints = await _rawTracking.fetchAllRawGpsPoints(sessionId);
      } catch (e) {
        if (_isAuthError(e)) {
          _updateState(
            sessionId,
            RawGpsVerificationState.authRequired,
            0,
            localCanon.length,
          );
          return RawGpsCanonicalVerification.verify(
            workoutId: sessionId,
            localPoints: localCanon,
            cloudPoints: const [],
            isAuthError: true,
          );
        }
        // Cloud read-back failed: local points stay retryable (NOT marked synced)
        _updateState(
          sessionId,
          RawGpsVerificationState.partial,
          0,
          localCanon.length,
          error: 'Read-back verification fetch failed: $e',
        );
        return RawGpsVerificationReport(
          workoutId: sessionId,
          state: RawGpsVerificationState.partial,
          localCount: localCanon.length,
          cloudCount: 0,
          localDigest: RawGpsCanonicalVerification.computeCanonicalDigest(
            localCanon,
          ),
          cloudDigest: null,
          missingCloudSampleCount: localCanon.length,
          extraCloudSampleCount: 0,
          mismatchedSampleCount: 0,
          message: 'Read-back verification failed to connect to cloud: $e',
        );
      }

      final cloudCanon =
          cloudPoints.map(CanonicalGpsPoint.fromPayload).toList();
      final report = RawGpsCanonicalVerification.verify(
        workoutId: sessionId,
        localPoints: localCanon,
        cloudPoints: cloudCanon,
      );

      _updateState(
        sessionId,
        report.state,
        report.cloudCount,
        report.localCount,
        error: report.isVerified ? null : report.message,
      );

      // Account may change while awaiting network. Never ACK another user's GPS.
      if (_currentUserId() != activeUser) {
        _updateState(sessionId, RawGpsVerificationState.authRequired, 0, 0);
        throw StateError('Authentication changed during raw GPS verification');
      }

      // 4. State ACK: ONLY mark Isar points as synced if read-back verification PASSED (P0-01)
      if (report.isVerified) {
        if (reconciled.isarPointIdsToMarkSynced.isNotEmpty) {
          await _markPointsSynced(reconciled.isarPointIdsToMarkSynced);
        }

        await _journal.checkpoint(
          sessionId,
          isFinalized: true,
          cloudVerified: true,
          cloudVerifiedCount: report.cloudCount,
          cloudVerifiedSha256: report.cloudDigest,
        );
      }

      return report;
    } finally {
      _inFlightSessions.remove(sessionId);
    }
  }

  /// Resumes eligible unfinished uploads for the authenticated user (P0-03).
  ///
  /// Can be safely invoked on app startup, connectivity recovery, or user sign-in.
  /// Bounded to [maxSessions] to avoid battery thrashing.
  Future<int> resumePendingUploads({
    int maxSessions = 5,
    Set<String> excludedSessionIds = const <String>{},
  }) async {
    final activeUser = _currentUserId();
    if (activeUser == null || activeUser.trim().isEmpty || maxSessions <= 0) {
      return 0;
    }
    if (_isProcessingOutbox) return 0;

    _isProcessingOutbox = true;
    var verifiedCount = 0;

    try {
      List<String> candidates;
      if (_getUnsyncedSessionIds != null) {
        // Legacy/test injection; production always uses owner-scoped discovery.
        candidates = await _getUnsyncedSessionIds(activeUser);
      } else {
        final ownedSessionIds = (await _getOwnedSessionIds(activeUser)).toSet();
        if (ownedSessionIds.isEmpty) return 0;
        final gpsPending = await _getPendingGpsSessionIds(activeUser);
        final journalPending = await _journal.listPendingSessionIdsForUser(
          activeUser,
          ownedSessionIds: ownedSessionIds,
        );
        candidates = <String>[
          ...gpsPending.where(ownedSessionIds.contains),
          ...journalPending,
        ];
      }

      // Deduplicate before applying the bounded work budget. Never replay
      // sessions queued for deletion, even when their local journal survives.
      final sessionsToProcess = candidates
          .where((id) => id.isNotEmpty && !excludedSessionIds.contains(id))
          .toSet()
          .toList()..sort();
      for (final sessionId in sessionsToProcess.take(maxSessions)) {
        if (_currentUserId() != activeUser) break; // logout/account switch
        try {
          final report = await uploadAndVerifySession(sessionId);
          if (report.isVerified) verifiedCount++;
        } catch (e) {
          debugPrint('[Outbox] Pending GPS retry failed for $sessionId: $e');
        }
      }
    } finally {
      _isProcessingOutbox = false;
    }

    return verifiedCount;
  }

  void _updateState(
    String sessionId,
    RawGpsVerificationState state,
    int processed,
    int total, {
    String? error,
  }) {
    _sessionStates[sessionId] = state;
    if (!_eventController.isClosed) {
      _eventController.add(
        RawGpsOutboxEvent(
          sessionId: sessionId,
          state: state,
          pointsProcessed: processed,
          totalPoints: total,
          error: error,
        ),
      );
    }
  }

  bool _isAuthError(Object error) {
    if (error is AuthException) return true;
    if (error is PostgrestException) {
      final code = error.code ?? '';
      return code == '401' ||
          code == 'PGRST301' ||
          error.message.toLowerCase().contains('jwt') ||
          error.message.toLowerCase().contains('unauthorized') ||
          error.message.toLowerCase().contains('forbidden');
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('auth');
  }

  bool _isOfflineError(Object error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    final msg = error.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('timed out') ||
        msg.contains('connection refused') ||
        msg.contains('no address associated');
  }
}
