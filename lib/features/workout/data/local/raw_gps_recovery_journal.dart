import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Status outcomes for recovery journal reading.
enum RawGpsRecoveryStatus {
  verifiedIntact,
  staleCheckpoint,
  integrityUnverified,
  corrupted,
  corruptedWithRecoveredPoints,
  partiallyRecoveredTruncated,
  recoveredLegacyNoManifest,
  accountMismatch,
  emptyOrNotFound;

  static const legacyUnverified = recoveredLegacyNoManifest;
  static const partialTruncated = partiallyRecoveredTruncated;
}

/// Versioned companion manifest tracking raw GPS journal checkpoints.
class RawGpsJournalManifest {
  static const String schemaVersionV1 = 'aetron.raw_gps.manifest.v1';
  static const String currentSchemaVersion = 'aetron.raw_gps.manifest.v2';

  final String schemaVersion;
  final String workoutId;
  final String? userId;
  final int sampleCount;
  final DateTime? firstTimestampUtc;
  final DateTime? lastTimestampUtc;
  /// SHA-256 digest of the raw JSONL file on disk.
  final String? fileSha256;
  /// Versioned canonical capture digest (v1 canonical representation) of durable local points.
  final String? canonicalCaptureDigest;
  final int checkpointSeq;
  final DateTime checkpointTimestampUtc;
  final bool isFinalized;
  final bool cloudVerified;
  final int cloudVerifiedCount;
  /// Canonical digest verified by server read-back.
  final String? cloudVerifiedSha256;

  /// Backward-compatible alias for fileSha256.
  String? get sha256Digest => fileSha256;

  const RawGpsJournalManifest({
    this.schemaVersion = currentSchemaVersion,
    required this.workoutId,
    this.userId,
    required this.sampleCount,
    this.firstTimestampUtc,
    this.lastTimestampUtc,
    String? fileSha256,
    String? sha256Digest,
    this.canonicalCaptureDigest,
    required this.checkpointSeq,
    required this.checkpointTimestampUtc,
    this.isFinalized = false,
    this.cloudVerified = false,
    this.cloudVerifiedCount = 0,
    this.cloudVerifiedSha256,
  }) : fileSha256 = fileSha256 ?? sha256Digest;

  RawGpsJournalManifest copyWith({
    String? schemaVersion,
    int? sampleCount,
    DateTime? firstTimestampUtc,
    DateTime? lastTimestampUtc,
    String? fileSha256,
    String? sha256Digest,
    String? canonicalCaptureDigest,
    int? checkpointSeq,
    DateTime? checkpointTimestampUtc,
    bool? isFinalized,
    bool? cloudVerified,
    int? cloudVerifiedCount,
    String? cloudVerifiedSha256,
  }) {
    return RawGpsJournalManifest(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      workoutId: workoutId,
      userId: userId,
      sampleCount: sampleCount ?? this.sampleCount,
      firstTimestampUtc: firstTimestampUtc ?? this.firstTimestampUtc,
      lastTimestampUtc: lastTimestampUtc ?? this.lastTimestampUtc,
      fileSha256: fileSha256 ?? sha256Digest ?? this.fileSha256,
      canonicalCaptureDigest:
          canonicalCaptureDigest ?? this.canonicalCaptureDigest,
      checkpointSeq: checkpointSeq ?? this.checkpointSeq,
      checkpointTimestampUtc:
          checkpointTimestampUtc ?? this.checkpointTimestampUtc,
      isFinalized: isFinalized ?? this.isFinalized,
      cloudVerified: cloudVerified ?? this.cloudVerified,
      cloudVerifiedCount: cloudVerifiedCount ?? this.cloudVerifiedCount,
      cloudVerifiedSha256: cloudVerifiedSha256 ?? this.cloudVerifiedSha256,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'workout_id': workoutId,
    if (userId != null) 'user_id': userId,
    'sample_count': sampleCount,
    if (firstTimestampUtc != null)
      'first_timestamp_utc': firstTimestampUtc!.toUtc().toIso8601String(),
    if (lastTimestampUtc != null)
      'last_timestamp_utc': lastTimestampUtc!.toUtc().toIso8601String(),
    if (fileSha256 != null) 'file_sha256': fileSha256,
    if (fileSha256 != null) 'sha256_digest': fileSha256,
    if (canonicalCaptureDigest != null)
      'canonical_capture_digest': canonicalCaptureDigest,
    'checkpoint_seq': checkpointSeq,
    'checkpoint_timestamp_utc': checkpointTimestampUtc.toUtc().toIso8601String(),
    'is_finalized': isFinalized,
    'cloud_verified': cloudVerified,
    'cloud_verified_count': cloudVerifiedCount,
    if (cloudVerifiedSha256 != null)
      'cloud_verified_sha256': cloudVerifiedSha256,
  };

  factory RawGpsJournalManifest.fromJson(Map<String, dynamic> json) {
    final fileHash = json['file_sha256'] as String? ??
        json['sha256_digest'] as String?;
    return RawGpsJournalManifest(
      schemaVersion:
          json['schema_version'] as String? ?? currentSchemaVersion,
      workoutId: json['workout_id'] as String,
      userId: json['user_id'] as String?,
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
      firstTimestampUtc: json['first_timestamp_utc'] != null
          ? DateTime.tryParse(json['first_timestamp_utc'] as String)?.toUtc()
          : null,
      lastTimestampUtc: json['last_timestamp_utc'] != null
          ? DateTime.tryParse(json['last_timestamp_utc'] as String)?.toUtc()
          : null,
      fileSha256: fileHash,
      canonicalCaptureDigest:
          json['canonical_capture_digest'] as String?,
      checkpointSeq: (json['checkpoint_seq'] as num?)?.toInt() ?? 0,
      checkpointTimestampUtc: DateTime.tryParse(
            json['checkpoint_timestamp_utc'] as String? ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc(),
      isFinalized: json['is_finalized'] as bool? ?? false,
      cloudVerified: json['cloud_verified'] as bool? ?? false,
      cloudVerifiedCount:
          (json['cloud_verified_count'] as num?)?.toInt() ?? 0,
      cloudVerifiedSha256: json['cloud_verified_sha256'] as String?,
    );
  }
}

/// Explicit result of an append operation to the raw GPS recovery journal.
class RawGpsAppendResult {
  final bool success;
  final int sampleIndex;
  final int latencyMicros;
  final String? error;

  const RawGpsAppendResult({
    required this.success,
    required this.sampleIndex,
    required this.latencyMicros,
    this.error,
  });
}

/// Diagnostics snapshot for an active journal writer.
class RawGpsJournalDiagnostics {
  final String sessionId;
  final int acceptedSamples;
  final int queuedAppends;
  final int committedSamples;
  final int durableSamples;
  final int failedSamples;
  final int droppedSamples;
  final int totalLatencyMicros;
  final int minLatencyMicros;
  final int maxLatencyMicros;

  const RawGpsJournalDiagnostics({
    required this.sessionId,
    this.acceptedSamples = 0,
    required this.queuedAppends,
    required this.committedSamples,
    int? durableSamples,
    this.failedSamples = 0,
    required this.droppedSamples,
    required this.totalLatencyMicros,
    required this.minLatencyMicros,
    required this.maxLatencyMicros,
  }) : durableSamples = durableSamples ?? committedSamples;

  double get meanLatencyMs => committedSamples > 0
      ? (totalLatencyMicros / committedSamples) / 1000.0
      : 0.0;
  double get minLatencyMs => minLatencyMicros / 1000.0;
  double get maxLatencyMs => maxLatencyMicros / 1000.0;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'accepted_samples': acceptedSamples,
    'queued_appends': queuedAppends,
    'committed_samples': committedSamples,
    'durable_samples': durableSamples,
    'failed_samples': failedSamples,
    'dropped_samples': droppedSamples,
    'mean_latency_ms': meanLatencyMs,
    'min_latency_ms': minLatencyMs,
    'max_latency_ms': maxLatencyMs,
  };
}

/// Recovery result produced by reading a journal.
class RawGpsRecoveryResult {
  final String sessionId;
  final List<LocalGPSPoint> points;
  final RawGpsJournalManifest? manifest;
  final RawGpsRecoveryStatus status;
  final int validPointsCount;
  final int duplicatePointsCount;
  final int corruptedLinesCount;
  final bool hasTruncatedFinalLine;
  final String? truncatedLineSnippet;
  final bool isUnfinalizedCrash;
  final String? accountMismatchUserId;
  final String? warningMessage;

  const RawGpsRecoveryResult({
    required this.sessionId,
    required this.points,
    this.manifest,
    required this.status,
    required this.validPointsCount,
    required this.duplicatePointsCount,
    required this.corruptedLinesCount,
    required this.hasTruncatedFinalLine,
    this.truncatedLineSnippet,
    required this.isUnfinalizedCrash,
    this.accountMismatchUserId,
    this.warningMessage,
  });

  factory RawGpsRecoveryResult.empty(String sessionId) =>
      RawGpsRecoveryResult(
        sessionId: sessionId,
        points: const [],
        status: RawGpsRecoveryStatus.emptyOrNotFound,
        validPointsCount: 0,
        duplicatePointsCount: 0,
        corruptedLinesCount: 0,
        hasTruncatedFinalLine: false,
        isUnfinalizedCrash: false,
      );

  factory RawGpsRecoveryResult.accountMismatch({
    required String sessionId,
    required String accountMismatchUserId,
  }) =>
      RawGpsRecoveryResult(
        sessionId: sessionId,
        points: const [],
        status: RawGpsRecoveryStatus.accountMismatch,
        validPointsCount: 0,
        duplicatePointsCount: 0,
        corruptedLinesCount: 0,
        hasTruncatedFinalLine: false,
        isUnfinalizedCrash: true,
        accountMismatchUserId: accountMismatchUserId,
        warningMessage:
            'Journal is isolated to user $accountMismatchUserId and cannot be read by active user.',
      );
}

/// Diagnostics information for a retained journal file on disk.
class RawGpsOrphanJournalInfo {
  final String workoutId;
  final String? userId;
  final int sampleCount;
  final String? fileSha256;
  final String? canonicalCaptureDigest;
  final bool hasLocalWorkout;
  final bool isOwnerMatch;
  final bool isCorrupted;
  final bool isCloudVerified;
  final String statusMessage;

  const RawGpsOrphanJournalInfo({
    required this.workoutId,
    this.userId,
    required this.sampleCount,
    this.fileSha256,
    this.canonicalCaptureDigest,
    required this.hasLocalWorkout,
    required this.isOwnerMatch,
    required this.isCorrupted,
    required this.isCloudVerified,
    required this.statusMessage,
  });
}

/// Append-only, crash-safe, durable recovery copy of raw GPS samples.
///
/// Implements RG-1A:
/// 1. Serialized append operations with explicit flush: true to OS storage.
/// 2. Bounded in-flight queue to prevent unbounded memory growth.
/// 3. Versioned integrity manifest with atomic .tmp -> rename checkpointing.
/// 4. Robust recovery reader detecting and discarding truncated final lines
///    while preserving all prior committed records with zero metric fabrication.
/// 5. Account isolation rejecting cross-user journal replays.
/// 6. Safe deletion requiring local/cloud verification; no blind TTL deletion.
class RawGpsRecoveryJournal {
  RawGpsRecoveryJournal({
    Future<Directory> Function()? documentsDirectory,
    this.checkpointInterval = 25,
    this.maxQueueDepth = 1000,
    this.onIoFaultInject,
    this.workoutOwnershipVerifier,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static final RawGpsRecoveryJournal instance = RawGpsRecoveryJournal();

  final Future<Directory> Function() _documentsDirectory;
  final int checkpointInterval;
  final int maxQueueDepth;

  /// Optional fault injection hook for testing resilience to I/O failures.
  final Future<void> Function(String phase)? onIoFaultInject;

  /// Optional default verifier for workouts when manifest.userId is missing.
  final Future<bool> Function(String sessionId, String userId)?
      workoutOwnershipVerifier;

  final Map<String, _SessionJournalWriter> _activeWriters = {};
  final Map<String, Future<_SessionJournalWriter>> _pendingWriters = {};

  /// Appends a point to the recovery journal. Backwards compatible with
  /// existing coordinator calls.
  Future<void> append(LocalGPSPoint point) async {
    final result = await appendPoint(point);
    if (!result.success) {
      throw StateError(result.error ?? 'Raw GPS recovery append failed');
    }
  }

  /// Appends a raw GPS point with explicit acknowledgement and per-sample latency.
  Future<RawGpsAppendResult> appendPoint(
    LocalGPSPoint point, {
    String? userId,
  }) async {
    final writer = await _getOrCreateWriter(point.sessionId, userId: userId);
    return writer.append(point, userId: userId);
  }

  /// Writes an atomic manifest checkpoint for [sessionId].
  Future<void> checkpoint(
    String sessionId, {
    bool isFinalized = false,
    bool cloudVerified = false,
    int? cloudVerifiedCount,
    String? cloudVerifiedSha256,
    String? canonicalCaptureDigest,
  }) async {
    final writer = _activeWriters[sessionId];
    if (writer != null) {
      await writer.checkpoint(
        isFinalized: isFinalized,
        cloudVerified: cloudVerified,
        cloudVerifiedCount: cloudVerifiedCount,
        cloudVerifiedSha256: cloudVerifiedSha256,
        canonicalCaptureDigest: canonicalCaptureDigest,
      );
    } else {
      // If writer is not in memory, update manifest file directly if it exists
      final manifestFile = await manifestFileForSession(sessionId);
      if (await manifestFile.exists()) {
        final content = await manifestFile.readAsString();
        final existing = RawGpsJournalManifest.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        final journalFile = await fileForSession(sessionId);
        var canonicalDigest =
            canonicalCaptureDigest ?? existing.canonicalCaptureDigest;
        if (canonicalDigest == null && await journalFile.exists()) {
          canonicalDigest =
              await _computeCanonicalDigestFromFile(journalFile);
        }
        final updated = existing.copyWith(
          isFinalized: isFinalized,
          cloudVerified: cloudVerified,
          cloudVerifiedCount: cloudVerifiedCount,
          cloudVerifiedSha256: cloudVerifiedSha256,
          canonicalCaptureDigest: canonicalDigest,
          checkpointTimestampUtc: DateTime.now().toUtc(),
          checkpointSeq: existing.checkpointSeq + 1,
        );
        await _writeManifestAtomic(
          manifestFile,
          updated,
          faultInject: onIoFaultInject,
        );
      }
    }
  }

  /// Flushes all queued appends and checkpoints the session.
  Future<void> flushSession(String sessionId) async {
    final writer = _activeWriters[sessionId];
    if (writer != null) {
      await writer.waitForInFlightWrites();
      await writer.checkpoint();
    }
  }

  /// Returns diagnostic metrics for the session writer.
  RawGpsJournalDiagnostics getDiagnostics(String sessionId) {
    final writer = _activeWriters[sessionId];
    if (writer == null) {
      return RawGpsJournalDiagnostics(
        sessionId: sessionId,
        queuedAppends: 0,
        committedSamples: 0,
        droppedSamples: 0,
        totalLatencyMicros: 0,
        minLatencyMicros: 0,
        maxLatencyMicros: 0,
      );
    }
    return writer.getDiagnostics();
  }

  /// Reads and recovers the raw GPS journal for [sessionId].
  ///
  /// Guarantees:
  /// - Discards truncated final line if interrupted mid-write, preserving all
  ///   prior valid committed lines.
  /// - Deterministically deduplicates records by (timestamp, lat, lng).
  /// - Enforces account isolation if [activeUserId] is provided.
  /// - Never fabricates summary workout metrics.
  Future<RawGpsRecoveryResult> readJournal(
    String sessionId, {
    String? activeUserId,
  }) async {
    final file = await fileForSession(sessionId);
    if (!await file.exists()) {
      return RawGpsRecoveryResult.empty(sessionId);
    }

    RawGpsJournalManifest? manifest = await readManifest(sessionId);

    // Account Isolation Check
    if (activeUserId != null &&
        manifest != null &&
        manifest.userId != null &&
        manifest.userId != activeUserId) {
      return RawGpsRecoveryResult.accountMismatch(
        sessionId: sessionId,
        accountMismatchUserId: manifest.userId!,
      );
    }

    final rawLines = await file.readAsLines();
    if (rawLines.isEmpty) {
      if (activeUserId != null &&
          manifest != null &&
          manifest.userId != null &&
          manifest.userId != activeUserId) {
        return RawGpsRecoveryResult.accountMismatch(
          sessionId: sessionId,
          accountMismatchUserId: manifest.userId!,
        );
      }
      if (activeUserId != null && manifest != null && manifest.userId == null) {
        return RawGpsRecoveryResult(
          sessionId: sessionId,
          points: const [],
          manifest: manifest,
          status: RawGpsRecoveryStatus.emptyOrNotFound,
          validPointsCount: 0,
          duplicatePointsCount: 0,
          corruptedLinesCount: 0,
          hasTruncatedFinalLine: false,
          isUnfinalizedCrash: !manifest.isFinalized,
          warningMessage:
              'Journal lacks ownership metadata and cannot be safely replayed for active user $activeUserId.',
        );
      }

      RawGpsRecoveryStatus status;
      if (manifest == null) {
        status = RawGpsRecoveryStatus.emptyOrNotFound;
      } else if (manifest.sampleCount > 0) {
        status = RawGpsRecoveryStatus.corrupted;
      } else {
        // manifest.sampleCount == 0:
        // Treat zero-sample empty journals as VERIFIED_INTACT only when
        // their integrity evidence is actually validated against the file digest.
        final fileDigest = await _computeFileSha256(file);
        if (manifest.sha256Digest == null) {
          status = RawGpsRecoveryStatus.integrityUnverified;
        } else if (manifest.sha256Digest!.toLowerCase() ==
            fileDigest?.toLowerCase()) {
          status = RawGpsRecoveryStatus.verifiedIntact;
        } else {
          status = RawGpsRecoveryStatus.corrupted;
        }
      }

      return RawGpsRecoveryResult(
        sessionId: sessionId,
        points: const [],
        manifest: manifest,
        status: status,
        validPointsCount: 0,
        duplicatePointsCount: 0,
        corruptedLinesCount: 0,
        hasTruncatedFinalLine: false,
        isUnfinalizedCrash: manifest == null ? true : !manifest.isFinalized,
      );
    }

    final validPoints = <LocalGPSPoint>[];
    final seenKeys = <String>{};
    var duplicateCount = 0;
    var corruptedLinesCount = 0;
    var hasTruncatedFinalLine = false;
    String? truncatedSnippet;
    var hasAnyLineUserId = false;

    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;

      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }

        // Line-level account isolation
        final lineUserId = decoded['user_id'] as String?;
        if (lineUserId != null) {
          hasAnyLineUserId = true;
          if (activeUserId != null && lineUserId != activeUserId) {
            return RawGpsRecoveryResult.accountMismatch(
              sessionId: sessionId,
              accountMismatchUserId: lineUserId,
            );
          }
        }

        final point = _pointFromJson(decoded);
        final key =
            '${point.timestamp.toUtc().microsecondsSinceEpoch}|${point.latitude}|${point.longitude}';
        if (seenKeys.contains(key)) {
          duplicateCount += 1;
        } else {
          seenKeys.add(key);
          validPoints.add(point);
        }
      } catch (e) {
        final isLastLine = (i == rawLines.length - 1);
        if (isLastLine) {
          hasTruncatedFinalLine = true;
          truncatedSnippet = line.length > 80 ? line.substring(0, 80) : line;
        } else {
          corruptedLinesCount += 1;
        }
      }
    }

    // Conservative Account Isolation:
    // If activeUserId is provided, but neither manifest nor any line has ownership metadata,
    // fail closed to prevent unauthorized cross-account replay of anonymous/orphaned traces.
    final hasOwnershipMetadata = (manifest?.userId != null) || hasAnyLineUserId;
    if (activeUserId != null && !hasOwnershipMetadata) {
      return RawGpsRecoveryResult.accountMismatch(
        sessionId: sessionId,
        accountMismatchUserId: 'unknown_unattributed',
      );
    }

    // Sort monotonically by timestamp
    validPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    RawGpsRecoveryStatus status;
    if (hasTruncatedFinalLine) {
      status = RawGpsRecoveryStatus.partiallyRecoveredTruncated;
    } else if (corruptedLinesCount > 0) {
      status = RawGpsRecoveryStatus.corrupted;
    } else if (manifest == null) {
      status = RawGpsRecoveryStatus.recoveredLegacyNoManifest;
    } else {
      final actualFileSha256 = await _computeFileSha256(file);
      final digestMatches = manifest.sha256Digest != null &&
          actualFileSha256 != null &&
          manifest.sha256Digest!.toLowerCase() == actualFileSha256.toLowerCase();

      if (validPoints.length == manifest.sampleCount && digestMatches) {
        status = RawGpsRecoveryStatus.verifiedIntact;
      } else if (validPoints.length > manifest.sampleCount) {
        // Stale checkpoint: check if the checkpointed prefix is verified intact.
        if (manifest.sha256Digest != null) {
          final actualLines = rawLines.where((l) => l.trim().isNotEmpty).toList();
          if (actualLines.length >= manifest.sampleCount) {
            final prefixContent = actualLines
                .take(manifest.sampleCount)
                .map((l) => '$l\n')
                .join();
            final prefixSha256 =
                sha256.convert(utf8.encode(prefixContent)).toString();
            if (prefixSha256.toLowerCase() ==
                manifest.sha256Digest!.toLowerCase()) {
              status = RawGpsRecoveryStatus.staleCheckpoint;
            } else {
              // Prefix modified/corrupted: do not conceal corruption under staleCheckpoint!
              status = RawGpsRecoveryStatus.corrupted;
            }
          } else {
            status = RawGpsRecoveryStatus.integrityUnverified;
          }
        } else {
          status = RawGpsRecoveryStatus.integrityUnverified;
        }
      } else {
        // Count mismatch (< sampleCount) or digest mismatch (coordinate tampering/corruption)
        status = RawGpsRecoveryStatus.corrupted;
      }
    }

    final isUnfinalizedCrash = manifest == null ? true : !manifest.isFinalized;

    return RawGpsRecoveryResult(
      sessionId: sessionId,
      points: List.unmodifiable(validPoints),
      manifest: manifest,
      status: status,
      validPointsCount: validPoints.length,
      duplicatePointsCount: duplicateCount,
      corruptedLinesCount: corruptedLinesCount,
      hasTruncatedFinalLine: hasTruncatedFinalLine,
      truncatedLineSnippet: truncatedSnippet,
      isUnfinalizedCrash: isUnfinalizedCrash,
    );
  }

  /// Reads the companion manifest for [sessionId], if present.
  Future<RawGpsJournalManifest?> readManifest(String sessionId) async {
    final file = await manifestFileForSession(sessionId);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return RawGpsJournalManifest.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[RawGpsRecoveryJournal] readManifest failed for $sessionId: $e');
      return null;
    }
  }

  /// Locates the journal file for [sessionId].
  Future<File> fileForSession(String sessionId) async {
    final documents = await _documentsDirectory();
    final safeSessionId = sessionId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(
      p.join(
        documents.path,
        'raw_gps_recovery',
        'raw-gps-$safeSessionId.jsonl',
      ),
    );
  }

  /// Locates the manifest file for [sessionId].
  Future<File> manifestFileForSession(String sessionId) async {
    final documents = await _documentsDirectory();
    final safeSessionId = sessionId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(
      p.join(
        documents.path,
        'raw_gps_recovery',
        'raw-gps-$safeSessionId.manifest.json',
      ),
    );
  }


  /// Enumerates user-owned journal sessions that may need cloud reconciliation.
  ///
  /// Safe Ownership & Orphan Recovery Semantics (RG-F1.2):
  /// - A journal with `manifest.userId == userId` belongs to that user even if
  ///   `LocalWorkout` metadata was lost (e.g. wiped SQLite cache / crash).
  /// - An unannotated or legacy journal with `manifest.userId == null` is NEVER
  ///   associated with `userId` by assumption. It requires either presence in
  ///   [ownedSessionIds] or explicit verification via [ownershipVerifier] or
  ///   [workoutOwnershipVerifier]. Unverified journals remain safely on disk.
  /// - Foreign-user journals (`manifest.userId != userId`) are strictly isolated.
  /// - Corrupted journals fail closed and are not enqueued for normal upload.
  Future<List<String>> listPendingSessionIdsForUser(
    String userId, {
    required Set<String> ownedSessionIds,
    Future<bool> Function(String sessionId, String userId)? ownershipVerifier,
  }) async {
    if (userId.trim().isEmpty) return const [];
    final documents = await _documentsDirectory();
    final directory = Directory(p.join(documents.path, 'raw_gps_recovery'));
    if (!await directory.exists()) return const [];

    final pending = <String>{};
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.manifest.json')) continue;
      try {
        final content = await entry.readAsString();
        final manifest = RawGpsJournalManifest.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        final manifestFile = await manifestFileForSession(manifest.workoutId);
        if (p.normalize(manifestFile.path) != p.normalize(entry.path)) continue;
        final journalFile = await fileForSession(manifest.workoutId);
        if (!await journalFile.exists()) continue;

        // Skip if already cloud verified
        if (manifest.cloudVerified &&
            manifest.cloudVerifiedCount == manifest.sampleCount &&
            manifest.cloudVerifiedSha256 != null) {
          continue;
        }

        // Ownership Verification (RG-F1.2)
        var isOwner = false;
        if (manifest.userId != null) {
          if (manifest.userId == userId) {
            isOwner = true;
          } else {
            // Foreign user journal: strict isolation, never claim or upload
            continue;
          }
        } else {
          // Unknown owner / legacy journal without manifest.userId:
          // NEVER associate with userId by assumption!
          // Only verify if trusted check succeeds.
          if (ownedSessionIds.contains(manifest.workoutId)) {
            isOwner = true;
          } else if (ownershipVerifier != null &&
              await ownershipVerifier(manifest.workoutId, userId)) {
            isOwner = true;
          } else if (workoutOwnershipVerifier != null &&
              await workoutOwnershipVerifier!(manifest.workoutId, userId)) {
            isOwner = true;
          }
        }

        if (!isOwner) continue;

        // Validate journal integrity before declaring pending for recovery
        final status = await _verifyJournalFileIntegrity(journalFile, manifest);
        if (status == RawGpsRecoveryStatus.corrupted) {
          debugPrint(
            '[RawGpsRecoveryJournal] Skipping corrupted journal for pending recovery: ${manifest.workoutId}',
          );
          continue;
        }

        pending.add(manifest.workoutId);
      } on FormatException catch (e) {
        debugPrint('[RawGpsRecoveryJournal] invalid recovery manifest: $e');
      } on FileSystemException catch (e) {
        debugPrint('[RawGpsRecoveryJournal] cannot inspect manifest: $e');
        rethrow;
      }
    }
    return pending.toList()..sort();
  }

  /// Verifies file-level integrity against manifest expectations.
  Future<RawGpsRecoveryStatus> _verifyJournalFileIntegrity(
    File journalFile,
    RawGpsJournalManifest manifest,
  ) async {
    final length = await journalFile.length();
    if (length == 0) {
      return manifest.sampleCount > 0
          ? RawGpsRecoveryStatus.corrupted
          : RawGpsRecoveryStatus.verifiedIntact;
    }
    final actualFileSha256 = await _computeFileSha256(journalFile);
    if (manifest.fileSha256 != null &&
        actualFileSha256 != null &&
        manifest.fileSha256!.toLowerCase() == actualFileSha256.toLowerCase()) {
      return RawGpsRecoveryStatus.verifiedIntact;
    }
    if (!manifest.isFinalized) {
      return RawGpsRecoveryStatus.staleCheckpoint;
    }
    if (manifest.fileSha256 != null &&
        actualFileSha256 != null &&
        manifest.fileSha256!.toLowerCase() != actualFileSha256.toLowerCase()) {
      return RawGpsRecoveryStatus.corrupted;
    }
    return RawGpsRecoveryStatus.integrityUnverified;
  }

  /// Lists diagnostics information for all retained journals on disk, including
  /// unannotated, orphaned, or foreign journals.
  Future<List<RawGpsOrphanJournalInfo>> listOrphanJournals({
    String? activeUserId,
    Set<String> ownedSessionIds = const <String>{},
  }) async {
    final documents = await _documentsDirectory();
    final directory = Directory(p.join(documents.path, 'raw_gps_recovery'));
    if (!await directory.exists()) return const [];

    final list = <RawGpsOrphanJournalInfo>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.manifest.json')) continue;
      try {
        final content = await entry.readAsString();
        final manifest = RawGpsJournalManifest.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        final journalFile = await fileForSession(manifest.workoutId);
        final exists = await journalFile.exists();
        final hasLocal = ownedSessionIds.contains(manifest.workoutId);
        final isOwnerMatch =
            activeUserId != null && manifest.userId == activeUserId;

        var isCorrupted = false;
        var statusMsg = 'intact';
        if (!exists) {
          isCorrupted = true;
          statusMsg = 'journal_file_missing';
        } else {
          final integrity =
              await _verifyJournalFileIntegrity(journalFile, manifest);
          if (integrity == RawGpsRecoveryStatus.corrupted) {
            isCorrupted = true;
            statusMsg = 'checksum_mismatch';
          } else if (!hasLocal) {
            statusMsg = 'missing_local_workout_metadata';
          }
        }

        list.add(
          RawGpsOrphanJournalInfo(
            workoutId: manifest.workoutId,
            userId: manifest.userId,
            sampleCount: manifest.sampleCount,
            fileSha256: manifest.fileSha256,
            canonicalCaptureDigest: manifest.canonicalCaptureDigest,
            hasLocalWorkout: hasLocal,
            isOwnerMatch: isOwnerMatch,
            isCorrupted: isCorrupted,
            isCloudVerified: manifest.cloudVerified,
            statusMessage: statusMsg,
          ),
        );
      } catch (e) {
        debugPrint(
          '[RawGpsRecoveryJournal] Error reading orphan journal info: $e',
        );
      }
    }
    return list;
  }

  /// Static helper to compute SHA-256 digest of a file.
  static Future<String?> _computeFileSha256(File file) async {
    try {
      if (!await file.exists()) return null;
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } catch (_) {
      return null;
    }
  }

  /// Computes the versioned canonical capture digest from lines in [file].
  static Future<String?> _computeCanonicalDigestFromFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final lines = await file.readAsLines();
      if (lines.isEmpty) return RawGpsCanonicalVerification.emptyDigest;
      final points = <CanonicalGpsPoint>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            points.add(CanonicalGpsPoint.fromJson(decoded));
          }
        } catch (_) {
          // Exclude truncated/corrupted lines from canonical capture digest
        }
      }
      return RawGpsCanonicalVerification.computeCanonicalDigest(points);
    } catch (_) {
      return null;
    }
  }

  /// Safe deletion requiring explicit user authorization.
  ///
  /// Safe Deletion Semantics (RG-1A):
  /// - Automatic cleanup is DISABLED until RG-1B implements trusted canonical
  ///   cloud read-back verification. Calling `delete(sessionId)` without options
  ///   or without `force: true` fails closed and throws StateError.
  /// - Caller-provided SHA-256 or row counts are NOT accepted as proof of actual
  ///   Supabase read-back verification.
  /// - Explicit user-authorized workout/account deletion requires [force: true]
  ///   AND a verified non-empty [authorizedUserId]. Forced deletion without
  ///   trusted authorization fails closed.
  /// - If [manifest.userId] is present, it MUST match [authorizedUserId].
  /// - If [manifest.userId] is missing (legacy journals or missing manifest),
  ///   an independent trusted workout ownership verification is required via
  ///   [trustedWorkoutOwnershipVerifier] or [workoutOwnershipVerifier].
  /// - Ensures logout/account switching cannot delete another account's journal.
  Future<void> delete(
    String sessionId, {
    bool force = false,
    bool verifySafe = false,
    String? authorizedUserId,
    Future<bool> Function(String sessionId, String userId)?
        trustedWorkoutOwnershipVerifier,
    int? verifiedCloudCount,
    int? verifiedIsarCount,
    String? cloudReadBackSha256,
  }) async {
    // 1. Any automatic or non-forced deletion MUST fail closed.
    if (!force) {
      throw StateError(
        'Automatic raw GPS recovery journal deletion is disabled until RG-1B canonical cloud '
        'read-back verification is implemented. Journals cannot be deleted automatically '
        'based on counts, flags, or caller-provided hashes.',
      );
    }

    // 2. Reject any forced deletion without trusted authorization.
    // Do not permit optional authorizedUserId to bypass ownership checking.
    if (authorizedUserId == null || authorizedUserId.trim().isEmpty) {
      throw StateError(
        'Cannot delete raw GPS recovery journal for $sessionId without trusted authorization. '
        'Forced deletion requires a verified, non-empty authorizedUserId.',
      );
    }

    final manifest = await readManifest(sessionId);

    // 3. Ownership verification:
    if (manifest != null && manifest.userId != null) {
      if (manifest.userId != authorizedUserId) {
        throw StateError(
          'Cannot delete raw GPS recovery journal for $sessionId: unauthorized. '
          'Authorized user ($authorizedUserId) does not match journal owner (${manifest.userId}).',
        );
      }
    } else {
      // 4. If manifest.userId is missing, require independent, trusted workout
      // ownership verification before deletion.
      final verifier =
          trustedWorkoutOwnershipVerifier ?? workoutOwnershipVerifier;
      if (verifier == null) {
        throw StateError(
          'Cannot delete raw GPS recovery journal for $sessionId: manifest owner is missing '
          'and no independent trusted workout ownership verifier was provided.',
        );
      }
      final isVerified = await verifier(sessionId, authorizedUserId);
      if (!isVerified) {
        throw StateError(
          'Cannot delete raw GPS recovery journal for $sessionId: unauthorized. '
          'Independent workout ownership verification failed for user $authorizedUserId.',
        );
      }
    }

    _pendingWriters.remove(sessionId);
    final writer = _activeWriters.remove(sessionId);
    if (writer != null) {
      await writer.dispose();
    }

    final journalFile = await fileForSession(sessionId);
    if (await journalFile.exists()) {
      await journalFile.delete();
    }

    final manifestFile = await manifestFileForSession(sessionId);
    if (await manifestFile.exists()) {
      await manifestFile.delete();
    }

    final tmpManifest = File('${manifestFile.path}.tmp');
    if (await tmpManifest.exists()) {
      await tmpManifest.delete();
    }

    final quarantineFile = File('${journalFile.path}.quarantine');
    if (await quarantineFile.exists()) {
      await quarantineFile.delete();
    }

    final repairedTmp = File('${journalFile.path}.repaired.tmp');
    if (await repairedTmp.exists()) {
      await repairedTmp.delete();
    }

    final origBak = File('${journalFile.path}.orig.bak');
    if (await origBak.exists()) {
      await origBak.delete();
    }
  }

  Future<_SessionJournalWriter> _getOrCreateWriter(
    String sessionId, {
    String? userId,
  }) {
    final existing = _activeWriters[sessionId];
    if (existing != null) return Future.value(existing);

    final pending = _pendingWriters[sessionId];
    if (pending != null) return pending;

    final future = _createWriter(sessionId, userId: userId);
    _pendingWriters[sessionId] = future;
    return future;
  }

  Future<_SessionJournalWriter> _createWriter(
    String sessionId, {
    String? userId,
  }) async {
    try {
      final journalFile = await fileForSession(sessionId);
      final manifestFile = await manifestFileForSession(sessionId);
      await journalFile.parent.create(recursive: true);

      // Check existing manifest
      RawGpsJournalManifest? existingManifest;
      if (await manifestFile.exists()) {
        try {
          final content = await manifestFile.readAsString();
          existingManifest = RawGpsJournalManifest.fromJson(
            jsonDecode(content) as Map<String, dynamic>,
          );
        } catch (_) {}
      }

      // Reconcile actual committed lines and detect truncated final line
      var actualCommittedCount = 0;
      DateTime? firstTimestamp;
      DateTime? lastTimestamp;
      if (await journalFile.exists()) {
        final lines = await journalFile.readAsLines();
        final validLines = <String>[];
        var hadTruncatedFinalLine = false;
        String? truncatedSnippet;

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          try {
            final decoded = jsonDecode(line);
            if (decoded is! Map<String, dynamic>) {
              throw const FormatException('Expected JSON object');
            }
            validLines.add(line);
            final tsStr = decoded['timestamp'] as String?;
            if (tsStr != null) {
              final ts = DateTime.tryParse(tsStr)?.toUtc();
              if (ts != null) {
                firstTimestamp ??= ts;
                lastTimestamp = ts;
              }
            }
          } catch (_) {
            if (i == lines.length - 1) {
              hadTruncatedFinalLine = true;
              truncatedSnippet = line;
            }
          }
        }

        actualCommittedCount = validLines.length;

        // If final line was truncated, quarantine it and rewrite clean valid lines.
        // NON-DESTRUCTIVE: Creates verified replacement file before switching.
        // Preserves original bytes until replacement is safely committed.
        // If safe replacement fails, abort and leave the original recoverable.
        if (hadTruncatedFinalLine && truncatedSnippet != null) {
          final repairedTmp = File('${journalFile.path}.repaired.tmp');
          final originalBak = File('${journalFile.path}.orig.bak');
          final quarantineFile = File('${journalFile.path}.quarantine');

          try {
            if (onIoFaultInject != null) {
              await onIoFaultInject!('repair_copy');
            }

            final cleanContent = validLines.isEmpty
                ? ''
                : '${validLines.join('\n')}\n';
            await repairedTmp.writeAsString(cleanContent, flush: true);

            if (onIoFaultInject != null) {
              await onIoFaultInject!('repair_flush');
            }

            // Verify replacement file exists and matches expected content length
            final repairedBytes = utf8.encode(cleanContent);
            if (!await repairedTmp.exists() ||
                await repairedTmp.length() != repairedBytes.length) {
              throw StateError(
                'Repaired replacement journal file verification failed',
              );
            }

            // Write quarantine entry
            await quarantineFile.writeAsString(
              '$truncatedSnippet\n',
              mode: FileMode.append,
              flush: true,
            );

            // Safe atomic swap: backup original first, rename replacement, remove backup
            await journalFile.copy(originalBak.path);

            if (onIoFaultInject != null) {
              await onIoFaultInject!('repair_rename');
            }

            await repairedTmp.rename(journalFile.path);
            if (await originalBak.exists()) {
              await originalBak.delete();
            }
          } catch (e) {
            // Rollback: restore original if needed and clean up tmp files
            if (await originalBak.exists()) {
              await originalBak.copy(journalFile.path);
              await originalBak.delete();
            }
            if (await repairedTmp.exists()) {
              await repairedTmp.delete();
            }
            rethrow;
          }
        }
      }

      final initialCount = actualCommittedCount > 0
          ? actualCommittedCount
          : (existingManifest?.sampleCount ?? 0);

      final writer = _SessionJournalWriter(
        sessionId: sessionId,
        journalFile: journalFile,
        manifestFile: manifestFile,
        userId: userId ?? existingManifest?.userId,
        initialManifest: existingManifest,
        initialSampleCount: initialCount,
        initialFirstTimestamp: firstTimestamp,
        initialLastTimestamp: lastTimestamp,
        checkpointInterval: checkpointInterval,
        maxQueueDepth: maxQueueDepth,
        onIoFaultInject: onIoFaultInject,
      );
      _activeWriters[sessionId] = writer;
      return writer;
    } finally {
      _pendingWriters.remove(sessionId);
    }
  }

  static LocalGPSPoint _pointFromJson(Map<String, dynamic> json) {
    return LocalGPSPoint()
      ..sessionId = json['workout_id'] as String? ?? ''
      ..timestamp = DateTime.parse(json['timestamp'] as String).toUtc()
      ..latitude = (json['latitude'] as num).toDouble()
      ..longitude = (json['longitude'] as num).toDouble()
      ..altitude = (json['altitude'] as num?)?.toDouble()
      ..speed = (json['speed'] as num?)?.toDouble()
      ..accuracy = (json['accuracy'] as num?)?.toDouble()
      ..heading = (json['heading'] as num?)?.toDouble()
      ..deviceSource = json['device_source'] as String?
      ..confidence = json['confidence'] as String? ?? 'high'
      ..isSynced = false;
  }

  static Future<void> _writeManifestAtomic(
    File manifestFile,
    RawGpsJournalManifest manifest, {
    Future<void> Function(String phase)? faultInject,
  }) async {
    final tmpFile = File('${manifestFile.path}.tmp');
    final jsonStr = jsonEncode(manifest.toJson());
    await tmpFile.writeAsString(jsonStr, flush: true);

    if (faultInject != null) {
      await faultInject('checkpoint_rename');
    }

    try {
      await tmpFile.rename(manifestFile.path);
    } catch (e) {
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }
}

/// Internal session-scoped serialized writer managing FIFO append ordering,
/// bounded queue backpressure, and atomic manifest checkpoints.
class _SessionJournalWriter {
  _SessionJournalWriter({
    required this.sessionId,
    required this.journalFile,
    required this.manifestFile,
    this.userId,
    RawGpsJournalManifest? initialManifest,
    int initialSampleCount = 0,
    DateTime? initialFirstTimestamp,
    DateTime? initialLastTimestamp,
    required this.checkpointInterval,
    required this.maxQueueDepth,
    this.onIoFaultInject,
  }) : _manifest =
           initialManifest ??
           RawGpsJournalManifest(
             workoutId: sessionId,
             userId: userId,
             sampleCount: initialSampleCount,
             checkpointSeq: 0,
             checkpointTimestampUtc: DateTime.now().toUtc(),
           ),
       _sampleCount = initialSampleCount,
       _acceptedCount = initialSampleCount,
       _committedCount = initialSampleCount,
       _durableCount = initialSampleCount,
       _firstTimestamp = initialFirstTimestamp ?? initialManifest?.firstTimestampUtc,
       _lastTimestamp = initialLastTimestamp ?? initialManifest?.lastTimestampUtc,
       _checkpointSeq = initialManifest?.checkpointSeq ?? 0;

  final String sessionId;
  final File journalFile;
  final File manifestFile;
  final String? userId;
  final int checkpointInterval;
  final int maxQueueDepth;
  final Future<void> Function(String phase)? onIoFaultInject;

  RawGpsJournalManifest _manifest;
  int _sampleCount;
  int _checkpointSeq;
  int _acceptedCount;
  int _queuedCount = 0;
  int _committedCount;
  int _durableCount;
  int _failedCount = 0;
  int _droppedCount = 0;
  int _totalLatencyMicros = 0;
  int _minLatencyMicros = 0x7fffffffffffffff;
  int _maxLatencyMicros = 0;

  DateTime? _firstTimestamp;
  DateTime? _lastTimestamp;

  Future<void> _writeTail = Future<void>.value();

  Future<RawGpsAppendResult> append(
    LocalGPSPoint point, {
    String? userId,
  }) {
    if (_queuedCount >= maxQueueDepth) {
      _droppedCount += 1;
      return Future.value(
        const RawGpsAppendResult(
          success: false,
          sampleIndex: -1,
          latencyMicros: 0,
          error:
              'Raw GPS journal queue buffer overflow: maximum depth exceeded.',
        ),
      );
    }

    _acceptedCount += 1;
    _queuedCount += 1;
    final completer = Completer<RawGpsAppendResult>();

    _writeTail = _writeTail.then((_) async {
      final sw = Stopwatch()..start();
      try {
        final lineMap = _toJson(point, userId: userId ?? this.userId);
        final lineStr = '${jsonEncode(lineMap)}\n';

        await journalFile.writeAsString(
          lineStr,
          mode: FileMode.append,
          flush: true,
        );

        _sampleCount += 1;
        _committedCount += 1;
        _durableCount += 1;
        _firstTimestamp ??= point.timestamp.toUtc();
        _lastTimestamp = point.timestamp.toUtc();

        sw.stop();
        final latencyMicros = sw.elapsedMicroseconds;
        _totalLatencyMicros += latencyMicros;
        if (latencyMicros < _minLatencyMicros) {
          _minLatencyMicros = latencyMicros;
        }
        if (latencyMicros > _maxLatencyMicros) {
          _maxLatencyMicros = latencyMicros;
        }

        if (_sampleCount % checkpointInterval == 0) {
          await _executeCheckpointInternal();
        }

        completer.complete(
          RawGpsAppendResult(
            success: true,
            sampleIndex: _sampleCount,
            latencyMicros: latencyMicros,
          ),
        );
      } catch (error) {
        sw.stop();
        _failedCount += 1;
        completer.complete(
          RawGpsAppendResult(
            success: false,
            sampleIndex: _sampleCount,
            latencyMicros: sw.elapsedMicroseconds,
            error: error.toString(),
          ),
        );
      } finally {
        _queuedCount -= 1;
      }
    });

    return completer.future;
  }

  Future<void> checkpoint({
    bool isFinalized = false,
    bool cloudVerified = false,
    int? cloudVerifiedCount,
    String? cloudVerifiedSha256,
    String? canonicalCaptureDigest,
  }) {
    final completer = Completer<void>();
    _writeTail = _writeTail.then((_) async {
      try {
        await _executeCheckpointInternal(
          isFinalized: isFinalized,
          cloudVerified: cloudVerified,
          cloudVerifiedCount: cloudVerifiedCount,
          cloudVerifiedSha256: cloudVerifiedSha256,
          canonicalCaptureDigest: canonicalCaptureDigest,
        );
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<void> waitForInFlightWrites() {
    return _writeTail;
  }

  RawGpsJournalDiagnostics getDiagnostics() {
    return RawGpsJournalDiagnostics(
      sessionId: sessionId,
      acceptedSamples: _acceptedCount,
      queuedAppends: _queuedCount,
      committedSamples: _committedCount,
      durableSamples: _durableCount,
      failedSamples: _failedCount,
      droppedSamples: _droppedCount,
      totalLatencyMicros: _totalLatencyMicros,
      minLatencyMicros:
          _minLatencyMicros == 0x7fffffffffffffff ? 0 : _minLatencyMicros,
      maxLatencyMicros: _maxLatencyMicros,
    );
  }

  Future<void> dispose() async {
    await waitForInFlightWrites();
  }

  Future<void> _executeCheckpointInternal({
    bool? isFinalized,
    bool? cloudVerified,
    int? cloudVerifiedCount,
    String? cloudVerifiedSha256,
    String? canonicalCaptureDigest,
  }) async {
    _checkpointSeq += 1;
    final currentDigest = await _computeFileSha256();
    if (currentDigest == null && _sampleCount > 0) {
      throw StateError(
        'Failed to compute SHA-256 for journal $sessionId at checkpoint sequence $_checkpointSeq',
      );
    }

    final canonicalDigest = canonicalCaptureDigest ??
        await RawGpsRecoveryJournal._computeCanonicalDigestFromFile(journalFile);

    _manifest = _manifest.copyWith(
      sampleCount: _sampleCount,
      firstTimestampUtc: _firstTimestamp,
      lastTimestampUtc: _lastTimestamp,
      fileSha256: currentDigest,
      canonicalCaptureDigest: canonicalDigest,
      checkpointSeq: _checkpointSeq,
      checkpointTimestampUtc: DateTime.now().toUtc(),
      isFinalized: isFinalized ?? _manifest.isFinalized,
      cloudVerified: cloudVerified ?? _manifest.cloudVerified,
      cloudVerifiedCount: cloudVerifiedCount ?? _manifest.cloudVerifiedCount,
      cloudVerifiedSha256:
          cloudVerifiedSha256 ?? _manifest.cloudVerifiedSha256,
    );

    await RawGpsRecoveryJournal._writeManifestAtomic(
      manifestFile,
      _manifest,
      faultInject: onIoFaultInject,
    );
  }

  Future<String?> _computeFileSha256() =>
      RawGpsRecoveryJournal._computeFileSha256(journalFile);

  static Map<String, dynamic> _toJson(
    LocalGPSPoint point, {
    String? userId,
  }) => {
    'workout_id': point.sessionId,
    'user_id': ?userId,
    'timestamp': point.timestamp.toUtc().toIso8601String(),
    'latitude': point.latitude,
    'longitude': point.longitude,
    if (point.altitude != null) 'altitude': point.altitude,
    if (point.speed != null) 'speed': point.speed,
    if (point.accuracy != null) 'accuracy': point.accuracy,
    if (point.heading != null) 'heading': point.heading,
    if (point.deviceSource != null) 'device_source': point.deviceSource,
    'confidence': point.confidence,
  };
}
