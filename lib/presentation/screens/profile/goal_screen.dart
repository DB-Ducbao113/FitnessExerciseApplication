import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/presentation/providers/goal_providers.dart';

class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key});

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen> {
  GoalType _selectedType = GoalType.distance;
  GoalPeriod _selectedPeriod = GoalPeriod.monthly;
  final _targetController = TextEditingController(text: '50');
  bool _isSaving = false;

  static const _primaryColor = Color(0xff18b0e8);

  @override
  void initState() {
    super.initState();
    // Pre-fill if a goal already exists
    final existing = ref.read(userGoalProvider).valueOrNull;
    if (existing != null) {
      _selectedType = existing.goalType;
      _selectedPeriod = existing.period;
      _targetController.text = existing.targetValue % 1 == 0
          ? existing.targetValue.toInt().toString()
          : existing.targetValue.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = double.tryParse(_targetController.text);
    if (raw == null || raw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target value')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final existing = ref.read(userGoalProvider).valueOrNull;

    final goal = UserGoal(
      id: existing?.id ?? '',
      userId: userId,
      goalType: _selectedType,
      targetValue: raw,
      period: _selectedPeriod,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(userGoalProvider.notifier).saveGoal(goal);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6fa),
      appBar: AppBar(
        title: const Text('Fitness Goal'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Delete goal action
          ref.watch(userGoalProvider).valueOrNull != null
              ? IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove goal',
                  onPressed: () async {
                    await ref.read(userGoalProvider.notifier).deleteGoal();
                    if (mounted) Navigator.of(context).pop();
                  },
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Goal type selector ────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose your goal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...GoalType.values.map(
                      (type) => _GoalTypeOption(
                        type: type,
                        isSelected: _selectedType == type,
                        onTap: () {
                          setState(() {
                            _selectedType = type;
                            // Reset sensible defaults per type
                            _targetController.text = switch (type) {
                              GoalType.distance => '50',
                              GoalType.workouts => '3',
                              GoalType.calories => '2000',
                            };
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Target value input ────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set your target',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _targetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xffe8f7fd),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _unitLabel(_selectedType),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Period selector ───────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Period',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: GoalPeriod.values.map((p) {
                        final selected = _selectedPeriod == p;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedPeriod = p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? _primaryColor
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? _primaryColor
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    p == GoalPeriod.weekly
                                        ? 'Weekly'
                                        : 'Monthly',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Preview ───────────────────────────────────────────
            _GoalPreview(
              type: _selectedType,
              target: double.tryParse(_targetController.text) ?? 0,
              period: _selectedPeriod,
            ),

            const SizedBox(height: 24),

            // ── Save button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save Goal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _unitLabel(GoalType type) {
    return switch (type) {
      GoalType.distance => 'km',
      GoalType.workouts => 'sessions',
      GoalType.calories => 'kcal',
    };
  }
}

// ── Goal Type Option row ─────────────────────────────────────────────
class _GoalTypeOption extends StatelessWidget {
  final GoalType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalTypeOption({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  static const _primaryColor = Color(0xff18b0e8);

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (type) {
      GoalType.distance => (
        Icons.directions_run,
        'Distance',
        'Track km per week or month',
      ),
      GoalType.workouts => (
        Icons.fitness_center,
        'Workouts',
        'Track sessions per week or month',
      ),
      GoalType.calories => (
        Icons.local_fire_department,
        'Calories',
        'Track kcal burned per period',
      ),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryColor : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _primaryColor : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: _primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Goal Preview Card ─────────────────────────────────────────────
class _GoalPreview extends StatelessWidget {
  final GoalType type;
  final double target;
  final GoalPeriod period;

  const _GoalPreview({
    required this.type,
    required this.target,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final label = _buildLabel();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff00d4ff), Color(0xff0099ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your goal',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildLabel() {
    final p = period == GoalPeriod.weekly ? 'per week' : 'this month';
    final t = target <= 0
        ? '?'
        : (target % 1 == 0
              ? target.toInt().toString()
              : target.toStringAsFixed(1));
    return switch (type) {
      GoalType.distance => 'Run $t km $p',
      GoalType.workouts => '$t workouts $p',
      GoalType.calories => 'Burn $t kcal $p',
    };
  }
}
