import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Durable Cloud Upload Outbox service implementing RG-1B:
/// - Persists pending upload work across app restarts using Isar (`isSynced = false`).
/// - Recovers incomplete/in-flight chunks after crash or process restart.
/// - Uses bounded batches and exponential retry with jitter.
/// - Handles offline, network timeouts, 401/auth expiration, 429, and 5xx errors.
/// - Preserves raw GPS locally when uploads fail (never deletes unverified local points).
/// - Enforces idempotent ingestion without duplicate records.
/// - Executes canonical read-back verification after upload before transitioning to `CLOUD_VERIFIED`.
/// - Never deletes recovery journals automatically.
class RawGpsCloudOutboxService {
  final RawTrackingRemoteDataSource _rawTracking;
  final RawGpsRecoveryJournal _journal;
  final Future<List<LocalGPSPoint>> Function(String sessionId) _getUnsyncedPoints;
  final Future<List<LocalGPSPoint>> Function(String sessionId) _getAllLocalPoints;
  final Future<void> Function(List<int> ids) _markPointsSynced;
  final String? Function() _currentUserId;
  final int chunkSize;
  final Duration baseRetryDelay;
  final Random _random;

  final Map<String, RawGpsVerificationState> _sessionStates = {};
  final StreamController<RawGpsOutboxEvent> _eventController =
      StreamController<RawGpsOutboxEvent>.broadcast();

  RawGpsCloudOutboxService({
    required RawTrackingRemoteDataSource rawTracking,
    RawGpsRecoveryJournal? journal,
    Future<List<LocalGPSPoint>> Function(String sessionId)? getUnsyncedPoints,
    Future<List<LocalGPSPoint>> Function(String sessionId)? getAllLocalPoints,
    Future<void> Function(List<int> ids)? markPointsSynced,
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
       _currentUserId = currentUserId,
       _random = random ?? Random();

  Stream<RawGpsOutboxEvent> get events => _eventController.stream;

  RawGpsVerificationState stateForSession(String sessionId) {
    return _sessionStates[sessionId] ?? RawGpsVerificationState.unknown;
  }

  void dispose() {
    _eventController.close();
  }

  /// Uploads all unsynced points for [sessionId] with bounded batches, exponential backoff,
  /// and post-upload canonical read-back verification.
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

    _updateState(sessionId, RawGpsVerificationState.uploading, 0, 0);

    // 1. Fetch unsynced points for this session
    final unsynced = await _getUnsyncedPoints(sessionId);
    final allLocal = await _getAllLocalPoints(sessionId);

    // If local storage has 0 points total, check if journal has points that can be recovered
    var localCanon = allLocal.map(CanonicalGpsPoint.fromLocal).toList();
    if (localCanon.isEmpty) {
      final recovery = await _journal.readJournal(sessionId, activeUserId: activeUser);
      if (recovery.points.isNotEmpty) {
        localCanon = recovery.points.map(CanonicalGpsPoint.fromLocal).toList();
      }
    }

    if (localCanon.isEmpty) {
      _updateState(sessionId, RawGpsVerificationState.unknown, 0, 0);
      return RawGpsCanonicalVerification.verify(
        workoutId: sessionId,
        localPoints: const [],
        cloudPoints: const [],
      );
    }

    // 2. Upload unsynced points in bounded batches with retry and jitter
    if (unsynced.isNotEmpty) {
      final payloads = unsynced.map(LocalDB.rawGpsPointToPayload).toList(growable: false);
      final syncedPointIds = <int>[];

      for (var i = 0; i < payloads.length; i += chunkSize) {
        final end = (i + chunkSize < payloads.length) ? i + chunkSize : payloads.length;
        final batch = payloads.sublist(i, end);
        final batchPoints = unsynced.sublist(i, end);

        var attempt = 0;
        var batchSuccess = false;

        while (!batchSuccess && attempt < maxRetries) {
          try {
            await _rawTracking.saveRawGpsPoints(batch);
            batchSuccess = true;
            syncedPointIds.addAll(batchPoints.map((p) => p.id));
            _updateState(
              sessionId,
              RawGpsVerificationState.uploading,
              syncedPointIds.length,
              payloads.length,
            );
          } catch (e) {
            attempt++;
            if (_isAuthError(e)) {
              _updateState(
                sessionId,
                RawGpsVerificationState.authRequired,
                syncedPointIds.length,
                payloads.length,
                error: 'Authentication expired: $e',
              );
              // Stop immediately without spamming network
              return RawGpsVerificationReport(
                workoutId: sessionId,
                state: RawGpsVerificationState.authRequired,
                localCount: localCanon.length,
                cloudCount: 0,
                localDigest: RawGpsCanonicalVerification.computeCanonicalDigest(localCanon),
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
                syncedPointIds.length,
                payloads.length,
                error: 'Offline/network unavailable: $e',
              );
              // Safe retention: preserve points locally and abort
              return RawGpsVerificationReport(
                workoutId: sessionId,
                state: RawGpsVerificationState.pendingUpload,
                localCount: localCanon.length,
                cloudCount: 0,
                localDigest: RawGpsCanonicalVerification.computeCanonicalDigest(localCanon),
                cloudDigest: null,
                missingCloudSampleCount: localCanon.length,
                extraCloudSampleCount: 0,
                mismatchedSampleCount: 0,
                message: 'Device offline or network unavailable; raw GPS preserved locally.',
              );
            }

            if (attempt >= maxRetries) {
              _updateState(
                sessionId,
                RawGpsVerificationState.partial,
                syncedPointIds.length,
                payloads.length,
                error: 'Upload batch failed after $maxRetries attempts: $e',
              );
              rethrow;
            }

            // Exponential backoff with jitter
            final jitterMs = _random.nextInt(100);
            final backoffFactor = pow(2, attempt).toInt();
            final delay = (baseRetryDelay * backoffFactor) + Duration(milliseconds: jitterMs);
            await Future.delayed(delay);
          }
        }
      }

      // Mark locally succeeded points in Isar
      if (syncedPointIds.isNotEmpty) {
        await _markPointsSynced(syncedPointIds);
      }
    }

    // 3. Post-Upload Canonical Read-Back Verification
    // Do NOT trust HTTP 200/201 alone as final verification!
    List<RawGpsPointPayload> cloudPoints;
    try {
      cloudPoints = await _rawTracking.fetchAllRawGpsPoints(sessionId);
    } catch (e) {
      if (_isAuthError(e)) {
        _updateState(sessionId, RawGpsVerificationState.authRequired, 0, localCanon.length);
        return RawGpsCanonicalVerification.verify(
          workoutId: sessionId,
          localPoints: localCanon,
          cloudPoints: const [],
          isAuthError: true,
        );
      }
      _updateState(sessionId, RawGpsVerificationState.partial, 0, localCanon.length);
      rethrow;
    }

    final cloudCanon = cloudPoints.map(CanonicalGpsPoint.fromPayload).toList();
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

    // If verified, record trusted verification into journal manifest
    if (report.isVerified) {
      await _journal.checkpoint(
        sessionId,
        cloudVerified: true,
        cloudVerifiedCount: report.cloudCount,
        cloudVerifiedSha256: report.cloudDigest,
      );
    }

    return report;
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
    return msg.contains('401') || msg.contains('unauthorized') || msg.contains('auth');
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
