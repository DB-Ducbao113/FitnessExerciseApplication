import 'dart:convert';

import 'package:latlong2/latlong.dart';

/// One validated sample from a field-recorded raw GPS journal.
class FieldGpsSample {
  final String workoutId;
  final DateTime timestamp;
  final LatLng position;
  final double? altitudeMeters;
  final double speedMetersPerSecond;
  final double reportedAccuracyMeters;
  final double? headingDegrees;
  final String? deviceSource;
  final String? confidence;

  const FieldGpsSample({
    required this.workoutId,
    required this.timestamp,
    required this.position,
    required this.altitudeMeters,
    required this.speedMetersPerSecond,
    required this.reportedAccuracyMeters,
    required this.headingDegrees,
    required this.deviceSource,
    required this.confidence,
  });
}

/// A time-ordered, timestamp-deduplicated field trace.
class FieldGpsTrace {
  final String workoutId;
  final List<FieldGpsSample> samples;
  final int sourceLineCount;
  final int duplicateTimestampCount;

  const FieldGpsTrace({
    required this.workoutId,
    required this.samples,
    required this.sourceLineCount,
    required this.duplicateTimestampCount,
  });
}

/// Structured boundary error for malformed or inconsistent JSONL input.
class FieldGpsTraceParseException implements FormatException {
  final String code;
  final int lineNumber;

  @override
  final String message;

  @override
  final Object? source;

  @override
  final int? offset;

  const FieldGpsTraceParseException({
    required this.code,
    required this.lineNumber,
    required this.message,
    this.source,
    this.offset,
  });

  @override
  String toString() =>
      'FieldGpsTraceParseException($code, line $lineNumber): $message';
}

/// Parses app recovery journals without depending on storage or networking.
class FieldGpsTraceParser {
  const FieldGpsTraceParser();

  FieldGpsTrace parseLines(Iterable<String> lines) {
    final indexedSamples = <_IndexedFieldGpsSample>[];
    String? workoutId;
    var sourceLineCount = 0;
    var lineNumber = 0;

    for (final rawLine in lines) {
      lineNumber += 1;
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      sourceLineCount += 1;

      final json = _decodeObject(line, lineNumber);
      final sampleWorkoutId = _requiredString(json, 'workout_id', lineNumber);
      if (workoutId != null && workoutId != sampleWorkoutId) {
        throw FieldGpsTraceParseException(
          code: 'mixed_workout_ids',
          lineNumber: lineNumber,
          message: 'Expected workout_id $workoutId, got $sampleWorkoutId',
          source: line,
        );
      }
      workoutId ??= sampleWorkoutId;

      final timestampText = _requiredString(json, 'timestamp', lineNumber);
      final parsedTimestamp = DateTime.tryParse(timestampText);
      if (parsedTimestamp == null) {
        throw FieldGpsTraceParseException(
          code: 'invalid_timestamp',
          lineNumber: lineNumber,
          message: 'timestamp must be ISO-8601',
          source: timestampText,
        );
      }

      final latitude = _requiredFiniteDouble(json, 'latitude', lineNumber);
      if (latitude < -90 || latitude > 90) {
        throw FieldGpsTraceParseException(
          code: 'invalid_latitude',
          lineNumber: lineNumber,
          message: 'latitude must be between -90 and 90',
          source: latitude,
        );
      }

      final longitude = _requiredFiniteDouble(json, 'longitude', lineNumber);
      if (longitude < -180 || longitude > 180) {
        throw FieldGpsTraceParseException(
          code: 'invalid_longitude',
          lineNumber: lineNumber,
          message: 'longitude must be between -180 and 180',
          source: longitude,
        );
      }

      final accuracy = _requiredFiniteDouble(json, 'accuracy', lineNumber);
      if (accuracy < 0) {
        throw FieldGpsTraceParseException(
          code: 'invalid_accuracy',
          lineNumber: lineNumber,
          message: 'accuracy must be non-negative',
          source: accuracy,
        );
      }

      final sample = FieldGpsSample(
        workoutId: sampleWorkoutId,
        timestamp: parsedTimestamp.toUtc(),
        position: LatLng(latitude, longitude),
        altitudeMeters: _optionalFiniteDouble(json, 'altitude', lineNumber),
        speedMetersPerSecond: _requiredFiniteDouble(json, 'speed', lineNumber),
        reportedAccuracyMeters: accuracy,
        headingDegrees: _optionalFiniteDouble(json, 'heading', lineNumber),
        deviceSource: _optionalString(json, 'device_source', lineNumber),
        confidence: _optionalString(json, 'confidence', lineNumber),
      );
      indexedSamples.add(
        _IndexedFieldGpsSample(
          sample: sample,
          sourceIndex: indexedSamples.length,
        ),
      );
    }

    if (indexedSamples.isEmpty || workoutId == null) {
      throw const FieldGpsTraceParseException(
        code: 'empty_trace',
        lineNumber: 0,
        message: 'The JSONL trace has no samples',
      );
    }

    indexedSamples.sort((left, right) {
      final timestampOrder = left.sample.timestamp.compareTo(
        right.sample.timestamp,
      );
      if (timestampOrder != 0) return timestampOrder;
      final sourceOrder = _sourcePriority(
        left.sample.deviceSource,
      ).compareTo(_sourcePriority(right.sample.deviceSource));
      if (sourceOrder != 0) return sourceOrder;
      return left.sourceIndex.compareTo(right.sourceIndex);
    });

    final samples = <FieldGpsSample>[];
    var duplicateTimestampCount = 0;
    for (final indexed in indexedSamples) {
      if (samples.isNotEmpty &&
          samples.last.timestamp == indexed.sample.timestamp) {
        duplicateTimestampCount += 1;
        continue;
      }
      samples.add(indexed.sample);
    }

    return FieldGpsTrace(
      workoutId: workoutId,
      samples: List<FieldGpsSample>.unmodifiable(samples),
      sourceLineCount: sourceLineCount,
      duplicateTimestampCount: duplicateTimestampCount,
    );
  }

  Map<String, dynamic> _decodeObject(String line, int lineNumber) {
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException catch (error) {
      throw FieldGpsTraceParseException(
        code: 'invalid_json',
        lineNumber: lineNumber,
        message: error.message,
        source: line,
        offset: error.offset,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw FieldGpsTraceParseException(
        code: 'invalid_json_object',
        lineNumber: lineNumber,
        message: 'Each JSONL line must be an object',
        source: line,
      );
    }
    return decoded;
  }

  String _requiredString(
    Map<String, dynamic> json,
    String key,
    int lineNumber,
  ) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FieldGpsTraceParseException(
      code: 'invalid_$key',
      lineNumber: lineNumber,
      message: '$key must be a non-empty string',
      source: value,
    );
  }

  String? _optionalString(
    Map<String, dynamic> json,
    String key,
    int lineNumber,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FieldGpsTraceParseException(
      code: 'invalid_$key',
      lineNumber: lineNumber,
      message: '$key must be a string or null',
      source: value,
    );
  }

  double _requiredFiniteDouble(
    Map<String, dynamic> json,
    String key,
    int lineNumber,
  ) {
    final value = _optionalFiniteDouble(json, key, lineNumber);
    if (value != null) return value;
    throw FieldGpsTraceParseException(
      code: 'invalid_$key',
      lineNumber: lineNumber,
      message: '$key must be a finite number',
      source: json[key],
    );
  }

  double? _optionalFiniteDouble(
    Map<String, dynamic> json,
    String key,
    int lineNumber,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is num) {
      final result = value.toDouble();
      if (result.isFinite) return result;
    }
    throw FieldGpsTraceParseException(
      code: 'invalid_$key',
      lineNumber: lineNumber,
      message: '$key must be a finite number or null',
      source: value,
    );
  }

  static int _sourcePriority(String? deviceSource) {
    return switch (deviceSource) {
      'geolocator_position_stream' => 0,
      'geolocator_position_stream_recovery' => 1,
      _ => 2,
    };
  }
}

class _IndexedFieldGpsSample {
  final FieldGpsSample sample;
  final int sourceIndex;

  const _IndexedFieldGpsSample({
    required this.sample,
    required this.sourceIndex,
  });
}
