import 'package:fitness_exercise_application/features/workout/domain/services/workout_signal_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'seed/workout_ai_seed_data.dart';

void main() {
  late WorkoutSignalExtractor extractor;

  setUp(() {
    extractor = const WorkoutSignalExtractor();
  });

  group('WorkoutSignalExtractor Tests', () {
    test('computePaceFatigueSlope calculates positive slope for fatigued run', () {
      final slope = extractor.computePaceFatigueSlope(
        WorkoutAiSeedData.scenarioFatiguedRun.lapSplits,
      );

      // Laps: 5.0 -> 5.5 -> 6.0 -> 6.67 -> 7.0 (Slowing down)
      expect(slope, greaterThan(0.4));
    });

    test('computePaceFatigueSlope returns near 0 for consistent run', () {
      final slope = extractor.computePaceFatigueSlope(
        WorkoutAiSeedData.scenarioConsistentRun.lapSplits,
      );

      expect(slope.abs(), lessThan(0.05));
    });

    test('computePaceFatigueSlope handles edge cases with <2 splits', () {
      expect(extractor.computePaceFatigueSlope([]), 0.0);
    });

    test('computePaceConsistencyCv calculates small CV for steady run', () {
      final cv = extractor.computePaceConsistencyCv(
        WorkoutAiSeedData.scenarioConsistentRun.lapSplits,
      );

      expect(cv, lessThan(0.05));
      expect(cv, greaterThanOrEqualTo(0.0));
    });

    test('computeRestRatio calculates correct ratio and bounds', () {
      final ratio = extractor.computeRestRatio(
        restDurationSec: 600,
        totalDurationSec: 2400,
      );

      expect(ratio, 0.25);
      expect(extractor.computeRestRatio(restDurationSec: 0, totalDurationSec: 0), 0.0);
    });

    test('computeBaselinePaceZScore calculates baseline z-score with 30-day history', () {
      final zScore = extractor.computeBaselinePaceZScore(
        WorkoutAiSeedData.scenarioConsistentRun,
        WorkoutAiSeedData.history30Days,
      );

      // Baseline pace is ~6.0 min/km, consistent run is 6.0 min/km -> z-score near 0
      expect(zScore.abs(), lessThan(0.5));
    });

    test('computeBaselinePaceZScore returns 0.0 when history has fewer than 3 workouts', () {
      final zScore = extractor.computeBaselinePaceZScore(
        WorkoutAiSeedData.scenarioConsistentRun,
        [],
      );

      expect(zScore, 0.0);
    });

    test('evaluateGoalAlignment handles exceeded, on_track, behind, and none', () {
      final workout = WorkoutAiSeedData.scenarioConsistentRun; // 5.0 km

      expect(extractor.evaluateGoalAlignment(workout, 4.0), 'exceeded');
      expect(extractor.evaluateGoalAlignment(workout, 5.5), 'on_track');
      expect(extractor.evaluateGoalAlignment(workout, 10.0), 'behind');
      expect(extractor.evaluateGoalAlignment(workout, null), 'none');
    });

    test('extractSignals runs end-to-end and returns complete WorkoutAiSignals object', () {
      final signals = extractor.extractSignals(
        workout: WorkoutAiSeedData.scenarioConsistentRun,
        last30DaysWorkouts: WorkoutAiSeedData.history30Days,
        userGoalTargetDistanceKm: 5.0,
      );

      expect(signals.paceFatigueSlope.abs(), lessThan(0.05));
      expect(signals.paceConsistencyCv, lessThan(0.05));
      expect(signals.gpsReliabilityScore, greaterThan(0.9));
      expect(signals.goalAlignment, 'exceeded');
      expect(signals.recent7dVolumeKm, greaterThan(0.0));
    });
  });
}
