import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/raw_gps_export_bundle.dart';

/// Pure Dart research dataset exporter and lossless replay engine (RG-F4).
class RawGpsDatasetExporter {
  /// Default threshold for splitting GPX track segments on GPS signal outages.
  static const double defaultGapThresholdSeconds = 15.0;

  /// Default commit SHA placeholder when running in development environments.
  static const String defaultAppCommit = '5386d1cb2b000efdc2b10c78ef88b46cc44012ae';

  /// Serializes points into deterministic lossless JSONL (research master).
  ///
  /// Points are sorted deterministically by timestamp, latitude, and longitude.
  /// All telemetry fields and original precision are preserved.
  static String generateJsonl(List<RawGpsExportPoint> points) {
    if (points.isEmpty) return '';
    final sorted = List<RawGpsExportPoint>.from(points)..sort();
    final buffer = StringBuffer();
    for (final point in sorted) {
      buffer.write(jsonEncode(point.toJson()));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  /// Replays a JSONL string back into memory as strongly-typed points without needing a GPS sensor.
  ///
  /// Guarantees lossless round-trip recovery of all preserved fields.
  static List<RawGpsExportPoint> parseJsonl(String jsonlContent) {
    if (jsonlContent.trim().isEmpty) return const [];
    final lines = jsonlContent.split('\n');
    final points = <RawGpsExportPoint>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        final decoded = jsonDecode(line) as Map<String, dynamic>;
        points.add(RawGpsExportPoint.fromJson(decoded));
      } catch (e) {
        throw FormatException('Failed to parse JSONL line ${i + 1}: $e\nLine: $line');
      }
    }
    return points;
  }

  /// Serializes points into RFC 4180 compliant CSV for statistical tools and analysis.
  static String generateCsv(List<RawGpsExportPoint> points) {
    final buffer = StringBuffer();
    buffer.write(
      'timestamp,latitude,longitude,altitude,speed,accuracy,heading,device_source,workout_id\n',
    );
    if (points.isEmpty) return buffer.toString();

    final sorted = List<RawGpsExportPoint>.from(points)..sort();
    for (final p in sorted) {
      buffer.write(p.timestamp.toUtc().toIso8601String());
      buffer.write(',');
      buffer.write(p.latitude);
      buffer.write(',');
      buffer.write(p.longitude);
      buffer.write(',');
      buffer.write(p.altitude != null ? p.altitude.toString() : '');
      buffer.write(',');
      buffer.write(p.speed != null ? p.speed.toString() : '');
      buffer.write(',');
      buffer.write(p.accuracy != null ? p.accuracy.toString() : '');
      buffer.write(',');
      buffer.write(p.heading != null ? p.heading.toString() : '');
      buffer.write(',');
      buffer.write(_escapeCsv(p.deviceSource ?? ''));
      buffer.write(',');
      buffer.write(_escapeCsv(p.workoutId));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  /// Serializes points into standard GPX 1.1 for mapping applications.
  ///
  /// Track segments (`<trkseg>`) are split on signal gaps exceeding [gapThresholdSeconds].
  /// Extended telemetry (accuracy, speed, heading, source) is stored in `<extensions>`.
  static String generateGpx(
    List<RawGpsExportPoint> points, {
    String workoutId = '',
    double gapThresholdSeconds = defaultGapThresholdSeconds,
    DateTime? exportTimeUtc,
  }) {
    final buffer = StringBuffer();
    final exportTime = exportTimeUtc ?? DateTime.now().toUtc();
    final timeStr = exportTime.toUtc().toIso8601String();
    final safeWorkoutId = _escapeXml(workoutId);

    buffer.write('<?xml version="1.0" encoding="UTF-8"?>\n');
    buffer.write(
      '<gpx version="1.1" creator="Aetron" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">\n',
    );
    buffer.write('  <metadata>\n');
    buffer.write('    <name>Aetron Raw GPS Export</name>\n');
    buffer.write('    <desc>Owner-scoped research GPS export</desc>\n');
    buffer.write('    <time>$timeStr</time>\n');
    buffer.write('  </metadata>\n');
    buffer.write('  <trk>\n');
    buffer.write('    <name>Workout $safeWorkoutId</name>\n');

    if (points.isEmpty) {
      buffer.write('    <trkseg/>\n');
      buffer.write('  </trk>\n');
      buffer.write('</gpx>\n');
      return buffer.toString();
    }

    final sorted = List<RawGpsExportPoint>.from(points)..sort();
    var inSegment = false;
    DateTime? lastTimestamp;

    for (final p in sorted) {
      final pTime = p.timestamp.toUtc();
      final isNewSegment = lastTimestamp == null ||
          (pTime.difference(lastTimestamp).inMicroseconds / 1000000.0) >
              gapThresholdSeconds;

      if (isNewSegment) {
        if (inSegment) {
          buffer.write('    </trkseg>\n');
        }
        buffer.write('    <trkseg>\n');
        inSegment = true;
      }

      buffer.write('      <trkpt lat="${p.latitude}" lon="${p.longitude}">\n');
      if (p.altitude != null) {
        buffer.write('        <ele>${p.altitude}</ele>\n');
      }
      buffer.write('        <time>${pTime.toIso8601String()}</time>\n');

      final hasExtensions = p.accuracy != null ||
          p.speed != null ||
          p.heading != null ||
          (p.deviceSource != null && p.deviceSource!.isNotEmpty);

      if (hasExtensions) {
        buffer.write('        <extensions>\n');
        if (p.accuracy != null) {
          buffer.write('          <accuracy>${p.accuracy}</accuracy>\n');
        }
        if (p.speed != null) {
          buffer.write('          <speed>${p.speed}</speed>\n');
        }
        if (p.heading != null) {
          buffer.write('          <heading>${p.heading}</heading>\n');
        }
        if (p.deviceSource != null && p.deviceSource!.isNotEmpty) {
          buffer.write(
            '          <device_source>${_escapeXml(p.deviceSource!)}</device_source>\n',
          );
        }
        buffer.write('        </extensions>\n');
      }

      buffer.write('      </trkpt>\n');
      lastTimestamp = pTime;
    }

    if (inSegment) {
      buffer.write('    </trkseg>\n');
    }
    buffer.write('  </trk>\n');
    buffer.write('</gpx>\n');
    return buffer.toString();
  }

  /// Calculates gap summary metrics for the given points.
  static Map<String, dynamic> calculateGapSummary(
    List<RawGpsExportPoint> sortedPoints, {
    double gapThresholdSeconds = defaultGapThresholdSeconds,
  }) {
    if (sortedPoints.length <= 1) {
      return {
        'gap_threshold_seconds': gapThresholdSeconds,
        'gap_count': 0,
        'max_gap_seconds': 0.0,
      };
    }

    var gapCount = 0;
    var maxGapSec = 0.0;

    for (var i = 1; i < sortedPoints.length; i++) {
      final deltaSec = (sortedPoints[i].timestamp.toUtc().difference(
                sortedPoints[i - 1].timestamp.toUtc(),
              ).inMicroseconds) /
          1000000.0;
      if (deltaSec > gapThresholdSeconds) {
        gapCount += 1;
      }
      if (deltaSec > maxGapSec) {
        maxGapSec = deltaSec;
      }
    }

    return {
      'gap_threshold_seconds': gapThresholdSeconds,
      'gap_count': gapCount,
      'max_gap_seconds': maxGapSec,
    };
  }

  /// Builds a complete export bundle with deterministic hashes and provenance manifest.
  static RawGpsExportBundle buildBundle({
    required String workoutId,
    required List<RawGpsExportPoint> rawPoints,
    required RawGpsExportSourceKind sourceKind,
    String? rawJsonlByteSha256,
    String? canonicalCaptureDigest,
    String? appCommit,
    DateTime? exportGeneratedAtUtc,
    double gapThresholdSeconds = defaultGapThresholdSeconds,
  }) {
    final sorted = List<RawGpsExportPoint>.from(rawPoints)..sort();

    // Calculate duplicates by identityKey
    final seenKeys = <String>{};
    var duplicateCount = 0;
    for (final p in sorted) {
      if (!seenKeys.add(p.identityKey)) {
        duplicateCount += 1;
      }
    }

    final exportTime = exportGeneratedAtUtc ?? DateTime.now().toUtc();
    final jsonlContent = generateJsonl(sorted);
    final csvContent = generateCsv(sorted);
    final gpxContent = generateGpx(
      sorted,
      workoutId: workoutId,
      gapThresholdSeconds: gapThresholdSeconds,
      exportTimeUtc: exportTime,
    );

    final jsonlHash = sha256.convert(utf8.encode(jsonlContent)).toString();
    final csvHash = sha256.convert(utf8.encode(csvContent)).toString();
    final gpxHash = sha256.convert(utf8.encode(gpxContent)).toString();

    final gapSummary = calculateGapSummary(
      sorted,
      gapThresholdSeconds: gapThresholdSeconds,
    );

    final manifest = RawGpsExportManifest(
      sourceKind: sourceKind.value,
      userScoped: true,
      workoutId: workoutId,
      exportGeneratedAtUtc: exportTime,
      appCommit: appCommit ?? defaultAppCommit,
      recordCount: sorted.length,
      firstSampleUtc: sorted.isNotEmpty ? sorted.first.timestamp.toUtc() : null,
      lastSampleUtc: sorted.isNotEmpty ? sorted.last.timestamp.toUtc() : null,
      duplicateCount: duplicateCount,
      gapSummary: gapSummary,
      rawJsonlByteSha256: rawJsonlByteSha256,
      canonicalCaptureDigest: canonicalCaptureDigest,
      exportJsonlSha256: jsonlHash,
      exportCsvSha256: csvHash,
      exportGpxSha256: gpxHash,
      consentScope: 'owner_research_export',
    );

    return RawGpsExportBundle(
      workoutId: workoutId,
      manifest: manifest,
      jsonlContent: jsonlContent,
      csvContent: csvContent,
      gpxContent: gpxContent,
      points: sorted,
    );
  }

  static String _escapeCsv(String input) {
    if (input.contains(',') || input.contains('"') || input.contains('\n')) {
      return '"${input.replaceAll('"', '""')}"';
    }
    return input;
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
