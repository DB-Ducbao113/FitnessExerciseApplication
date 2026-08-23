import 'package:flutter/foundation.dart';

/// Aggregated Deterministic Weak Signals extracted from a workout session.
/// LLM MUST receive these pre-computed numbers and NEVER compute math itself.
@immutable
class WorkoutAiSignals {
  final double paceFatigueSlope; // >0 means slowing down, <0 means speeding up
  final double paceConsistencyCv; // Coefficient of variation (stddev / mean)
  final double restRatio; // restDurationSec / totalDurationSec
  final double gpsReliabilityScore; // 0.0 (unreliable) to 1.0 (perfect)
  final double baselinePaceZScore; // Z-score relative to 30-day average pace
  final double baselineDistanceZScore; // Z-score relative to 30-day average distance
  final String goalAlignment; // 'on_track', 'behind', 'exceeded', 'none'
  final double recent7dVolumeKm;

  const WorkoutAiSignals({
    required this.paceFatigueSlope,
    required this.paceConsistencyCv,
    required this.restRatio,
    required this.gpsReliabilityScore,
    required this.baselinePaceZScore,
    required this.baselineDistanceZScore,
    required this.goalAlignment,
    required this.recent7dVolumeKm,
  });

  factory WorkoutAiSignals.empty() {
    return const WorkoutAiSignals(
      paceFatigueSlope: 0.0,
      paceConsistencyCv: 0.0,
      restRatio: 0.0,
      gpsReliabilityScore: 1.0,
      baselinePaceZScore: 0.0,
      baselineDistanceZScore: 0.0,
      goalAlignment: 'none',
      recent7dVolumeKm: 0.0,
    );
  }

  factory WorkoutAiSignals.fromJson(Map<String, dynamic> json) {
    return WorkoutAiSignals(
      paceFatigueSlope: (json['pace_fatigue_slope'] as num?)?.toDouble() ?? 0.0,
      paceConsistencyCv: (json['pace_consistency_cv'] as num?)?.toDouble() ?? 0.0,
      restRatio: (json['rest_ratio'] as num?)?.toDouble() ?? 0.0,
      gpsReliabilityScore: (json['gps_reliability_score'] as num?)?.toDouble() ?? 1.0,
      baselinePaceZScore: (json['baseline_pace_zscore'] as num?)?.toDouble() ?? 0.0,
      baselineDistanceZScore: (json['baseline_distance_zscore'] as num?)?.toDouble() ?? 0.0,
      goalAlignment: (json['goal_alignment'] ?? 'none').toString(),
      recent7dVolumeKm: (json['recent_7d_volume_km'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pace_fatigue_slope': paceFatigueSlope,
      'pace_consistency_cv': paceConsistencyCv,
      'rest_ratio': restRatio,
      'gps_reliability_score': gpsReliabilityScore,
      'baseline_pace_zscore': baselinePaceZScore,
      'baseline_distance_zscore': baselineDistanceZScore,
      'goal_alignment': goalAlignment,
      'recent_7d_volume_km': recent7dVolumeKm,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutAiSignals &&
          runtimeType == other.runtimeType &&
          paceFatigueSlope == other.paceFatigueSlope &&
          paceConsistencyCv == other.paceConsistencyCv &&
          restRatio == other.restRatio &&
          gpsReliabilityScore == other.gpsReliabilityScore &&
          baselinePaceZScore == other.baselinePaceZScore &&
          baselineDistanceZScore == other.baselineDistanceZScore &&
          goalAlignment == other.goalAlignment &&
          recent7dVolumeKm == other.recent7dVolumeKm;

  @override
  int get hashCode =>
      paceFatigueSlope.hashCode ^
      paceConsistencyCv.hashCode ^
      restRatio.hashCode ^
      gpsReliabilityScore.hashCode ^
      baselinePaceZScore.hashCode ^
      baselineDistanceZScore.hashCode ^
      goalAlignment.hashCode ^
      recent7dVolumeKm.hashCode;
}
