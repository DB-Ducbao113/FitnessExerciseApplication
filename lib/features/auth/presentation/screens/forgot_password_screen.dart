import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kResetCallbackUrl = 'io.supabase.flutter://callback';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final lang = ref.read(appLanguageProvider);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: kIsWeb ? null : _kResetCallbackUrl,
      );

      if (!mounted) return;
      setState(() {
        _successMessage = lang == AppLanguage.vi
            ? 'Liên kết khôi phục mật khẩu đã được gửi đến email của bạn. Vui lòng mở email để đặt lại mật khẩu.'
            : 'We sent a secure reset link to your email. Open it to set a new password.';
        _isLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = lang == AppLanguage.vi
            ? 'Không thể gửi email khôi phục. Vui lòng thử lại.'
            : 'Could not send reset email. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    const backgroundTop = Color(0xFF10283D);
    const backgroundBottom = Color(0xFF091521);
    const neonBlue = Color(0xFF00D1FF);
    const actionBlue = Color(0xFF007BFF);
    const mutedText = Color(0xFF8C97AA);
    const labelText = Color(0xFF7E8798);

    return Scaffold(
      backgroundColor: backgroundBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundTop, backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
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
                          style: const TextStyle(fontSize: 16),
                        ),
                        label: Text(
                          currentLang == AppLanguage.vi
                              ? 'Tiếng Việt'
                              : 'English',
                          style: const TextStyle(
                            color: neonBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF123B57), Color(0xFF0C233A)],
                        ),
                        border: Border.all(
                          color: neonBlue.withValues(alpha: 0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: neonBlue.withValues(alpha: 0.28),
                            blurRadius: 28,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: neonBlue,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'AETRON',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: actionBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTranslations.get('forgot_password', currentLang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your account email and we will send you a reset link',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: mutedText,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    AppTranslations.get('email', currentLang).toUpperCase(),
                    style: const TextStyle(
                      color: labelText,
                      fontSize: 20,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ResetTextField(
                    controller: _emailController,
                    hintText: AppTranslations.get('enter_email', currentLang),
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return AppTranslations.get('enter_email', currentLang);
                      }
                      if (!email.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _MessageBox.error(_errorMessage!),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 18),
                    _MessageBox.success(_successMessage!),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF08111B),
                      foregroundColor: neonBlue,
                      disabledBackgroundColor: const Color(0xFF08111B),
                      disabledForegroundColor: neonBlue.withValues(alpha: 0.6),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: actionBlue, width: 2.2),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                neonBlue,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppTranslations.get('reset_password', currentLang).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.2,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Icon(Icons.mark_email_read_outlined, size: 20),
                            ],
                          ),
                  ),
                  const SizedBox(height: 28),
                  _GoogleAccountResetNote(mutedText: mutedText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleAccountResetNote extends StatelessWidget {
  const _GoogleAccountResetNote({required this.mutedText});

  final Color mutedText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF123A57)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Text(
              'G',
              style: TextStyle(
                color: Color(0xFF1A73E8),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Using Google sign-in? You do not need an AETRON password. Sign in with Google, or recover access from your Google Account.',
              style: TextStyle(
                color: mutedText,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.onPasswordUpdated});

  final VoidCallback? onPasswordUpdated;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (!mounted) return;
      setState(() {
        _successMessage = 'Password updated successfully.';
        _isLoading = false;
      });
      widget.onPasswordUpdated?.call();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not update password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF10283D);
    const backgroundBottom = Color(0xFF091521);
    const neonBlue = Color(0xFF00D1FF);
    const actionBlue = Color(0xFF007BFF);
    const mutedText = Color(0xFF8C97AA);
    const labelText = Color(0xFF7E8798);

    return Scaffold(
      backgroundColor: backgroundBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundTop, backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF123B57), Color(0xFF0C233A)],
                        ),
                        border: Border.all(
                          color: neonBlue.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Icon(
                        Icons.password_rounded,
                        color: neonBlue,
                        size: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Set New Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose a new password for your AETRON account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: mutedText,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    'NEW PASSWORD',
                    style: TextStyle(
                      color: labelText,
                      fontSize: 20,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ResetTextField(
                    controller: _passwordController,
                    hintText: 'At least 6 characters',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: mutedText,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'CONFIRM PASSWORD',
                    style: TextStyle(
                      color: labelText,
                      fontSize: 20,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ResetTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Repeat your password',
                    obscureText: true,
                    prefixIcon: Icons.verified_user_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _MessageBox.error(_errorMessage!),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 18),
                    _MessageBox.success(_successMessage!),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF08111B),
                      foregroundColor: neonBlue,
                      disabledBackgroundColor: const Color(0xFF08111B),
                      disabledForegroundColor: neonBlue.withValues(alpha: 0.6),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: actionBlue, width: 2.2),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                neonBlue,
                              ),
                            ),
                          )
                        : const Text(
                            'UPDATE PASSWORD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetTextField extends StatelessWidget {
  const _ResetTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF123A57);
    const fieldColor = Color(0xFF101C2C);
    const hintColor = Color(0xFF7F889B);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: hintColor,
          fontSize: 18,
          fontWeight: FontWeight.w300,
        ),
        filled: true,
        fillColor: fieldColor,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(prefixIcon),
        ),
        prefixIconColor: hintColor,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 24,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF00D1FF), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF6B8A)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF6B8A), width: 1.4),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  factory _MessageBox.error(String message) {
    return _MessageBox(
      message: message,
      backgroundColor: const Color(0xFF401A24),
      borderColor: const Color(0xFFFF6B8A).withValues(alpha: 0.45),
      textColor: const Color(0xFFFFB3C3),
    );
  }

  factory _MessageBox.success(String message) {
    return _MessageBox(
      message: message,
      backgroundColor: const Color(0xFF103125),
      borderColor: const Color(0xFF4DE6B3).withValues(alpha: 0.45),
      textColor: const Color(0xFFA9F5D8),
    );
  }

  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(message, style: TextStyle(color: textColor, fontSize: 15)),
    );
  }
}
