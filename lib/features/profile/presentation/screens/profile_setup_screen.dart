import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
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

const _kBgTop = Color(0xff0a0e1a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);
const _kNeonBlue = Color(0xff00bfff);

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
      final enteredWeight = double.parse(_weightController.text);
      final heightCm = useMetricUnits
          ? double.parse(_heightController.text)
          : (int.parse(_heightFeetController.text) * 12 +
                    double.parse(_heightInchesController.text)) *
                2.54;
      final weightKg = useMetricUnits
          ? enteredWeight
          : enteredWeight / 2.2046226218;

      final profile = UserProfile(
        id: profileId,
        userId: user.id,
        weightKg: weightKg,
        heightCm: heightCm,
        dateOfBirth: _approximateDateOfBirth(int.parse(_ageController.text)),
        legacyAge: int.parse(_ageController.text),
        gender: _selectedGender,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        avatarUrl: widget.existingProfile?.avatarUrl,
      );

      final repository = ref.read(userProfileRepositoryProvider);

      if (widget.existingProfile != null) {
        await repository.updateProfile(profile);
        ref.invalidate(userProfileProvider(user.id));

        if (mounted) {
          showAetronNotice(
            context,
            message: 'Profile updated successfully',
            tone: AetronNoticeTone.success,
          );
          Navigator.of(context).pop();
        }
      } else {
        await repository.createProfile(profile);
        ref.invalidate(hasUserProfileProvider(user.id));
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
      backgroundColor: _kBgTop,
      body: AetronBackground(
        child: Column(
          children: [
            AetronHeader(
              title: isEditing ? AppTranslations.get('edit_profile', currentLang) : AppTranslations.get('profile', currentLang),
              eyebrow: isEditing ? 'Biometric update' : 'Initial calibration',
              compact: true,
              titleSize: 22,
              leading: isEditing
                  ? Tooltip(
                      message: 'Back',
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AetronColors.cyanSoft,
                        style: IconButton.styleFrom(
                          backgroundColor: AetronColors.cyan.withValues(
                            alpha: 0.10,
                          ),
                          fixedSize: const Size(44, 44),
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('BIOMETRIC DATA', style: AetronText.label),
                      const SizedBox(height: 8),
                      Text(
                        isEditing
                            ? 'Update your health profile'
                            : 'Set your baseline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _UnitSelector(
                        useMetricUnits: useMetricUnits,
                        onChanged: _setUseMetricUnits,
                      ),
                      const SizedBox(height: 14),
                      _GlassCard(
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  colors: [_kNeonBlue, _kNeonCyan],
                                ),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: _kBgTop,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _InputField(
                              controller: _weightController,
                              label: 'Weight',
                              hint: useMetricUnits ? 'kg' : 'lb',
                              icon: Icons.monitor_weight_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your weight';
                                }
                                final weight = double.tryParse(value);
                                final minWeight = useMetricUnits ? 30.0 : 66.0;
                                final maxWeight = useMetricUnits
                                    ? 300.0
                                    : 661.0;
                                if (weight == null ||
                                    weight < minWeight ||
                                    weight > maxWeight) {
                                  return useMetricUnits
                                      ? 'Weight must be between 30-300 kg'
                                      : 'Weight must be between 66-661 lb';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            if (useMetricUnits)
                              _InputField(
                                controller: _heightController,
                                label: 'Height',
                                hint: 'cm',
                                icon: Icons.height_rounded,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your height';
                                  }
                                  final height = double.tryParse(value);
                                  if (height == null ||
                                      height < 100 ||
                                      height > 250) {
                                    return 'Height must be between 100-250 cm';
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
                                        final feet = int.tryParse(value ?? '');
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
                                          value ?? '',
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
                              label: 'Age',
                              hint: 'years',
                              icon: Icons.cake_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your age';
                                }
                                final age = int.tryParse(value);
                                if (age == null || age < 10 || age > 120) {
                                  return 'Age must be between 10-120 years';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Gender',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _GenderOption(
                                    label: 'Male',
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
                                    label: 'Female',
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
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kNeonBlue, _kNeonCyan],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _kNeonCyan.withValues(alpha: 0.24),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: _kBgTop,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: _kBgTop,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    isEditing
                                        ? 'Update Profile'
                                        : 'Finish Setup',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ),
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
        const Text('PREFERRED UNITS', style: AetronText.label),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xff101a29),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _kNeonCyan.withValues(alpha: 0.14) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _kNeonCyan : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _kMutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                detail,
                style: TextStyle(
                  color: selected ? _kNeonCyan : _kMutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _kMutedText),
        hintStyle: const TextStyle(color: _kMutedText),
        prefixIcon: Icon(icon, color: _kNeonCyan),
        filled: true,
        fillColor: const Color(0xff101a29),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kNeonCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? _kNeonCyan.withValues(alpha: 0.10)
              : const Color(0xff101a29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _kNeonCyan : _kCardBorder),
        ),
        child: Row(
          children: [
            Icon(
              label == 'Male' ? Icons.male_rounded : Icons.female_rounded,
              color: selected ? _kNeonCyan : _kMutedText,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _kMutedText,
                fontWeight: FontWeight.w700,
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
