import 'dart:io';

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/field_gps_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FieldGpsTraceParser();

  group('FieldGpsTraceParser', () {
    test('sorts samples and prefers live stream over duplicate recovery', () {
      final lines = File(
        'test/fixtures/gps/anonymized_raw_gps_trace.jsonl',
      ).readAsLinesSync();

      final trace = parser.parseLines(lines);

      expect(trace.workoutId, 'fixture-workout');
      expect(trace.sourceLineCount, 4);
      expect(trace.duplicateTimestampCount, 1);
      expect(trace.samples, hasLength(3));
      expect(
        trace.samples.first.timestamp,
        DateTime.utc(2026, 10, 15, 10, 30, 1),
      );
      expect(trace.samples.first.deviceSource, 'geolocator_position_stream');
      expect(trace.samples.first.reportedAccuracyMeters, 6.0);
      expect(
        trace.samples.last.timestamp,
        DateTime.utc(2026, 10, 15, 10, 30, 3),
      );
    });

    test('rejects a coordinate outside the valid latitude range', () {
      const invalidLine =
          '{"workout_id":"w","timestamp":"2026-10-15T10:30:00Z",'
          '"latitude":91,"longitude":2,"accuracy":8,"speed":1,"heading":0}';

      expect(
        () => parser.parseLines(const [invalidLine]),
        throwsA(
          isA<FieldGpsTraceParseException>()
              .having((error) => error.lineNumber, 'lineNumber', 1)
              .having((error) => error.code, 'code', 'invalid_latitude'),
        ),
      );
    });

    test('rejects mixed workout identifiers', () {
      const first =
          '{"workout_id":"w1","timestamp":"2026-10-15T10:30:00Z",'
          '"latitude":1,"longitude":2,"accuracy":8,"speed":1,"heading":0}';
      const second =
          '{"workout_id":"w2","timestamp":"2026-10-15T10:30:01Z",'
          '"latitude":1,"longitude":2,"accuracy":8,"speed":1,"heading":0}';

      expect(
        () => parser.parseLines(const [first, second]),
        throwsA(
          isA<FieldGpsTraceParseException>().having(
            (error) => error.code,
            'code',
            'mixed_workout_ids',
          ),
        ),
      );
    });

    test('rejects non-numeric measurement values', () {
      const invalidLine =
          '{"workout_id":"w","timestamp":"2026-10-15T10:30:00Z",'
          '"latitude":1,"longitude":2,"accuracy":"unknown",'
          '"speed":1,"heading":0}';

      expect(
        () => parser.parseLines(const [invalidLine]),
        throwsA(
          isA<FieldGpsTraceParseException>().having(
            (error) => error.code,
            'code',
            'invalid_accuracy',
          ),
        ),
      );
    });
  });
}
