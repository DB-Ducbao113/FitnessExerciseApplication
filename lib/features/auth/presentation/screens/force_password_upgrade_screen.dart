import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForcePasswordUpgradeScreen extends ConsumerStatefulWidget {
  const ForcePasswordUpgradeScreen({super.key});

  @override
  ConsumerState<ForcePasswordUpgradeScreen> createState() =>
      _ForcePasswordUpgradeScreenState();
}

class _ForcePasswordUpgradeScreenState
    extends ConsumerState<ForcePasswordUpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (_) => false,
    );
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final currentLang = ref.read(appLanguageProvider);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
          data: {'password_upgraded_v1': true},
        ),
      );

      // Sign out so user logs in with new credentials
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentLang == AppLanguage.vi
                ? 'Đã nâng cấp mật khẩu thành công! Vui lòng đăng nhập bằng mật khẩu mới.'
                : 'Password upgraded successfully! Please log in with your new password.',
          ),
          backgroundColor: AetronColors.mint,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = currentLang == AppLanguage.vi
            ? 'Không thể cập nhật mật khẩu. Vui lòng thử lại.'
            : 'Could not update password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row Header with Logout Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AetronColors.danger,
                        size: 18,
                      ),
                      label: Text(
                        currentLang == AppLanguage.vi
                            ? 'ĐĂNG XUẤT'
                            : 'LOG OUT',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AetronColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final next = currentLang == AppLanguage.vi
                            ? AppLanguage.en
                            : AppLanguage.vi;
                        ref
                            .read(appLanguageProvider.notifier)
                            .setLanguage(next);
                      },
                      icon: Text(
                        currentLang == AppLanguage.vi ? '🇻🇳' : '🇬🇧',
                        style: const TextStyle(fontSize: 14),
                      ),
                      label: Text(
                        currentLang == AppLanguage.vi ? 'Tiếng Việt' : 'English',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AetronColors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3D Floating Security Shield Icon
                Center(
                  child: Aetron3DFloatingWidget(
                    floatOffset: 8,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AetronColors.space,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: AetronColors.gold.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AetronColors.gold.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.security_update_warning_rounded,
                        color: AetronColors.gold,
                        size: 46,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Security Title
                Text(
                  AppTranslations.get('mandatory_password_upgrade_title', currentLang).isEmpty
                      ? (currentLang == AppLanguage.vi
                          ? 'YÊU CẦU NÂNG CẤP MẬT KHẨU'
                          : 'MANDATORY PASSWORD UPGRADE')
                      : AppTranslations.get('mandatory_password_upgrade_title', currentLang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.textPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Security Description Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AetronColors.panelHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AetronColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    currentLang == AppLanguage.vi
                        ? 'Mật khẩu hiện tại của bạn chưa đủ mạnh. Để bảo vệ tài khoản theo quy chuẩn mới, bạn phải tạo mật khẩu mới (chữ hoa, chữ thường, số & ký tự đặc biệt) trước khi truy cập ứng dụng.'
                        : 'Your current password does not meet the new security standards. Please create a new strong password (uppercase, lowercase, number & special char) before proceeding.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: AetronColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // New Password Input
                _FieldLabel(currentLang == AppLanguage.vi
                    ? 'MẬT KHẨU MỚI'
                    : 'NEW PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  validator: (val) => validatePasswordStrict(val, currentLang),
                  decoration: _inputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AetronColors.cyanSoft,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                PasswordSecurityMeter(
                  password: _passwordController.text,
                  lang: currentLang,
                ),
                const SizedBox(height: 12),

                // Confirm Password Input
                _FieldLabel(currentLang == AppLanguage.vi
                    ? 'XÁC NHẬN MẬT KHẨU MỚI'
                    : 'CONFIRM NEW PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return AppTranslations.get('password_mismatch', currentLang);
                    }
                    return null;
                  },
                  decoration: _inputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icons.lock_clock_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AetronColors.cyanSoft,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(
                            () => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AetronColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AetronColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: Color(0xFFFFB3C3),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit Button
                Aetron3DPrimaryButton(
                  label: currentLang == AppLanguage.vi
                      ? 'CẬP NHẬT & ĐĂNG NHẬP LẠI →'
                      : 'UPDATE & LOG IN AGAIN →',
                  icon: Icons.shield_rounded,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _updatePassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: 'Outfit',
        color: AetronColors.textSecondary.withValues(alpha: 0.5),
        fontSize: 14,
      ),
      filled: true,
      fillColor: const Color(0xFF0F1524),
      prefixIcon: Icon(prefixIcon, color: AetronColors.cyanSoft, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AetronColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AetronColors.cyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AetronColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AetronColors.error, width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Outfit',
        color: AetronColors.cyanSoft,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }
}
