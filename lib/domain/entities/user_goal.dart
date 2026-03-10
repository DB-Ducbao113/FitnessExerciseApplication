/// Supported goal types in the fitness app.
enum GoalType { distance, workouts, calories }

/// Goal period: defines the rolling window for progress calculation.
enum GoalPeriod { weekly, monthly }

/// User's active fitness goal – stored in [user_goals] Supabase table.
class UserGoal {
  final String id;
  final String userId;
  final GoalType goalType;
  final double targetValue; // km | sessions | kcal depending on goalType
  final GoalPeriod period;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserGoal({
    required this.id,
    required this.userId,
    required this.goalType,
    required this.targetValue,
    required this.period,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── DB serialization ──────────────────────────────────────────
  factory UserGoal.fromMap(Map<String, dynamic> m) => UserGoal(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    goalType: GoalType.values.firstWhere((e) => e.name == m['goal_type']),
    targetValue: (m['target_value'] as num).toDouble(),
    period: GoalPeriod.values.firstWhere((e) => e.name == m['period']),
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
  );

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'goal_type': goalType.name,
    'target_value': targetValue,
    'period': period.name,
    'updated_at': updatedAt.toIso8601String(),
  };

  // ── Human-readable label ──────────────────────────────────────
  String get label {
    final p = period == GoalPeriod.weekly ? 'per week' : 'this month';
    switch (goalType) {
      case GoalType.distance:
        return 'Run ${targetValue.toStringAsFixed(0)} km $p';
      case GoalType.workouts:
        return '${targetValue.toInt()} workouts $p';
      case GoalType.calories:
        return 'Burn ${targetValue.toInt()} kcal $p';
    }
  }

  String get unit {
    switch (goalType) {
      case GoalType.distance:
        return 'km';
      case GoalType.workouts:
        return 'sessions';
      case GoalType.calories:
        return 'kcal';
    }
  }

  UserGoal copyWith({
    GoalType? goalType,
    double? targetValue,
    GoalPeriod? period,
  }) => UserGoal(
    id: id,
    userId: userId,
    goalType: goalType ?? this.goalType,
    targetValue: targetValue ?? this.targetValue,
    period: period ?? this.period,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
