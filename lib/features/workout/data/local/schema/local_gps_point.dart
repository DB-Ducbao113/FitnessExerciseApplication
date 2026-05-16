import 'package:isar/isar.dart';

part 'local_gps_point.g.dart';

@collection
class LocalGPSPoint {
  Id id = Isar.autoIncrement;

  @Index()
  late String sessionId;

  @Index()
  late int localWorkoutId; // Foreign key to LocalWorkout.id

  late DateTime timestamp;
  late double latitude;
  late double longitude;
  double? altitude;
  double? speed;
  double? accuracy;
  double? heading;
  late String confidence;

  bool isSynced = false; // To track if this specific point has been uploaded
}
