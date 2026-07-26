import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kNeonCyan = Color(0xff00e5ff);

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

  @override
  void initState() {
    super.initState();
    final existing = ref.read(userGoalProvider).valueOrNull;
    final useMetricUnits =
        ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    if (existing != null) {
      _selectedType = existing.goalType;
      _selectedPeriod = existing.period;
      final initialTarget =
          existing.goalType == GoalType.distance && !useMetricUnits
          ? WorkoutFormatters.kmToMi(existing.targetValue)
          : existing.targetValue;
      _targetController.text = initialTarget % 1 == 0
          ? initialTarget.toInt().toString()
          : initialTarget.toStringAsFixed(1);
    }
    _targetController.addListener(_refreshTargetPreview);
  }

  void _refreshTargetPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _targetController.removeListener(_refreshTargetPreview);
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = double.tryParse(_targetController.text);
    final useMetricUnits =
        ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    if (raw == null || raw <= 0) {
      showAetronNotice(
        context,
        message: 'Enter a target value greater than zero.',
        tone: AetronNoticeTone.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final existing = ref.read(userGoalProvider).valueOrNull;
    final normalizedTarget =
        _selectedType == GoalType.distance && !useMetricUnits
        ? raw / 0.621371
        : raw;

    final goal = UserGoal(
      id: existing?.id ?? '',
      userId: userId,
      goalType: _selectedType,
      targetValue: normalizedTarget,
      period: _selectedPeriod,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(userGoalProvider.notifier).saveGoal(goal);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        showAetronNotice(
          context,
          message: 'Could not save goal. Check your connection and try again.',
          tone: AetronNoticeTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final hasGoal = ref.watch(userGoalProvider).valueOrNull != null;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: AetronBackground(
        withGrid: false,
        child: Column(
          children: [
            AetronHeader(
              title: AppTranslations.get('create_goal', currentLang),
              compact: true,
              titleSize: 22,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AetronColors.cyanSoft,
                ),
              ),
              trailing: hasGoal
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Remove goal',
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await ref.read(userGoalProvider.notifier).deleteGoal();
                        if (mounted) navigator.pop();
                      },
                    )
                  : const SizedBox(width: 48),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SELECT GOAL TYPE', style: AetronText.label),
                    const SizedBox(height: 14),
                    Row(
                      children: GoalType.values.map((type) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: _GoalTypeHudOption(
                              type: type,
                              useMetricUnits: useMetricUnits,
                              isSelected: _selectedType == type,
                              onTap: () {
                                setState(() {
                                  _selectedType = type;
                                  _targetController.text = switch (type) {
                                    GoalType.distance => '5',
                                    GoalType.workouts => '3',
                                    GoalType.calories => '2000',
                                  };
                                });
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text('TARGET VALUE', style: AetronText.label),
                    const SizedBox(height: 14),
                    _TargetHudPicker(
                      controller: _targetController,
                      unit: _unitLabel(
                        _selectedType,
                        useMetricUnits: useMetricUnits,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('GOAL FREQUENCY', style: AetronText.label),
                    const SizedBox(height: 14),
                    AetronSegmented<GoalPeriod>(
                      values: GoalPeriod.values,
                      selected: _selectedPeriod,
                      labelBuilder: (period) =>
                          period == GoalPeriod.weekly ? 'Weekly' : 'Monthly',
                      onChanged: (period) =>
                          setState(() => _selectedPeriod = period),
                    ),
                    const SizedBox(height: 20),
                    _GoalPreview(
                      type: _selectedType,
                      target: double.tryParse(_targetController.text) ?? 0,
                      period: _selectedPeriod,
                      useMetricUnits: useMetricUnits,
                    ),
                    const SizedBox(height: 24),
                    _isSaving
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AetronColors.cyan,
                            ),
                          )
                        : AetronPrimaryButton(
                            label: 'Save Goal',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _save,
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _unitLabel(GoalType type, {required bool useMetricUnits}) {
    return switch (type) {
      GoalType.distance => WorkoutFormatters.distanceUnitLabel(
        useMetric: useMetricUnits,
      ),
      GoalType.workouts => 'sessions',
      GoalType.calories => 'kcal',
    };
  }
}

class _GoalTypeHudOption extends StatelessWidget {
  final GoalType type;
  final bool useMetricUnits;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalTypeHudOption({
    required this.type,
    required this.useMetricUnits,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (type) {
      GoalType.distance => (Icons.route_rounded, 'Distance'),
      GoalType.workouts => (Icons.fitness_center_rounded, 'Workouts'),
      GoalType.calories => (Icons.local_fire_department_rounded, 'Calories'),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 116,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AetronColors.panel.withValues(alpha: 0.92)
              : AetronColors.panel.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AetronColors.cyanSoft : AetronColors.border,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AetronColors.cyan.withValues(alpha: 0.16),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AetronColors.cyanSoft : AetronColors.muted,
              size: 28,
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected
                      ? AetronColors.cyanSoft
                      : AetronColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetHudPicker extends StatelessWidget {
  const _TargetHudPicker({required this.controller, required this.unit});

  final TextEditingController controller;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final current = double.tryParse(controller.text) ?? 0;
    final prev = (current - 1).clamp(0, 9999).round();
    final next = (current + 1).round();

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AetronColors.cyan.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AetronColors.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(child: Center(child: _GhostNumber('$prev'))),
                Container(height: 1.4, color: AetronColors.cyan),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 180,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AetronColors.text,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(height: 1.4, color: AetronColors.cyan),
                Expanded(child: Center(child: _GhostNumber('$next'))),
              ],
            ),
          ),
          Positioned(
            right: 22,
            bottom: 24,
            child: Text(
              unit.toUpperCase(),
              style: AetronText.label.copyWith(
                color: AetronColors.text.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostNumber extends StatelessWidget {
  const _GhostNumber(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        color: AetronColors.muted.withValues(alpha: 0.34),
        fontSize: 32,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _GoalPreview extends StatelessWidget {
  final GoalType type;
  final double target;
  final GoalPeriod period;
  final bool useMetricUnits;

  const _GoalPreview({
    required this.type,
    required this.target,
    required this.period,
    required this.useMetricUnits,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _previewLabel(type, target, period, useMetricUnits),
            style: const TextStyle(
              color: _kNeonCyan,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _previewLabel(
    GoalType type,
    double target,
    GoalPeriod period,
    bool useMetricUnits,
  ) {
    final value = target % 1 == 0
        ? target.toInt().toString()
        : target.toStringAsFixed(1);
    final periodLabel = period == GoalPeriod.weekly ? 'per week' : 'this month';
    return switch (type) {
      GoalType.distance =>
        'Run $value ${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits)} $periodLabel',
      GoalType.workouts => 'Complete $value workouts $periodLabel',
      GoalType.calories => 'Burn $value kcal $periodLabel',
    };
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: _kNeonCyan.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}
