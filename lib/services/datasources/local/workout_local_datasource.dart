import 'package:fitness_exercise_application/services/datasources/local/database_helper.dart';
import 'package:fitness_exercise_application/models/workout_model.dart';
import 'package:fitness_exercise_application/models/gps_track_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class WorkoutLocalDataSource {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();

  WorkoutLocalDataSource(this._dbHelper);

  /// Create a new workout locally (offline mode)
  Future<String> createWorkout(String activityType, String userId) async {
    final db = await _dbHelper.database;
    final workoutId = _uuid.v4();

    final workout = WorkoutModel(
      id: workoutId,
      userId: userId,
      activityType: activityType,
      startedAt: DateTime.now(),
      synced: false,
    );

    await db.insert('workouts', workout.toSQLite());
    return workoutId;
  }

  /// Save workout from remote
  Future<void> saveWorkout(WorkoutModel workout) async {
    final db = await _dbHelper.database;
    await db.insert(
      'workouts',
      workout.toSQLite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing workout
  Future<void> updateWorkout(WorkoutModel workout) async {
    final db = await _dbHelper.database;
    await db.update(
      'workouts',
      workout.toSQLite(),
      where: 'id = ?',
      whereArgs: [workout.id],
    );
  }

  /// Get all workouts
  Future<List<WorkoutModel>> getWorkouts() async {
    final db = await _dbHelper.database;
    final maps = await db.query('workouts', orderBy: 'started_at DESC');
    return maps.map((map) => WorkoutModel.fromSQLite(map)).toList();
  }

  /// Get single workout
  Future<WorkoutModel?> getWorkout(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('workouts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WorkoutModel.fromSQLite(maps.first);
  }

  /// Save GPS track
  Future<void> saveGPSTrack(GPSTrackModel track) async {
    final db = await _dbHelper.database;
    await db.insert('gps_tracks', track.toSQLite());
  }

  /// Get GPS tracks for a workout
  Future<List<GPSTrackModel>> getGPSTracks(String workoutId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'gps_tracks',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'recorded_at ASC',
    );
    return maps.map((map) => GPSTrackModel.fromSQLite(map)).toList();
  }

  /// Get unsynced workouts
  Future<List<WorkoutModel>> getUnsyncedWorkouts() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'workouts',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return maps.map((map) => WorkoutModel.fromSQLite(map)).toList();
  }

  /// Mark workout as synced
  Future<void> markAsSynced(String workoutId) async {
    final db = await _dbHelper.database;
    await db.update(
      'workouts',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  /// Delete workout from local database
  Future<void> deleteWorkout(String workoutId) async {
    final db = await _dbHelper.database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
  }
}
