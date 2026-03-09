import 'package:isar/isar.dart';
import 'package:fitness_exercise_application/domain/entities/workout_session.dart';

part 'local_workout.g.dart';

@collection
class LocalWorkout {
  Id id = Isar.autoIncrement; // Local ID

  @Index(unique: true, replace: true)
  late String sessionId; // UUID from client

  late String userId;
  late String activityType;

  late DateTime startedAt;
  late DateTime endedAt;

  int durationSec = 0;
  double distanceKm = 0;
  int steps = 0;
  double avgSpeedKmh = 0;
  double caloriesKcal = 0;
  String mode = 'outdoor';
  late DateTime createdAt;

  // Sync tracking
  bool isSynced = false;

  WorkoutSession toEntity() {
    return WorkoutSession(
      id: sessionId,
      userId: userId,
      activityType: activityType,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSec: durationSec,
      distanceKm: distanceKm,
      steps: steps,
      avgSpeedKmh: avgSpeedKmh,
      caloriesKcal: caloriesKcal,
      mode: mode,
      createdAt: createdAt,
    );
  }

  static LocalWorkout fromEntity(WorkoutSession session) {
    return LocalWorkout()
      ..sessionId = session.id
      ..userId = session.userId
      ..activityType = session.activityType
      ..startedAt = session.startedAt.toUtc()
      ..endedAt = session.endedAt.toUtc()
      ..durationSec = session.durationSec
      ..distanceKm = session.distanceKm
      ..steps = session.steps
      ..avgSpeedKmh = session.avgSpeedKmh
      ..caloriesKcal = session.caloriesKcal
      ..mode = session.mode
      ..createdAt = session.createdAt.toUtc()
      ..isSynced = true;
  }
}
