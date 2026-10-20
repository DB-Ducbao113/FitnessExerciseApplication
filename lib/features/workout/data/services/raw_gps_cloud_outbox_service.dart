import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/storage/database_helper.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/pending_workout_sync_store.dart';
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
        isSessionPendingDeletion: (sessionId, userId) async {
          // FAIL CLOSED (P0-02): Store read exceptions propagate so the outbox
          // never assumes upload is permitted on database failure.
          final store = PendingWorkoutSyncStore(DatabaseHelper.instance);
          final ops = await store.listForUser(userId);
          if (PendingWorkoutSyncStore.deletesAll(ops)) return true;
          return PendingWorkoutSyncStore.hiddenSessionIds(ops).contains(sessionId);
        },
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

/// Internal retry state tracking attempts and backoff for outbox fairness (P1-01).
class _SessionRetryState {
  final int retryCount;
  final DateTime lastRetryUtc;
  final DateTime? nextRetryUtc;

  const _SessionRetryState({
    required this.retryCount,
    required this.lastRetryUtc,
    this.nextRetryUtc,
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
  final RawGpsJournalManifest? manifest;
  final RawGpsRecoveryStatus journalStatus;
  final bool hasTruncatedFinalLine;
  final bool isLocalCaptureIncomplete;
  final int? expectedSampleCount;
  final String? expectedDigest;
  final String? incompleteReason;

  const ReconciledLocalCapture({
    required this.canonicalPoints,
    required this.payloadsToUpload,
    required this.isarPointIdsToMarkSynced,
    required this.hasCorruptedJournal,
    required this.corruptedJournalLines,
    required this.isarCount,
    required this.journalCount,
    this.manifest,
    this.journalStatus = RawGpsRecoveryStatus.emptyOrNotFound,
    this.hasTruncatedFinalLine = false,
    this.isLocalCaptureIncomplete = false,
    this.expectedSampleCount,
    this.expectedDigest,
    this.incompleteReason,
  });

  factory ReconciledLocalCapture.empty() => const ReconciledLocalCapture(
    canonicalPoints: [],
    payloadsToUpload: [],
    isarPointIdsToMarkSynced: [],
    hasCorruptedJournal: false,
    corruptedJournalLines: 0,
    isarCount: 0,
    journalCount: 0,
    journalStatus: RawGpsRecoveryStatus.emptyOrNotFound,
  );
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
  final Future<bool> Function(String sessionId, String userId)?
      _ownershipVerifier;
  final Future<bool> Function(String sessionId, String userId)?
      _isSessionPendingDeletion;
  final String? Function() _currentUserId;
  final int chunkSize;
  final Duration baseRetryDelay;
  final Duration Function(int attempt)? _retryBackoffCalculator;
  final Random _random;

  final Map<String, RawGpsVerificationState> _sessionStates = {};
  final Set<String> _inFlightSessions = {};
  final Map<String, _SessionRetryState> _retryStates = {};
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
    Future<bool> Function(String sessionId, String userId)? ownershipVerifier,
    Future<bool> Function(String sessionId, String userId)?
        isSessionPendingDeletion,
    required String? Function() currentUserId,
    this.chunkSize = 250,
    this.baseRetryDelay = const Duration(milliseconds: 150),
    Duration Function(int attempt)? retryBackoffCalculator,
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
       _ownershipVerifier = ownershipVerifier,
       _isSessionPendingDeletion = isSessionPendingDeletion,
       _currentUserId = currentUserId,
       _retryBackoffCalculator = retryBackoffCalculator,
       _random = random ?? Random();

  Stream<RawGpsOutboxEvent> get events => _eventController.stream;

  RawGpsVerificationState stateForSession(String sessionId) {
    return _sessionStates[sessionId] ?? RawGpsVerificationState.unknown;
  }

  int getRetryCount(String sessionId) =>
      _retryStates[sessionId]?.retryCount ?? 0;

  DateTime? getNextRetryUtc(String sessionId) =>
      _retryStates[sessionId]?.nextRetryUtc;

  Duration computeBackoff(int attempt) {
    final calc = _retryBackoffCalculator;
    if (calc != null) {
      return calc(attempt);
    }
    // Exponential backoff: 15s * 2^(attempt - 1), capped at 300s (5m), plus 0..5s jitter
    final factor = pow(2, min(attempt - 1, 5)).toInt();
    final baseSecs = min(15 * factor, 300);
    final jitterSecs = _random.nextInt(5);
    return Duration(seconds: baseSecs + jitterSecs);
  }

  Future<void> _recordRetrySuccess(String sessionId) async {
    _retryStates.remove(sessionId);
    try {
      await _journal.recordRetryAttempt(sessionId, success: true);
    } catch (_) {}
  }

  Future<void> _recordRetryFailure(
    String sessionId, {
    Duration? overrideBackoff,
  }) async {
    final current = _retryStates[sessionId];
    final newCount = (current?.retryCount ?? 0) + 1;
    final backoff = overrideBackoff ?? computeBackoff(newCount);
    final now = DateTime.now().toUtc();
    final nextRetry = now.add(backoff);
    _retryStates[sessionId] = _SessionRetryState(
      retryCount: newCount,
      lastRetryUtc: now,
      nextRetryUtc: nextRetry,
    );
    try {
      await _journal.recordRetryAttempt(
        sessionId,
        success: false,
        nextBackoff: backoff,
      );
    } catch (_) {}
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
    if (kIsWeb) {
      return ReconciledLocalCapture.empty();
    }
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

    final manifest = journalResult.manifest;
    bool isLocalCaptureIncomplete = false;
    int? expectedSampleCount;
    String? expectedDigest;
    String? incompleteReason;

    if (manifest != null && manifest.sampleCount > 0) {
      expectedSampleCount = manifest.sampleCount;
      expectedDigest = manifest.canonicalCaptureDigest;

      if (canonicalPoints.length < manifest.sampleCount) {
        isLocalCaptureIncomplete = true;
        incompleteReason =
            'Incomplete local capture: found ${canonicalPoints.length} points, but manifest specifies ${manifest.sampleCount} captured samples.';
      } else if (manifest.canonicalCaptureDigest != null &&
          manifest.canonicalCaptureDigest!.isNotEmpty &&
          manifest.schemaVersion != RawGpsJournalManifest.schemaVersionV1 &&
          journalResult.status != RawGpsRecoveryStatus.staleCheckpoint) {
        final localDigest =
            RawGpsCanonicalVerification.computeCanonicalDigest(canonicalPoints);
        if (localDigest != manifest.canonicalCaptureDigest) {
          isLocalCaptureIncomplete = true;
          incompleteReason =
              'Incomplete local capture: local canonical digest ($localDigest) does not match manifest capture digest (${manifest.canonicalCaptureDigest}).';
        }
      }
    } else if (manifest == null) {
      final lostLines = journalResult.corruptedLinesCount +
          (journalResult.hasTruncatedFinalLine ? 1 : 0);
      if (lostLines > 0) {
        final totalRecovered = canonicalPoints.length;
        final minExpected = journalResult.points.length + lostLines;
        if (totalRecovered < minExpected) {
          isLocalCaptureIncomplete = true;
          expectedSampleCount = minExpected;
          incompleteReason =
              'Incomplete local capture: journal suffered data loss ($lostLines corrupted/truncated lines) and Isar only supplied $totalRecovered/$minExpected samples.';
        }
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
      manifest: manifest,
      journalStatus: journalResult.status,
      hasTruncatedFinalLine: journalResult.hasTruncatedFinalLine,
      isLocalCaptureIncomplete: isLocalCaptureIncomplete,
      expectedSampleCount: expectedSampleCount,
      expectedDigest: expectedDigest,
      incompleteReason: incompleteReason,
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
    if (kIsWeb) {
      _updateState(sessionId, RawGpsVerificationState.unsupported, 0, 0);
      return RawGpsCanonicalVerification.unsupportedPlatform(
        workoutId: sessionId,
        platform: 'web',
      );
    }
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

    // Respect sessions pending explicit deletion (RG-F1.3 / P0-02)
    final pendingDeletionCheck = _isSessionPendingDeletion;
    if (pendingDeletionCheck != null) {
      bool isPending;
      try {
        isPending = await pendingDeletionCheck(sessionId, activeUser);
      } catch (e) {
        // FAIL CLOSED (P0-02): If deletion store cannot be verified, NEVER assume upload is permitted.
        // Preserve raw GPS safely locally without uploading to cloud.
        debugPrint(
          '[Outbox] Failed to verify deletion state for session $sessionId: $e. Preserving raw GPS locally.',
        );
        _updateState(
          sessionId,
          RawGpsVerificationState.pendingUpload,
          0,
          0,
          error: 'Deletion state indeterminate: $e',
        );
        return RawGpsVerificationReport(
          workoutId: sessionId,
          state: RawGpsVerificationState.pendingUpload,
          localCount: 0,
          cloudCount: 0,
          localDigest: RawGpsCanonicalVerification.emptyDigest,
          cloudDigest: null,
          missingCloudSampleCount: 0,
          extraCloudSampleCount: 0,
          mismatchedSampleCount: 0,
          message:
              'Deletion state cannot be determined safely ($e); preserving raw GPS locally without cloud upload.',
        );
      }

      if (isPending) {
        debugPrint(
          '[Outbox] Skipping upload for session pending deletion: $sessionId',
        );
        return RawGpsVerificationReport(
          workoutId: sessionId,
          state: RawGpsVerificationState.unknown,
          localCount: 0,
          cloudCount: 0,
          localDigest: RawGpsCanonicalVerification.emptyDigest,
          cloudDigest: null,
          missingCloudSampleCount: 0,
          extraCloudSampleCount: 0,
          mismatchedSampleCount: 0,
          message: 'Session is pending explicit deletion.',
        );
      }
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
          if (_currentUserId() != activeUser) {
            _updateState(sessionId, RawGpsVerificationState.authRequired, 0, 0);
            throw StateError(
              'Authentication changed during raw GPS verification',
            );
          }
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
                await _recordRetryFailure(sessionId);
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
                await _recordRetryFailure(sessionId);
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

      if (_currentUserId() != activeUser) {
        _updateState(sessionId, RawGpsVerificationState.authRequired, 0, 0);
        throw StateError('Authentication changed during raw GPS verification');
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
        await _recordRetryFailure(sessionId);
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
      RawGpsVerificationReport report;

      var manifest = reconciled.manifest;

      // RG-F1: Provenance-based upgrade for legacy v1 manifests.
      // If upgrading a legacy manifest to v2, require a demonstrably trustworthy original capture source
      // and validated provenance. Never manufacture proof from cloud read-back.
      if (manifest != null &&
          manifest.schemaVersion == RawGpsJournalManifest.schemaVersionV1) {
        final hasValidatedProvenance =
            reconciled.journalStatus == RawGpsRecoveryStatus.verifiedIntact &&
            manifest.fileSha256 != null &&
            manifest.fileSha256!.isNotEmpty &&
            !reconciled.hasTruncatedFinalLine &&
            reconciled.corruptedJournalLines == 0 &&
            reconciled.journalCount == manifest.sampleCount &&
            reconciled.canonicalPoints.length == manifest.sampleCount &&
            !reconciled.isLocalCaptureIncomplete;

        if (hasValidatedProvenance) {
          final trustedDigest =
              RawGpsCanonicalVerification.computeCanonicalDigest(
            reconciled.canonicalPoints,
          );
          manifest = manifest.copyWith(
            schemaVersion: RawGpsJournalManifest.currentSchemaVersion,
            canonicalCaptureDigest: trustedDigest,
          );
        }
      }

      if (reconciled.isLocalCaptureIncomplete) {
        // Enforce journal integrity and sample completeness before marking CLOUD_VERIFIED (P0-A).
        // If local capture was corrupted or truncated without complete Isar backup,
        // it can NEVER be CLOUD_VERIFIED, even if cloud matches the partial local subset.
        final localDigest =
            RawGpsCanonicalVerification.computeCanonicalDigest(localCanon);
        final cloudDigest =
            RawGpsCanonicalVerification.computeCanonicalDigest(cloudCanon);
        final expectedCount = reconciled.expectedSampleCount ??
            (localCanon.length + reconciled.corruptedJournalLines);
        report = RawGpsVerificationReport(
          workoutId: sessionId,
          state: RawGpsVerificationState.partial,
          localCount: expectedCount,
          cloudCount: cloudCanon.length,
          localDigest: reconciled.expectedDigest ?? localDigest,
          cloudDigest: cloudDigest,
          missingCloudSampleCount: expectedCount > cloudCanon.length
              ? expectedCount - cloudCanon.length
              : 1,
          extraCloudSampleCount: 0,
          mismatchedSampleCount: 0,
          message: reconciled.incompleteReason ??
              'Partial local capture: journal records were corrupted/truncated without complete Isar backup; marked as PARTIAL.',
        );
      } else if (reconciled.journalStatus ==
          RawGpsRecoveryStatus.staleCheckpoint) {
        // QA-2: Stale checkpoint verification.
        // An existing stale checkpoint covers only a historical subset of local samples.
        // Fallback verification must NEVER grant CLOUD_VERIFIED without validated capture completeness.
        // When capture completeness proof is unavailable, preserve all original samples and fail closed
        // to RESTORED_UNVERIFIED (or PARTIAL if cloud records are incomplete).
        // Verified completion (CLOUD_VERIFIED) is permitted only after trusted recovery/checkpoint validation.
        final localDigest =
            RawGpsCanonicalVerification.computeCanonicalDigest(localCanon);
        final cloudDigest =
            RawGpsCanonicalVerification.computeCanonicalDigest(cloudCanon);
        final isCloudComplete = cloudCanon.length >= localCanon.length;

        if (!isCloudComplete) {
          report = RawGpsVerificationReport(
            workoutId: sessionId,
            state: RawGpsVerificationState.partial,
            localCount: localCanon.length,
            cloudCount: cloudCanon.length,
            localDigest: localDigest,
            cloudDigest: cloudDigest,
            missingCloudSampleCount: localCanon.length - cloudCanon.length,
            extraCloudSampleCount: 0,
            mismatchedSampleCount: 0,
            message:
                'Stale checkpoint recovery: partial cloud records (${cloudCanon.length}/${localCanon.length}); marked as PARTIAL.',
          );
        } else {
          report = RawGpsVerificationReport(
            workoutId: sessionId,
            state: RawGpsVerificationState.restoredUnverified,
            localCount: localCanon.length,
            cloudCount: cloudCanon.length,
            localDigest: localDigest,
            cloudDigest: cloudDigest,
            missingCloudSampleCount: 0,
            extraCloudSampleCount: cloudCanon.length > localCanon.length
                ? cloudCanon.length - localCanon.length
                : 0,
            mismatchedSampleCount: 0,
            message:
                'Capture manifest contains a stale unfinalized checkpoint (${manifest?.sampleCount ?? 0} samples) '
                'which does not validate full original capture completeness (${localCanon.length} samples); '
                'failing closed to RESTORED_UNVERIFIED without fabricating verification.',
          );
        }
      } else if (manifest != null) {
        report = RawGpsCanonicalVerification.verifyAgainstManifest(
          workoutId: sessionId,
          manifest: manifest,
          cloudPoints: cloudCanon,
        );
      } else {
        report = RawGpsCanonicalVerification.verify(
          workoutId: sessionId,
          localPoints: localCanon,
          cloudPoints: cloudCanon,
        );
      }

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
          canonicalCaptureDigest: report.localDigest,
          schemaVersion: RawGpsJournalManifest.currentSchemaVersion,
          verificationState: RawGpsVerificationState.cloudVerified.name,
        );
        await _recordRetrySuccess(sessionId);
      } else if (report.state == RawGpsVerificationState.restoredUnverified) {
        // Fail-closed legacy recovery & unverified capture (QA-1 & QA-2):
        // Cloud copy consistency requires full canonical data equality across all mutually
        // preserved fields (timestamp, lat, lng, altitude, speed, accuracy, heading, deviceSource),
        // NOT identityKey equality alone.
        // Invariants:
        // 1. Do NOT mark Isar points as synced (no false Isar sync ACK).
        // 2. Do NOT set cloudVerified to true.
        // 3. Checkpoint manifest with verificationState = 'restoredUnverified' ONLY when full canonical
        //    copy consistency is established, ensuring discovery and outbox agree on completion.
        // 4. If copy is inconsistent, do NOT mark completed and do NOT suppress necessary retry
        //    (invoke _recordRetryFailure).
        final localDigest =
            RawGpsCanonicalVerification.computeCanonicalDigest(localCanon);
        final cloudDigest =
            RawGpsCanonicalVerification.computeCanonicalDigest(cloudCanon);
        final isCloudCopyConsistent = cloudCanon.length == localCanon.length &&
            localDigest == cloudDigest &&
            localCanon.every((lp) => cloudCanon.any((cp) => cp == lp));

        if (isCloudCopyConsistent) {
          await _journal.checkpoint(
            sessionId,
            isFinalized: true,
            cloudVerified: false,
            cloudVerifiedCount: report.cloudCount,
            cloudVerifiedSha256: report.cloudDigest,
            canonicalCaptureDigest: null,
            verificationState: RawGpsVerificationState.restoredUnverified.name,
          );
          await _recordRetrySuccess(sessionId);
        } else {
          await _recordRetryFailure(sessionId);
        }
      } else {
        await _recordRetryFailure(sessionId);
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
    if (kIsWeb) return 0;
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
        final gpsPending = await _getPendingGpsSessionIds(activeUser);
        final journalPending = await _journal.listPendingSessionIdsForUser(
          activeUser,
          ownedSessionIds: ownedSessionIds,
          ownershipVerifier: _ownershipVerifier,
        );
        candidates = <String>[
          ...gpsPending.where(ownedSessionIds.contains),
          ...journalPending,
        ];
      }

      // Deduplicate before applying the bounded work budget. Never replay
      // sessions queued for deletion, even when their local journal survives.
      final pendingDeletionCheck = _isSessionPendingDeletion;
      final eligibleSessions = <String>[];
      final now = DateTime.now().toUtc();

      for (final id in candidates.toSet()) {
        if (id.isEmpty || excludedSessionIds.contains(id)) continue;

        if (pendingDeletionCheck != null) {
          try {
            final isPending = await pendingDeletionCheck(id, activeUser);
            if (isPending) continue;
          } catch (e) {
            // FAIL CLOSED (P0-02): If deletion status cannot be determined due to DB failure,
            // DO NOT upload this session! Preserve it locally and skip from current upload run.
            debugPrint(
              '[Outbox] Cannot determine deletion status for candidate $id ($e); skipping upload.',
            );
            continue;
          }
        }

        final candidateManifest = await _journal.readManifest(id);
        if (candidateManifest != null) {
          final hasTrustedCaptureProof = candidateManifest.canonicalCaptureDigest != null &&
              candidateManifest.canonicalCaptureDigest!.isNotEmpty &&
              candidateManifest.schemaVersion != RawGpsJournalManifest.schemaVersionV1 &&
              candidateManifest.cloudVerifiedSha256 != null &&
              candidateManifest.cloudVerifiedSha256 == candidateManifest.canonicalCaptureDigest;

          final isCompletedVerified = candidateManifest.cloudVerified &&
              candidateManifest.cloudVerifiedCount >= candidateManifest.sampleCount &&
              hasTrustedCaptureProof;

          final isCompletedRestoredUnverified =
              (candidateManifest.verificationState ==
                      RawGpsVerificationState.restoredUnverified.name ||
                  candidateManifest.verificationState == 'restoredUnverified') &&
              candidateManifest.cloudVerifiedCount >= candidateManifest.sampleCount &&
              candidateManifest.cloudVerifiedSha256 != null;

          if (isCompletedVerified || isCompletedRestoredUnverified) {
            continue;
          }
        }

        var retryState = _retryStates[id];
        if (retryState == null) {
          if (candidateManifest != null &&
              candidateManifest.lastRetryTimestampUtc != null) {
            retryState = _SessionRetryState(
              retryCount: candidateManifest.retryCount,
              lastRetryUtc: candidateManifest.lastRetryTimestampUtc!,
              nextRetryUtc: candidateManifest.nextRetryTimestampUtc,
            );
            _retryStates[id] = retryState;
          }
        }

        if (retryState?.nextRetryUtc != null &&
            now.isBefore(retryState!.nextRetryUtc!)) {
          debugPrint(
            '[Outbox] Candidate $id is in retry backoff until ${retryState.nextRetryUtc} (attempt #${retryState.retryCount}); skipping to prevent starvation.',
          );
          continue;
        }

        eligibleSessions.add(id);
      }

      // Fair scheduling (P1-01): Sort by least-recently-attempted to prevent starvation
      eligibleSessions.sort((a, b) {
        final aTime = _retryStates[a]?.lastRetryUtc;
        final bTime = _retryStates[b]?.lastRetryUtc;
        if (aTime == null && bTime != null) return -1;
        if (aTime != null && bTime == null) return 1;
        if (aTime != null && bTime != null) {
          final cmp = aTime.compareTo(bTime);
          if (cmp != 0) return cmp;
        }
        return a.compareTo(b);
      });

      for (final sessionId in eligibleSessions.take(maxSessions)) {
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
