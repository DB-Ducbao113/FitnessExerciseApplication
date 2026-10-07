import 'dart:async';

import 'package:fitness_exercise_application/app/bootstrap.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/google_oauth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Design tokens (mirrors stitch dark palette) ────────────────────────────
const _bg = Color(0xFF0C1316);
const _surface = Color(0xFF162025);
const _surfaceLow = Color(0xFF11181C);
const _outlineVariant = Color(0xFF23323A);
const _primary = Color(0xFFA8DCE7);
const _onPrimary = Color(0xFF09181C);
const _onSurface = Color(0xFFE2E8EA);
const _onSurfaceVariant = Color(0xFF90A2A7);
const _error = Color(0xFFFF4B6E);

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialErrorMessage;
  const LoginScreen({super.key, this.initialErrorMessage});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;
    WidgetsBinding.instance.addObserver(this);

    try {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session =
            data.session ?? Supabase.instance.client.auth.currentSession;
        if (session != null && mounted) {
          setState(() {
            _isGoogleLoading = false;
            _isLoading = false;
          });
          unawaited(
            ref.read(appBootstrapServiceProvider).hydrateUser(session.user.id),
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
            );
          }
        }
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        try {
          if (Supabase.instance.client.auth.currentSession == null &&
              _isGoogleLoading) {
            setState(() {
              _isGoogleLoading = false;
            });
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authClient = Supabase.instance.client.auth;
      final input = _emailController.text.trim();
      final resolvedEmail =
          input.contains('@') ? input : internalEmailForUsername(input);

      final response = await authClient.signInWithPassword(
        email: resolvedEmail,
        password: _passwordController.text,
      );

      if (response.user != null && mounted) {
        unawaited(
          ref.read(appBootstrapServiceProvider).hydrateUser(response.user!.id),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
          );
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage =
            'Could not sign in right now. Please check your credentials.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    try {
      final success = await startGoogleOAuthSignIn();
      if (!success && mounted) {
        setState(() => _isGoogleLoading = false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isGoogleLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Google Sign-In could not be completed. Please try again.';
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Top App Bar (matches stitch home/activity header) ─────────────
          Container(
            color: _bg.withValues(alpha: 0.97),
            padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
            child: SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  isVi ? 'Đăng nhập' : 'Sign In',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                    letterSpacing: -0.01 * 18,
                  ),
                ),
              ),
            ),
          ),
          // Divider matching stitch border-b border-[#23323a]
          const Divider(height: 1, thickness: 1, color: _outlineVariant),

          // ── Scrollable Body ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero image area (editorial athletic photo) ──────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/login_header.png',
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 180,
                              color: _surface,
                              child: const Center(
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  color: _primary,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                          // Gradient scrim — same as stitch home hero
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    _bg.withValues(alpha: 0.2),
                                    _bg.withValues(alpha: 0.80),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Bottom overlay text
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVi ? 'Hành trình của bạn' : 'Your journey',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _primary,
                                    letterSpacing: 0.05 * 10,
                                  ),
                                ),
                                Text(
                                  isVi
                                      ? 'Sẵn sàng tiếp tục?'
                                      : 'Ready to continue?',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: _onSurface,
                                    letterSpacing: -0.015 * 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Email / Username field ──────────────────────────────
                    _SectionLabel(isVi ? 'EMAIL HOẶC TÀI KHOẢN' : 'EMAIL OR USERNAME'),
                    const SizedBox(height: 6),
                    _StitchTextField(
                      controller: _emailController,
                      hintText: isVi
                          ? 'Nhập email hoặc tên tài khoản'
                          : 'Enter your email or username',
                      prefixIcon: Icons.mail_outline_rounded,
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) {
                          return isVi
                              ? 'Vui lòng nhập email hoặc tên tài khoản'
                              : 'Enter your email or username';
                        }
                        if (trimmed.contains('@')) {
                          if (!trimmed.contains('.') || trimmed.length < 5) {
                            return isVi
                                ? 'Địa chỉ email không hợp lệ'
                                : 'Invalid email address';
                          }
                          return null;
                        }
                        return validateUsername(trimmed, isVi: isVi);
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Password field ──────────────────────────────────────
                    _SectionLabel(isVi ? 'MẬT KHẨU' : 'PASSWORD'),
                    const SizedBox(height: 6),
                    _StitchTextField(
                      controller: _passwordController,
                      hintText: isVi
                          ? 'Nhập mật khẩu của bạn'
                          : 'Enter your password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _primary.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return isVi
                              ? 'Vui lòng nhập mật khẩu'
                              : 'Enter your password';
                        }
                        if (value.length < 6) {
                          return isVi
                              ? 'Tối thiểu 6 ký tự'
                              : 'Minimum 6 characters';
                        }
                        return null;
                      },
                    ),

                    // ── Forgot password ─────────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(
                                initialEmail: _emailController.text.trim().isNotEmpty
                                    ? _emailController.text.trim()
                                    : null,
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isVi ? 'Quên mật khẩu?' : 'Forgot password?',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                      ),
                    ),

                    // ── Error message ───────────────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      _ErrorMessage(_errorMessage!),
                    ],
                    const SizedBox(height: 20),

                    // ── Primary CTA (stitch: bg-[#A8DCE7] text-[#09181c] pill) ─
                    _PrimaryButton(
                      label: isVi ? 'Đăng Nhập' : 'Sign In',
                      isLoading: _isLoading,
                      disabled: _isGoogleLoading,
                      onPressed: _login,
                    ),
                    const SizedBox(height: 20),

                    // ── Divider ─────────────────────────────────────────────
                    Row(
                      children: [
                        const Expanded(child: Divider(color: _outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            isVi ? 'Hoặc tiếp tục với' : 'Or continue with',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: _outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Google button ───────────────────────────────────────
                    _GoogleButton(
                      label: isVi ? 'Tiếp tục với Google' : 'Continue with Google',
                      isLoading: _isGoogleLoading,
                      disabled: _isLoading,
                      onPressed: _loginWithGoogle,
                    ),
                    const SizedBox(height: 28),

                    // ── Sign up link ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isVi
                              ? 'Chưa có tài khoản? '
                              : "Don't have an account? ",
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            color: _onSurfaceVariant,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            isVi ? 'Tạo tài khoản' : 'Create account',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared design components (stitch-aligned)
// ─────────────────────────────────────────────────────────────────────────────


class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _onSurfaceVariant,
        letterSpacing: 0.03 * 10,
      ),
    );
  }
}

class _StitchTextField extends StatelessWidget {
  const _StitchTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _onSurface,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _onSurfaceVariant,
        ),
        filled: true,
        fillColor: _surfaceLow,
        prefixIcon: Icon(prefixIcon, color: _onSurfaceVariant, size: 18),
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
      ),
    );
  }
}

/// Primary action button — bg #A8DCE7, text #09181c, pill, shadow (stitch CTA)
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (isLoading || disabled) ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _onPrimary,
                    strokeWidth: 2.4,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _onPrimary,
                        letterSpacing: 0.01 * 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: _onPrimary,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Google sign-in button — dark surface, border outline-variant
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.label,
    required this.isLoading,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (isLoading || disabled) ? null : onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _outlineVariant),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/GoogleLogo.jpg',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata,
                      color: _primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                color: _error.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
