import 'package:flutter/foundation.dart';

/// Represents next session suggestion structured response from AI or Rule-based Fallback.
@immutable
class NextSessionSuggestion {
  final String recommendedActivity; // 'running', 'walking', 'cycling', 'rest'
  final int targetDurationMin;
  final String targetIntensity; // 'recovery', 'aerobic', 'tempo', 'interval'
  final String reason;

  const NextSessionSuggestion({
    required this.recommendedActivity,
    required this.targetDurationMin,
    required this.targetIntensity,
    required this.reason,
  });

  factory NextSessionSuggestion.fromJson(Map<String, dynamic> json) {
    return NextSessionSuggestion(
      recommendedActivity: (json['recommended_activity'] ?? json['recommendedActivity'] ?? 'walking').toString(),
      targetDurationMin: (json['target_duration_min'] ?? json['targetDurationMin'] ?? 20) as int,
      targetIntensity: (json['target_intensity'] ?? json['targetIntensity'] ?? 'recovery').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommended_activity': recommendedActivity,
      'target_duration_min': targetDurationMin,
      'target_intensity': targetIntensity,
      'reason': reason,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NextSessionSuggestion &&
          runtimeType == other.runtimeType &&
          recommendedActivity == other.recommendedActivity &&
          targetDurationMin == other.targetDurationMin &&
          targetIntensity == other.targetIntensity &&
          reason == other.reason;

  @override
  int get hashCode =>
      recommendedActivity.hashCode ^
      targetDurationMin.hashCode ^
      targetIntensity.hashCode ^
      reason.hashCode;
}

/// Structured AI Post-Workout Insight Entity.
@immutable
class WorkoutAiInsight {
  final String id;
  final String workoutId;
  final String userId;
  final String source; // 'llm' | 'fallback_rule'
  final double confidence;
  final String headline;
  final String mainInsight;
  final List<String> strengths;
  final List<String> watchouts;
  final NextSessionSuggestion nextSessionSuggestion;
  final List<String> usedSignals;
  final String payloadHash;
  final String? fallbackReason;
  final DateTime createdAt;

  const WorkoutAiInsight({
    required this.id,
    required this.workoutId,
    required this.userId,
    required this.source,
    required this.confidence,
    required this.headline,
    required this.mainInsight,
    required this.strengths,
    required this.watchouts,
    required this.nextSessionSuggestion,
    required this.usedSignals,
    required this.payloadHash,
    this.fallbackReason,
    required this.createdAt,
  });

  bool get isFallback => source == 'fallback_rule';

  factory WorkoutAiInsight.fromJson(Map<String, dynamic> json) {
    final rawJson = json['insight_json'] is Map<String, dynamic>
        ? json['insight_json'] as Map<String, dynamic>
        : json;

    final suggestionRaw = rawJson['next_session_suggestion'] ?? rawJson['nextSessionSuggestion'];
    final suggestionMap = suggestionRaw is Map<String, dynamic>
        ? suggestionRaw
        : <String, dynamic>{};

    return WorkoutAiInsight(
      id: (json['id'] ?? '').toString(),
      workoutId: (json['workout_id'] ?? json['workoutId'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      source: (json['source'] ?? 'fallback_rule').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      headline: (rawJson['headline'] ?? 'Workout Summary').toString(),
      mainInsight: (rawJson['main_insight'] ?? rawJson['mainInsight'] ?? '').toString(),
      strengths: (rawJson['strengths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      watchouts: (rawJson['watchouts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      nextSessionSuggestion: NextSessionSuggestion.fromJson(suggestionMap),
      usedSignals: (rawJson['used_signals'] ?? rawJson['usedSignals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      payloadHash: (json['payload_hash'] ?? json['payloadHash'] ?? '').toString(),
      fallbackReason: json['fallback_reason']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workout_id': workoutId,
      'user_id': userId,
      'source': source,
      'confidence': confidence,
      'insight_json': {
        'headline': headline,
        'main_insight': mainInsight,
        'strengths': strengths,
        'watchouts': watchouts,
        'next_session_suggestion': nextSessionSuggestion.toJson(),
        'used_signals': usedSignals,
      },
      'payload_hash': payloadHash,
      'fallback_reason': fallbackReason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutAiInsight &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workoutId == other.workoutId &&
          userId == other.userId &&
          source == other.source &&
          confidence == other.confidence &&
          payloadHash == other.payloadHash;

  @override
  int get hashCode =>
      id.hashCode ^
      workoutId.hashCode ^
      userId.hashCode ^
      source.hashCode ^
      confidence.hashCode ^
      payloadHash.hashCode;
}
