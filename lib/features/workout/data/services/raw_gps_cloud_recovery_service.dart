import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';

/// Result of a cloud download and reconciliation operation.
class RawGpsCloudRecoveryResult {
  final String workoutId;
  final RawGpsVerificationState state;
  final int restoredPointsCount;
  final int preservedLocalPointsCount;
  final int totalPointsCount;
  final RawGpsVerificationReport? verificationReport;
  final String message;

  const RawGpsCloudRecoveryResult({
    required this.workoutId,
    required this.state,
    required this.restoredPointsCount,
    required this.preservedLocalPointsCount,
    required this.totalPointsCount,
    this.verificationReport,
    required this.message,
  });

  bool get isSuccess =>
      state == RawGpsVerificationState.cloudVerified ||
      (state != RawGpsVerificationState.authRequired &&
          state != RawGpsVerificationState.integrityMismatch);
}

/// Service implementing Cloud Download and Recovery for RG-1B:
/// - Downloads raw GPS for an authenticated user's workout with pagination.
/// - Verifies account/workout ownership using authenticated Supabase context and RLS.
/// - Reconciles cloud records against local Isar and journal.
/// - Deterministically deduplicates records by (timestamp, lat, lng).
/// - NEVER overwrites a richer local record with a cloud record missing fields.
/// - Does NOT reconstruct unavailable `confidence` or other local-only fields as if they were original.
/// - Historical workouts without a reliable manifest remain UNKNOWN until verified.
/// - NEVER fabricates workout distance or automatically finalizes crashed sessions.
class RawGpsCloudRecoveryService {
  final RawTrackingRemoteDataSource _rawTracking;
  final RawGpsRecoveryJournal _journal;
  final Future<List<LocalGPSPoint>> Function(String sessionId) _getLocalPoints;
  final Future<void> Function(List<LocalGPSPoint> points) _saveLocalPoints;
  final String? Function() _currentUserId;

  RawGpsCloudRecoveryService({
    required RawTrackingRemoteDataSource rawTracking,
    RawGpsRecoveryJournal? journal,
    Future<List<LocalGPSPoint>> Function(String sessionId)? getLocalPoints,
    Future<void> Function(List<LocalGPSPoint> points)? saveLocalPoints,
    required String? Function() currentUserId,
  }) : _rawTracking = rawTracking,
       _journal = journal ?? RawGpsRecoveryJournal.instance,
       _getLocalPoints = getLocalPoints ?? LocalDB.getPointsForSession,
       _saveLocalPoints = saveLocalPoints ?? LocalDB.savePoints,
       _currentUserId = currentUserId;

  /// Restores raw GPS points from cloud for [workoutId], reconciling against local records.
  Future<RawGpsCloudRecoveryResult> restoreRawGpsFromCloud(
    String workoutId, {
    int pageSize = 1000,
  }) async {
    final userId = _currentUserId();
    if (userId == null || userId.trim().isEmpty) {
      return RawGpsCloudRecoveryResult(
        workoutId: workoutId,
        state: RawGpsVerificationState.authRequired,
        restoredPointsCount: 0,
        preservedLocalPointsCount: 0,
        totalPointsCount: 0,
        message: 'User authentication required to restore raw GPS from cloud.',
      );
    }

    // 1. Fetch all cloud points via pagination
    List<RawGpsPointPayload> cloudPayloads;
    try {
      cloudPayloads = await _rawTracking.fetchAllRawGpsPoints(
        workoutId,
        pageSize: pageSize,
      );
    } catch (e) {
      return RawGpsCloudRecoveryResult(
        workoutId: workoutId,
        state: RawGpsVerificationState.unknown,
        restoredPointsCount: 0,
        preservedLocalPointsCount: 0,
        totalPointsCount: 0,
        message: 'Failed to download raw GPS from cloud: $e',
      );
    }

    // 2. Fetch existing local points (Isar and/or Journal)
    var existingLocal = await _getLocalPoints(workoutId);
    if (existingLocal.isEmpty) {
      final recovery = await _journal.readJournal(workoutId, activeUserId: userId);
      if (recovery.points.isNotEmpty) {
        existingLocal = recovery.points;
      }
    }

    // If cloud has 0 rows
    if (cloudPayloads.isEmpty) {
      return RawGpsCloudRecoveryResult(
        workoutId: workoutId,
        state: existingLocal.isEmpty
            ? RawGpsVerificationState.unknown
            : RawGpsVerificationState.pendingUpload,
        restoredPointsCount: 0,
        preservedLocalPointsCount: existingLocal.length,
        totalPointsCount: existingLocal.length,
        message: existingLocal.isEmpty
            ? 'No records found in cloud or local storage.'
            : 'No cloud records found; local records are pending upload.',
      );
    }

    // 3. Reconcile cloud records against local records:
    // RULE: "Never overwrite a richer local record with a cloud record missing fields."
    // RULE: "Do not reconstruct unavailable confidence or other local-only fields as if they were original."
    final localMap = <String, LocalGPSPoint>{};
    for (final p in existingLocal) {
      final key =
          '${p.timestamp.toUtc().microsecondsSinceEpoch}|${p.latitude.toStringAsFixed(7)}|${p.longitude.toStringAsFixed(7)}';
      localMap[key] = p;
    }

    final pointsToInsert = <LocalGPSPoint>[];
    var preservedLocalCount = 0;
    final seenKeys = <String>{...localMap.keys};

    for (final cp in cloudPayloads) {
      final key =
          '${cp.timestamp.toUtc().microsecondsSinceEpoch}|${cp.latitude.toStringAsFixed(7)}|${cp.longitude.toStringAsFixed(7)}';
      if (localMap.containsKey(key)) {
        // Richer local record already exists locally: PRESERVE IT!
        preservedLocalCount++;
      } else if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        // Point is missing locally: restore from cloud with isSynced = true
        // and explicit 'cloud_restored' confidence marker (do not fabricate sensor confidence).
        final restoredPoint = LocalGPSPoint()
          ..sessionId = workoutId
          ..timestamp = cp.timestamp.toUtc()
          ..latitude = cp.latitude
          ..longitude = cp.longitude
          ..altitude = cp.altitude
          ..speed = cp.speed
          ..accuracy = cp.accuracy
          ..heading = cp.heading
          ..deviceSource = cp.deviceSource
          ..confidence = 'cloud_restored'
          ..isSynced = true;
        pointsToInsert.add(restoredPoint);
      }
    }

    if (pointsToInsert.isNotEmpty) {
      await _saveLocalPoints(pointsToInsert);
    }

    final allLocalAfter = await _getLocalPoints(workoutId);
    final localCanon = allLocalAfter.map(CanonicalGpsPoint.fromLocal).toList();
    final cloudCanon = cloudPayloads.map(CanonicalGpsPoint.fromPayload).toList();
    final report = RawGpsCanonicalVerification.verify(
      workoutId: workoutId,
      localPoints: localCanon,
      cloudPoints: cloudCanon,
    );

    return RawGpsCloudRecoveryResult(
      workoutId: workoutId,
      state: report.state,
      restoredPointsCount: pointsToInsert.length,
      preservedLocalPointsCount: preservedLocalCount,
      totalPointsCount: allLocalAfter.length,
      verificationReport: report,
      message:
          'Cloud recovery complete: ${pointsToInsert.length} points restored, '
          '$preservedLocalCount local points preserved without overwrite.',
    );
  }
}
