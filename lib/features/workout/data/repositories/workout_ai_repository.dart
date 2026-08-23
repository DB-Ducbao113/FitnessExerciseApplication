import 'package:fitness_exercise_application/features/workout/data/datasources/workout_ai_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_insight.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_signals.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_signal_extractor.dart';
import 'package:flutter/foundation.dart';

/// Repository managing AI Post-Workout Insight operations with local fallback protection.
class WorkoutAiRepository {
  final WorkoutAiRemoteDatasource _remoteDatasource;
  final WorkoutSignalExtractor _signalExtractor;

  WorkoutAiRepository({
    WorkoutAiRemoteDatasource? remoteDatasource,
    WorkoutSignalExtractor? signalExtractor,
  })  : _remoteDatasource = remoteDatasource ?? WorkoutAiRemoteDatasource(),
        _signalExtractor = signalExtractor ?? const WorkoutSignalExtractor();

  /// Gets AI Insight for a workout. Extracts signals, invokes backend, and falls back gracefully.
  Future<WorkoutAiInsight> getWorkoutInsight({
    required WorkoutSession workout,
    List<WorkoutSession> last30DaysWorkouts = const [],
    double? userGoalTargetDistanceKm,
  }) async {
    // 1. Extract deterministic signals
    final signals = _signalExtractor.extractSignals(
      workout: workout,
      last30DaysWorkouts: last30DaysWorkouts,
      userGoalTargetDistanceKm: userGoalTargetDistanceKm,
    );

    // 2. Attempt fetching from Supabase Edge Function
    try {
      final insight = await _remoteDatasource.fetchWorkoutInsight(
        workoutId: workout.id,
        signals: signals,
      );
      return insight;
    } catch (e) {
      debugPrint('[WorkoutAiRepository] Edge Function unavailable, generating local fallback: $e');
      // 3. Fallback locally if network or Edge Function fails
      return _generateLocalFallbackInsight(workout, signals, e.toString());
    }
  }

  WorkoutAiInsight _generateLocalFallbackInsight(
    WorkoutSession workout,
    WorkoutAiSignals signals,
    String errorMsg,
  ) {
    final isRunning = workout.activityType.toLowerCase() == 'running';
    final strengths = <String>[];
    final watchouts = <String>[];

    if (signals.paceConsistencyCv < 0.10 && signals.paceConsistencyCv > 0) {
      strengths.add('Duy trì nhịp chạy rất ổn định trong suốt buổi tập.');
    }
    if (signals.paceFatigueSlope > 0.08) {
      watchouts.add('Tốc độ có xu hướng chậm lại ở chặng cuối.');
    } else if (signals.paceFatigueSlope < -0.02) {
      strengths.add('Tăng tốc tốt ở đoạn kết thúc buổi tập (Negative split).');
    }

    if (strengths.isEmpty) {
      strengths.add('Hoàn thành buổi tập đúng mục tiêu thời gian.');
    }
    if (watchouts.isEmpty) {
      watchouts.add('Chú ý uống bù nước và thả lỏng sau khi tập.');
    }

    return WorkoutAiInsight(
      id: 'local-fallback-${workout.id}',
      workoutId: workout.id,
      userId: workout.userId,
      source: 'fallback_rule',
      confidence: 1.0,
      headline: 'Đánh giá buổi ${workout.activityType}',
      mainInsight: isRunning
          ? 'Buổi chạy duy trì tốc độ tốt. Các chỉ số về thời gian di chuyển và calo tiêu thụ hoàn toàn khớp với mục tiêu thể lực.'
          : 'Hoàn thành buổi tập thành công với nhịp độ vận động hợp lý.',
      strengths: strengths,
      watchouts: watchouts,
      nextSessionSuggestion: NextSessionSuggestion(
        recommendedActivity: isRunning ? 'running' : 'walking',
        targetDurationMin: isRunning ? 30 : 25,
        targetIntensity: 'recovery',
        reason: 'Buổi tập nhẹ nhàng giúp thả lỏng cơ bắp và phục hồi.',
      ),
      usedSignals: const [
        'pace_fatigue_slope',
        'pace_consistency_cv',
        'rest_ratio',
      ],
      payloadHash: 'local_hash_${workout.id}',
      fallbackReason: 'provider_error',
      createdAt: DateTime.now(),
    );
  }
}
