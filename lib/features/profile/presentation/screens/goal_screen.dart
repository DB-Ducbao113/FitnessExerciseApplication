import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key});

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen> {
  GoalType _selectedType = GoalType.distance;
  GoalPeriod _selectedPeriod = GoalPeriod.weekly;
  double _targetValue = 40.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(userGoalProvider).valueOrNull;
    final useMetricUnits = ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    if (existing != null) {
      _selectedType = existing.goalType;
      _selectedPeriod = existing.period;
      _targetValue = existing.goalType == GoalType.distance && !useMetricUnits
          ? WorkoutFormatters.kmToMi(existing.targetValue)
          : existing.targetValue;
    } else {
      _targetValue = _defaultTargetFor(_selectedType, _selectedPeriod);
    }
  }

  double _defaultTargetFor(GoalType type, GoalPeriod period) {
    final isWeekly = period == GoalPeriod.weekly;
    switch (type) {
      case GoalType.distance:
        return isWeekly ? 35.0 : 150.0;
      case GoalType.workouts:
        return isWeekly ? 4.0 : 16.0;
      case GoalType.calories:
        return isWeekly ? 3500.0 : 15000.0;
    }
  }

  double _minTargetFor(GoalType type, GoalPeriod period) {
    final isWeekly = period == GoalPeriod.weekly;
    switch (type) {
      case GoalType.distance:
        return isWeekly ? 5.0 : 20.0;
      case GoalType.workouts:
        return isWeekly ? 1.0 : 4.0;
      case GoalType.calories:
        return isWeekly ? 500.0 : 2000.0;
    }
  }

  double _maxTargetFor(GoalType type, GoalPeriod period) {
    final isWeekly = period == GoalPeriod.weekly;
    switch (type) {
      case GoalType.distance:
        return isWeekly ? 150.0 : 600.0;
      case GoalType.workouts:
        return isWeekly ? 14.0 : 45.0;
      case GoalType.calories:
        return isWeekly ? 15000.0 : 60000.0;
    }
  }

  double _stepSizeFor(GoalType type) {
    switch (type) {
      case GoalType.distance:
        return 5.0;
      case GoalType.workouts:
        return 1.0;
      case GoalType.calories:
        return 250.0;
    }
  }

  void _updateTarget(double value) {
    final minVal = _minTargetFor(_selectedType, _selectedPeriod);
    final maxVal = _maxTargetFor(_selectedType, _selectedPeriod);
    setState(() {
      _targetValue = value.clamp(minVal, maxVal);
    });
  }

  void _adjustTarget(double delta) {
    HapticFeedback.selectionClick();
    _updateTarget(_targetValue + delta);
  }

  Future<void> _save() async {
    final useMetricUnits = ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    if (_targetValue <= 0) {
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
        ? _targetValue / 0.621371
        : _targetValue;

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
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
      }
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

  void _showDirectValueEditor(BuildContext context, AppLanguage currentLang) {
    final controller = TextEditingController(
      text: _targetValue % 1 == 0
          ? _targetValue.toInt().toString()
          : _targetValue.toStringAsFixed(1),
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AetronColors.space,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentLang == AppLanguage.vi ? 'NHẬP CHÍNH XÁC MỤC TIÊU' : 'ENTER EXACT TARGET',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.cyan,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AetronColors.panelHigh,
                  suffixText: _unitLabel(_selectedType, useMetricUnits: true).toUpperCase(),
                  suffixStyle: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AetronColors.cyan,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AetronColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: currentLang == AppLanguage.vi ? 'ÁP DỤNG MỤC TIÊU' : 'APPLY TARGET',
                icon: Icons.check_circle_rounded,
                onPressed: () {
                  final parsed = double.tryParse(controller.text.trim());
                  if (parsed != null && parsed > 0) {
                    _updateTarget(parsed);
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final hasGoal = ref.watch(userGoalProvider).valueOrNull != null;
    final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final unit = _unitLabel(_selectedType, useMetricUnits: useMetricUnits);
    final minVal = _minTargetFor(_selectedType, _selectedPeriod);
    final maxVal = _maxTargetFor(_selectedType, _selectedPeriod);
    final step = _stepSizeFor(_selectedType);

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, currentLang, hasGoal),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // 1. Goal Type 3D Selector (Distance / Workouts / Calories)
                  _buildTypeSelector(currentLang),
                  const SizedBox(height: 14),

                  // 2. Period Sprint Selector (Weekly Sprint vs Monthly Campaign)
                  _buildPeriodSelector(currentLang),
                  const SizedBox(height: 16),

                  // 3. Central Holographic Radial Target Dial
                  _buildHolographicDialCard(
                    context,
                    currentLang,
                    unit,
                    minVal,
                    maxVal,
                    step,
                  ),
                  const SizedBox(height: 18),

                  // 4. Mission Tier Presets (Starter / Pro / Elite / Beast)
                  _buildMissionTierPresets(currentLang, useMetricUnits),
                  const SizedBox(height: 18),

                  // 5. Live AI Telemetry Forecast & Feasibility
                  _buildAiForecastCard(currentLang, useMetricUnits),
                  const SizedBox(height: 24),

                  // 6. Action Button
                  _isSaving
                      ? const Center(
                          child: CircularProgressIndicator(color: AetronColors.cyan),
                        )
                      : Aetron3DPrimaryButton(
                          label: hasGoal
                              ? (currentLang == AppLanguage.vi ? 'CẬP NHẬT NHIỆM VỤ' : 'UPDATE GOAL PROTOCOL')
                              : (currentLang == AppLanguage.vi ? 'KÍCH HOẠT NHIỆM VỤ' : 'ACTIVATE GOAL PROTOCOL'),
                          icon: Icons.bolt_rounded,
                          onPressed: _save,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppLanguage currentLang, bool hasGoal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AetronColors.panelHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AetronColors.borderSubtle),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AetronColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentLang == AppLanguage.vi ? 'GIAO THỨC THỂ LỰC' : 'FITNESS PROTOCOL',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  hasGoal
                      ? (currentLang == AppLanguage.vi ? 'Thiết Lập Mục Tiêu' : 'Edit Goal Matrix')
                      : (currentLang == AppLanguage.vi ? 'Kích Hoạt Mục Tiêu' : 'Set New Target'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (hasGoal)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await ref.read(userGoalProvider.notifier).deleteGoal();
                  if (mounted) navigator.pop();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AetronColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AetronColors.error.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AetronColors.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(AppLanguage currentLang) {
    final types = [
      (GoalType.distance, Icons.route_rounded, 'CỰ LY', 'DISTANCE'),
      (GoalType.workouts, Icons.fitness_center_rounded, 'BUỔI TẬP', 'SESSIONS'),
      (GoalType.calories, Icons.local_fire_department_rounded, 'CALO', 'CALORIES'),
    ];

    return Row(
      children: types.map((item) {
        final type = item.$1;
        final icon = item.$2;
        final label = currentLang == AppLanguage.vi ? item.$3 : item.$4;
        final isSelected = _selectedType == type;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedType = type;
                    _targetValue = _defaultTargetFor(type, _selectedPeriod);
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AetronColors.cyan.withValues(alpha: 0.18)
                        : AetronColors.panelHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AetronColors.cyan
                          : AetronColors.borderSubtle,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AetronColors.cyan.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected ? AetronColors.cyan : AetronColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? AetronColors.cyan : AetronColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPeriodSelector(AppLanguage currentLang) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodTab(
              label: currentLang == AppLanguage.vi ? 'Sprint Hàng Tuần (7 Ngày)' : 'Weekly Sprint (7 Days)',
              isSelected: _selectedPeriod == GoalPeriod.weekly,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedPeriod = GoalPeriod.weekly;
                  _targetValue = _defaultTargetFor(_selectedType, GoalPeriod.weekly);
                });
              },
            ),
          ),
          Expanded(
            child: _buildPeriodTab(
              label: currentLang == AppLanguage.vi ? 'Chiến Dịch Tháng (30 Ngày)' : 'Monthly Campaign',
              isSelected: _selectedPeriod == GoalPeriod.monthly,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedPeriod = GoalPeriod.monthly;
                  _targetValue = _defaultTargetFor(_selectedType, GoalPeriod.monthly);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AetronColors.cyan.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AetronColors.cyan.withValues(alpha: 0.4))
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? AetronColors.cyan : AetronColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHolographicDialCard(
    BuildContext context,
    AppLanguage currentLang,
    String unit,
    double minVal,
    double maxVal,
    double step,
  ) {
    final progressRatio = ((_targetValue - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
    final displayValue = _targetValue % 1 == 0
        ? _targetValue.toInt().toString()
        : _targetValue.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Column(
        children: [
          // Radial Holographic Arc & Big Typography
          GestureDetector(
            onTap: () => _showDirectValueEditor(context, currentLang),
            child: SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Custom Paint Arc
                  CustomPaint(
                    size: const Size(210, 210),
                    painter: _RadialTargetGaugePainter(
                      progress: progressRatio,
                      color: AetronColors.cyan,
                    ),
                  ),

                  // Center Content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AetronColors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _selectedPeriod == GoalPeriod.weekly
                              ? (currentLang == AppLanguage.vi ? 'MỤC TIÊU TUẦN' : 'WEEKLY TARGET')
                              : (currentLang == AppLanguage.vi ? 'MỤC TIÊU THÁNG' : 'MONTHLY TARGET'),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AetronColors.cyan,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayValue,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.textPrimary,
                          letterSpacing: -1.0,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unit.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AetronColors.cyanSoft,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, size: 10, color: AetronColors.muted),
                          const SizedBox(width: 3),
                          Text(
                            currentLang == AppLanguage.vi ? 'Chạm để gõ' : 'Tap to edit',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9,
                              color: AetronColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stepper & Slider Controls Row
          Row(
            children: [
              // Decrement Button
              _buildStepButton(
                icon: Icons.remove_rounded,
                label: '-$step',
                onTap: () => _adjustTarget(-step),
              ),

              // Interactive Slider
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    activeTrackColor: AetronColors.cyan,
                    inactiveTrackColor: AetronColors.space,
                    thumbColor: AetronColors.cyan,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayColor: AetronColors.cyan.withValues(alpha: 0.25),
                  ),
                  child: Slider(
                    value: _targetValue.clamp(minVal, maxVal),
                    min: minVal,
                    max: maxVal,
                    onChanged: (val) {
                      _updateTarget(val);
                    },
                  ),
                ),
              ),

              // Increment Button
              _buildStepButton(
                icon: Icons.add_rounded,
                label: '+$step',
                onTap: () => _adjustTarget(step),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AetronColors.space,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AetronColors.cyan),
              const SizedBox(width: 2),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AetronColors.cyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionTierPresets(AppLanguage currentLang, bool useMetricUnits) {
    final isWeekly = _selectedPeriod == GoalPeriod.weekly;

    final presets = switch (_selectedType) {
      GoalType.distance => [
          ('Starter', 'Khởi Nguyên', isWeekly ? 20.0 : 80.0, Icons.spa_rounded, AetronColors.mint),
          ('Pro', 'Bứt Phá', isWeekly ? 45.0 : 180.0, Icons.bolt_rounded, AetronColors.cyan),
          ('Elite', 'Đẳng Cấp', isWeekly ? 80.0 : 320.0, Icons.workspace_premium_rounded, AetronColors.gold),
          ('Beast', 'Vô Cực', isWeekly ? 120.0 : 480.0, Icons.whatshot_rounded, const Color(0xFFA55EEA)),
        ],
      GoalType.workouts => [
          ('Starter', 'Khởi Nguyên', isWeekly ? 3.0 : 12.0, Icons.spa_rounded, AetronColors.mint),
          ('Pro', 'Bứt Phá', isWeekly ? 5.0 : 20.0, Icons.bolt_rounded, AetronColors.cyan),
          ('Elite', 'Đẳng Cấp', isWeekly ? 7.0 : 28.0, Icons.workspace_premium_rounded, AetronColors.gold),
          ('Beast', 'Vô Cực', isWeekly ? 10.0 : 38.0, Icons.whatshot_rounded, const Color(0xFFA55EEA)),
        ],
      GoalType.calories => [
          ('Starter', 'Khởi Nguyên', isWeekly ? 2000.0 : 8000.0, Icons.spa_rounded, AetronColors.mint),
          ('Pro', 'Bứt Phá', isWeekly ? 4500.0 : 18000.0, Icons.bolt_rounded, AetronColors.cyan),
          ('Elite', 'Đẳng Cấp', isWeekly ? 8000.0 : 32000.0, Icons.workspace_premium_rounded, AetronColors.gold),
          ('Beast', 'Vô Cực', isWeekly ? 12000.0 : 48000.0, Icons.whatshot_rounded, const Color(0xFFA55EEA)),
        ],
    };

    final unitLabel = _unitLabel(_selectedType, useMetricUnits: useMetricUnits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentLang == AppLanguage.vi ? 'GÓI NHIỆM VỤ ĐỀ XUẤT' : 'RECOMMENDED PROTOCOLS',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AetronColors.cyanSoft,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: presets.map((p) {
            final title = currentLang == AppLanguage.vi ? p.$2 : p.$1;
            final val = p.$3;
            final icon = p.$4;
            final color = p.$5;
            final isSelected = (_targetValue - val).abs() < 0.5;

            final displayVal = val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(0);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _updateTarget(val);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.18) : AetronColors.panelHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? color : AetronColors.borderSubtle,
                          width: isSelected ? 1.4 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Icon(icon, size: 18, color: color),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$displayVal $unitLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AetronColors.textPrimary : AetronColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAiForecastCard(AppLanguage currentLang, bool useMetricUnits) {
    final isWeekly = _selectedPeriod == GoalPeriod.weekly;

    // Calculations for forecast
    String dailyOrSessionBreakdown;
    String energyEquivalent;
    String badgePotential;

    switch (_selectedType) {
      case GoalType.distance:
        final sessionCount = isWeekly ? 4 : 16;
        final kmPerSession = _targetValue / sessionCount;
        dailyOrSessionBreakdown = currentLang == AppLanguage.vi
            ? 'Khoảng ~$sessionCount buổi (${kmPerSession.toStringAsFixed(1)} km/buổi)'
            : '~$sessionCount sessions (${kmPerSession.toStringAsFixed(1)} km/session)';
        final kcalEst = (_targetValue * 65).round();
        final fatLossKg = (kcalEst / 7700).toStringAsFixed(2);
        energyEquivalent = currentLang == AppLanguage.vi
            ? '~$kcalEst kcal (tương đương ~$fatLossKg kg mỡ)'
            : '~$kcalEst kcal (~$fatLossKg kg fat burn)';
        badgePotential = _targetValue >= 100
            ? (currentLang == AppLanguage.vi ? '🥇 Thám Hiểm 100K' : '🥇 Century 100K')
            : (_targetValue >= 42
                ? (currentLang == AppLanguage.vi ? '🥈 Bán Marathon 21K' : '🥈 Half-Marathon 21K')
                : (currentLang == AppLanguage.vi ? '🥉 Bứt Phá 5K' : '🥉 5K Pioneer'));
        break;

      case GoalType.workouts:
        final daysInterval = isWeekly ? (7 / _targetValue).toStringAsFixed(1) : (30 / _targetValue).toStringAsFixed(1);
        dailyOrSessionBreakdown = currentLang == AppLanguage.vi
            ? 'Mỗi $daysInterval ngày tập 1 buổi'
            : '1 workout every $daysInterval days';
        final kcalEst = (_targetValue * 350).round();
        energyEquivalent = currentLang == AppLanguage.vi
            ? 'Ước tính tiêu hao ~$kcalEst kcal'
            : 'Est. burn ~$kcalEst kcal';
        badgePotential = _targetValue >= (isWeekly ? 7 : 25)
            ? (currentLang == AppLanguage.vi ? '🥇 Vòng Xoáy Kiên Định' : '🥇 14-Day Orbit')
            : (currentLang == AppLanguage.vi ? '🥈 Chiến Binh Tuần Lễ' : '🥈 Weekly Ignite');
        break;

      case GoalType.calories:
        final kcalPerDay = (_targetValue / (isWeekly ? 7 : 30)).round();
        dailyOrSessionBreakdown = currentLang == AppLanguage.vi
            ? 'Cần đốt ~$kcalPerDay kcal/ngày'
            : 'Target ~$kcalPerDay kcal/day';
        final fatLossKg = (_targetValue / 7700).toStringAsFixed(2);
        energyEquivalent = currentLang == AppLanguage.vi
            ? 'Tương đương ~$fatLossKg kg calo chuyển hóa'
            : 'Equiv. ~$fatLossKg kg metabolic fat loss';
        badgePotential = _targetValue >= (isWeekly ? 5000 : 20000)
            ? (currentLang == AppLanguage.vi ? '🥈 Lò Phản Ứng Calo' : '🥈 Calorie Reactor')
            : (currentLang == AppLanguage.vi ? '🥉 Tia Lửa 3 Ngày' : '🥉 3-Day Spark');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.08),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AetronColors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 14, color: AetronColors.cyan),
              ),
              const SizedBox(width: 8),
              Text(
                currentLang == AppLanguage.vi ? 'DỰ BÁO TIẾN ĐỘ MỤC TIÊU' : 'TELEMETRY PERFORMANCE FORECAST',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.cyan,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildForecastRow(
            icon: Icons.calendar_today_rounded,
            label: currentLang == AppLanguage.vi ? 'Phân rã lộ trình:' : 'Session breakdown:',
            value: dailyOrSessionBreakdown,
          ),
          const SizedBox(height: 10),
          _buildForecastRow(
            icon: Icons.local_fire_department_rounded,
            label: currentLang == AppLanguage.vi ? 'Chuyển hóa năng lượng:' : 'Energy metabolic impact:',
            value: energyEquivalent,
          ),
          const SizedBox(height: 10),
          _buildForecastRow(
            icon: Icons.emoji_events_rounded,
            label: currentLang == AppLanguage.vi ? 'Huy hiệu tiềm năng:' : 'Target badge unlock:',
            value: badgePotential,
          ),
        ],
      ),
    );
  }

  Widget _buildForecastRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AetronColors.cyanSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  color: AetronColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AetronColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _unitLabel(GoalType type, {required bool useMetricUnits}) {
    return switch (type) {
      GoalType.distance => WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits),
      GoalType.workouts => 'buổi',
      GoalType.calories => 'kcal',
    };
  }
}

// ─── Radial Target Gauge Custom Painter ─────────────────────────────────────
class _RadialTargetGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RadialTargetGaugePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    const startAngle = 135.0 * (math.pi / 180.0);
    const sweepAngle = 270.0 * (math.pi / 180.0);

    // 1. Background Arc Track
    final bgPaint = Paint()
      ..color = AetronColors.space
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. Active Glow Arc Track
    final activeSweep = sweepAngle * progress.clamp(0.02, 1.0);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      glowPaint,
    );

    // 3. Main Active Gradient Arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        AetronColors.cyanDim,
        AetronColors.cyan,
        AetronColors.mint,
      ],
    );

    final activePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      activeSweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialTargetGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
