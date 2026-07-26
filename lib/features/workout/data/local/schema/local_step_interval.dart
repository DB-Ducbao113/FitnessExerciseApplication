import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:isar/isar.dart';

part 'local_step_interval.g.dart';

@collection
class LocalStepInterval {
  Id id = Isar.autoIncrement;

  @Index()
  late String sessionId;

  late DateTime intervalStart;
  late DateTime intervalEnd;
  int stepsCount = 0;
  String? deviceSource;

  bool isSynced = false;

  RawStepIntervalPayload toPayload() {
    return RawStepIntervalPayload(
      workoutId: sessionId,
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      stepsCount: stepsCount,
      deviceSource: deviceSource,
    );
  }
}
