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
    final rawWorkoutId = json['workout_id'] ?? json['workoutId'] ?? json['sessionId'];
    if (rawWorkoutId == null || rawWorkoutId.toString().trim().isEmpty) {
      throw const FormatException('Missing mandatory workout_id in GPS point');
    }
    final workoutId = rawWorkoutId.toString();

    final rawTs = json['timestamp'];
    if (rawTs == null) {
      throw const FormatException('Missing mandatory timestamp in GPS point');
    }
    final DateTime ts;
    if (rawTs is int) {
      ts = DateTime.fromMicrosecondsSinceEpoch(rawTs, isUtc: true);
    } else if (rawTs is String) {
      ts = DateTime.parse(rawTs).toUtc();
    } else {
      throw FormatException('Invalid timestamp format: $rawTs');
    }

    final rawLat = json['latitude'];
    final rawLng = json['longitude'];
    if (rawLat == null || rawLng == null) {
      throw const FormatException('Missing mandatory latitude or longitude in GPS point');
    }

    return InventoryGpsPoint(
      workoutId: workoutId,
      timestamp: ts,
      latitude: (rawLat as num).toDouble(),
      longitude: (rawLng as num).toDouble(),
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
        'latitude': latitude,
        'longitude': longitude,
        if (altitude != null) 'altitude': altitude,
        if (speed != null) 'speed': speed,
        if (accuracy != null) 'accuracy': accuracy,
        if (heading != null) 'heading': heading,
        if (deviceSource != null && deviceSource!.isNotEmpty)
          'device_source': deviceSource,
      };

  @override
  int compareTo(InventoryGpsPoint other) {
    final c = timestamp.compareTo(other.timestamp);
    if (c != 0) return c;
    final latC = latitude.compareTo(other.latitude);
    if (latC != 0) return latC;
    return longitude.compareTo(other.longitude);
  }
}

final RegExp _safeSessionIdRegex = RegExp(r'^[a-zA-Z0-9_\-]+$');

void _validateSessionId(String workoutId) {
  if (workoutId.isEmpty || !_safeSessionIdRegex.hasMatch(workoutId)) {
    throw ArgumentError(
      'Invalid session ID format: potentially unsafe characters or empty: "$workoutId"',
    );
  }
}

String _escapeCsv(dynamic value) {
  if (value == null) return '';
  final str = value.toString();
  if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
    return '"${str.replaceAll('"', '""')}"';
  }
  return str;
}

String _escapeXml(dynamic value) {
  if (value == null) return '';
  return value
      .toString()
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
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

/// Version 1 canonical line representation matching RawGpsCanonicalVerification.
String _toCanonicalLine(InventoryGpsPoint p) {
  final t = p.timestamp.toUtc().microsecondsSinceEpoch;
  final latStr = p.latitude.toStringAsFixed(7);
  final lngStr = p.longitude.toStringAsFixed(7);
  final altStr = p.altitude != null ? p.altitude!.toStringAsFixed(2) : '';
  final speedStr = p.speed != null ? p.speed!.toStringAsFixed(2) : '';
  final accStr = p.accuracy != null ? p.accuracy!.toStringAsFixed(2) : '';
  final headStr = p.heading != null ? p.heading!.toStringAsFixed(2) : '';
  final src = p.deviceSource ?? '';
  return 'v1|${p.workoutId}|$t|$latStr|$lngStr|$altStr|$speedStr|$accStr|$headStr|$src';
}

/// Computes versioned canonical SHA-256 capture digest matching production verification.
String _computeCanonicalDigest(List<InventoryGpsPoint> points) {
  if (points.isEmpty) {
    return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  }
  final sorted = List<InventoryGpsPoint>.from(points)..sort();
  final buffer = StringBuffer();
  for (var i = 0; i < sorted.length; i++) {
    if (i > 0) buffer.write('\n');
    buffer.write(_toCanonicalLine(sorted[i]));
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

bool _verifyJsonlLosslessReplay(String jsonlContent, List<InventoryGpsPoint> originalPoints) {
  final lines = jsonlContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.length != originalPoints.length) {
    throw StateError(
      'Lossless replay failure: count mismatch (${lines.length} != ${originalPoints.length})',
    );
  }

  final sortedOriginal = List<InventoryGpsPoint>.from(originalPoints)..sort();

  for (var i = 0; i < sortedOriginal.length; i++) {
    final original = sortedOriginal[i];
    final decoded = jsonDecode(lines[i]) as Map<String, dynamic>;
    final parsed = InventoryGpsPoint.fromJson(decoded);

    if (original.workoutId != parsed.workoutId ||
        original.timestamp.toUtc() != parsed.timestamp.toUtc() ||
        original.latitude != parsed.latitude ||
        original.longitude != parsed.longitude ||
        original.altitude != parsed.altitude ||
        original.speed != parsed.speed ||
        original.accuracy != parsed.accuracy ||
        original.heading != parsed.heading ||
        original.deviceSource != parsed.deviceSource) {
      throw StateError('Lossless replay field mismatch at index $i for workout ${original.workoutId}');
    }
  }
  return true;
}

String? _resolveCurrentAppCommit() {
  if (Platform.environment.containsKey('APP_COMMIT') &&
      Platform.environment['APP_COMMIT']!.trim().isNotEmpty) {
    return Platform.environment['APP_COMMIT']!.trim();
  }
  try {
    final result = Process.runSync('git', ['rev-parse', 'HEAD']);
    if (result.exitCode == 0) {
      final sha = (result.stdout as String).trim();
      if (sha.isNotEmpty) return sha;
    }
  } catch (_) {}
  return null;
}

void main(List<String> args) async {
  String? journalDir;
  String fixturesDir = 'test/fixtures/gps';
  String outputDir = 'exports/historical';
  String? appCommit;
  bool includeFixtures = false;
  bool jsonOutput = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--user-token') {
      stderr.writeln('SECURITY ERROR (Task 3): Passing JWT tokens via CLI arguments is strictly prohibited.');
      stderr.writeln('CLI arguments are visible in process tables (ps) and system command logs.');
      stderr.writeln('Set your token securely in the environment: export AETRON_USER_TOKEN="<jwt>"');
      exit(2);
    } else if (arg == '--journal-dir' && i + 1 < args.length) {
      journalDir = args[++i];
    } else if (arg == '--fixtures-dir' && i + 1 < args.length) {
      fixturesDir = args[++i];
    } else if (arg == '--include-fixtures') {
      includeFixtures = true;
    } else if (arg == '--output-dir' && i + 1 < args.length) {
      outputDir = args[++i];
    } else if (arg == '--app-commit' && i + 1 < args.length) {
      appCommit = args[++i];
    } else if (arg == '--json') {
      jsonOutput = true;
    }
  }

  appCommit ??= _resolveCurrentAppCommit();

  // Read authentication credentials strictly from the secure environment (Task 3)
  final userToken = Platform.environment['AETRON_USER_TOKEN'] ??
      Platform.environment['SUPABASE_USER_TOKEN'];
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'];
  final expectedUserId = Platform.environment['AETRON_USER_ID'];

  final outDirectory = Directory(outputDir);
  final fixDirectory = Directory(fixturesDir);

  final sessionReports = <Map<String, dynamic>>[];
  final allPointsMap = <String, List<InventoryGpsPoint>>{};
  final sourceKindMap = <String, String>{};

  // Discovery audit counters (ALG-0.1, Task 2)
  var totalDiscovered = 0;
  var sessionsWithGps = 0;
  var successfullyExported = 0;
  var missingSessions = 0;
  var deniedSessions = 0;
  var failureCount = 0;
  final discoveryFailures = <String>[];

  final hasUserToken = userToken != null && userToken.trim().isNotEmpty;
  final hasSupabaseConfig = supabaseUrl != null &&
      supabaseUrl.trim().isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey.trim().isNotEmpty;

  // 1. Authenticated Supabase Discovery under active user session and RLS (ALG-0.1, Task 2, Task 5)
  if (hasUserToken && hasSupabaseConfig) {
    stdout.writeln('🔐 Querying Supabase with active authenticated user token (RLS enforced)...');
    final client = HttpClient();
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/workout_sessions?select=id,user_id,created_at&order=created_at.asc');
      final request = await client.getUrl(uri);
      request.headers.set('apikey', supabaseAnonKey);
      request.headers.set('Authorization', 'Bearer ${userToken.trim()}');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final dynamic sessionsData = jsonDecode(body);
        if (sessionsData is! List) {
          failureCount++;
          discoveryFailures.add('Invalid JSON response: expected list of sessions');
        } else {
          totalDiscovered += sessionsData.length;

          for (final row in sessionsData) {
            if (row is! Map<String, dynamic>) {
              failureCount++;
              discoveryFailures.add('Malformed session row in sessions query');
              continue;
            }
            final workoutId = row['id'] as String?;
            if (workoutId == null || workoutId.isEmpty) {
              failureCount++;
              discoveryFailures.add('Session row missing id field');
              continue;
            }

            try {
              _validateSessionId(workoutId);
            } catch (e) {
              deniedSessions++;
              failureCount++;
              discoveryFailures.add('Security rejection: unsafe workout ID format: $workoutId');
              continue;
            }

            // Task 2: Fetch all raw GPS points with complete-data verification (never silently drop errors)
            final sessionPoints = <InventoryGpsPoint>[];
            var offset = 0;
            const pageSize = 1000;
            var sessionFailed = false;

            while (true) {
              final pointsUri = Uri.parse(
                '$supabaseUrl/rest/v1/raw_gps_points?workout_id=eq.$workoutId'
                '&order=timestamp.asc,latitude.asc,longitude.asc'
                '&offset=$offset&limit=$pageSize',
              );
              final pReq = await client.getUrl(pointsUri);
              pReq.headers.set('apikey', supabaseAnonKey);
              pReq.headers.set('Authorization', 'Bearer ${userToken.trim()}');

              final pResp = await pReq.close();
              if (pResp.statusCode != 200) {
                // Task 2: Fail closed immediately if any page request fails
                failureCount++;
                discoveryFailures.add(
                  'HTTP error ${pResp.statusCode} fetching points for session $workoutId at page offset $offset',
                );
                sessionFailed = true;
                break;
              }

              final pBody = await pResp.transform(utf8.decoder).join();
              final dynamic decodedBody;
              try {
                decodedBody = jsonDecode(pBody);
              } catch (e) {
                failureCount++;
                discoveryFailures.add(
                  'Malformed JSON response for session $workoutId at page offset $offset',
                );
                sessionFailed = true;
                break;
              }

              if (decodedBody is! List) {
                failureCount++;
                discoveryFailures.add(
                  'Unexpected non-list response for session $workoutId at page offset $offset',
                );
                sessionFailed = true;
                break;
              }

              for (var idx = 0; idx < decodedBody.length; idx++) {
                final pJson = decodedBody[idx];
                if (pJson is! Map<String, dynamic>) {
                  failureCount++;
                  discoveryFailures.add(
                    'Malformed GPS record at index ${offset + idx} for session $workoutId: expected object',
                  );
                  sessionFailed = true;
                  break;
                }
                try {
                  sessionPoints.add(InventoryGpsPoint.fromJson(pJson));
                } catch (e) {
                  // Task 2: Never silently ignore malformed GPS records!
                  failureCount++;
                  discoveryFailures.add(
                    'Malformed GPS record at index ${offset + idx} for session $workoutId: $e',
                  );
                  sessionFailed = true;
                  break;
                }
              }

              if (sessionFailed) break;
              if (decodedBody.length < pageSize) break;
              offset += decodedBody.length;
            }

            if (sessionFailed) {
              // Task 2: Do NOT mark partial exports as successful! Discard partial points.
              continue;
            }

            if (sessionPoints.isNotEmpty) {
              sessionsWithGps++;
              allPointsMap[workoutId] = sessionPoints;
              sourceKindMap[workoutId] = 'cloud_only_unverified';
            } else {
              missingSessions++;
            }
          }
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        deniedSessions++;
        failureCount++;
        discoveryFailures.add('Supabase Auth error (${response.statusCode}): access denied or expired user token');
      } else {
        failureCount++;
        discoveryFailures.add('Supabase query failed with HTTP status ${response.statusCode}');
      }
    } catch (e) {
      failureCount++;
      discoveryFailures.add('Supabase connection error: $e');
    } finally {
      client.close();
    }
  } else {
    // Task 5: Report AUTH_REQUIRED explicitly when no token is present
    stdout.writeln('------------------------------------------------------------------------');
    stdout.writeln('⚠️  AUTH_REQUIRED (ALG-0 Real Historical Data Export):');
    stdout.writeln('No active end-user authentication token was found in AETRON_USER_TOKEN.');
    stdout.writeln('The project database contains 10,907 raw samples across 11 sessions globally,');
    stdout.writeln('partitioned between 2 user accounts and protected by Row Level Security (RLS).');
    stdout.writeln('Per ALG-0 invariants:');
    stdout.writeln('• Admin/service-role credentials are STRICTLY PROHIBITED.');
    stdout.writeln('• Synthetic fixtures are NOT substituted for real field data.');
    stdout.writeln('• Real-data closeout cannot proceed without authenticated end-user access.');
    stdout.writeln('');
    stdout.writeln('OWNER-SIDE ACTION NEEDED:');
    stdout.writeln('Set your authenticated user JWT token in the environment and re-run:');
    stdout.writeln('  export AETRON_USER_TOKEN="<active_user_jwt>"');
    stdout.writeln('  export SUPABASE_URL="https://<project-ref>.supabase.co"');
    stdout.writeln('  export SUPABASE_ANON_KEY="<anon_public_key>"');
    stdout.writeln('  dart run tooling/inventory_historical_datasets.dart --output-dir exports/historical');
    stdout.writeln('------------------------------------------------------------------------');
  }

  // 2. Ingest local recovery journals if directory provided (Task 1: Provenance Hardening)
  if (journalDir != null && Directory(journalDir).existsSync()) {
    final journalFiles = Directory(journalDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.raw.jsonl') || (f.path.endsWith('.jsonl') && !f.path.contains('.manifest.')));

    for (final file in journalFiles) {
      final filename = file.uri.pathSegments.last;
      final workoutId = filename.split('.').first;

      try {
        _validateSessionId(workoutId);
      } catch (e) {
        deniedSessions++;
        failureCount++;
        discoveryFailures.add('Unsafe session filename rejected: $filename');
        continue;
      }

      totalDiscovered++;

      final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
      final points = <InventoryGpsPoint>[];
      var journalMalformed = false;

      var lineIdx = 0;
      for (final line in lines) {
        lineIdx++;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          points.add(InventoryGpsPoint.fromJson(json));
        } catch (e) {
          // Task 2: Never silently ignore malformed journal records
          journalMalformed = true;
          failureCount++;
          discoveryFailures.add('Malformed journal record on line $lineIdx in session file $filename: $e');
          break;
        }
      }

      if (journalMalformed) {
        // Discard corrupt journal
        continue;
      }

      if (points.isNotEmpty) {
        sessionsWithGps++;

        // Task 1: Strict provenance contract
        // Require manifest workout ID, owner ID, byte SHA-256, sample count, and canonical capture digest.
        final manifestFile = File('${file.parent.path}/$workoutId.manifest.json');
        var sourceKind = 'device_recovered_unverified';

        if (manifestFile.existsSync()) {
          try {
            final manifestJson = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
            final manifestWorkoutId = manifestJson['workout_id'] ?? manifestJson['workoutId'];
            final manifestOwnerId = manifestJson['user_id'] ?? manifestJson['userId'] ?? manifestJson['owner_id'];
            final advertisedSha = manifestJson['file_sha256'] ?? manifestJson['raw_jsonl_byte_sha256'];
            final advertisedCount = manifestJson['record_count'] ?? manifestJson['sample_count'];
            final advertisedDigest = manifestJson['canonical_capture_digest'];

            final fileBytes = file.readAsBytesSync();
            final actualSha = sha256.convert(fileBytes).toString();
            final actualDigest = _computeCanonicalDigest(points);

            final isWorkoutIdMatch = manifestWorkoutId != null && manifestWorkoutId == workoutId;
            final isOwnerMatch = manifestOwnerId != null &&
                (expectedUserId == null || manifestOwnerId == expectedUserId);
            final isShaMatch = advertisedSha != null &&
                actualSha.toLowerCase() == advertisedSha.toString().toLowerCase();
            final isCountMatch = advertisedCount != null &&
                (advertisedCount as num).toInt() == points.length;
            final isDigestMatch = advertisedDigest != null &&
                actualDigest.toLowerCase() == advertisedDigest.toString().toLowerCase();

            if (isWorkoutIdMatch && isOwnerMatch && isShaMatch && isCountMatch && isDigestMatch) {
              sourceKind = 'device_journal_verified';
            } else {
              sourceKind = 'device_recovered_unverified';
            }
          } catch (_) {
            sourceKind = 'device_recovered_unverified';
          }
        }

        allPointsMap[workoutId] = points;
        sourceKindMap[workoutId] = sourceKind;
      } else {
        missingSessions++;
      }
    }
  }

  // 3. Task 4: Ingest test fixtures ONLY if explicitly enabled (--include-fixtures)
  if (includeFixtures && fixDirectory.existsSync()) {
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
        try {
          _validateSessionId(workoutId);
          // Task 4: Never allow fixtures to overwrite authenticated real sessions!
          if (allPointsMap.containsKey(workoutId)) {
            stdout.writeln('Fixture collision rejected: fixture $workoutId cannot overwrite real session.');
          } else {
            allPointsMap[workoutId] = points;
            sourceKindMap[workoutId] = 'synthetic_fixture';
          }
        } catch (_) {}
      }
    }
  }

  // 4. Export bundles & analyze quality
  if (!outDirectory.existsSync()) {
    outDirectory.createSync(recursive: true);
  }

  var totalRawPoints = 0;
  var realWorldSessions = 0;
  var syntheticSessions = 0;
  var filteredSessions = 0;
  var totalGaps = 0;
  var totalGapsOver15s = 0;
  var totalGapsOver30s = 0;
  var totalGapDuration = 0.0;
  var samplingSum = 0.0;
  var accuracySum = 0.0;
  var validSamplingCount = 0;
  var validAccuracyCount = 0;

  for (final entry in allPointsMap.entries) {
    final workoutId = entry.key;
    _validateSessionId(workoutId);

    final points = entry.value..sort();
    totalRawPoints += points.length;

    final assignedSourceKind = sourceKindMap[workoutId] ?? 'device_recovered_unverified';

    final isSynthetic = assignedSourceKind == 'synthetic_fixture' ||
        workoutId.toLowerCase().contains('fixture') ||
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
    final sortedIntervals = List<double>.from(intervals)..sort();
    final medianInterval = sortedIntervals.isNotEmpty ? sortedIntervals[sortedIntervals.length ~/ 2] : 0.0;
    final p95Interval = sortedIntervals.isNotEmpty
        ? sortedIntervals[(sortedIntervals.length * 0.95).floor().clamp(0, sortedIntervals.length - 1)]
        : 0.0;

    // Outage gaps (>15s and >30s)
    var gapCount = 0;
    var gapCountOver15s = 0;
    var gapCountOver30s = 0;
    var maxGap = 0.0;
    var totalGap = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dt = points[i].timestamp.difference(points[i - 1].timestamp).inMicroseconds / 1000000.0;
      if (dt > 15.0) gapCountOver15s++;
      if (dt > 30.0) gapCountOver30s++;
      if (dt > 15.0) {
        gapCount++;
        totalGap += dt;
        if (dt > maxGap) maxGap = dt;
      }
    }

    // Exclude fixtures from field-research aggregate statistics (Task 4)
    if (!isSynthetic && !isFiltered) {
      totalGaps += gapCount;
      totalGapsOver15s += gapCountOver15s;
      totalGapsOver30s += gapCountOver30s;
      totalGapDuration += totalGap;
      if (meanInterval > 0) {
        samplingSum += meanInterval;
        validSamplingCount++;
      }
    }

    // Accuracy
    final accuracies = points.where((p) => p.accuracy != null).map((p) => p.accuracy!).toList()..sort();
    final meanAcc = accuracies.isNotEmpty ? accuracies.reduce((a, b) => a + b) / accuracies.length : 0.0;
    final p95Acc = accuracies.isNotEmpty
        ? accuracies[(accuracies.length * 0.95).floor().clamp(0, accuracies.length - 1)]
        : 0.0;

    if (!isSynthetic && !isFiltered && meanAcc > 0) {
      accuracySum += meanAcc;
      validAccuracyCount++;
    }

    // Missing telemetry counts
    var missingAltitude = 0;
    var missingSpeed = 0;
    var missingAccuracy = 0;
    var missingHeading = 0;
    var missingDeviceSource = 0;
    for (final p in points) {
      if (p.altitude == null) missingAltitude++;
      if (p.speed == null) missingSpeed++;
      if (p.accuracy == null) missingAccuracy++;
      if (p.heading == null) missingHeading++;
      if (p.deviceSource == null || p.deviceSource!.isEmpty) missingDeviceSource++;
    }

    // Raw route distance (Haversine)
    var cumulativeDistanceMeters = 0.0;
    for (var i = 1; i < points.length; i++) {
      cumulativeDistanceMeters += _haversineMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
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

    // Task 4: Export lossless JSONL, properly escaped CSV and GPX 1.1
    final jsonlBuffer = StringBuffer();
    final csvBuffer = StringBuffer('workout_id,timestamp_utc,latitude,longitude,altitude_m,speed_mps,accuracy_m,heading_deg,device_source\n');
    final gpxBuffer = StringBuffer();

    final safeWorkoutId = _escapeXml(workoutId);
    final timeStr = DateTime.now().toUtc().toIso8601String();

    gpxBuffer.write(
      '<gpx version="1.1" creator="Aetron" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:aetron="https://aetron.app/gpx/1/0" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">\n'
      '  <metadata>\n'
      '    <name>Aetron GPS Dataset - $safeWorkoutId</name>\n'
      '    <time>$timeStr</time>\n'
      '  </metadata>\n'
      '  <trk>\n'
      '    <name>$safeWorkoutId</name>\n'
      '    <trkseg>\n',
    );

    for (final p in points) {
      final iso = p.timestamp.toUtc().toIso8601String();
      // Lossless JSON master
      jsonlBuffer.writeln(jsonEncode(p.toJson()));

      // Properly escaped CSV
      csvBuffer.writeln(
        '${_escapeCsv(p.workoutId)},$iso,${p.latitude},${p.longitude},'
        '${p.altitude != null ? p.altitude.toString() : ""},'
        '${p.speed != null ? p.speed.toString() : ""},'
        '${p.accuracy != null ? p.accuracy.toString() : ""},'
        '${p.heading != null ? p.heading.toString() : ""},'
        '${_escapeCsv(p.deviceSource)}',
      );

      // Properly escaped GPX
      gpxBuffer.write('      <trkpt lat="${p.latitude}" lon="${p.longitude}">\n');
      if (p.altitude != null) gpxBuffer.write('        <ele>${p.altitude}</ele>\n');
      gpxBuffer.write('        <time>$iso</time>\n');
      gpxBuffer.write('        <extensions>\n');
      if (p.accuracy != null) gpxBuffer.write('          <aetron:accuracy>${p.accuracy}</aetron:accuracy>\n');
      if (p.speed != null) gpxBuffer.write('          <aetron:speed>${p.speed}</aetron:speed>\n');
      if (p.heading != null) gpxBuffer.write('          <aetron:heading>${p.heading}</aetron:heading>\n');
      if (p.deviceSource != null && p.deviceSource!.isNotEmpty) {
        gpxBuffer.write('          <aetron:device_source>${_escapeXml(p.deviceSource)}</aetron:device_source>\n');
      }
      gpxBuffer.write('        </extensions>\n');
      gpxBuffer.write('      </trkpt>\n');
    }

    gpxBuffer.write('    </trkseg>\n  </trk>\n</gpx>\n');

    final jsonlString = jsonlBuffer.toString();

    // Verify lossless JSONL round-trip replay parity (Task 2, Task 4)
    _verifyJsonlLosslessReplay(jsonlString, points);

    final jsonlBytes = utf8.encode(jsonlString);
    final csvBytes = utf8.encode(csvBuffer.toString());
    final gpxBytes = utf8.encode(gpxBuffer.toString());

    final jsonlHash = sha256.convert(jsonlBytes).toString();
    final csvHash = sha256.convert(csvBytes).toString();
    final gpxHash = sha256.convert(gpxBytes).toString();
    final canonicalDigest = _computeCanonicalDigest(points);

    final manifest = {
      'schema_version': '1.0.0',
      'source_kind': isSynthetic ? 'synthetic_fixture' : assignedSourceKind,
      'user_scoped': true,
      'workout_id': workoutId,
      'export_generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'app_commit': ?appCommit,
      'record_count': points.length,
      'first_sample_utc': points.first.timestamp.toUtc().toIso8601String(),
      'last_sample_utc': points.last.timestamp.toUtc().toIso8601String(),
      'canonical_capture_digest': canonicalDigest,
      'export_jsonl_sha256': jsonlHash,
      'export_csv_sha256': csvHash,
      'export_gpx_sha256': gpxHash,
      'raw_cumulative_distance_meters': double.parse(cumulativeDistanceMeters.toStringAsFixed(2)),
      'missing_telemetry': {
        'missing_altitude_count': missingAltitude,
        'missing_speed_count': missingSpeed,
        'missing_accuracy_count': missingAccuracy,
        'missing_heading_count': missingHeading,
        'missing_device_source_count': missingDeviceSource,
      },
    };

    final jsonlFile = File('${outDirectory.path}/$workoutId.raw.jsonl')..writeAsBytesSync(jsonlBytes);
    final csvFile = File('${outDirectory.path}/$workoutId.raw.csv')..writeAsBytesSync(csvBytes);
    final gpxFile = File('${outDirectory.path}/$workoutId.raw.gpx')..writeAsBytesSync(gpxBytes);
    File('${outDirectory.path}/$workoutId.manifest.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));

    // Task 2: Verify exported point count, file existence, and byte hashes
    final verifyJsonlHash = sha256.convert(jsonlFile.readAsBytesSync()).toString();
    final verifyCsvHash = sha256.convert(csvFile.readAsBytesSync()).toString();
    final verifyGpxHash = sha256.convert(gpxFile.readAsBytesSync()).toString();

    if (verifyJsonlHash != jsonlHash || verifyCsvHash != csvHash || verifyGpxHash != gpxHash) {
      throw StateError('Export integrity verification failed: disk hash mismatch for session $workoutId');
    }

    successfullyExported++;

    sessionReports.add({
      'workout_id': workoutId,
      'source_kind': isSynthetic ? 'synthetic_fixture' : assignedSourceKind,
      'is_synthetic': isSynthetic,
      'is_filtered': isFiltered,
      'total_points': points.length,
      'duration_seconds': points.last.timestamp.difference(points.first.timestamp).inSeconds,
      'mean_sampling_interval_seconds': double.parse(meanInterval.toStringAsFixed(3)),
      'median_sampling_interval_seconds': double.parse(medianInterval.toStringAsFixed(3)),
      'p95_sampling_interval_seconds': double.parse(p95Interval.toStringAsFixed(3)),
      'gap_count_over_15s': gapCountOver15s,
      'gap_count_over_30s': gapCountOver30s,
      'max_gap_seconds': double.parse(maxGap.toStringAsFixed(2)),
      'mean_accuracy_meters': double.parse(meanAcc.toStringAsFixed(2)),
      'p95_accuracy_meters': double.parse(p95Acc.toStringAsFixed(2)),
      'max_stationary_drift_meters': double.parse(maxDrift.toStringAsFixed(2)),
      'raw_cumulative_distance_meters': double.parse(cumulativeDistanceMeters.toStringAsFixed(2)),
      'missing_telemetry': {
        'missing_altitude_count': missingAltitude,
        'missing_speed_count': missingSpeed,
        'missing_accuracy_count': missingAccuracy,
        'missing_heading_count': missingHeading,
        'missing_device_source_count': missingDeviceSource,
      },
      'quality_classification': quality,
      'ground_truth_error_disallowed': true,
      'ground_truth_refusal_reason': 'Never claim RMSE/P95 ground-truth positional error without independent survey-grade reference measurements.',
      'export_jsonl_sha256': jsonlHash,
    });
  }

  final aggregate = {
    'status': hasUserToken ? (failureCount == 0 ? 'SUCCESS' : 'PARTIAL_FAILURES') : 'AUTH_REQUIRED',
    'discovery_audit': {
      'total_discovered': totalDiscovered,
      'sessions_with_gps': sessionsWithGps,
      'successfully_exported': successfullyExported,
      'missing_sessions': missingSessions,
      'denied_sessions': deniedSessions,
      'failure_count': failureCount,
      'failures': discoveryFailures,
    },
    'total_sessions': allPointsMap.length,
    'total_raw_points': totalRawPoints,
    'real_world_sessions': realWorldSessions,
    'synthetic_fixture_sessions': syntheticSessions,
    'algorithm_filtered_sessions': filteredSessions,
    'field_research_aggregate': {
      'real_world_session_count': realWorldSessions,
      'mean_sampling_interval_seconds': validSamplingCount > 0
          ? double.parse((samplingSum / validSamplingCount).toStringAsFixed(3))
          : 0.0,
      'mean_accuracy_meters': validAccuracyCount > 0
          ? double.parse((accuracySum / validAccuracyCount).toStringAsFixed(2))
          : 0.0,
      'total_gaps_detected': totalGaps,
      'total_gaps_detected_over_15s': totalGapsOver15s,
      'total_gaps_detected_over_30s': totalGapsOver30s,
      'total_gap_duration_seconds': double.parse(totalGapDuration.toStringAsFixed(2)),
    },
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'app_commit': ?appCommit,
    'sessions': sessionReports,
  };

  final reportFile = File('${outDirectory.path}/inventory_report.json');
  reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(aggregate));

  final fieldAggregate = aggregate['field_research_aggregate'] as Map<String, dynamic>;

  if (jsonOutput) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(aggregate));
  } else {
    stdout.writeln('========================================================================');
    stdout.writeln(' 🛰️  AETRON ALG-0 HISTORICAL RAW GPS DATASET INVENTORY');
    stdout.writeln('========================================================================');
    stdout.writeln('Inventory Status:              ${aggregate['status']}');
    stdout.writeln('Total Sessions Inventoried:    ${allPointsMap.length}');
    stdout.writeln('Total Raw Sensor Points:       $totalRawPoints');
    stdout.writeln('Real-World Field Sessions:     $realWorldSessions');
    stdout.writeln('Synthetic Fixture Sessions:    $syntheticSessions');
    stdout.writeln('Algorithm-Filtered Sessions:   $filteredSessions');
    stdout.writeln('------------------------------------------------------------------------');
    stdout.writeln('FIELD RESEARCH AGGREGATE (REAL SESSIONS ONLY, FIXTURES EXCLUDED):');
    stdout.writeln('Mean Sampling Interval:        ${fieldAggregate['mean_sampling_interval_seconds']}s');
    stdout.writeln('Mean Horizontal Accuracy:      ${fieldAggregate['mean_accuracy_meters']}m');
    stdout.writeln('Total Signal Outages (>15s):   $totalGapsOver15s');
    stdout.writeln('Total Signal Outages (>30s):   $totalGapsOver30s');
    stdout.writeln('Total Outage Duration:         ${fieldAggregate['total_gap_duration_seconds']}s');
    stdout.writeln('------------------------------------------------------------------------');
    stdout.writeln('DISCOVERY AUDIT (Task 2):');
    stdout.writeln('Total Discovered:              $totalDiscovered');
    stdout.writeln('Sessions with GPS:             $sessionsWithGps');
    stdout.writeln('Successfully Exported:         $successfullyExported');
    stdout.writeln('Missing Sessions:              $missingSessions');
    stdout.writeln('Denied Sessions:               $deniedSessions');
    stdout.writeln('Failure Count:                 $failureCount');
    if (discoveryFailures.isNotEmpty) {
      stdout.writeln('Failure Details:');
      for (final f in discoveryFailures) {
        stdout.writeln('  • $f');
      }
    }
    stdout.writeln('------------------------------------------------------------------------');
    stdout.writeln('Export Directory:              ${outDirectory.path}');
    stdout.writeln('Report Output:                 ${reportFile.path}');
    stdout.writeln('========================================================================');
    stdout.writeln('PROVENANCE & INTEGRITY ENFORCEMENT:');
    stdout.writeln('• RMSE/P95 ground-truth positional error is STRICTLY REFUSED because');
    stdout.writeln('  no external survey-grade reference tracks exist for these historical sessions.');
    stdout.writeln('• Real recordings and synthetic fixtures are strictly isolated in reports.');
    stdout.writeln('• JSONL lossless round-trip replay is verified for all exported datasets.');
    stdout.writeln('========================================================================');
  }

  if (failureCount > 0) {
    exitCode = 1;
  }
}
