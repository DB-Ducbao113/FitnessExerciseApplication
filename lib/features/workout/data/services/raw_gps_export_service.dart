import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/core/constants/db_tables.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_export_bundle.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_session_quality.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_dataset_exporter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_quality_analyzer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final rawGpsExportServiceProvider = Provider<RawGpsExportService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final rawTracking = ref.watch(rawTrackingRemoteDataSourceProvider);
  return RawGpsExportService(
    supabaseClient: supabase,
    remoteDataSource: rawTracking,
    currentUserIdProvider: () => ref.read(currentUserIdProvider),
  );
});

/// Security exception thrown when attempting unauthorized export across account boundaries.
class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

/// Service orchestrating account-scoped raw GPS dataset exports and native sharing (RG-F4).
class RawGpsExportService {
  final SupabaseClient? _supabaseClient;
  final RawTrackingRemoteDataSource? _remoteDataSource;
  final RawGpsRecoveryJournal _journal;
  final String? Function()? _currentUserIdProvider;

  RawGpsExportService({
    SupabaseClient? supabaseClient,
    RawTrackingRemoteDataSource? remoteDataSource,
    RawGpsRecoveryJournal? journal,
    String? Function()? currentUserIdProvider,
  })  : _supabaseClient = supabaseClient,
        _remoteDataSource = remoteDataSource,
        _journal = journal ?? RawGpsRecoveryJournal.instance,
        _currentUserIdProvider = currentUserIdProvider;

  /// Exports an owner-selected workout session into a deterministic research bundle.
  ///
  /// Evaluates local recovery journals first. If verified local capture proof exists,
  /// tags as `device_journal_verified`. If recovered without full proof, tags as
  /// `device_recovered_unverified`. If only present in Supabase cloud, tags as
  /// `cloud_only_unverified`.
  Future<RawGpsExportBundle> exportSession({
    required String workoutId,
    String? activeUserId,
    String? appCommit,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Research-grade raw GPS dataset export is unsupported on web.',
      );
    }

    final userId = _resolveUserId(activeUserId);

    // 1. Check local write-ahead recovery journal
    final journalResult = await _journal.readJournal(
      workoutId,
      activeUserId: userId,
    );

    if (journalResult.status == RawGpsRecoveryStatus.accountMismatch) {
      throw SecurityException(
        'Session $workoutId belongs to another user account.',
      );
    }

    if (journalResult.points.isNotEmpty) {
      final manifest = journalResult.manifest;

      // Ensure trusted ownership metadata exists and matches active user
      if (manifest == null || manifest.userId == null || manifest.userId!.isEmpty) {
        throw SecurityException(
          'Owner authorization failure: Journal for workout $workoutId lacks trusted owner metadata.',
        );
      }
      if (manifest.userId != userId) {
        throw SecurityException(
          'Session $workoutId belongs to another user account (${manifest.userId} != $userId).',
        );
      }

      final rawPoints = journalResult.points
          .map((p) => RawGpsExportPoint.fromLocal(p))
          .toList(growable: false);

      final isVerified = await _isJournalIntactAndVerified(
        workoutId,
        rawPoints,
        manifest,
        journalResult.status,
      );

      final sourceKind = isVerified
          ? RawGpsExportSourceKind.deviceJournalVerified
          : RawGpsExportSourceKind.deviceRecoveredUnverified;

      return RawGpsDatasetExporter.buildBundle(
        workoutId: workoutId,
        rawPoints: rawPoints,
        sourceKind: sourceKind,
        rawJsonlByteSha256: isVerified ? manifest.fileSha256 : null,
        canonicalCaptureDigest:
            isVerified ? manifest.canonicalCaptureDigest : null,
        appCommit: appCommit,
      );
    }

    // 2. Check local Isar storage
    final isarPoints = await LocalDB.getPointsForSession(workoutId);
    if (isarPoints.isNotEmpty) {
      final localWorkout = await LocalDB.getSessionById(workoutId);
      final manifest = await _journal.readManifest(workoutId);

      // Check trusted owner metadata:
      // Must be proven either by LocalWorkout.userId or an orphan journal manifest.userId
      final String? ownerId;
      if (localWorkout != null && localWorkout.userId.isNotEmpty) {
        ownerId = localWorkout.userId;
      } else if (manifest != null && manifest.userId != null && manifest.userId!.isNotEmpty) {
        // Legitimate orphan journal recovery pathway
        ownerId = manifest.userId;
      } else {
        ownerId = null;
      }

      if (ownerId == null) {
        throw SecurityException(
          'Owner authorization failure: Isar points exist for workout $workoutId but no trusted owner metadata was found. Never infer ownership from session ID.',
        );
      }

      if (ownerId != userId) {
        throw SecurityException(
          'Local workout $workoutId belongs to another user ($ownerId != $userId).',
        );
      }

      final rawPoints = isarPoints
          .map((p) => RawGpsExportPoint.fromLocal(p))
          .toList(growable: false);

      return RawGpsDatasetExporter.buildBundle(
        workoutId: workoutId,
        rawPoints: rawPoints,
        sourceKind: RawGpsExportSourceKind.deviceRecoveredUnverified,
        appCommit: appCommit,
      );
    }

    // 3. Fallback to authenticated historical Supabase export
    return exportHistoricalCloudSession(
      workoutId: workoutId,
      activeUserId: userId,
      appCommit: appCommit,
    );
  }

  /// Exports an existing historical raw GPS session from Supabase cloud database.
  ///
  /// Strictly verifies ownership via `workout_sessions.user_id == auth.uid()`.
  /// Never fabricates missing original capture proof; always labels as `cloud_only_unverified`.
  Future<RawGpsExportBundle> exportHistoricalCloudSession({
    required String workoutId,
    String? activeUserId,
    String? appCommit,
  }) async {
    final userId = _resolveUserId(activeUserId);

    if (_supabaseClient == null || _remoteDataSource == null) {
      throw StateError(
        'Supabase client and remote datasource are required for cloud dataset export.',
      );
    }

    // Account isolation check: verify session ownership
    final sessionData = await _supabaseClient
        .from(DbTables.workoutSessions)
        .select('id, user_id')
        .eq('id', workoutId)
        .maybeSingle();

    if (sessionData == null) {
      throw StateError(
        'Workout session $workoutId was not found in cloud database.',
      );
    }

    final ownerId = sessionData['user_id'] as String?;
    if (ownerId != userId) {
      throw SecurityException(
        'Cross-account violation: Workout $workoutId is not owned by user $userId.',
      );
    }

    // Fetch all points with deterministic PostgREST pagination (handles >1000 points)
    final payloads = await _remoteDataSource.fetchAllRawGpsPoints(workoutId);
    final rawPoints = payloads
        .map((p) => RawGpsExportPoint.fromPayload(p))
        .toList(growable: false);

    return RawGpsDatasetExporter.buildBundle(
      workoutId: workoutId,
      rawPoints: rawPoints,
      sourceKind: RawGpsExportSourceKind.cloudOnlyUnverified,
      rawJsonlByteSha256: null,
      canonicalCaptureDigest: null,
      appCommit: appCommit,
    );
  }

  /// Verifies that all prepared export files exist on disk and strictly match
  /// the cryptographic SHA-256 hashes advertised in the companion manifest.
  static bool verifyExportFiles(
    List<File> files,
    RawGpsExportManifest manifest,
  ) {
    if (files.length < 4) {
      throw StateError('Expected 4 export files, found ${files.length}');
    }

    final jsonlFile = files[0];
    final csvFile = files[1];
    final gpxFile = files[2];
    final manifestFile = files[3];

    if (!jsonlFile.existsSync() ||
        !csvFile.existsSync() ||
        !gpxFile.existsSync() ||
        !manifestFile.existsSync()) {
      throw StateError('One or more export files are missing on disk.');
    }

    final jsonlBytes = jsonlFile.readAsBytesSync();
    final jsonlHash = sha256.convert(jsonlBytes).toString();
    if (jsonlHash.toLowerCase() != manifest.exportJsonlSha256.toLowerCase()) {
      throw StateError(
        'JSONL file SHA-256 mismatch ($jsonlHash != ${manifest.exportJsonlSha256}).',
      );
    }

    final csvBytes = csvFile.readAsBytesSync();
    final csvHash = sha256.convert(csvBytes).toString();
    if (csvHash.toLowerCase() != manifest.exportCsvSha256.toLowerCase()) {
      throw StateError(
        'CSV file SHA-256 mismatch ($csvHash != ${manifest.exportCsvSha256}).',
      );
    }

    final gpxBytes = gpxFile.readAsBytesSync();
    final gpxHash = sha256.convert(gpxBytes).toString();
    if (gpxHash.toLowerCase() != manifest.exportGpxSha256.toLowerCase()) {
      throw StateError(
        'GPX file SHA-256 mismatch ($gpxHash != ${manifest.exportGpxSha256}).',
      );
    }

    return true;
  }

  /// Purges stale temporary export directories (`aetron_export_*`) older than [olderThan].
  ///
  /// Prevents accumulation of temporary sharing files while ensuring active shares
  /// are never prematurely deleted before external applications finish copying them.
  Future<void> purgeStaleExportDirectories({
    Duration olderThan = const Duration(minutes: 15),
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thresholdTime = DateTime.now().subtract(olderThan);

      final entities = tempDir.listSync();
      for (final entity in entities) {
        if (entity is Directory && entity.path.contains('aetron_export_')) {
          try {
            final stat = entity.statSync();
            if (stat.modified.isBefore(thresholdTime)) {
              entity.deleteSync(recursive: true);
            }
          } catch (e) {
            debugPrint('[RawGpsExportService] error deleting stale export dir: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[RawGpsExportService] purgeStaleExportDirectories error: $e');
    }
  }

  /// Prepares the export bundle files in an isolated app-owned temporary directory.
  Future<List<File>> prepareExportFiles(RawGpsExportBundle bundle) async {
    // Purge older exports first to avoid unbounded storage growth
    await purgeStaleExportDirectories();

    final tempDir = await getTemporaryDirectory();
    final exportDirPath =
        '${tempDir.path}/aetron_export_${bundle.workoutId}_${DateTime.now().millisecondsSinceEpoch}';
    final exportDir = Directory(exportDirPath);
    await exportDir.create(recursive: true);

    final jsonlFile = File('${exportDir.path}/${bundle.workoutId}.raw.jsonl');
    final csvFile = File('${exportDir.path}/${bundle.workoutId}.raw.csv');
    final gpxFile = File('${exportDir.path}/${bundle.workoutId}.raw.gpx');
    final manifestFile = File('${exportDir.path}/${bundle.workoutId}.manifest.json');

    await jsonlFile.writeAsString(bundle.jsonlContent, flush: true);
    await csvFile.writeAsString(bundle.csvContent, flush: true);
    await gpxFile.writeAsString(bundle.gpxContent, flush: true);
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(bundle.manifest.toJson()),
      flush: true,
    );

    final files = [jsonlFile, csvFile, gpxFile, manifestFile];

    // Pre-flight validation: verify files exist and match advertised manifest hashes
    verifyExportFiles(files, bundle.manifest);

    return files;
  }

  /// Triggers the native iOS/Android Share Sheet to share the research dataset bundle.
  ///
  /// Safely manages temporary file lifecycle with explicit MIME types, ensuring
  /// temporary export files match advertised hashes without race-condition cleanup
  /// deleting attachments before external applications finish reading them.
  Future<void> shareExportBundle(
    RawGpsExportBundle bundle, {
    Rect? sharePositionOrigin,
    bool autoCleanup = true,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Native share sheet is unsupported on web.',
      );
    }

    final files = await prepareExportFiles(bundle);
    try {
      final xFiles = [
        XFile(
          files[0].path,
          mimeType: 'application/x-ndjson',
          name: '${bundle.workoutId}.raw.jsonl',
        ),
        XFile(
          files[1].path,
          mimeType: 'text/csv',
          name: '${bundle.workoutId}.raw.csv',
        ),
        XFile(
          files[2].path,
          mimeType: 'application/gpx+xml',
          name: '${bundle.workoutId}.raw.gpx',
        ),
        XFile(
          files[3].path,
          mimeType: 'application/json',
          name: '${bundle.workoutId}.manifest.json',
        ),
      ];

      await Share.shareXFiles(
        xFiles,
        text: 'Aetron Research GPS Dataset (${bundle.workoutId})',
        subject: 'Aetron GPS Dataset - ${bundle.workoutId}',
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      if (autoCleanup) {
        // Defer immediate deletion by a safe completion window (5 min) to prevent
        // race conditions where native receivers (AirDrop, Files, Mail) lose files.
        // Also automatically cleaned up on next export or app startup.
        Future.delayed(const Duration(minutes: 5), () async {
          await cleanupExportFiles(files);
        });
      }
    }
  }

  /// Safely cleans up temporary export files without touching original local data.
  ///
  /// Strictly verifies that each file is located within an `aetron_export_*` directory.
  /// Original journals, Isar databases, and persistent files are strictly protected.
  Future<void> cleanupExportFiles(List<File> files) async {
    for (final file in files) {
      try {
        final path = file.path;
        // Strictly ensure we ONLY delete files inside temporary aetron_export_* folders
        if (!path.contains('aetron_export_')) {
          debugPrint(
            '[RawGpsExportService] safety rejection: cannot delete non-export file: $path',
          );
          continue;
        }
        if (await file.exists()) {
          final parent = file.parent;
          await file.delete();
          // Remove parent temp directory if empty and named aetron_export_*
          if (parent.path.contains('aetron_export_')) {
            final remaining = await parent.list().toList();
            if (remaining.isEmpty) {
              await parent.delete();
            }
          }
        }
      } catch (e) {
        debugPrint('[RawGpsExportService] cleanup error: $e');
      }
    }
  }

  /// Discovers all workout sessions owned by the authenticated user across
  /// local journals, local database, and cloud records.
  Future<List<String>> listAvailableSessionIdsForUser({
    String? activeUserId,
  }) async {
    final userId = _resolveUserId(activeUserId);
    final sessionIds = <String>{};

    // 1 & 2. Local recovery journals and Isar database
    try {
      final ownedSessionIds =
          (await LocalDB.getRawGpsOwnedSessionIdsForUser(userId)).toSet();
      sessionIds.addAll(ownedSessionIds);

      final journalSessions = await _journal.listPendingSessionIdsForUser(
        userId,
        ownedSessionIds: ownedSessionIds,
      );
      sessionIds.addAll(journalSessions);
    } catch (e) {
      debugPrint('[RawGpsExportService] error listing local sessions: $e');
    }

    // 3. Cloud Supabase workout sessions
    if (_supabaseClient != null) {
      try {
        final cloudRows = await _supabaseClient
            .from(DbTables.workoutSessions)
            .select('id')
            .eq('user_id', userId);
        for (final row in cloudRows as List) {
          final id = row['id'] as String?;
          if (id != null && id.isNotEmpty) {
            sessionIds.add(id);
          }
        }
      } catch (e) {
        debugPrint('[RawGpsExportService] error querying cloud sessions: $e');
      }
    }

    final sorted = sessionIds.toList()..sort();
    return sorted;
  }

  /// Performs an automated ALG-0 inventory across all sessions owned by the authenticated user.
  ///
  /// Extracts available raw GPS points, labels provenance, analyzes sampling and telemetry quality,
  /// and compiles a comprehensive research inventory report.
  Future<RawGpsAggregateInventoryReport> inventoryUserSessions({
    String? activeUserId,
    String? appCommit,
  }) async {
    final userId = _resolveUserId(activeUserId);
    final sessionIds = await listAvailableSessionIdsForUser(activeUserId: userId);
    final sessionReports = <RawGpsSessionQualityReport>[];

    for (final sessionId in sessionIds) {
      try {
        final bundle = await exportSession(
          workoutId: sessionId,
          activeUserId: userId,
          appCommit: appCommit,
        );

        final report = RawGpsQualityAnalyzer.analyzeSession(
          workoutId: sessionId,
          points: bundle.points,
          sourceKind: RawGpsExportSourceKind.values.firstWhere(
            (k) => k.value == bundle.manifest.sourceKind,
            orElse: () => RawGpsExportSourceKind.cloudOnlyUnverified,
          ),
        );
        sessionReports.add(report);
      } catch (e) {
        debugPrint('[RawGpsExportService] skipping session $sessionId during inventory: $e');
      }
    }

    return RawGpsQualityAnalyzer.aggregateReports(
      sessionReports,
      appCommit: appCommit,
    );
  }

  String _resolveUserId(String? activeUserId) {
    final authenticatedUserId =
        _currentUserIdProvider?.call() ?? _supabaseClient?.auth.currentUser?.id;

    if (authenticatedUserId == null || authenticatedUserId.isEmpty) {
      throw StateError(
        'User must be authenticated to perform raw GPS dataset export.',
      );
    }

    if (activeUserId != null &&
        activeUserId.isNotEmpty &&
        activeUserId != authenticatedUserId) {
      throw SecurityException(
        'Active user conflict: provided activeUserId ($activeUserId) does not match authenticated user ($authenticatedUserId).',
      );
    }
    return authenticatedUserId;
  }

  Future<bool> _isJournalIntactAndVerified(
    String workoutId,
    List<RawGpsExportPoint> points,
    RawGpsJournalManifest? manifest,
    RawGpsRecoveryStatus status,
  ) async {
    if (manifest == null || !manifest.isFinalized) return false;
    if (status != RawGpsRecoveryStatus.verifiedIntact) return false;
    if (manifest.schemaVersion == RawGpsJournalManifest.schemaVersionV1) {
      return false;
    }

    final journalFile = await _journal.fileForSession(workoutId);
    if (!await journalFile.exists()) return false;

    // 1. Verify byte checksum of raw file
    final rawBytes = await journalFile.readAsBytes();
    final computedFileSha = sha256.convert(rawBytes).toString();
    if (computedFileSha.toLowerCase() != manifest.fileSha256?.toLowerCase()) {
      return false;
    }

    // 2. Verify canonical capture digest
    final canonicalPoints = points.map((p) => p.toCanonical()).toList();
    final computedDigest =
        RawGpsCanonicalVerification.computeCanonicalDigest(canonicalPoints);

    if (computedDigest != manifest.canonicalCaptureDigest) {
      return false;
    }

    return true;
  }
}
