import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/local/raw_gps_recovery_journal.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('journal keeps raw GPS samples until explicitly deleted', () async {
    final documents = await Directory.systemTemp.createTemp(
      'aetron-raw-gps-journal-',
    );
    addTearDown(() => documents.delete(recursive: true));
    final journal = RawGpsRecoveryJournal(
      documentsDirectory: () async => documents,
    );

    await journal.append(_point(0));
    await journal.append(_point(1));

    final file = await journal.fileForSession(_workoutId);
    expect(await file.exists(), isTrue);
    final lines = await file.readAsLines();
    expect(lines, hasLength(2));
    final first = jsonDecode(lines.first) as Map<String, dynamic>;
    expect(first['workout_id'], _workoutId);
    expect(first['latitude'], 10.738);
    expect(first['accuracy'], 5.0);

    await journal.delete(_workoutId);
    expect(await file.exists(), isFalse);
  });
}

const _workoutId = '11111111-1111-4111-8111-111111111111';

LocalGPSPoint _point(int seconds) => LocalGPSPoint()
  ..sessionId = _workoutId
  ..timestamp = DateTime.utc(2026, 10, 14, 1, 0, seconds)
  ..latitude = 10.738 + seconds * 0.00001
  ..longitude = 106.625 + seconds * 0.00001
  ..altitude = 2
  ..speed = 4
  ..accuracy = 5
  ..heading = 90
  ..deviceSource = 'geolocator_position_stream'
  ..confidence = 'high';
