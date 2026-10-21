import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_trace.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/experimental_gps_recovery_state_machine.dart';

/// Parses CSV records, including newlines inside quoted fields. Errors never
/// include field content because that content may contain coordinates.
List<({int line, List<String> fields})> parseRfc4180CsvRecords(String content) {
  final records = <({int line, List<String> fields})>[];
  var fields = <String>[];
  var field = StringBuffer();
  var line = 1;
  var recordLine = 1;
  var quoted = false;
  var closedQuote = false;
  var atFieldStart = true;

  for (var i = 0; i < content.length; i++) {
    final char = content[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closedQuote = true;
        }
      } else {
        field.write(char);
        if (char == '\n') line++;
      }
      continue;
    }
    if (char == '"') {
      if (!atFieldStart || closedQuote) {
        throw FormatException('RFC 4180 syntax error at line $line');
      }
      quoted = true;
      atFieldStart = false;
    } else if (char == ',' || char == '\r' || char == '\n') {
      fields.add(field.toString());
      field = StringBuffer();
      atFieldStart = true;
      closedQuote = false;
      if (char != ',') {
        records.add((line: recordLine, fields: fields));
        fields = <String>[];
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
        line++;
        recordLine = line;
      }
    } else {
      if (closedQuote) {
        throw FormatException('RFC 4180 syntax error at line $line');
      }
      field.write(char);
      atFieldStart = false;
    }
  }
  if (quoted) {
    throw FormatException('RFC 4180 unclosed quoted field at line $recordLine');
  }
  if (fields.isNotEmpty || !atFieldStart || closedQuote) {
    fields.add(field.toString());
    records.add((line: recordLine, fields: fields));
  }
  return records;
}

/// Strict, fail-closed CSV parser for Aetron raw GPS recordings.
/// Guarantees that neither raw coordinates nor full row contents appear in error messages.
List<FieldGpsSample> parseGpsCsvFile(File file) {
  final records = parseRfc4180CsvRecords(file.readAsStringSync());
  if (records.isEmpty) {
    throw const FormatException('GPS CSV file is empty');
  }

  final header = records.first.fields.map((c) => c.trim()).toList();
  const expectedHeader = [
    'workout_id',
    'timestamp',
    'latitude',
    'longitude',
    'altitude',
    'speed',
    'accuracy',
    'heading',
    'device_source',
    'confidence',
  ];

  if (header.length != expectedHeader.length) {
    throw FormatException(
      'Invalid CSV header column count: expected ${expectedHeader.length}, got ${header.length}',
    );
  }
  for (var i = 0; i < expectedHeader.length; i++) {
    if (header[i] != expectedHeader[i]) {
      throw FormatException(
        'Invalid CSV column at index $i: expected "${expectedHeader[i]}"',
      );
    }
  }

  final samples = <FieldGpsSample>[];
  for (final record in records.skip(1)) {
    final lineNumber = record.line;
    final cols = record.fields;
    if (cols.length == 1 && cols.single.trim().isEmpty) continue;
    if (cols.length != 10) {
      throw FormatException(
        'Line $lineNumber: expected 10 columns, but parsed ${cols.length}',
      );
    }

    final workoutId = cols[0].trim();
    if (workoutId.isEmpty) {
      throw FormatException('Line $lineNumber, column 1: empty workout_id');
    }

    final timestamp = DateTime.tryParse(cols[1].trim())?.toUtc();
    if (timestamp == null) {
      throw FormatException(
        'Line $lineNumber, column 2: invalid timestamp format',
      );
    }

    final lat = double.tryParse(cols[2].trim());
    if (lat == null || !lat.isFinite || lat < -90.0 || lat > 90.0) {
      throw FormatException(
        'Line $lineNumber, column 3: invalid latitude value',
      );
    }

    final lng = double.tryParse(cols[3].trim());
    if (lng == null || !lng.isFinite || lng < -180.0 || lng > 180.0) {
      throw FormatException(
        'Line $lineNumber, column 4: invalid longitude value',
      );
    }

    final altStr = cols[4].trim();
    final alt = altStr.isNotEmpty ? double.tryParse(altStr) : null;
    if (altStr.isNotEmpty && (alt == null || !alt.isFinite)) {
      throw FormatException(
        'Line $lineNumber, column 5: invalid altitude value',
      );
    }

    final spdStr = cols[5].trim();
    final spd = spdStr.isNotEmpty ? double.tryParse(spdStr) : 0.0;
    if (spd == null || !spd.isFinite || spd < 0.0) {
      throw FormatException('Line $lineNumber, column 6: invalid speed value');
    }

    final accStr = cols[6].trim();
    final acc = accStr.isNotEmpty ? double.tryParse(accStr) : 10.0;
    if (acc == null || !acc.isFinite || acc < 0.0) {
      throw FormatException(
        'Line $lineNumber, column 7: invalid accuracy value',
      );
    }

    final hdgStr = cols[7].trim();
    final hdg = hdgStr.isNotEmpty ? double.tryParse(hdgStr) : null;
    if (hdgStr.isNotEmpty &&
        (hdg == null || !hdg.isFinite || hdg < 0.0 || hdg > 360.0)) {
      throw FormatException(
        'Line $lineNumber, column 8: invalid heading value',
      );
    }

    final src = cols[8].trim().isNotEmpty ? cols[8].trim() : null;
    final conf = cols[9].trim().isNotEmpty ? cols[9].trim() : null;

    samples.add(
      FieldGpsSample(
        workoutId: workoutId,
        timestamp: timestamp,
        position: LatLng(lat, lng),
        altitudeMeters: alt,
        speedMetersPerSecond: spd,
        reportedAccuracyMeters: acc,
        headingDegrees: hdg,
        deviceSource: src,
        confidence: conf,
      ),
    );
  }
  return samples;
}

({Map<DateTime, String> rejections, int accepted, double distanceMeters})
replayProductionValidation(List<FieldGpsSample> samples) {
  const engine = WorkoutTrackingEngine();
  final route = <LatLng>[];
  final rejections = <DateTime, String>{};
  LatLng? anchor;
  DateTime? lastAccepted;
  var wasWeak = false;
  var distanceMeters = 0.0;
  for (final sample in samples) {
    final decision = engine.evaluateGpsUpdate(
      position: Position(
        latitude: sample.position.latitude,
        longitude: sample.position.longitude,
        timestamp: sample.timestamp,
        accuracy: sample.reportedAccuracyMeters,
        altitude: sample.altitudeMeters ?? 0,
        altitudeAccuracy: 0,
        heading: sample.headingDegrees ?? 0,
        headingAccuracy: 0,
        speed: sample.speedMetersPerSecond,
        speedAccuracy: 0,
      ),
      activityType: 'cycling',
      routePoints: route,
      currentLatLng: route.isEmpty ? null : route.last,
      distanceAnchorPoint: anchor,
      lastAcceptedPositionTime: lastAccepted,
      shouldResetAnchorOnResume: false,
      wasGpsSignalWeak: wasWeak,
    );
    if (decision.type == TrackingGpsDecisionType.skip) {
      rejections[sample.timestamp] = decision.reason.name;
      if (decision.reason.name == 'lowAccuracy') wasWeak = true;
      continue;
    }
    if (decision.shouldAddDistance) distanceMeters += decision.segmentMeters;
    route.add(decision.livePoint);
    anchor = decision.livePoint;
    lastAccepted = sample.timestamp;
    wasWeak = false;
  }
  return (
    rejections: rejections,
    accepted: route.length,
    distanceMeters: distanceMeters,
  );
}

void main() {
  test(
    'CSV records preserve quoted commas, escaped quotes, and line breaks',
    () {
      final rows = parseRfc4180CsvRecords(
        'id,note\r\n"ride,one","said ""go""\r\nthen stopped"\r\n',
      );
      expect(rows, hasLength(2));
      expect(rows[1].line, 2);
      expect(rows[1].fields, ['ride,one', 'said "go"\r\nthen stopped']);
    },
  );

  test('GPS CSV file parses multiline quoted metadata as one sample', () {
    final directory = Directory.systemTemp.createTempSync('gps-csv-qa-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/trace.csv');
    file.writeAsStringSync(
      'workout_id,timestamp,latitude,longitude,altitude,speed,accuracy,heading,device_source,confidence\r\n'
      'fixture,2026-10-15T00:00:00Z,10.77,106.69,0,4,8,0,"phone, ""beta""\r\nreceiver",high\r\n',
    );
    final samples = parseGpsCsvFile(file);
    expect(samples, hasLength(1));
    expect(samples.single.deviceSource, 'phone, "beta"\r\nreceiver');
    expect(samples.single.position, const LatLng(10.77, 106.69));
  });

  test('CSV syntax errors omit coordinate and field content', () {
    const sensitive = '10.770001,106.690001';
    for (final input in [
      'id,note\n1,"$sensitive',
      'id,note\n1,"safe"$sensitive',
      'id,note\n1,$sensitive"',
    ]) {
      expect(
        () => parseRfc4180CsvRecords(input),
        throwsA(
          isA<FormatException>().having(
            (error) => error.toString(),
            'safe message',
            isNot(contains(sensitive)),
          ),
        ),
      );
    }
  });

  test('checked-in research manifest hashes exact report bytes', () {
    final report = File('docs/benchmarks/real_gps_research_benchmark.json');
    final manifest =
        jsonDecode(
              File(
                'docs/benchmarks/real_gps_research_benchmark_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(
      manifest['benchmark_results_sha256'],
      sha256.convert(report.readAsBytesSync()).toString(),
    );
    final sessions =
        (jsonDecode(report.readAsStringSync())
                as Map<String, dynamic>)['sessions']
            as List<dynamic>;
    for (final session in sessions) {
      expect(session, isNot(contains('workout_id')));
      expect(session, isNot(contains('latencies_us_per_point')));
    }
  });

  const expectedCsvPath = 'exports/historical/aetron_raw_gps_combined.csv';
  const expectedSha256 =
      '4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5';

  final bool hasPrivateDataset = File(expectedCsvPath).existsSync();

  group('AETRON Real GPS Research Benchmark Suite (Opt-in Local Research)', () {
    late File csvFile;
    late List<FieldGpsSample> allParsedSamples;
    late Map<String, List<FieldGpsSample>> rawSessions;

    setUpAll(() {
      if (!hasPrivateDataset) return;

      csvFile = File(expectedCsvPath);
      final bytes = csvFile.readAsBytesSync();
      final actualHash = sha256.convert(bytes).toString();
      expect(
        actualHash,
        equals(expectedSha256),
        reason: 'CSV SHA-256 hash must match verified baseline',
      );

      allParsedSamples = parseGpsCsvFile(csvFile);
      expect(
        allParsedSamples.length,
        equals(10779),
        reason: 'CSV must contain exactly 10,779 valid data points',
      );

      rawSessions = <String, List<FieldGpsSample>>{};
      for (final sample in allParsedSamples) {
        rawSessions.putIfAbsent(sample.workoutId, () => []).add(sample);
      }
    });

    test(
      'BENCH-01: Discovered CSV contains 7 sessions and 10,779 points with valid schema',
      () {
        expect(rawSessions.length, equals(7));
        final totalParsed = rawSessions.values.fold<int>(
          0,
          (sum, list) => sum + list.length,
        );
        expect(totalParsed, equals(10779));

        for (final entry in rawSessions.entries) {
          expect(entry.value.length, greaterThan(0));
          for (final s in entry.value) {
            expect(s.workoutId, equals(entry.key));
            expect(s.position.latitude.isFinite, isTrue);
            expect(s.position.longitude.isFinite, isTrue);
            expect(s.reportedAccuracyMeters, greaterThan(0));
            expect(s.speedMetersPerSecond, greaterThanOrEqualTo(0));
            expect(s.altitudeMeters, isNotNull);
          }
        }
      },
      skip: hasPrivateDataset
          ? null
          : 'Private dataset not present (public CI environment); skipping real data benchmark test',
    );

    test(
      'BENCH-02: Dataset audit verifies original timestamp ordering before sorting, nominal 1Hz rate, and outage counts',
      () {
        var totalOriginalInversions = 0;
        var totalDups = 0;
        var totalGapsOver2s = 0;
        var totalGapsOver5s = 0;
        var totalGapsOver15s = 0;
        var totalGapsOver30s = 0;

        for (final entry in rawSessions.entries) {
          final originalSequence = entry.value;

          // Requirement QA: Validate original sequence ordering BEFORE sorting
          for (var i = 1; i < originalSequence.length; i++) {
            if (originalSequence[i].timestamp.isBefore(
              originalSequence[i - 1].timestamp,
            )) {
              totalOriginalInversions++;
            }
          }

          final sorted = List<FieldGpsSample>.from(originalSequence)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

          for (var i = 1; i < sorted.length; i++) {
            final dt =
                sorted[i].timestamp
                    .difference(sorted[i - 1].timestamp)
                    .inMilliseconds /
                1000.0;
            expect(
              dt,
              greaterThanOrEqualTo(0.0),
              reason: 'Sorted timestamps must be non-decreasing',
            );
            if (dt == 0.0) totalDups++;
            if (dt > 2.0) totalGapsOver2s++;
            if (dt > 5.0) totalGapsOver5s++;
            if (dt > 15.0) totalGapsOver15s++;
            if (dt > 30.0) totalGapsOver30s++;
          }
        }

        // Assert zero original inversions before sorting
        expect(
          totalOriginalInversions,
          equals(0),
          reason:
              'Original raw CSV rows must be strictly chronological before any sort operation',
        );
        expect(totalDups, equals(49));
        expect(
          totalGapsOver15s,
          equals(1),
        ); // exactly 1 true outage >15s (17.0s)
        expect(totalGapsOver30s, equals(0)); // 0 severe outages >30s
        expect(totalGapsOver5s, equals(89));
        expect(totalGapsOver2s, equals(149));
      },
      skip: hasPrivateDataset
          ? null
          : 'Private dataset not present (public CI environment); skipping real data benchmark test',
    );

    test(
      'BENCH-03: Comprehensive production-baseline equivalence across high, medium, low confidence, turn-boost, stationary freeze, and gap recovery',
      () {
        const smoothingService = GpsSmoothingService();

        final origin = LatLng(10.770000, 106.690000);
        final straightStep = LatLng(
          10.770045,
          106.690045,
        ); // ~7.0m displacement

        // Case 1: High Confidence Smoothing (alpha = 0.72)
        final highUpdate = smoothingService.smoothAcceptedPoint(
          activityType: 'cycling',
          acceptedPoint: straightStep,
          previousAcceptedPoint: origin,
          previousSmoothedPoint: origin,
          lastSmoothedRoutePoint: origin,
          accuracyMeters: 8.0,
          speedMs: 5.0,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );
        expect(highUpdate.confidence, GpsConfidence.high);
        expect(
          highUpdate.smoothedPoint.latitude,
          closeTo(origin.latitude * 0.28 + straightStep.latitude * 0.72, 1e-6),
        );
        expect(
          highUpdate.smoothedPoint.longitude,
          closeTo(
            origin.longitude * 0.28 + straightStep.longitude * 0.72,
            1e-6,
          ),
        );
        expect(highUpdate.isStationary, isFalse);
        expect(highUpdate.shouldAppendRoutePoint, isTrue);

        // Case 2: Medium Confidence Smoothing (accuracy > 15m -> alpha = 0.52)
        final medUpdate = smoothingService.smoothAcceptedPoint(
          activityType: 'cycling',
          acceptedPoint: straightStep,
          previousAcceptedPoint: origin,
          previousSmoothedPoint: origin,
          lastSmoothedRoutePoint: origin,
          accuracyMeters: 20.0,
          speedMs: 5.0,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );
        expect(medUpdate.confidence, GpsConfidence.medium);
        expect(
          medUpdate.smoothedPoint.latitude,
          closeTo(origin.latitude * 0.48 + straightStep.latitude * 0.52, 1e-6),
        );
        expect(
          medUpdate.smoothedPoint.longitude,
          closeTo(
            origin.longitude * 0.48 + straightStep.longitude * 0.52,
            1e-6,
          ),
        );

        // Case 3: Low Confidence Smoothing (accuracy > 30m -> alpha = 0.34)
        final lowUpdate = smoothingService.smoothAcceptedPoint(
          activityType: 'cycling',
          acceptedPoint: straightStep,
          previousAcceptedPoint: origin,
          previousSmoothedPoint: origin,
          lastSmoothedRoutePoint: origin,
          accuracyMeters: 32.0,
          speedMs: 5.0,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );
        expect(lowUpdate.confidence, GpsConfidence.low);
        expect(
          lowUpdate.smoothedPoint.latitude,
          closeTo(origin.latitude * 0.66 + straightStep.latitude * 0.34, 1e-6),
        );
        expect(
          lowUpdate.smoothedPoint.longitude,
          closeTo(
            origin.longitude * 0.66 + straightStep.longitude * 0.34,
            1e-6,
          ),
        );

        // Case 4: Turn-Boost Activation (turnDelta > 28° and acceptedDelta > 4.0m -> alpha boosted to max(alpha, 0.82))
        // Bearing from previousAcceptedPoint to acceptedPoint is 0° (North)
        // Bearing from previousSmoothedPoint to acceptedPoint is 45° (North-East) -> turnDelta = 45° > 28°
        final prevFix = LatLng(10.770000, 106.690000);
        final currentHeadingFix = LatLng(
          10.770000,
          106.690060,
        ); // East (~6.5m from prevFix)
        final sharpTurnFix = LatLng(
          10.770060,
          106.690060,
        ); // North (~6.6m from currentHeadingFix)
        final turnUpdate = smoothingService.smoothAcceptedPoint(
          activityType: 'cycling',
          acceptedPoint: sharpTurnFix,
          previousAcceptedPoint: currentHeadingFix,
          previousSmoothedPoint: prevFix,
          lastSmoothedRoutePoint: prevFix,
          accuracyMeters: 8.0,
          speedMs: 5.0,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );
        expect(
          turnUpdate.smoothedPoint.latitude,
          closeTo(prevFix.latitude * 0.18 + sharpTurnFix.latitude * 0.82, 1e-6),
        );
        expect(
          turnUpdate.smoothedPoint.longitude,
          closeTo(
            prevFix.longitude * 0.18 + sharpTurnFix.longitude * 0.82,
            1e-6,
          ),
        );

        // Case 5: Stationary Freeze (speed <= 0.8 m/s, delta < 2.5m stationary radius for cycling)
        final tinyJitterFix = LatLng(10.770005, 106.690005); // ~0.78m
        final freezeUpdate = smoothingService.smoothAcceptedPoint(
          activityType: 'cycling',
          acceptedPoint: tinyJitterFix,
          previousAcceptedPoint: origin,
          previousSmoothedPoint: origin,
          lastSmoothedRoutePoint: origin,
          accuracyMeters: 8.0,
          speedMs: 0.2, // stationary speed
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );
        expect(freezeUpdate.isStationary, isTrue);
        // Under stationary freeze (< 2.5m freeze distance), smoothed point is held frozen to previous smoothed point
        expect(freezeUpdate.smoothedPoint, equals(origin));
        expect(freezeUpdate.shouldAppendRoutePoint, isFalse);

        // Case 6: Gap Segment Recovery (gpsGapDurationSec > 5.0s forces shouldAppendRoutePoint)
        final gapFix = LatLng(
          10.770500,
          106.690500,
        ); // 75m jump after 8s outage
        final gapUpdate = smoothingService.smoothAcceptedPoint(
          activityType: 'cycling',
          acceptedPoint: gapFix,
          previousAcceptedPoint: origin,
          previousSmoothedPoint: origin,
          lastSmoothedRoutePoint: origin,
          accuracyMeters: 8.0,
          speedMs: 6.0,
          timeDeltaSec: 8.0,
          gpsGapDurationSec: 8.0,
        );
        expect(gapUpdate.shouldAppendRoutePoint, isTrue);
        expect(
          gapUpdate.confidence,
          GpsConfidence.low,
        ); // outage > 5s yields low confidence
      },
    );

    test(
      'BENCH-04: Replays all 5 pipelines deterministically and produces sanitized, coordinate-free benchmark & manifest',
      () async {
        const runner = FieldGpsBenchmarkRunner();
        final benchmarkResults = <String, dynamic>{};
        final workoutSummary = <Map<String, dynamic>>[];

        var totalAppBaselineDistance = 0.0;
        var totalCurrentDisplayDistance = 0.0;
        var totalEkfDisplayDistance = 0.0;
        var totalDbscanDisplayDistance = 0.0;
        var totalEkfDbscanDisplayDistance = 0.0;
        var totalDOptDistance = 0.0;
        var totalValidatedPointsCount = 0;

        for (final entry in rawSessions.entries) {
          final wid = entry.key;
          final samples = List<FieldGpsSample>.from(entry.value)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

          final deduped = <FieldGpsSample>[];
          var dupCount = 0;
          for (final s in samples) {
            if (deduped.isNotEmpty && deduped.last.timestamp == s.timestamp) {
              dupCount++;
              continue;
            }
            deduped.add(s);
          }

          final trace = FieldGpsTrace(
            workoutId: wid,
            samples: List.unmodifiable(deduped),
            sourceLineCount: samples.length,
            duplicateTimestampCount: dupCount,
          );

          final report = runner.run(
            trace,
            variants: {
              GpsPipelineVariant.current,
              GpsPipelineVariant.ekf,
              GpsPipelineVariant.dbscan,
              GpsPipelineVariant.ekfThenDbscan,
            },
          );

          final cur = report.results[GpsPipelineVariant.current]!;
          final production = replayProductionValidation(deduped);
          expect(cur.rejectionReasonByTimestamp, production.rejections);
          expect(cur.acceptedPointCount, production.accepted);
          expect(
            cur.appDistanceMeters,
            closeTo(production.distanceMeters, 0.01),
          );
          final ekf = report.results[GpsPipelineVariant.ekf]!;
          final dbscan = report.results[GpsPipelineVariant.dbscan]!;
          final ekfDbscan = report.results[GpsPipelineVariant.ekfThenDbscan]!;

          // Run D+Opt candidate on the exact same validated points
          final validatedPoints = cur.validatedInputPoints;
          totalValidatedPointsCount += validatedPoints.length;

          final dOptEkf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
          final dOptFsm = ExperimentalGpsRecoveryStateMachine(
            ekf: dOptEkf,
            enableAlongTrackProjection: false,
            enableBoundedHybridDistance: true,
            enableGapOverlapCorrection: true,
            enableProbationVarianceInflation: true,
            enableAlternativeRollbackRecovery: true,
            enableMultiFixHeadingEstimation: true,
            enableProbationConsecutiveRejections: true,
            enableAdaptiveTurnUncertainty: true,
            enableNoiseAwareKinematicScreening: true,
          );

          DateTime? prevT;
          final dOptStateCounts = <String, int>{};

          for (final pt in validatedPoints) {
            final t = pt.timestamp;
            final dt = prevT == null
                ? 1.0
                : t.difference(prevT).inMilliseconds / 1000.0;
            prevT = t;

            final out = dOptFsm.processMeasurement(
              point: pt.position,
              accuracyMeters: pt.reportedAccuracyMeters,
              timeDeltaSec: dt,
              timestamp: t,
              speedMs: pt.speedMetersPerSecond,
              headingDeg: pt.headingDegrees,
              hasAuxiliarySensors: pt.headingDegrees != null,
            );

            dOptStateCounts[out.state.name] =
                (dOptStateCounts[out.state.name] ?? 0) + 1;
          }
          final dOptDistance = dOptFsm.accumulatedDistanceMeters;

          totalAppBaselineDistance += cur.appDistanceMeters;
          totalCurrentDisplayDistance += cur.displayDistanceMeters;
          totalEkfDisplayDistance += ekf.displayDistanceMeters;
          totalDbscanDisplayDistance += dbscan.displayDistanceMeters;
          totalEkfDbscanDisplayDistance += ekfDbscan.displayDistanceMeters;
          totalDOptDistance += dOptDistance;

          workoutSummary.add({
            'session_label': 'session_${workoutSummary.length + 1}',
            'raw_points': samples.length,
            'deduped_points': deduped.length,
            'duplicate_timestamps': dupCount,
            'validated_points': validatedPoints.length,
            'acceptance_rate_pct': double.parse(
              (validatedPoints.length / deduped.length * 100.0).toStringAsFixed(
                2,
              ),
            ),
            'rejection_counts': cur.rejectionCounts,
            'current_app_baseline_distance_m': double.parse(
              cur.appDistanceMeters.toStringAsFixed(2),
            ),
            'current_display_distance_m': double.parse(
              cur.displayDistanceMeters.toStringAsFixed(2),
            ),
            'ekf_display_distance_m': double.parse(
              ekf.displayDistanceMeters.toStringAsFixed(2),
            ),
            'dbscan_display_distance_m': double.parse(
              dbscan.displayDistanceMeters.toStringAsFixed(2),
            ),
            'ekf_dbscan_display_distance_m': double.parse(
              ekfDbscan.displayDistanceMeters.toStringAsFixed(2),
            ),
            'dopt_distance_m': double.parse(dOptDistance.toStringAsFixed(2)),
            'deviations_vs_app_baseline': {
              'current_display_m': double.parse(
                (cur.displayDistanceMeters - cur.appDistanceMeters)
                    .toStringAsFixed(2),
              ),
              'current_display_pct': double.parse(
                ((cur.displayDistanceMeters - cur.appDistanceMeters) /
                        cur.appDistanceMeters *
                        100)
                    .toStringAsFixed(2),
              ),
              'ekf_m': double.parse(
                (ekf.displayDistanceMeters - cur.appDistanceMeters)
                    .toStringAsFixed(2),
              ),
              'ekf_pct': double.parse(
                ((ekf.displayDistanceMeters - cur.appDistanceMeters) /
                        cur.appDistanceMeters *
                        100)
                    .toStringAsFixed(2),
              ),
              'dbscan_m': double.parse(
                (dbscan.displayDistanceMeters - cur.appDistanceMeters)
                    .toStringAsFixed(2),
              ),
              'dbscan_pct': double.parse(
                ((dbscan.displayDistanceMeters - cur.appDistanceMeters) /
                        cur.appDistanceMeters *
                        100)
                    .toStringAsFixed(2),
              ),
              'ekf_dbscan_m': double.parse(
                (ekfDbscan.displayDistanceMeters - cur.appDistanceMeters)
                    .toStringAsFixed(2),
              ),
              'ekf_dbscan_pct': double.parse(
                ((ekfDbscan.displayDistanceMeters - cur.appDistanceMeters) /
                        cur.appDistanceMeters *
                        100)
                    .toStringAsFixed(2),
              ),
              'dopt_m': double.parse(
                (dOptDistance - cur.appDistanceMeters).toStringAsFixed(2),
              ),
              'dopt_pct': double.parse(
                ((dOptDistance - cur.appDistanceMeters) /
                        cur.appDistanceMeters *
                        100)
                    .toStringAsFixed(2),
              ),
            },
            'dbscan_dwell_clusters': dbscan.detectedDwellClusterCount,
            'dbscan_phantom_drift_removed_m': double.parse(
              dbscan.phantomDriftRemovedMeters.toStringAsFixed(2),
            ),
            'dopt_state_counts': dOptStateCounts,
            'dopt_escrow_m': double.parse(
              dOptFsm.escrowDistanceMeters.toStringAsFixed(2),
            ),
          });
        }

        benchmarkResults['dataset_summary'] = {
          'csv_path': expectedCsvPath,
          'csv_sha256': expectedSha256,
          'total_raw_points': 10779,
          'total_sessions': 7,
          'total_validated_points': totalValidatedPointsCount,
          'overall_acceptance_rate_pct': double.parse(
            (totalValidatedPointsCount / (10779 - 49) * 100.0).toStringAsFixed(
              2,
            ),
          ),
        };

        benchmarkResults['aggregate_totals'] = {
          'current_app_baseline_distance_m': double.parse(
            totalAppBaselineDistance.toStringAsFixed(2),
          ),
          'current_display_distance_m': double.parse(
            totalCurrentDisplayDistance.toStringAsFixed(2),
          ),
          'ekf_display_distance_m': double.parse(
            totalEkfDisplayDistance.toStringAsFixed(2),
          ),
          'dbscan_display_distance_m': double.parse(
            totalDbscanDisplayDistance.toStringAsFixed(2),
          ),
          'ekf_dbscan_display_distance_m': double.parse(
            totalEkfDbscanDisplayDistance.toStringAsFixed(2),
          ),
          'dopt_distance_m': double.parse(totalDOptDistance.toStringAsFixed(2)),
          'deviations_vs_current_app_baseline': {
            'current_display_pct': double.parse(
              ((totalCurrentDisplayDistance - totalAppBaselineDistance) /
                      totalAppBaselineDistance *
                      100)
                  .toStringAsFixed(2),
            ),
            'ekf_pct': double.parse(
              ((totalEkfDisplayDistance - totalAppBaselineDistance) /
                      totalAppBaselineDistance *
                      100)
                  .toStringAsFixed(2),
            ),
            'dbscan_pct': double.parse(
              ((totalDbscanDisplayDistance - totalAppBaselineDistance) /
                      totalAppBaselineDistance *
                      100)
                  .toStringAsFixed(2),
            ),
            'ekf_dbscan_pct': double.parse(
              ((totalEkfDbscanDisplayDistance - totalAppBaselineDistance) /
                      totalAppBaselineDistance *
                      100)
                  .toStringAsFixed(2),
            ),
            'dopt_pct': double.parse(
              ((totalDOptDistance - totalAppBaselineDistance) /
                      totalAppBaselineDistance *
                      100)
                  .toStringAsFixed(2),
            ),
          },
          'deviations_vs_current_display_distance': {
            'ekf_pct': double.parse(
              ((totalEkfDisplayDistance - totalCurrentDisplayDistance) /
                      totalCurrentDisplayDistance *
                      100)
                  .toStringAsFixed(2),
            ),
            'dbscan_pct': double.parse(
              ((totalDbscanDisplayDistance - totalCurrentDisplayDistance) /
                      totalCurrentDisplayDistance *
                      100)
                  .toStringAsFixed(2),
            ),
            'ekf_dbscan_pct': double.parse(
              ((totalEkfDbscanDisplayDistance - totalCurrentDisplayDistance) /
                      totalCurrentDisplayDistance *
                      100)
                  .toStringAsFixed(2),
            ),
            'dopt_pct': double.parse(
              ((totalDOptDistance - totalCurrentDisplayDistance) /
                      totalCurrentDisplayDistance *
                      100)
                  .toStringAsFixed(2),
            ),
          },
        };

        benchmarkResults['ground_truth_policy'] = {
          'ground_truth_available': false,
          'claim_prohibition':
              'Never describe distance deviation from baseline as ground-truth error without survey-grade reference measurements.',
        };

        benchmarkResults['sessions'] = workoutSummary;

        // Write reproducible report to docs/benchmarks/real_gps_research_benchmark.json
        final outDir = Directory('docs/benchmarks');
        if (!outDir.existsSync()) outDir.createSync(recursive: true);
        final jsonFile = File(
          'docs/benchmarks/real_gps_research_benchmark.json',
        );
        await jsonFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(benchmarkResults),
          flush: true,
        );
        final resultsHash = sha256
            .convert(await jsonFile.readAsBytes())
            .toString();

        // Generate reproducibility manifest
        final manifestFile = File(
          'docs/benchmarks/real_gps_research_benchmark_manifest.json',
        );
        final manifestJson = {
          'schema_version': '1.0.0',
          'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
          'execution_mode': 'OPT_IN_LOCAL_AUTHORIZED_BENCHMARK',
          'public_ci_behavior': 'SKIPPED_GRACEFULLY_WHEN_PRIVATE_CSV_ABSENT',
          'dataset_evidence': {
            'source_file': 'exports/historical/aetron_raw_gps_combined.csv',
            'file_sha256': expectedSha256,
            'total_raw_points': 10779,
            'deduped_points': 10730,
            'session_count': 7,
          },
          'benchmark_results_file':
              'docs/benchmarks/real_gps_research_benchmark.json',
          'benchmark_results_sha256': resultsHash,
          'timing_policy':
              'Processing latency is diagnostic only and excluded from this reproducible results artifact.',
          'privacy_policy': {
            'coordinates_scrubbed': true,
            'direct_workout_ids_retained': false,
            'historical_report_identifiers_remain_reachable': true,
            'public_git_exposure_prohibited': true,
            'error_messages_contain_no_raw_coordinates': true,
          },
          'scientific_governance': {
            'ground_truth_reference_present': false,
            'metric_nature': 'relative_algorithm_deviation_only',
            'causal_claims_policy': 'HYPOTHESIS_BASED_REQUIRING_ABLATION_STUDY',
            'production_decision': 'HOLD_EXISTING_PRODUCTION_ALGORITHM',
          },
        };
        await manifestFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(manifestJson),
        );

        // Assert expected aggregate values
        expect(totalAppBaselineDistance, closeTo(58036.6, 1.0));
        expect(totalCurrentDisplayDistance, closeTo(57068.8, 1.0));
        expect(totalEkfDisplayDistance, closeTo(57662.4, 1.0));
        expect(totalDbscanDisplayDistance, closeTo(57882.0, 1.0));
        expect(totalDOptDistance, closeTo(58695.9, 1.0));
      },
      skip: hasPrivateDataset
          ? null
          : 'Private dataset not present (public CI environment); skipping real data benchmark test',
    );
  });
}
