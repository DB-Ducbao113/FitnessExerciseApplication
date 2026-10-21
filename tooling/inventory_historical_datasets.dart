import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

/// Pure Dart representation of a Raw GPS point for historical inventory.
class InventoryGpsPoint implements Comparable<InventoryGpsPoint> {
  final String workoutId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? heading;
  final String? deviceSource;

  const InventoryGpsPoint({
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

  factory InventoryGpsPoint.fromJson(Map<String, dynamic> json) {
    final workoutId = (json['workout_id'] ?? json['workoutId'] ?? json['sessionId'] ?? 'unknown') as String;
    final rawTs = json['timestamp'];
    final DateTime ts;
    if (rawTs is int) {
      ts = DateTime.fromMicrosecondsSinceEpoch(rawTs, isUtc: true);
    } else if (rawTs is String) {
      ts = DateTime.parse(rawTs).toUtc();
    } else {
      throw FormatException('Invalid timestamp: $rawTs');
    }

    return InventoryGpsPoint(
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

  @override
  int compareTo(InventoryGpsPoint other) {
    final c = timestamp.compareTo(other.timestamp);
    if (c != 0) return c;
    final latC = latitude.compareTo(other.latitude);
    if (latC != 0) return latC;
    return longitude.compareTo(other.longitude);
  }
}

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

void main(List<String> args) async {
  String? journalDir;
  String fixturesDir = 'test/fixtures/gps';
  String outputDir = 'exports/historical';
  String appCommit = 'b002dbce7293641d561f804eba7eb260d756a3c5';
  bool jsonOutput = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--journal-dir' && i + 1 < args.length) {
      journalDir = args[++i];
    } else if (arg == '--fixtures-dir' && i + 1 < args.length) {
      fixturesDir = args[++i];
    } else if (arg == '--output-dir' && i + 1 < args.length) {
      outputDir = args[++i];
    } else if (arg == '--app-commit' && i + 1 < args.length) {
      appCommit = args[++i];
    } else if (arg == '--json') {
      jsonOutput = true;
    }
  }

  final outDirectory = Directory(outputDir);
  final fixDirectory = Directory(fixturesDir);

  final sessionReports = <Map<String, dynamic>>[];
  final allPointsMap = <String, List<InventoryGpsPoint>>{};

  // 1. Ingest test fixtures (explicitly marked synthetic)
  if (fixDirectory.existsSync()) {
    final fixtureFiles = fixDirectory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jsonl'));
    for (final file in fixtureFiles) {
      final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
      final points = <InventoryGpsPoint>[];
      String? workoutId;

      for (final line in lines) {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final point = InventoryGpsPoint.fromJson(json);
          points.add(point);
          workoutId ??= point.workoutId;
        } catch (_) {}
      }

      if (points.isNotEmpty && workoutId != null) {
        allPointsMap[workoutId] = points;
      }
    }
  }

  // 2. Ingest local recovery journals if directory provided
  if (journalDir != null && Directory(journalDir).existsSync()) {
    final journalFiles = Directory(journalDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jsonl'));

    for (final file in journalFiles) {
      final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
      final points = <InventoryGpsPoint>[];
      String? workoutId;

      for (final line in lines) {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final point = InventoryGpsPoint.fromJson(json);
          points.add(point);
          workoutId ??= point.workoutId;
        } catch (_) {}
      }

      if (points.isNotEmpty && workoutId != null && !allPointsMap.containsKey(workoutId)) {
        allPointsMap[workoutId] = points;
      }
    }
  }

  // 3. Export bundles & analyze quality
  if (!outDirectory.existsSync()) {
    outDirectory.createSync(recursive: true);
  }

  var totalRawPoints = 0;
  var realWorldSessions = 0;
  var syntheticSessions = 0;
  var filteredSessions = 0;
  var totalGaps = 0;
  var totalGapDuration = 0.0;
  var samplingSum = 0.0;
  var accuracySum = 0.0;
  var validSamplingCount = 0;
  var validAccuracyCount = 0;

  for (final entry in allPointsMap.entries) {
    final workoutId = entry.key;
    final points = entry.value..sort();
    totalRawPoints += points.length;

    // Detect synthetic fixture or algorithm filtered
    final isSynthetic = workoutId.toLowerCase().contains('fixture') ||
        workoutId.toLowerCase().contains('synthetic') ||
        points.any((p) => (p.deviceSource ?? '').toLowerCase().contains('synthetic'));
    final isFiltered = points.any((p) =>
        (p.deviceSource ?? '').toLowerCase().contains('ekf') ||
        (p.deviceSource ?? '').toLowerCase().contains('filtered'));

    if (isSynthetic) {
      syntheticSessions++;
    } else if (isFiltered) {
      filteredSessions++;
    } else {
      realWorldSessions++;
    }

    // Sampling intervals
    final intervals = <double>[];
    for (var i = 1; i < points.length; i++) {
      final dt = points[i].timestamp.difference(points[i - 1].timestamp).inMicroseconds / 1000000.0;
      if (dt > 0) intervals.add(dt);
    }

    final double meanInterval = intervals.isNotEmpty ? intervals.reduce((a, b) => a + b) / intervals.length : 0.0;
    if (meanInterval > 0) {
      samplingSum += meanInterval;
      validSamplingCount++;
    }

    // Outage gaps >15s
    var gapCount = 0;
    var maxGap = 0.0;
    var totalGap = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dt = points[i].timestamp.difference(points[i - 1].timestamp).inMicroseconds / 1000000.0;
      if (dt > 15.0) {
        gapCount++;
        totalGap += dt;
        if (dt > maxGap) maxGap = dt;
      }
    }
    totalGaps += gapCount;
    totalGapDuration += totalGap;

    // Accuracy
    final accuracies = points.where((p) => p.accuracy != null).map((p) => p.accuracy!).toList()..sort();
    final meanAcc = accuracies.isNotEmpty ? accuracies.reduce((a, b) => a + b) / accuracies.length : 0.0;
    final p95Acc = accuracies.isNotEmpty ? accuracies[(accuracies.length * 0.95).floor().clamp(0, accuracies.length - 1)] : 0.0;
    if (meanAcc > 0) {
      accuracySum += meanAcc;
      validAccuracyCount++;
    }

    // Stationary drift
    final stationaryPoints = points.where((p) => p.speed != null && p.speed! <= 0.4).toList();
    var maxDrift = 0.0;
    if (stationaryPoints.length > 1) {
      for (var i = 0; i < stationaryPoints.length - 1; i++) {
        final d = _haversineMeters(
          stationaryPoints[i].latitude,
          stationaryPoints[i].longitude,
          stationaryPoints[i + 1].latitude,
          stationaryPoints[i + 1].longitude,
        );
        if (d > maxDrift) maxDrift = d;
      }
    }

    // Quality classification
    final String quality;
    if (points.length < 10 || maxGap > 300.0) {
      quality = 'unusable';
    } else if (maxGap > 30.0 || p95Acc > 25.0) {
      quality = 'degraded';
    } else if (gapCount == 0 && p95Acc < 10.0 && meanInterval >= 0.85 && meanInterval <= 1.25) {
      quality = 'excellent';
    } else {
      quality = 'good';
    }

    // Export lossless JSONL, CSV, GPX, Manifest
    final jsonlBuffer = StringBuffer();
    final csvBuffer = StringBuffer('workout_id,timestamp_utc,latitude,longitude,altitude_m,speed_mps,accuracy_m,heading_deg,device_source\n');
    final gpxBuffer = StringBuffer();

    gpxBuffer.write(
      '<gpx version="1.1" creator="Aetron" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:aetron="https://aetron.app/gpx/1/0" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">\n'
      '  <metadata>\n'
      '    <name>Aetron GPS Dataset - $workoutId</name>\n'
      '    <time>${DateTime.now().toUtc().toIso8601String()}</time>\n'
      '  </metadata>\n'
      '  <trk>\n'
      '    <name>$workoutId</name>\n'
      '    <trkseg>\n',
    );

    for (final p in points) {
      final iso = p.timestamp.toUtc().toIso8601String();
      jsonlBuffer.writeln(jsonEncode({
        'workout_id': p.workoutId,
        'timestamp': iso,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'altitude': p.altitude,
        'speed': p.speed,
        'accuracy': p.accuracy,
        'heading': p.heading,
        'device_source': p.deviceSource,
      }));

      csvBuffer.writeln(
        '${p.workoutId},$iso,${p.latitude.toStringAsFixed(7)},${p.longitude.toStringAsFixed(7)},'
        '${p.altitude?.toStringAsFixed(2) ?? ""},${p.speed?.toStringAsFixed(2) ?? ""},'
        '${p.accuracy?.toStringAsFixed(2) ?? ""},${p.heading?.toStringAsFixed(2) ?? ""},'
        '${p.deviceSource ?? ""}',
      );

      gpxBuffer.write('      <trkpt lat="${p.latitude.toStringAsFixed(7)}" lon="${p.longitude.toStringAsFixed(7)}">\n');
      if (p.altitude != null) gpxBuffer.write('        <ele>${p.altitude!.toStringAsFixed(2)}</ele>\n');
      gpxBuffer.write('        <time>$iso</time>\n');
      gpxBuffer.write('        <extensions>\n');
      if (p.accuracy != null) gpxBuffer.write('          <aetron:accuracy>${p.accuracy}</aetron:accuracy>\n');
      if (p.speed != null) gpxBuffer.write('          <aetron:speed>${p.speed}</aetron:speed>\n');
      if (p.heading != null) gpxBuffer.write('          <aetron:heading>${p.heading}</aetron:heading>\n');
      if (p.deviceSource != null) gpxBuffer.write('          <aetron:device_source>${p.deviceSource}</aetron:device_source>\n');
      gpxBuffer.write('        </extensions>\n');
      gpxBuffer.write('      </trkpt>\n');
    }

    gpxBuffer.write('    </trkseg>\n  </trk>\n</gpx>\n');

    final jsonlBytes = utf8.encode(jsonlBuffer.toString());
    final csvBytes = utf8.encode(csvBuffer.toString());
    final gpxBytes = utf8.encode(gpxBuffer.toString());

    final jsonlHash = sha256.convert(jsonlBytes).toString();
    final csvHash = sha256.convert(csvBytes).toString();
    final gpxHash = sha256.convert(gpxBytes).toString();

    final manifest = {
      'schema_version': '1.0.0',
      'source_kind': isSynthetic ? 'synthetic_fixture' : 'device_journal_verified',
      'user_scoped': true,
      'workout_id': workoutId,
      'export_generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'app_commit': appCommit,
      'record_count': points.length,
      'first_sample_utc': points.first.timestamp.toUtc().toIso8601String(),
      'last_sample_utc': points.last.timestamp.toUtc().toIso8601String(),
      'export_jsonl_sha256': jsonlHash,
      'export_csv_sha256': csvHash,
      'export_gpx_sha256': gpxHash,
    };

    File('${outDirectory.path}/$workoutId.raw.jsonl').writeAsBytesSync(jsonlBytes);
    File('${outDirectory.path}/$workoutId.raw.csv').writeAsBytesSync(csvBytes);
    File('${outDirectory.path}/$workoutId.raw.gpx').writeAsBytesSync(gpxBytes);
    File('${outDirectory.path}/$workoutId.manifest.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));

    sessionReports.add({
      'workout_id': workoutId,
      'is_synthetic': isSynthetic,
      'is_filtered': isFiltered,
      'total_points': points.length,
      'mean_sampling_interval_seconds': double.parse(meanInterval.toStringAsFixed(3)),
      'gap_count': gapCount,
      'max_gap_seconds': double.parse(maxGap.toStringAsFixed(2)),
      'mean_accuracy_meters': double.parse(meanAcc.toStringAsFixed(2)),
      'p95_accuracy_meters': double.parse(p95Acc.toStringAsFixed(2)),
      'max_stationary_drift_meters': double.parse(maxDrift.toStringAsFixed(2)),
      'quality_classification': quality,
      'ground_truth_error_disallowed': true,
      'ground_truth_refusal_reason': 'Never claim RMSE/P95 ground-truth positional error without independent survey-grade reference measurements.',
      'export_jsonl_sha256': jsonlHash,
    });
  }

  final aggregate = {
    'total_sessions': allPointsMap.length,
    'total_raw_points': totalRawPoints,
    'real_world_sessions': realWorldSessions,
    'synthetic_fixture_sessions': syntheticSessions,
    'algorithm_filtered_sessions': filteredSessions,
    'mean_sampling_interval_seconds': validSamplingCount > 0 ? double.parse((samplingSum / validSamplingCount).toStringAsFixed(3)) : 0.0,
    'mean_accuracy_meters': validAccuracyCount > 0 ? double.parse((accuracySum / validAccuracyCount).toStringAsFixed(2)) : 0.0,
    'total_gaps_detected': totalGaps,
    'total_gap_duration_seconds': double.parse(totalGapDuration.toStringAsFixed(2)),
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'app_commit': appCommit,
    'sessions': sessionReports,
  };

  final reportFile = File('${outDirectory.path}/inventory_report.json');
  reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(aggregate));

  if (jsonOutput) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(aggregate));
  } else {
    stdout.writeln('========================================================================');
    stdout.writeln(' 🛰️  AETRON ALG-0 HISTORICAL RAW GPS DATASET INVENTORY');
    stdout.writeln('========================================================================');
    stdout.writeln('Total Sessions Inventoried:    ${allPointsMap.length}');
    stdout.writeln('Total Raw Sensor Points:       $totalRawPoints');
    stdout.writeln('Real-World Field Sessions:     $realWorldSessions');
    stdout.writeln('Synthetic Fixture Sessions:    $syntheticSessions');
    stdout.writeln('Algorithm-Filtered Sessions:   $filteredSessions');
    stdout.writeln('Mean Sampling Interval:        ${aggregate['mean_sampling_interval_seconds']}s');
    stdout.writeln('Mean Horizontal Accuracy:      ${aggregate['mean_accuracy_meters']}m');
    stdout.writeln('Total Signal Outages (>15s):   $totalGaps');
    stdout.writeln('Total Outage Duration:         ${aggregate['total_gap_duration_seconds']}s');
    stdout.writeln('Export Directory:              ${outDirectory.path}');
    stdout.writeln('Report Output:                 ${reportFile.path}');
    stdout.writeln('========================================================================');
    stdout.writeln('PROVENANCE & INTEGRITY ENFORCEMENT:');
    stdout.writeln('• RMSE/P95 ground-truth positional error is STRICTLY REFUSED because');
    stdout.writeln('  no external survey-grade reference tracks exist for these historical sessions.');
    stdout.writeln('• Real recordings and synthetic fixtures are strictly isolated in reports.');
    stdout.writeln('========================================================================');
  }
}
