import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

/// Seed Test Data scenarios for testing WorkoutSignalExtractor and AI Insights.
class WorkoutAiSeedData {
  const WorkoutAiSeedData._();

  /// Scenario A: 5km Steady Run (Pace CV < 0.05, Slope ~ 0.0)
  static WorkoutSession get scenarioConsistentRun {
    final now = DateTime.now();
    return WorkoutSession(
      id: 'seed-workout-consistent-001',
      userId: 'seed-user-001',
      activityType: 'running',
      startedAt: now.subtract(const Duration(minutes: 30)),
      endedAt: now,
      durationSec: 1800,
      movingTimeSec: 1780,
      distanceKm: 5.0,
      avgSpeedKmh: 10.0,
      caloriesKcal: 350.0,
      steps: 4200,
      mode: 'outdoor',
      createdAt: now,
      lapSplits: const [
        WorkoutLapSplit(index: 1, durationSeconds: 360, distanceKm: 1.0, paceMinPerKm: 6.0),
        WorkoutLapSplit(index: 2, durationSeconds: 358, distanceKm: 1.0, paceMinPerKm: 5.97),
        WorkoutLapSplit(index: 3, durationSeconds: 362, distanceKm: 1.0, paceMinPerKm: 6.03),
        WorkoutLapSplit(index: 4, durationSeconds: 359, distanceKm: 1.0, paceMinPerKm: 5.98),
        WorkoutLapSplit(index: 5, durationSeconds: 361, distanceKm: 1.0, paceMinPerKm: 6.02),
      ],
      gpsAnalysis: const WorkoutGpsAnalysis(
        validDistanceKm: 5.0,
        restDurationSec: 20,
      ),
    );
  }

  /// Scenario B: 5km Fatigued Run (Pace slowing down progressively: 5.0 -> 7.0 min/km)
  static WorkoutSession get scenarioFatiguedRun {
    final now = DateTime.now();
    return WorkoutSession(
      id: 'seed-workout-fatigue-002',
      userId: 'seed-user-001',
      activityType: 'running',
      startedAt: now.subtract(const Duration(minutes: 32)),
      endedAt: now,
      durationSec: 1920,
      movingTimeSec: 1850,
      distanceKm: 5.0,
      avgSpeedKmh: 9.37,
      caloriesKcal: 380.0,
      steps: 4500,
      mode: 'outdoor',
      createdAt: now,
      lapSplits: const [
        WorkoutLapSplit(index: 1, durationSeconds: 300, distanceKm: 1.0, paceMinPerKm: 5.0),
        WorkoutLapSplit(index: 2, durationSeconds: 330, distanceKm: 1.0, paceMinPerKm: 5.5),
        WorkoutLapSplit(index: 3, durationSeconds: 360, distanceKm: 1.0, paceMinPerKm: 6.0),
        WorkoutLapSplit(index: 4, durationSeconds: 400, distanceKm: 1.0, paceMinPerKm: 6.67),
        WorkoutLapSplit(index: 5, durationSeconds: 420, distanceKm: 1.0, paceMinPerKm: 7.0),
      ],
      gpsAnalysis: const WorkoutGpsAnalysis(
        validDistanceKm: 4.95,
        restDurationSec: 70,
      ),
    );
  }

  /// Scenario C: 3km Walk with high rest ratio (Rest > 20%)
  static WorkoutSession get scenarioRecoveryWalk {
    final now = DateTime.now();
    return WorkoutSession(
      id: 'seed-workout-walk-003',
      userId: 'seed-user-001',
      activityType: 'walking',
      startedAt: now.subtract(const Duration(minutes: 40)),
      endedAt: now,
      durationSec: 2400,
      movingTimeSec: 1800,
      distanceKm: 3.0,
      avgSpeedKmh: 4.5,
      caloriesKcal: 180.0,
      steps: 3600,
      mode: 'outdoor',
      createdAt: now,
      lapSplits: const [
        WorkoutLapSplit(index: 1, durationSeconds: 700, distanceKm: 1.0, paceMinPerKm: 11.67),
        WorkoutLapSplit(index: 2, durationSeconds: 800, distanceKm: 1.0, paceMinPerKm: 13.33),
        WorkoutLapSplit(index: 3, durationSeconds: 900, distanceKm: 1.0, paceMinPerKm: 15.0),
      ],
      gpsAnalysis: const WorkoutGpsAnalysis(
        validDistanceKm: 3.0,
        restDurationSec: 600,
      ),
    );
  }

  /// 30-Day Historical Baseline Workouts (5 sessions)
  static List<WorkoutSession> get history30Days {
    final now = DateTime.now();
    return [
      WorkoutSession(
        id: 'hist-1',
        userId: 'seed-user-001',
        activityType: 'running',
        startedAt: now.subtract(const Duration(days: 20)),
        endedAt: now.subtract(const Duration(days: 20, minutes: 30)),
        durationSec: 1800,
        movingTimeSec: 1780,
        distanceKm: 5.0,
        avgSpeedKmh: 10.0,
        caloriesKcal: 350.0,
        steps: 4200,
        mode: 'outdoor',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      WorkoutSession(
        id: 'hist-2',
        userId: 'seed-user-001',
        activityType: 'running',
        startedAt: now.subtract(const Duration(days: 15)),
        endedAt: now.subtract(const Duration(days: 15, minutes: 31)),
        durationSec: 1860,
        movingTimeSec: 1840,
        distanceKm: 5.1,
        avgSpeedKmh: 9.87,
        caloriesKcal: 360.0,
        steps: 4300,
        mode: 'outdoor',
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      WorkoutSession(
        id: 'hist-3',
        userId: 'seed-user-001',
        activityType: 'running',
        startedAt: now.subtract(const Duration(days: 10)),
        endedAt: now.subtract(const Duration(days: 10, minutes: 29)),
        durationSec: 1740,
        movingTimeSec: 1720,
        distanceKm: 4.9,
        avgSpeedKmh: 10.13,
        caloriesKcal: 340.0,
        steps: 4100,
        mode: 'outdoor',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      WorkoutSession(
        id: 'hist-4',
        userId: 'seed-user-001',
        activityType: 'running',
        startedAt: now.subtract(const Duration(days: 5)),
        endedAt: now.subtract(const Duration(days: 5, minutes: 30)),
        durationSec: 1800,
        movingTimeSec: 1790,
        distanceKm: 5.0,
        avgSpeedKmh: 10.0,
        caloriesKcal: 350.0,
        steps: 4200,
        mode: 'outdoor',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      WorkoutSession(
        id: 'hist-5',
        userId: 'seed-user-001',
        activityType: 'running',
        startedAt: now.subtract(const Duration(days: 2)),
        endedAt: now.subtract(const Duration(days: 2, minutes: 30)),
        durationSec: 1800,
        movingTimeSec: 1780,
        distanceKm: 5.0,
        avgSpeedKmh: 10.0,
        caloriesKcal: 350.0,
        steps: 4200,
        mode: 'outdoor',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
