import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final useMetricUnits = ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    if (existing != null) {
      _selectedType = existing.goalType;
      _selectedPeriod = existing.period;
      final initialTarget = existing.goalType == GoalType.distance && !useMetricUnits
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

  double? get _parsedTargetValue {
    final text = _targetController.text.trim();
    if (text.isEmpty) return null;
    final val = double.tryParse(text);
    if (val == null || val <= 0) return null;
    return val;
  }

  bool get _isValid => _parsedTargetValue != null;

  void _adjustTarget(double delta) {
    final current = _parsedTargetValue ?? 0.0;
    final next = (current + delta).clamp(0.0, 99999.0);
    _targetController.text = next % 1 == 0
        ? next.toInt().toString()
        : next.toStringAsFixed(1);
  }

  Future<void> _save() async {
    final raw = _parsedTargetValue;
    final useMetricUnits = ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    if (raw == null || raw <= 0) {
      showAetronNotice(
        context,
        message: 'Enter a valid target value greater than zero.',
        tone: AetronNoticeTone.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final existing = ref.read(userGoalProvider).valueOrNull;
    final normalizedTarget = _selectedType == GoalType.distance && !useMetricUnits
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
    final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final targetVal = _parsedTargetValue ?? 0.0;
    final unitLabel = _unitLabel(_selectedType, useMetricUnits: useMetricUnits);

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            // 3D Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: AetronColors.cyanSoft,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.get('set_goal_title', currentLang),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasGoal
                              ? (currentLang == AppLanguage.vi ? 'Chỉnh sửa mục tiêu' : 'Edit Goal')
                              : (currentLang == AppLanguage.vi ? 'Tạo mục tiêu mới' : 'Create Goal'),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AetronColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasGoal)
                    Aetron3DOrbButton(
                      icon: Icons.delete_outline_rounded,
                      size: 40,
                      iconSize: 20,
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        await ref.read(userGoalProvider.notifier).deleteGoal();
                        if (mounted) navigator.pop();
                      },
                    ),
                ],
              ),
            ),

            // Main Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: "What do you want to achieve?"
                    Text(
                      AppTranslations.get('what_achievement', currentLang),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AetronColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: GoalType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GoalType3DCard(
                            type: type,
                            useMetricUnits: useMetricUnits,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedType = type;
                                _targetController.text = switch (type) {
                                  GoalType.distance => useMetricUnits ? '50' : '30',
                                  GoalType.workouts => '12',
                                  GoalType.calories => '5000',
                                };
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: YOUR TARGET (Numeric Counter Card)
                    Text(
                      AppTranslations.get('your_target', currentLang),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AetronColors.cyanSoft,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AetronColors.panelHigh,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AetronColors.cyan.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AetronColors.cyan.withValues(alpha: 0.12),
                            blurRadius: 14,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Decrement Button
                              Aetron3DOrbButton(
                                icon: Icons.remove_rounded,
                                size: 44,
                                iconSize: 22,
                                onTap: () => _adjustTarget(
                                  _selectedType == GoalType.calories ? -250 : -1,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Numeric Value & Unit
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    IntrinsicWidth(
                                      child: TextField(
                                        controller: _targetController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                          color: AetronColors.textPrimary,
                                          height: 1,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isCollapsed: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      unitLabel.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AetronColors.cyan,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Increment Button
                              Aetron3DOrbButton(
                                icon: Icons.add_rounded,
                                size: 44,
                                iconSize: 22,
                                onTap: () => _adjustTarget(
                                  _selectedType == GoalType.calories ? 250 : 1,
                                ),
                              ),
                            ],
                          ),
                          if (!_isValid) ...[
                            const SizedBox(height: 8),
                            Text(
                              currentLang == AppLanguage.vi
                                  ? 'Nhập giá trị lớn hơn 0'
                                  : 'Enter a value greater than zero',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                color: AetronColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 3: GOAL PERIOD
                    Text(
                      AppTranslations.get('goal_period', currentLang),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AetronColors.cyanSoft,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AetronSegmentedControl(
                      selectedIndex: _selectedPeriod == GoalPeriod.weekly ? 0 : 1,
                      tabs: [
                        currentLang == AppLanguage.vi ? 'Hàng tuần' : 'Weekly',
                        currentLang == AppLanguage.vi ? 'Hàng tháng' : 'Monthly',
                      ],
                      onTabChanged: (index) {
                        setState(() {
                          _selectedPeriod = index == 0 ? GoalPeriod.weekly : GoalPeriod.monthly;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Section 4: GOAL SUMMARY CARD
                    Text(
                      AppTranslations.get('your_goal_summary', currentLang),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AetronColors.cyanSoft,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Goal3DSummaryCard(
                      type: _selectedType,
                      target: targetVal,
                      period: _selectedPeriod,
                      useMetricUnits: useMetricUnits,
                      isValid: _isValid,
                    ),
                    const SizedBox(height: 28),

                    // Sticky Save Goal CTA Button
                    _isSaving
                        ? const Center(
                            child: CircularProgressIndicator(color: AetronColors.cyan),
                          )
                        : Aetron3DPrimaryButton(
                            label: hasGoal
                                ? AppTranslations.get('update_goal', currentLang)
                                : AppTranslations.get('save_goal', currentLang),
                            icon: Icons.check_circle_outline_rounded,
                            onPressed: _isValid ? _save : null,
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
      GoalType.workouts => 'workouts',
      GoalType.calories => 'kcal',
    };
  }
}

// ─── 3D Goal Type Card ──────────────────────────────────────────────────
class _GoalType3DCard extends ConsumerWidget {
  final GoalType type;
  final bool useMetricUnits;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalType3DCard({
    required this.type,
    required this.useMetricUnits,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    final (icon, titleVi, titleEn, descVi, descEn) = switch (type) {
      GoalType.distance => (
          Icons.route_rounded,
          'Khoảng cách',
          'Distance',
          'Đặt mục tiêu tổng quãng đường chạy/đi bộ',
          'Track total mileage goal',
        ),
      GoalType.workouts => (
          Icons.fitness_center_rounded,
          'Số buổi tập',
          'Workouts',
          'Đặt mục tiêu số buổi luyện tập hoàn thành',
          'Target workout session count',
        ),
      GoalType.calories => (
          Icons.local_fire_department_rounded,
          'Lượng Calo',
          'Calories',
          'Đặt mục tiêu tổng calo đốt cháy',
          'Target active calorie burn',
        ),
    };

    final title = currentLang == AppLanguage.vi ? titleVi : titleEn;
    final description = currentLang == AppLanguage.vi ? descVi : descEn;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AetronColors.panelHigh : AetronColors.space,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AetronColors.cyan
                : AetronColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AetronColors.cyan.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AetronColors.cyan.withValues(alpha: 0.2)
                    : AetronColors.panelHigh,
                border: Border.all(
                  color: isSelected ? AetronColors.cyan : AetronColors.borderSubtle,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? AetronColors.cyan : AetronColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? AetronColors.cyan : AetronColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: AetronColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? AetronColors.cyan : AetronColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3D Goal Summary Card ───────────────────────────────────────────────────
class _Goal3DSummaryCard extends ConsumerWidget {
  final GoalType type;
  final double target;
  final GoalPeriod period;
  final bool useMetricUnits;
  final bool isValid;

  const _Goal3DSummaryCard({
    required this.type,
    required this.target,
    required this.period,
    required this.useMetricUnits,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    if (!isValid) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AetronColors.space,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AetronColors.borderSubtle),
        ),
        child: Text(
          currentLang == AppLanguage.vi
              ? 'Nhập mục tiêu lớn hơn 0 để xem tổng quan.'
              : 'Enter a target value to see your goal summary.',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            color: AetronColors.textSecondary,
          ),
        ),
      );
    }

    final unit = switch (type) {
      GoalType.distance => WorkoutFormatters.distanceUnitLabel(
          useMetric: useMetricUnits,
        ),
      GoalType.workouts => currentLang == AppLanguage.vi ? 'buổi' : 'workouts',
      GoalType.calories => 'kcal',
    };

    final targetStr = target % 1 == 0
        ? target.toInt().toString()
        : target.toStringAsFixed(1);
    final periodStr = period == GoalPeriod.weekly
        ? (currentLang == AppLanguage.vi ? 'tuần này' : 'this week')
        : (currentLang == AppLanguage.vi ? 'tháng này' : 'this month');

    final summarySentence = switch (type) {
      GoalType.distance => currentLang == AppLanguage.vi
          ? 'Chạy $targetStr $unit $periodStr'
          : 'Run $targetStr $unit $periodStr',
      GoalType.workouts => currentLang == AppLanguage.vi
          ? 'Hoàn thành $targetStr $unit $periodStr'
          : 'Complete $targetStr $unit $periodStr',
      GoalType.calories => currentLang == AppLanguage.vi
          ? 'Đốt $targetStr $unit $periodStr'
          : 'Burn $targetStr $unit $periodStr',
    };

    final derivedContext = _calculateDerivedContext(type, target, period, unit, currentLang);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AetronColors.mint.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AetronColors.mint.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AetronColors.mint.withValues(alpha: 0.15),
                  border: Border.all(color: AetronColors.mint),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AetronColors.mint,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summarySentence,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.mint,
                  ),
                ),
              ),
            ],
          ),
          if (derivedContext != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AetronColors.mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                derivedContext,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: AetronColors.mint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _calculateDerivedContext(
    GoalType type,
    double target,
    GoalPeriod period,
    String unit,
    AppLanguage currentLang,
  ) {
    if (target <= 0) return null;

    final weekLabel = currentLang == AppLanguage.vi ? 'tuần' : 'week';
    final dayLabel = currentLang == AppLanguage.vi ? 'ngày' : 'day';

    if (period == GoalPeriod.monthly) {
      final perWeek = target / 4.0;
      final perWeekStr = perWeek % 1 == 0
          ? perWeek.toInt().toString()
          : perWeek.toStringAsFixed(1);
      return '≈ $perWeekStr $unit / $weekLabel';
    } else {
      final perDay = target / 7.0;
      final perDayStr = perDay % 1 == 0
          ? perDay.toInt().toString()
          : perDay.toStringAsFixed(1);
      return '≈ $perDayStr $unit / $dayLabel';
    }
  }
}
