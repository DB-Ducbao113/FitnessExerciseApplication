import 'package:fitness_exercise_application/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/data/local/schema/local_workout.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class LocalDB {
  static late Isar _isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([
      LocalWorkoutSchema,
      LocalGPSPointSchema,
    ], directory: dir.path);
  }

  static Isar get instance => _isar;

  // Workout Methods
  static Future<int> createWorkout(LocalWorkout workout) async {
    return await _isar.writeTxn(() async {
      return await _isar.localWorkouts.put(workout);
    });
  }

  static Future<LocalWorkout?> getWorkout(int id) async {
    return await _isar.localWorkouts.get(id);
  }

  static Future<void> updateWorkout(LocalWorkout workout) async {
    await _isar.writeTxn(() async {
      await _isar.localWorkouts.put(workout);
    });
  }

  static Future<List<LocalWorkout>> getAllWorkouts() async {
    return await _isar.localWorkouts.where().findAll();
  }

  static Future<void> deleteWorkout(int id) async {
    await _isar.writeTxn(() async {
      await _isar.localWorkouts.delete(id);
    });
  }

  static Future<List<LocalWorkout>> getUnsyncedWorkouts() async {
    return await _isar.localWorkouts.filter().isSyncedEqualTo(false).findAll();
  }

  // GPS Point Methods
  static Future<void> savePoints(List<LocalGPSPoint> points) async {
    await _isar.writeTxn(() async {
      await _isar.localGPSPoints.putAll(points);
    });
  }

  static Future<List<LocalGPSPoint>> getPointsForWorkout(int workoutId) async {
    return await _isar.localGPSPoints
        .filter()
        .localWorkoutIdEqualTo(workoutId)
        .sortByTimestamp()
        .findAll();
  }

  static Future<List<LocalGPSPoint>> getUnsyncedPoints(int workoutId) async {
    return await _isar.localGPSPoints
        .filter()
        .localWorkoutIdEqualTo(workoutId)
        .isSyncedEqualTo(false)
        .sortByTimestamp()
        .findAll();
  }

  static Future<void> markPointsAsSynced(List<int> pointIds) async {
    await _isar.writeTxn(() async {
      for (final id in pointIds) {
        final point = await _isar.localGPSPoints.get(id);
        if (point != null) {
          point.isSynced = true;
          await _isar.localGPSPoints.put(point);
        }
      }
    });
  }
}
