import 'package:isar/isar.dart';

part 'local_gps_point.g.dart';

@collection
class LocalGPSPoint {
  Id id = Isar.autoIncrement;

  @Index()
  late int localWorkoutId; // Foreign key to LocalWorkout.id

  late DateTime timestamp;
  late double latitude;
  late double longitude;
  late double altitude;
  late double speed;
  late double accuracy;
  late double heading;

  bool isSynced = false; // To track if this specific point has been uploaded
}
