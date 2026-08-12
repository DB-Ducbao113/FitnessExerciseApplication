import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final UserProfile? existingProfile;

  const ProfileSetupScreen({super.key, this.existingProfile});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _heightFeetController;
  late final TextEditingController _heightInchesController;
  late final TextEditingController _ageController;
  late String _selectedGender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.existingProfile;
    final useMetricUnits =
        ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    final weight = profile?.weightKg;
    final totalInches = (profile?.heightCm ?? 0) / 2.54;
    var feet = totalInches ~/ 12;
    var inches = (totalInches - (feet * 12)).round();
    if (inches == 12) {
      feet += 1;
      inches = 0;
    }
    _weightController = TextEditingController(
      text: weight == null
          ? ''
          : _formatValue(useMetricUnits ? weight : weight * 2.2046226218),
    );
    _heightController = TextEditingController(
      text: profile != null ? profile.heightCm.toString() : '',
    );
    _heightFeetController = TextEditingController(
      text: profile == null ? '' : '$feet',
    );
    _heightInchesController = TextEditingController(
      text: profile == null ? '' : '$inches',
    );
    _ageController = TextEditingController(
      text: profile != null ? profile.age.toString() : '',
    );
    _selectedGender = profile?.gender ?? 'male';
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final profileId = widget.existingProfile?.id ?? const Uuid().v4();
      final createdAt = widget.existingProfile?.createdAt ?? DateTime.now();
      final useMetricUnits =
          ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
      final cleanWeight = _weightController.text.trim().replaceAll(',', '.');
      final cleanHeight = _heightController.text.trim().replaceAll(',', '.');
      final cleanFeet = _heightFeetController.text.trim();
      final cleanInches = _heightInchesController.text.trim().replaceAll(',', '.');
      final cleanAge = _ageController.text.trim();

      final enteredWeight = double.parse(cleanWeight);
      final heightCm = useMetricUnits
          ? double.parse(cleanHeight)
          : (int.parse(cleanFeet) * 12 + double.parse(cleanInches)) * 2.54;
      final weightKg = useMetricUnits
          ? enteredWeight
          : enteredWeight / 2.2046226218;

      final profile = UserProfile(
        id: profileId,
        userId: user.id,
        weightKg: weightKg,
        heightCm: heightCm,
        dateOfBirth: _approximateDateOfBirth(int.parse(cleanAge)),
        legacyAge: int.parse(cleanAge),
        gender: _selectedGender,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        avatarUrl: widget.existingProfile?.avatarUrl,
      );

      final repository = ref.read(userProfileRepositoryProvider);

      if (widget.existingProfile != null) {
        await repository.updateProfile(profile);
      } else {
        await repository.createProfile(profile);
      }

      ref.invalidate(hasUserProfileProvider(user.id));
      ref.invalidate(userProfileProvider(user.id));

      if (mounted) {
        showAetronNotice(
          context,
          message: widget.existingProfile != null
              ? 'Profile updated successfully'
              : 'Profile created successfully',
          tone: AetronNoticeTone.success,
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        showAetronNotice(
          context,
          message:
              'Could not save profile. Check your connection and try again.',
          tone: AetronNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setUseMetricUnits(bool useMetricUnits) async {
    final currentlyMetric =
        ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    if (currentlyMetric == useMetricUnits) return;

    final weight = double.tryParse(_weightController.text);
    if (weight != null) {
      _weightController.text = _formatValue(
        useMetricUnits ? weight / 2.2046226218 : weight * 2.2046226218,
      );
    }

    if (useMetricUnits) {
      final feet = int.tryParse(_heightFeetController.text) ?? 0;
      final inches = double.tryParse(_heightInchesController.text) ?? 0;
      if (feet > 0 || inches > 0) {
        _heightController.text = _formatValue((feet * 12 + inches) * 2.54);
      }
    } else {
      final heightCm = double.tryParse(_heightController.text);
      if (heightCm != null && heightCm > 0) {
        final totalInches = heightCm / 2.54;
        var feet = totalInches ~/ 12;
        var inches = (totalInches - feet * 12).round();
        if (inches == 12) {
          feet += 1;
          inches = 0;
        }
        _heightFeetController.text = '$feet';
        _heightInchesController.text = '$inches';
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kMetricUnitsPrefKey, useMetricUnits);
    ref.invalidate(metricUnitsPreferenceProvider);
  }

  DateTime _approximateDateOfBirth(int age) {
    final now = DateTime.now();
    return DateTime(now.year - age, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isEditing = widget.existingProfile != null;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (isEditing)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: AetronColors.cyanSoft,
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentLang == AppLanguage.vi
                              ? (isEditing ? 'CẬP NHẬT SINH TRẮC' : 'KHỞI TẠO CHỈ SỐ')
                              : (isEditing ? 'BIOMETRIC UPDATE' : 'INITIAL CALIBRATION'),
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
                          isEditing ? AppTranslations.get('edit_profile', currentLang) : AppTranslations.get('profile', currentLang),
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
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppTranslations.get('biometric_data', currentLang).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AetronColors.cyanSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentLang == AppLanguage.vi
                            ? (isEditing ? 'Cập nhật chỉ số sức khỏe của bạn' : 'Thiết lập chỉ số ban đầu cho ứng dụng')
                            : (isEditing ? 'Update your health profile metrics' : 'Set your baseline metrics'),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AetronColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _UnitSelector(
                        useMetricUnits: useMetricUnits,
                        onChanged: _setUseMetricUnits,
                      ),
                      const SizedBox(height: 16),
                      _GlassCard(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AetronColors.cyan.withValues(alpha: 0.15),
                                border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.4), width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: AetronColors.cyan.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: AetronColors.cyan,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _InputField(
                              controller: _weightController,
                              label: AppTranslations.get('weight', currentLang),
                              hint: useMetricUnits ? 'kg' : 'lb',
                              icon: Icons.monitor_weight_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return currentLang == AppLanguage.vi ? 'Vui lòng nhập cân nặng' : 'Please enter your weight';
                                }
                                final weight = double.tryParse(
                                  value.trim().replaceAll(',', '.'),
                                );
                                final minWeight = useMetricUnits ? 30.0 : 66.0;
                                final maxWeight = useMetricUnits
                                    ? 300.0
                                    : 661.0;
                                if (weight == null ||
                                    weight < minWeight ||
                                    weight > maxWeight) {
                                  return useMetricUnits
                                      ? (currentLang == AppLanguage.vi ? 'Cân nặng phải từ 30-300 kg' : 'Weight must be between 30-300 kg')
                                      : (currentLang == AppLanguage.vi ? 'Cân nặng phải từ 66-661 lb' : 'Weight must be between 66-661 lb');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            if (useMetricUnits)
                              _InputField(
                                controller: _heightController,
                                label: AppTranslations.get('height', currentLang),
                                hint: 'cm',
                                icon: Icons.straighten_rounded,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return currentLang == AppLanguage.vi ? 'Vui lòng nhập chiều cao' : 'Please enter your height';
                                  }
                                  final height = double.tryParse(
                                    value.trim().replaceAll(',', '.'),
                                  );
                                  if (height == null ||
                                      height < 100 ||
                                      height > 250) {
                                    return currentLang == AppLanguage.vi ? 'Chiều cao phải từ 100-250 cm' : 'Height must be between 100-250 cm';
                                  }
                                  return null;
                                },
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: _InputField(
                                      controller: _heightFeetController,
                                      label: 'Feet',
                                      hint: 'ft',
                                      icon: Icons.height_rounded,
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        final feet = int.tryParse(value?.trim() ?? '');
                                        if (feet == null ||
                                            feet < 3 ||
                                            feet > 8) {
                                          return '3-8 ft';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InputField(
                                      controller: _heightInchesController,
                                      label: 'Inches',
                                      hint: 'in',
                                      icon: Icons.straighten_rounded,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      validator: (value) {
                                        final inches = double.tryParse(
                                          (value ?? '').trim().replaceAll(',', '.'),
                                        );
                                        if (inches == null ||
                                            inches < 0 ||
                                            inches >= 12) {
                                          return '0-11.9 in';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 14),
                            _InputField(
                              controller: _ageController,
                              label: AppTranslations.get('age', currentLang),
                              hint: AppTranslations.get('years_old', currentLang),
                              icon: Icons.cake_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return currentLang == AppLanguage.vi ? 'Vui lòng nhập tuổi' : 'Please enter your age';
                                }
                                final age = int.tryParse(value);
                                if (age == null || age < 10 || age > 120) {
                                  return currentLang == AppLanguage.vi ? 'Tuổi phải từ 10-120' : 'Age must be between 10-120 years';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppTranslations.get('gender', currentLang),
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  color: AetronColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _GenderOption(
                                    label: AppTranslations.get('male', currentLang),
                                    value: 'male',
                                    groupValue: _selectedGender,
                                    onTap: () => setState(
                                      () => _selectedGender = 'male',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _GenderOption(
                                    label: AppTranslations.get('female', currentLang),
                                    value: 'female',
                                    groupValue: _selectedGender,
                                    onTap: () => setState(
                                      () => _selectedGender = 'female',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Aetron3DPrimaryButton(
                        label: currentLang == AppLanguage.vi
                            ? (isEditing ? 'CẬP NHẬT HỒ SƠ →' : 'LƯU HỒ SƠ →')
                            : (isEditing ? 'UPDATE PROFILE →' : 'SAVE PROFILE →'),
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({required this.useMetricUnits, required this.onChanged});

  final bool useMetricUnits;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'PREFERRED UNITS',
            style: TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.cyanSoft,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AetronColors.panelHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _UnitOption(
                  label: 'METRIC',
                  detail: 'kg / cm',
                  selected: useMetricUnits,
                  onTap: () => onChanged(true),
                ),
              ),
              Expanded(
                child: _UnitOption(
                  label: 'IMPERIAL',
                  detail: 'lb / ft',
                  selected: !useMetricUnits,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnitOption extends StatelessWidget {
  const _UnitOption({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AetronColors.cyan.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AetronColors.cyan : Colors.transparent,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                color: selected ? AetronColors.cyan : AetronColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              detail,
              style: TextStyle(
                fontFamily: 'Outfit',
                color: selected ? AetronColors.textPrimary : AetronColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?) validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Outfit',
        color: AetronColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          fontFamily: 'Outfit',
          color: AetronColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Outfit',
          color: AetronColors.textSecondary,
        ),
        prefixIcon: Icon(icon, color: AetronColors.cyan, size: 20),
        filled: true,
        fillColor: AetronColors.space,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AetronColors.cyan.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AetronColors.cyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AetronColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AetronColors.danger),
        ),
      ),
      validator: validator,
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final color = value == 'male' ? AetronColors.cyan : const Color(0xffff4081);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AetronColors.space,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AetronColors.borderSubtle,
            width: selected ? 1.4 : 1.0,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 8,
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value == 'male' ? Icons.male_rounded : Icons.female_rounded,
              color: selected ? color : AetronColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                color: selected ? AetronColors.textPrimary : AetronColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: child,
    );
  }
}
