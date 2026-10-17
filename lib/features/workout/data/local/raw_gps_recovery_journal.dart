import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Append-only recovery copy of raw GPS samples.
///
/// Isar remains the queryable local database. This journal is deliberately a
/// separate, simple file so a broken Isar instance cannot destroy the only
/// local copy of a workout. The coordinator removes it only after both local
/// persistence and the server-visible row count are confirmed.
class RawGpsRecoveryJournal {
  RawGpsRecoveryJournal({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  static final RawGpsRecoveryJournal instance = RawGpsRecoveryJournal();

  final Future<Directory> Function() _documentsDirectory;

  Future<void> append(LocalGPSPoint point) async {
    final file = await fileForSession(point.sessionId);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(_toJson(point))}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

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

  Future<void> delete(String sessionId) async {
    final file = await fileForSession(sessionId);
    if (await file.exists()) await file.delete();
  }

  Map<String, dynamic> _toJson(LocalGPSPoint point) => {
    'workout_id': point.sessionId,
    'timestamp': point.timestamp.toUtc().toIso8601String(),
    'latitude': point.latitude,
    'longitude': point.longitude,
    'altitude': point.altitude,
    'speed': point.speed,
    'accuracy': point.accuracy,
    'heading': point.heading,
    'device_source': point.deviceSource,
    'confidence': point.confidence,
  };
}
