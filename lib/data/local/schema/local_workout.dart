import 'package:isar/isar.dart';

part 'local_workout.g.dart';

@collection
class LocalWorkout {
  Id id = Isar.autoIncrement; // Local ID

  @Index(unique: true, replace: true)
  String? syncId; // ID from Supabase (null if not synced yet)

  late String userId;
  late String activityType; // 'RUNNING', 'CYCLING', etc.

  @Enumerated(EnumType.name)
  late WorkoutStatus status; // ONGOING, COMPLETED, SYNCED

  late DateTime startTime;
  DateTime? endTime;

  double durationSeconds = 0;
  double distanceMeters = 0;
  double caloriesBurned = 0;
  double avgPace = 0;
  double elevationGain = 0;
  int stepCount = 0;
  String mode = 'outdoor';

  bool isSynced = false;
}

enum WorkoutStatus {
  ongoing,
  completed,
  synced, // Fully uploaded to server
}
