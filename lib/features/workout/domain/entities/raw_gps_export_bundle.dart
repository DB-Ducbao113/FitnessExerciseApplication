import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';

/// Provenance source kind for exported raw GPS datasets (RG-F4).
enum RawGpsExportSourceKind {
  /// Backed by a verified local journal with matching file SHA-256 and canonical capture digest.
  deviceJournalVerified('device_journal_verified'),

  /// Recovered from local storage or unverified/corrupted journal without full trusted manifest proof.
  deviceRecoveredUnverified('device_recovered_unverified'),

  /// Read back from Supabase cloud database without original local capture evidence.
  cloudOnlyUnverified('cloud_only_unverified');

  final String value;
  const RawGpsExportSourceKind(this.value);

  static RawGpsExportSourceKind fromValue(String value) {
    for (final kind in RawGpsExportSourceKind.values) {
      if (kind.value == value) return kind;
    }
    return RawGpsExportSourceKind.deviceRecoveredUnverified;
  }
}

/// Lossless research-grade raw GPS sample point for export, analysis, and replay.
class RawGpsExportPoint implements Comparable<RawGpsExportPoint> {
  final String workoutId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? heading;
  final String? deviceSource;

  const RawGpsExportPoint({
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

  factory RawGpsExportPoint.fromLocal(LocalGPSPoint point) => RawGpsExportPoint(
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

  factory RawGpsExportPoint.fromCanonical(CanonicalGpsPoint point) =>
      RawGpsExportPoint(
        workoutId: point.workoutId,
        timestamp: point.timestamp.toUtc(),
        latitude: point.latitude,
        longitude: point.longitude,
        altitude: point.altitude,
        speed: point.speed,
        accuracy: point.accuracy,
        heading: point.heading,
        deviceSource: point.deviceSource,
      );

  factory RawGpsExportPoint.fromPayload(RawGpsPointPayload payload) =>
      RawGpsExportPoint(
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

  factory RawGpsExportPoint.fromJson(Map<String, dynamic> json) {
    final workoutId = (json['workout_id'] ?? json['sessionId'] ?? '') as String;
    final rawTs = json['timestamp'];
    final DateTime ts;
    if (rawTs is int) {
      ts = DateTime.fromMicrosecondsSinceEpoch(rawTs, isUtc: true);
    } else if (rawTs is String) {
      ts = DateTime.parse(rawTs).toUtc();
    } else if (json['timestamp_micros'] is int) {
      ts = DateTime.fromMicrosecondsSinceEpoch(
        json['timestamp_micros'] as int,
        isUtc: true,
      );
    } else {
      throw FormatException('Invalid timestamp format in raw GPS point: $rawTs');
    }

    return RawGpsExportPoint(
      workoutId: workoutId,
      timestamp: ts,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      deviceSource: json['device_source'] as String? ?? json['deviceSource'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'workout_id': workoutId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'timestamp_micros': timestamp.toUtc().microsecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        if (altitude != null) 'altitude': altitude,
        if (speed != null) 'speed': speed,
        if (accuracy != null) 'accuracy': accuracy,
        if (heading != null) 'heading': heading,
        if (deviceSource != null) 'device_source': deviceSource,
      };

  CanonicalGpsPoint toCanonical() => CanonicalGpsPoint(
        workoutId: workoutId,
        timestamp: timestamp.toUtc(),
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        speed: speed,
        accuracy: accuracy,
        heading: heading,
        deviceSource: deviceSource,
      );

  RawGpsPointPayload toPayload() => RawGpsPointPayload(
        workoutId: workoutId,
        timestamp: timestamp.toUtc(),
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        speed: speed,
        accuracy: accuracy,
        heading: heading,
        deviceSource: deviceSource,
      );

  /// Identity key for deduplication and matching
  String get identityKey {
    final t = timestamp.toUtc().microsecondsSinceEpoch;
    final latStr = latitude.toStringAsFixed(7);
    final lngStr = longitude.toStringAsFixed(7);
    return '$t|$latStr|$lngStr';
  }

  @override
  int compareTo(RawGpsExportPoint other) {
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
      other is RawGpsExportPoint &&
          workoutId == other.workoutId &&
          timestamp.toUtc().microsecondsSinceEpoch ==
              other.timestamp.toUtc().microsecondsSinceEpoch &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          altitude == other.altitude &&
          speed == other.speed &&
          accuracy == other.accuracy &&
          heading == other.heading &&
          deviceSource == other.deviceSource;

  @override
  int get hashCode => Object.hash(
        workoutId,
        timestamp.toUtc().microsecondsSinceEpoch,
        latitude,
        longitude,
        altitude,
        speed,
        accuracy,
        heading,
        deviceSource,
      );
}

/// Provenance companion manifest tracking exported dataset integrity and provenance.
class RawGpsExportManifest {
  static const String currentSchemaVersion = 'aetron.rg_f4.dataset_manifest.v1';

  final String schemaVersion;
  final String sourceKind;
  final bool userScoped;
  final String workoutId;
  final DateTime exportGeneratedAtUtc;
  final String? appCommit;
  final int recordCount;
  final DateTime? firstSampleUtc;
  final DateTime? lastSampleUtc;
  final String timestampPrecision;
  final Map<String, String> units;
  final String nullSemantics;
  final int duplicateCount;
  final Map<String, dynamic> gapSummary;
  final String? rawJsonlByteSha256;
  final String? canonicalCaptureDigest;
  final String exportJsonlSha256;
  final String exportCsvSha256;
  final String exportGpxSha256;
  final String consentScope;

  const RawGpsExportManifest({
    this.schemaVersion = currentSchemaVersion,
    required this.sourceKind,
    this.userScoped = true,
    required this.workoutId,
    required this.exportGeneratedAtUtc,
    this.appCommit,
    required this.recordCount,
    this.firstSampleUtc,
    this.lastSampleUtc,
    this.timestampPrecision = 'microseconds',
    this.units = const {
      'latitude': 'degrees',
      'longitude': 'degrees',
      'altitude': 'meters',
      'speed': 'm/s',
      'accuracy': 'meters',
      'heading': 'degrees',
    },
    this.nullSemantics =
        'empty string in CSV, null in JSONL/manifest, omitted or namespaced in GPX',
    this.duplicateCount = 0,
    required this.gapSummary,
    this.rawJsonlByteSha256,
    this.canonicalCaptureDigest,
    required this.exportJsonlSha256,
    required this.exportCsvSha256,
    required this.exportGpxSha256,
    this.consentScope = 'owner_research_export',
  });

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'source_kind': sourceKind,
        'user_scoped': userScoped,
        'workout_id': workoutId,
        'export_generated_at_utc': exportGeneratedAtUtc.toUtc().toIso8601String(),
        if (appCommit != null) 'app_commit': appCommit,
        'record_count': recordCount,
        if (firstSampleUtc != null)
          'first_sample_utc': firstSampleUtc!.toUtc().toIso8601String(),
        if (lastSampleUtc != null)
          'last_sample_utc': lastSampleUtc!.toUtc().toIso8601String(),
        'timestamp_precision': timestampPrecision,
        'units': units,
        'null_semantics': nullSemantics,
        'duplicate_count': duplicateCount,
        'gap_summary': gapSummary,
        'raw_jsonl_byte_sha256': rawJsonlByteSha256,
        'canonical_capture_digest': canonicalCaptureDigest,
        'export_jsonl_sha256': exportJsonlSha256,
        'export_csv_sha256': exportCsvSha256,
        'export_gpx_sha256': exportGpxSha256,
        'consent_scope': consentScope,
      };

  factory RawGpsExportManifest.fromJson(Map<String, dynamic> json) {
    return RawGpsExportManifest(
      schemaVersion:
          json['schema_version'] as String? ?? currentSchemaVersion,
      sourceKind: json['source_kind'] as String? ??
          RawGpsExportSourceKind.deviceRecoveredUnverified.value,
      userScoped: json['user_scoped'] as bool? ?? true,
      workoutId: json['workout_id'] as String,
      exportGeneratedAtUtc: DateTime.parse(
        json['export_generated_at_utc'] as String,
      ).toUtc(),
      appCommit: json['app_commit'] as String?,
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
      firstSampleUtc: json['first_sample_utc'] != null
          ? DateTime.tryParse(json['first_sample_utc'] as String)?.toUtc()
          : null,
      lastSampleUtc: json['last_sample_utc'] != null
          ? DateTime.tryParse(json['last_sample_utc'] as String)?.toUtc()
          : null,
      timestampPrecision:
          json['timestamp_precision'] as String? ?? 'microseconds',
      units: (json['units'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {
            'latitude': 'degrees',
            'longitude': 'degrees',
            'altitude': 'meters',
            'speed': 'm/s',
            'accuracy': 'meters',
            'heading': 'degrees',
          },
      nullSemantics: json['null_semantics'] as String? ??
          'empty string in CSV, null in JSONL/manifest, omitted or namespaced in GPX',
      duplicateCount: (json['duplicate_count'] as num?)?.toInt() ?? 0,
      gapSummary: (json['gap_summary'] as Map<String, dynamic>?) ??
          const {
            'gap_threshold_seconds': 15.0,
            'gap_count': 0,
            'max_gap_seconds': 0.0,
          },
      rawJsonlByteSha256: json['raw_jsonl_byte_sha256'] as String?,
      canonicalCaptureDigest: json['canonical_capture_digest'] as String?,
      exportJsonlSha256: json['export_jsonl_sha256'] as String? ?? '',
      exportCsvSha256: json['export_csv_sha256'] as String? ?? '',
      exportGpxSha256: json['export_gpx_sha256'] as String? ?? '',
      consentScope:
          json['consent_scope'] as String? ?? 'owner_research_export',
    );
  }
}

/// In-memory bundle containing all serialized export artifacts.
class RawGpsExportBundle {
  final String workoutId;
  final RawGpsExportManifest manifest;
  final String jsonlContent;
  final String csvContent;
  final String gpxContent;
  final List<RawGpsExportPoint> points;
  final List<File> temporaryFiles;

  const RawGpsExportBundle({
    required this.workoutId,
    required this.manifest,
    required this.jsonlContent,
    required this.csvContent,
    required this.gpxContent,
    required this.points,
    this.temporaryFiles = const [],
  });
}
