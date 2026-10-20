import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';

/// Verification states for raw GPS cloud backup and integrity reconciliation (RG-1B / RG-1B.1).
enum RawGpsVerificationState {
  pendingUpload,
  uploading,
  uploadedUnverified,
  cloudVerified,
  partial,
  integrityMismatch,
  restoredUnverified,
  unknown,
  authRequired,
  unsupported;

  String get label => switch (this) {
    RawGpsVerificationState.pendingUpload => 'PENDING_UPLOAD',
    RawGpsVerificationState.uploading => 'UPLOADING',
    RawGpsVerificationState.uploadedUnverified => 'UPLOADED_UNVERIFIED',
    RawGpsVerificationState.cloudVerified => 'CLOUD_VERIFIED',
    RawGpsVerificationState.partial => 'PARTIAL',
    RawGpsVerificationState.integrityMismatch => 'INTEGRITY_MISMATCH',
    RawGpsVerificationState.restoredUnverified => 'RESTORED_UNVERIFIED',
    RawGpsVerificationState.unknown => 'UNKNOWN',
    RawGpsVerificationState.authRequired => 'AUTH_REQUIRED',
    RawGpsVerificationState.unsupported => 'UNSUPPORTED',
  };
}

/// Versioned canonical representation of a raw GPS point that is mutually preserved
/// by both client storage (Isar / JSONL journal) and Supabase (public.raw_gps_points).
///
/// PRECISION AND CANONICALIZATION SPECIFICATION:
/// 1. Spatial Resolution: `latitude` and `longitude` are formatted using `toStringAsFixed(7)`.
///    This represents ~1.1 cm resolution at the equator, eliminating floating-point
///    representation discrepancies across Dart (IEEE-754 double) and Postgres (numeric/float8).
/// 2. Telemetry Resolution: `altitude`, `speed`, `accuracy`, and `heading` are formatted using
///    `toStringAsFixed(2)` (cm, cm/s, 0.01 degrees). Null values are formatted as empty strings.
/// 3. Timestamp Resolution: UTC ISO 8601 microseconds (`toUtc().microsecondsSinceEpoch`).
/// 4. Local-only Attributes: `confidence` and `local_sequence_id` are intentionally excluded
///    from the canonical digest because they are not preserved in `public.raw_gps_points`.
///    Consequently, canonical verification evaluates true data fidelity of mutually preserved
///    fields, but does not imply full-fidelity capture of sensor-only local metadata.
class CanonicalGpsPoint implements Comparable<CanonicalGpsPoint> {
  final String workoutId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? heading;
  final String? deviceSource;

  const CanonicalGpsPoint({
    required this.workoutId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    this.heading,
    this.deviceSource,
  });

  factory CanonicalGpsPoint.fromLocal(LocalGPSPoint point) => CanonicalGpsPoint(
    workoutId: point.sessionId,
    timestamp: point.timestamp.toUtc(),
    latitude: point.latitude,
    longitude: point.longitude,
    altitude: point.altitude,
    speed: point.speed,
    accuracy: point.accuracy,
    heading: point.heading,
    deviceSource: point.deviceSource,
  );

  factory CanonicalGpsPoint.fromPayload(RawGpsPointPayload payload) =>
      CanonicalGpsPoint(
        workoutId: payload.workoutId,
        timestamp: payload.timestamp.toUtc(),
        latitude: payload.latitude,
        longitude: payload.longitude,
        altitude: payload.altitude,
        speed: payload.speed,
        accuracy: payload.accuracy,
        heading: payload.heading,
        deviceSource: payload.deviceSource,
      );

  factory CanonicalGpsPoint.fromJson(Map<String, dynamic> json) =>
      CanonicalGpsPoint(
        workoutId: (json['workout_id'] ?? json['sessionId'] ?? '') as String,
        timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        deviceSource: json['device_source'] as String?,
      );

  /// Sample identity key for deduplication and matching
  String get identityKey {
    final t = timestamp.toUtc().microsecondsSinceEpoch;
    final latStr = latitude.toStringAsFixed(7);
    final lngStr = longitude.toStringAsFixed(7);
    return '$t|$latStr|$lngStr';
  }

  /// Version 1 canonical string representation
  String toCanonicalLine() {
    final t = timestamp.toUtc().microsecondsSinceEpoch;
    final latStr = latitude.toStringAsFixed(7);
    final lngStr = longitude.toStringAsFixed(7);
    final altStr = altitude != null ? altitude!.toStringAsFixed(2) : '';
    final speedStr = speed != null ? speed!.toStringAsFixed(2) : '';
    final accStr = accuracy != null ? accuracy!.toStringAsFixed(2) : '';
    final headStr = heading != null ? heading!.toStringAsFixed(2) : '';
    final src = deviceSource ?? '';
    return 'v1|$workoutId|$t|$latStr|$lngStr|$altStr|$speedStr|$accStr|$headStr|$src';
  }

  @override
  int compareTo(CanonicalGpsPoint other) {
    final timeCmp = timestamp.toUtc().microsecondsSinceEpoch.compareTo(
      other.timestamp.toUtc().microsecondsSinceEpoch,
    );
    if (timeCmp != 0) return timeCmp;
    final latCmp = latitude.compareTo(other.latitude);
    if (latCmp != 0) return latCmp;
    return longitude.compareTo(other.longitude);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanonicalGpsPoint &&
          toCanonicalLine() == other.toCanonicalLine();

  @override
  int get hashCode => toCanonicalLine().hashCode;
}

/// Detailed result of canonical cloud read-back verification against local ground truth or manifest.
class RawGpsVerificationReport {
  final String workoutId;
  final RawGpsVerificationState state;
  final int localCount;
  final int cloudCount;
  final String localDigest;
  final String? cloudDigest;
  final int missingCloudSampleCount;
  final int extraCloudSampleCount;
  final int mismatchedSampleCount;
  final String message;

  const RawGpsVerificationReport({
    required this.workoutId,
    required this.state,
    required this.localCount,
    required this.cloudCount,
    required this.localDigest,
    this.cloudDigest,
    required this.missingCloudSampleCount,
    required this.extraCloudSampleCount,
    required this.mismatchedSampleCount,
    required this.message,
  });

  bool get isVerified => state == RawGpsVerificationState.cloudVerified;
}

/// Service implementing versioned canonical digest calculation and verification
/// for RG-1B / RG-1B.1 cloud preservation.
class RawGpsCanonicalVerification {
  /// Canonical SHA-256 digest of an empty record set
  static const String emptyDigest =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  /// Computes the versioned canonical SHA-256 digest of a collection of points.
  /// Points are sorted deterministically before computing the digest.
  static String computeCanonicalDigest(Iterable<CanonicalGpsPoint> points) {
    final sorted = points.toList()..sort();
    if (sorted.isEmpty) return emptyDigest;

    final buffer = StringBuffer();
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0) buffer.write('\n');
      buffer.write(sorted[i].toCanonicalLine());
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  /// Returns a fail-closed verification report explicitly designating an unsupported platform (RG-F2).
  static RawGpsVerificationReport unsupportedPlatform({
    required String workoutId,
    String platform = 'web',
  }) {
    return RawGpsVerificationReport(
      workoutId: workoutId,
      state: RawGpsVerificationState.unsupported,
      localCount: 0,
      cloudCount: 0,
      localDigest: emptyDigest,
      cloudDigest: null,
      missingCloudSampleCount: 0,
      extraCloudSampleCount: 0,
      mismatchedSampleCount: 0,
      message:
          'Research-grade raw GPS capture and cloud outbox verification are supported only on native mobile platforms (iOS/Android). Unsupported on $platform.',
    );
  }

  /// Verifies server-retrieved records against local ground truth.
  static RawGpsVerificationReport verify({
    required String workoutId,
    required List<CanonicalGpsPoint> localPoints,
    required List<CanonicalGpsPoint> cloudPoints,
    bool isAuthError = false,
  }) {
    if (isAuthError) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.authRequired,
        localCount: localPoints.length,
        cloudCount: cloudPoints.length,
        localDigest: computeCanonicalDigest(localPoints),
        cloudDigest: null,
        missingCloudSampleCount: localPoints.length,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: 0,
        message: 'Authentication required to verify cloud backup.',
      );
    }

    final localSorted = localPoints.toList()..sort();
    final cloudSorted = cloudPoints.toList()..sort();

    final localDigest = computeCanonicalDigest(localSorted);
    final cloudDigest = computeCanonicalDigest(cloudSorted);

    final localMap = <String, CanonicalGpsPoint>{};
    for (final p in localSorted) {
      localMap[p.identityKey] = p;
    }

    final cloudMap = <String, CanonicalGpsPoint>{};
    for (final p in cloudSorted) {
      cloudMap[p.identityKey] = p;
    }

    var missingCloud = 0;
    var mismatched = 0;
    for (final entry in localMap.entries) {
      final cloudMatch = cloudMap[entry.key];
      if (cloudMatch == null) {
        missingCloud++;
      } else {
        if (entry.value.toCanonicalLine() != cloudMatch.toCanonicalLine()) {
          mismatched++;
        }
      }
    }

    var extraCloud = 0;
    for (final key in cloudMap.keys) {
      if (!localMap.containsKey(key)) {
        extraCloud++;
      }
    }

    RawGpsVerificationState state;
    String message;

    if (localPoints.isEmpty && cloudPoints.isEmpty) {
      state = RawGpsVerificationState.unknown;
      message = 'No raw GPS records found locally or in cloud.';
    } else if (localPoints.isNotEmpty && cloudPoints.isEmpty) {
      state = RawGpsVerificationState.pendingUpload;
      message =
          'Points recorded locally (${localPoints.length}) awaiting cloud upload.';
    } else if (cloudPoints.length < localPoints.length) {
      state = RawGpsVerificationState.partial;
      message =
          'Partial cloud backup: ${cloudPoints.length}/${localPoints.length} points confirmed.';
    } else if (cloudPoints.length == localPoints.length &&
        localDigest == cloudDigest) {
      state = RawGpsVerificationState.cloudVerified;
      message =
          'Canonical cloud verification PASSED ($localDigest, ${localPoints.length} samples).';
    } else {
      state = RawGpsVerificationState.integrityMismatch;
      message =
          'Cloud data integrity mismatch: digests do not match ($mismatched differences).';
    }

    return RawGpsVerificationReport(
      workoutId: workoutId,
      state: state,
      localCount: localPoints.length,
      cloudCount: cloudPoints.length,
      localDigest: localDigest,
      cloudDigest: cloudDigest,
      missingCloudSampleCount: missingCloud,
      extraCloudSampleCount: extraCloud,
      mismatchedSampleCount: mismatched,
      message: message,
    );
  }

  /// Verifies cloud-retrieved records against an independently recorded capture manifest (P0-04).
  ///
  /// Prevents circular verification where downloaded cloud records are compared only against
  /// a local cache reconstructed from that same download. If no independent capture manifest
  /// exists, returns [RawGpsVerificationState.restoredUnverified] (or [unknown] if empty).
  static RawGpsVerificationReport verifyAgainstManifest({
    required String workoutId,
    required RawGpsJournalManifest? manifest,
    required List<CanonicalGpsPoint> cloudPoints,
  }) {
    if (cloudPoints.isEmpty && manifest == null) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.unknown,
        localCount: 0,
        cloudCount: 0,
        localDigest: emptyDigest,
        cloudDigest: null,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: 0,
        message: 'No cloud records or capture manifest found.',
      );
    }

    if (manifest == null) {
      // Independent capture manifest is missing: cannot prove full original capture completeness!
      final cloudDigest = computeCanonicalDigest(cloudPoints);
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.restoredUnverified,
        localCount: 0,
        cloudCount: cloudPoints.length,
        localDigest: emptyDigest,
        cloudDigest: cloudDigest,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: cloudPoints.length,
        mismatchedSampleCount: 0,
        message:
            'Downloaded ${cloudPoints.length} points from cloud without independent capture manifest; '
            'marked as RESTORED_UNVERIFIED.',
      );
    }

    final cloudSorted = cloudPoints.toList()..sort();
    final cloudDigest = computeCanonicalDigest(cloudSorted);

    // 1. Manifest Identity Check: manifest workoutId must match requested workoutId
    if (manifest.workoutId != workoutId) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.integrityMismatch,
        localCount: manifest.sampleCount,
        cloudCount: cloudPoints.length,
        localDigest: manifest.canonicalCaptureDigest ?? emptyDigest,
        cloudDigest: cloudDigest,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: cloudPoints.length,
        message:
            'Manifest workoutId (${manifest.workoutId}) does not match requested workoutId ($workoutId).',
      );
    }

    // 2. Point Identity Check: verify all cloud points belong to this workout
    final foreignPointsCount =
        cloudPoints.where((p) => p.workoutId != workoutId).length;
    if (foreignPointsCount > 0) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.integrityMismatch,
        localCount: manifest.sampleCount,
        cloudCount: cloudPoints.length,
        localDigest: manifest.canonicalCaptureDigest ?? emptyDigest,
        cloudDigest: cloudDigest,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: foreignPointsCount,
        message:
            'Point identity mismatch: cloud points contain $foreignPointsCount records for another workout.',
      );
    }

    // 3. Manifest Integrity Check: sample count sanity
    if (manifest.sampleCount < 0) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.integrityMismatch,
        localCount: manifest.sampleCount,
        cloudCount: cloudPoints.length,
        localDigest: manifest.canonicalCaptureDigest ?? emptyDigest,
        cloudDigest: cloudDigest,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: cloudPoints.length,
        message:
            'Manifest integrity error: negative sample count (${manifest.sampleCount}).',
      );
    }

    // 4. Sample Count Verification (Fail-closed on partial cloud records)
    final expectedCount = manifest.sampleCount;
    if (expectedCount > 0 && cloudPoints.length < expectedCount) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.partial,
        localCount: expectedCount,
        cloudCount: cloudPoints.length,
        localDigest: manifest.canonicalCaptureDigest ?? emptyDigest,
        cloudDigest: cloudDigest,
        missingCloudSampleCount: expectedCount - cloudPoints.length,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: 0,
        message:
            'Partial cloud records: ${cloudPoints.length}/$expectedCount confirmed.',
      );
    }

    // 5. Independent Capture Proof Check (P0-01)
    // ONLY manifest.canonicalCaptureDigest is valid independent capture proof.
    // cloudVerifiedSha256 is the cloud echo and MUST NEVER substitute for capture proof!
    // Legacy v1 manifests without trusted canonical capture proof must remain RESTORED_UNVERIFIED.
    final expectedDigest = manifest.canonicalCaptureDigest;
    final isLegacyV1 =
        manifest.schemaVersion == RawGpsJournalManifest.schemaVersionV1;

    if (expectedDigest == null || expectedDigest.isEmpty || isLegacyV1) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.restoredUnverified,
        localCount: manifest.sampleCount,
        cloudCount: cloudPoints.length,
        localDigest: emptyDigest,
        cloudDigest: cloudDigest,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: cloudPoints.length > manifest.sampleCount
            ? cloudPoints.length - manifest.sampleCount
            : 0,
        mismatchedSampleCount: 0,
        message:
            'Capture manifest lacks independent canonical capture digest (legacy v1 or unverified manifest); '
            'marked RESTORED_UNVERIFIED without fabricating verification.',
      );
    }

    if (expectedCount == 0) {
      if (cloudPoints.isEmpty && expectedDigest == emptyDigest) {
        return RawGpsVerificationReport(
          workoutId: workoutId,
          state: RawGpsVerificationState.cloudVerified,
          localCount: 0,
          cloudCount: 0,
          localDigest: expectedDigest,
          cloudDigest: cloudDigest,
          missingCloudSampleCount: 0,
          extraCloudSampleCount: 0,
          mismatchedSampleCount: 0,
          message:
              'Zero-sample manifest canonically verified against empty cloud records.',
        );
      } else {
        return RawGpsVerificationReport(
          workoutId: workoutId,
          state: RawGpsVerificationState.integrityMismatch,
          localCount: 0,
          cloudCount: cloudPoints.length,
          localDigest: expectedDigest,
          cloudDigest: cloudDigest,
          missingCloudSampleCount: 0,
          extraCloudSampleCount: cloudPoints.length,
          mismatchedSampleCount: cloudPoints.length,
          message:
              'Manifest specifies 0 samples but cloud returned ${cloudPoints.length} points.',
        );
      }
    }

    if (cloudPoints.length > expectedCount) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.integrityMismatch,
        localCount: expectedCount,
        cloudCount: cloudPoints.length,
        localDigest: expectedDigest,
        cloudDigest: cloudDigest,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: cloudPoints.length - expectedCount,
        mismatchedSampleCount: cloudPoints.length - expectedCount,
        message:
            'Integrity mismatch: cloud records count (${cloudPoints.length}) exceeds manifest sample count ($expectedCount).',
      );
    }

    // 6. Canonical Digest Verification
    final digestMatches = expectedDigest == cloudDigest;
    if (digestMatches) {
      return RawGpsVerificationReport(
        workoutId: workoutId,
        state: RawGpsVerificationState.cloudVerified,
        localCount: expectedCount,
        cloudCount: cloudPoints.length,
        localDigest: expectedDigest,
        cloudDigest: cloudDigest,
        missingCloudSampleCount: 0,
        extraCloudSampleCount: 0,
        mismatchedSampleCount: 0,
        message:
            'Canonical manifest verification PASSED ($cloudDigest, $expectedCount samples).',
      );
    }

    return RawGpsVerificationReport(
      workoutId: workoutId,
      state: RawGpsVerificationState.integrityMismatch,
      localCount: expectedCount,
      cloudCount: cloudPoints.length,
      localDigest: expectedDigest,
      cloudDigest: cloudDigest,
      missingCloudSampleCount: 0,
      extraCloudSampleCount: 0,
      mismatchedSampleCount: cloudPoints.length,
      message:
          'Integrity mismatch: expected digest $expectedDigest, got $cloudDigest.',
    );
  }
}
