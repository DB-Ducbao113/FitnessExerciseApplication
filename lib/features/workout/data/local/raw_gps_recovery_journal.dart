import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Status outcomes for recovery journal reading.
enum RawGpsRecoveryStatus {
  verifiedIntact,
  partiallyRecoveredTruncated,
  recoveredLegacyNoManifest,
  corruptedWithRecoveredPoints,
  accountMismatch,
  emptyOrNotFound,
}

/// Versioned companion manifest tracking raw GPS journal checkpoints.
class RawGpsJournalManifest {
  static const String currentSchemaVersion = 'aetron.raw_gps.manifest.v1';

  final String schemaVersion;
  final String workoutId;
  final String? userId;
  final int sampleCount;
  final DateTime? firstTimestampUtc;
  final DateTime? lastTimestampUtc;
  final String? sha256Digest;
  final int checkpointSeq;
  final DateTime checkpointTimestampUtc;
  final bool isFinalized;
  final bool cloudVerified;
  final int cloudVerifiedCount;
  final String? cloudVerifiedSha256;

  const RawGpsJournalManifest({
    this.schemaVersion = currentSchemaVersion,
    required this.workoutId,
    this.userId,
    required this.sampleCount,
    this.firstTimestampUtc,
    this.lastTimestampUtc,
    this.sha256Digest,
    required this.checkpointSeq,
    required this.checkpointTimestampUtc,
    this.isFinalized = false,
    this.cloudVerified = false,
    this.cloudVerifiedCount = 0,
    this.cloudVerifiedSha256,
  });

  RawGpsJournalManifest copyWith({
    int? sampleCount,
    DateTime? firstTimestampUtc,
    DateTime? lastTimestampUtc,
    String? sha256Digest,
    int? checkpointSeq,
    DateTime? checkpointTimestampUtc,
    bool? isFinalized,
    bool? cloudVerified,
    int? cloudVerifiedCount,
    String? cloudVerifiedSha256,
  }) {
    return RawGpsJournalManifest(
      schemaVersion: schemaVersion,
      workoutId: workoutId,
      userId: userId,
      sampleCount: sampleCount ?? this.sampleCount,
      firstTimestampUtc: firstTimestampUtc ?? this.firstTimestampUtc,
      lastTimestampUtc: lastTimestampUtc ?? this.lastTimestampUtc,
      sha256Digest: sha256Digest ?? this.sha256Digest,
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
    if (sha256Digest != null) 'sha256_digest': sha256Digest,
    'checkpoint_seq': checkpointSeq,
    'checkpoint_timestamp_utc': checkpointTimestampUtc.toUtc().toIso8601String(),
    'is_finalized': isFinalized,
    'cloud_verified': cloudVerified,
    'cloud_verified_count': cloudVerifiedCount,
    if (cloudVerifiedSha256 != null)
      'cloud_verified_sha256': cloudVerifiedSha256,
  };

  factory RawGpsJournalManifest.fromJson(Map<String, dynamic> json) {
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
      sha256Digest: json['sha256_digest'] as String?,
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
  final int queuedAppends;
  final int committedSamples;
  final int droppedSamples;
  final int totalLatencyMicros;
  final int minLatencyMicros;
  final int maxLatencyMicros;

  const RawGpsJournalDiagnostics({
    required this.sessionId,
    required this.queuedAppends,
    required this.committedSamples,
    required this.droppedSamples,
    required this.totalLatencyMicros,
    required this.minLatencyMicros,
    required this.maxLatencyMicros,
  });

  double get meanLatencyMs => committedSamples > 0
      ? (totalLatencyMicros / committedSamples) / 1000.0
      : 0.0;
  double get minLatencyMs => minLatencyMicros / 1000.0;
  double get maxLatencyMs => maxLatencyMicros / 1000.0;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'queued_appends': queuedAppends,
    'committed_samples': committedSamples,
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
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static final RawGpsRecoveryJournal instance = RawGpsRecoveryJournal();

  final Future<Directory> Function() _documentsDirectory;
  final int checkpointInterval;
  final int maxQueueDepth;

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
  }) async {
    final writer = _activeWriters[sessionId];
    if (writer != null) {
      await writer.checkpoint(
        isFinalized: isFinalized,
        cloudVerified: cloudVerified,
        cloudVerifiedCount: cloudVerifiedCount,
        cloudVerifiedSha256: cloudVerifiedSha256,
      );
    } else {
      // If writer is not in memory, update manifest file directly if it exists
      try {
        final manifestFile = await manifestFileForSession(sessionId);
        if (await manifestFile.exists()) {
          final content = await manifestFile.readAsString();
          final existing = RawGpsJournalManifest.fromJson(
            jsonDecode(content) as Map<String, dynamic>,
          );
          final updated = existing.copyWith(
            isFinalized: isFinalized,
            cloudVerified: cloudVerified,
            cloudVerifiedCount: cloudVerifiedCount,
            cloudVerifiedSha256: cloudVerifiedSha256,
            checkpointTimestampUtc: DateTime.now().toUtc(),
            checkpointSeq: existing.checkpointSeq + 1,
          );
          await _writeManifestAtomic(manifestFile, updated);
        }
      } catch (e) {
        if (e is! FlutterError) {
          debugPrint('[RawGpsRecoveryJournal] direct checkpoint failed: $e');
        }
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
      return RawGpsRecoveryResult(
        sessionId: sessionId,
        points: const [],
        manifest: manifest,
        status: manifest != null
            ? RawGpsRecoveryStatus.verifiedIntact
            : RawGpsRecoveryStatus.recoveredLegacyNoManifest,
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
        if (activeUserId != null &&
            lineUserId != null &&
            lineUserId != activeUserId) {
          return RawGpsRecoveryResult.accountMismatch(
            sessionId: sessionId,
            accountMismatchUserId: lineUserId,
          );
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

    // Sort monotonically by timestamp
    validPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    RawGpsRecoveryStatus status;
    if (hasTruncatedFinalLine) {
      status = RawGpsRecoveryStatus.partiallyRecoveredTruncated;
    } else if (corruptedLinesCount > 0) {
      status = RawGpsRecoveryStatus.corruptedWithRecoveredPoints;
    } else if (manifest == null) {
      status = RawGpsRecoveryStatus.recoveredLegacyNoManifest;
    } else {
      status = RawGpsRecoveryStatus.verifiedIntact;
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

  /// Safe deletion requiring explicit verification or [force].
  ///
  /// Rejects blind deletion if [verifySafe] is true and an alternative copy
  /// (cloud or Isar) has not been confirmed.
  Future<void> delete(
    String sessionId, {
    bool force = false,
    bool verifySafe = false,
    int? verifiedCloudCount,
    int? verifiedIsarCount,
  }) async {
    if (verifySafe && !force) {
      final manifest = await readManifest(sessionId);
      if (manifest != null && manifest.sampleCount > 0) {
        final cloudOk =
            verifiedCloudCount != null &&
            verifiedCloudCount >= manifest.sampleCount;
        final isarOk =
            verifiedIsarCount != null &&
            verifiedIsarCount >= manifest.sampleCount;
        if (!cloudOk && !isarOk && !manifest.cloudVerified) {
          throw StateError(
            'Cannot delete unverified raw GPS journal for $sessionId without confirmed local or cloud replica.',
          );
        }
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

      final writer = _SessionJournalWriter(
        sessionId: sessionId,
        journalFile: journalFile,
        manifestFile: manifestFile,
        userId: userId ?? existingManifest?.userId,
        initialManifest: existingManifest,
        checkpointInterval: checkpointInterval,
        maxQueueDepth: maxQueueDepth,
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
    RawGpsJournalManifest manifest,
  ) async {
    final tmpFile = File('${manifestFile.path}.tmp');
    final jsonStr = jsonEncode(manifest.toJson());
    await tmpFile.writeAsString(jsonStr, flush: true);
    try {
      await tmpFile.rename(manifestFile.path);
    } catch (_) {
      // Fallback for filesystems that do not support atomic replace
      await manifestFile.writeAsString(jsonStr, flush: true);
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
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
    required this.checkpointInterval,
    required this.maxQueueDepth,
  }) : _manifest =
           initialManifest ??
           RawGpsJournalManifest(
             workoutId: sessionId,
             userId: userId,
             sampleCount: 0,
             checkpointSeq: 0,
             checkpointTimestampUtc: DateTime.now().toUtc(),
           ),
       _sampleCount = initialManifest?.sampleCount ?? 0,
       _checkpointSeq = initialManifest?.checkpointSeq ?? 0;

  final String sessionId;
  final File journalFile;
  final File manifestFile;
  final String? userId;
  final int checkpointInterval;
  final int maxQueueDepth;

  RawGpsJournalManifest _manifest;
  int _sampleCount;
  int _checkpointSeq;
  int _queuedCount = 0;
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
  }) {
    final completer = Completer<void>();
    _writeTail = _writeTail.then((_) async {
      try {
        await _executeCheckpointInternal(
          isFinalized: isFinalized,
          cloudVerified: cloudVerified,
          cloudVerifiedCount: cloudVerifiedCount,
          cloudVerifiedSha256: cloudVerifiedSha256,
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
      queuedAppends: _queuedCount,
      committedSamples: _sampleCount,
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
  }) async {
    _checkpointSeq += 1;
    final currentDigest = await _computeFileSha256();

    _manifest = _manifest.copyWith(
      sampleCount: _sampleCount,
      firstTimestampUtc: _firstTimestamp,
      lastTimestampUtc: _lastTimestamp,
      sha256Digest: currentDigest,
      checkpointSeq: _checkpointSeq,
      checkpointTimestampUtc: DateTime.now().toUtc(),
      isFinalized: isFinalized ?? _manifest.isFinalized,
      cloudVerified: cloudVerified ?? _manifest.cloudVerified,
      cloudVerifiedCount: cloudVerifiedCount ?? _manifest.cloudVerifiedCount,
      cloudVerifiedSha256:
          cloudVerifiedSha256 ?? _manifest.cloudVerifiedSha256,
    );

    await RawGpsRecoveryJournal._writeManifestAtomic(manifestFile, _manifest);
  }

  Future<String?> _computeFileSha256() async {
    try {
      if (!await journalFile.exists()) return null;
      final length = await journalFile.length();
      if (length == 0) return null;
      final digest = await sha256.bind(journalFile.openRead()).first;
      return digest.toString();
    } catch (_) {
      return null;
    }
  }

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
