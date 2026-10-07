import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/terms_of_service_screen.dart';
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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSuccessSent = false;
  String? _registeredEmail;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
      setState(() {
        _errorMessage = isVi
            ? 'Vui lòng đồng ý với Điều khoản & Chính sách bảo mật.'
            : 'Please accept Terms of Service & Privacy Policy.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Supabase.instance.client.auth;

      if (auth.currentSession != null) {
        throw const AuthException(
          'Sign out of the current account before creating a new one.',
        );
      }

      final input = _emailController.text.trim();
      final isUsernameOnly = !input.contains('@');
      final resolvedEmail =
          isUsernameOnly ? internalEmailForUsername(input) : input;

      final response = await auth.signUp(
        email: resolvedEmail,
        password: _passwordController.text,
        data: {
          'password_upgraded_v1': true,
          if (isUsernameOnly) 'username': normalizeUsername(input),
        },
      );

      if (response.user != null && mounted) {
        // If session is already created (auto-confirm turned on in dev/supabase), route to AuthWrapper
        if (response.session != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (_) => false,
          );
        } else {
          // If username was used without @, attempt immediate sign-in for auto-confirm environments
          if (isUsernameOnly) {
            try {
              final signInResp = await auth.signInWithPassword(
                email: resolvedEmail,
                password: _passwordController.text,
              );
              if (signInResp.session != null && mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (_) => false,
                );
                return;
              }
            } catch (_) {
              // Fall through to success confirmation if confirmation required
            }
          }

          // Show confirmation screen
          setState(() {
            _isSuccessSent = true;
            _registeredEmail = isUsernameOnly ? normalizeUsername(input) : input;
            _isLoading = false;
          });
        }
      }
    } on AuthException catch (e) {
      final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
      String msg = e.message;
      final lower = msg.toLowerCase();
      if (lower.contains('user already registered') ||
          lower.contains('already exists') ||
          lower.contains('already registered')) {
        msg = isVi
            ? 'Tên tài khoản hoặc email này đã được sử dụng.'
            : 'This username or email is already registered.';
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
      final errStr = e.toString().toLowerCase();
      String msg;
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('connection failed') ||
          errStr.contains('network')) {
        msg = isVi
            ? 'Lỗi kết nối mạng: Không thể kết nối tới máy chủ. Vui lòng kiểm tra mạng.'
            : 'Network error: Unable to reach the server. Please check your connection.';
      } else {
        msg = isVi
            ? 'Không thể hoàn tất đăng ký. Vui lòng thử lại.'
            : 'Registration could not be completed. Please try again.';
      }
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted && !_isSuccessSent) setState(() => _isLoading = false);
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
          // ── Top App Bar ───────────────────────────────────────────────────
          Container(
            color: _bg.withValues(alpha: 0.97),
            padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
            child: Row(
              children: [
                _AppBarIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      isVi ? 'Đăng ký' : 'Sign Up',
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
                const SizedBox(width: 40),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _outlineVariant),

          // ── Scrollable body ───────────────────────────────────────────────
          Expanded(
            child: _isSuccessSent
                ? _buildSuccessVerification(context, isVi)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                    // ── Hero banner ─────────────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/login_header.png',
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 150,
                              color: _surface,
                              child: const Center(
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  color: _primary,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    _bg.withValues(alpha: 0.1),
                                    _bg.withValues(alpha: 0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVi ? 'Bắt đầu ngay hôm nay' : 'Start today',
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
                                      ? 'Theo dõi hành trình fitness'
                                      : 'Track your fitness journey',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _onSurface,
                                    letterSpacing: -0.015 * 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Email / Username field ───────────────────────────────
                    _SectionLabel(isVi ? 'TÊN ĐĂNG NHẬP HOẶC EMAIL' : 'USERNAME OR EMAIL'),
                    const SizedBox(height: 6),
                    _StitchTextField(
                      controller: _emailController,
                      hintText: isVi
                          ? 'Nhập tên tài khoản (VD: user1) hoặc email'
                          : 'Enter username (e.g. user1) or email',
                      prefixIcon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) {
                          return isVi
                              ? 'Vui lòng nhập tên tài khoản hoặc email'
                              : 'Please enter username or email';
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
                          ? 'Tối thiểu 8 ký tự (hoa, thường, số, ký tự)'
                          : 'Min 8 chars (upper, lower, num, symbol)',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _primary.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ),
                      validator: (value) => validatePasswordStrict(value, currentLang),
                    ),
                    const SizedBox(height: 16),

                    // ── Confirm password field ──────────────────────────────
                    _SectionLabel(isVi ? 'XÁC NHẬN MẬT KHẨU' : 'CONFIRM PASSWORD'),
                    const SizedBox(height: 6),
                    _StitchTextField(
                      controller: _confirmPasswordController,
                      hintText: isVi
                          ? 'Xác nhận lại mật khẩu'
                          : 'Confirm password',
                      prefixIcon: Icons.lock_reset_rounded,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _primary.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return isVi
                              ? 'Mật khẩu không khớp'
                              : 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Terms & Privacy checkbox ────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _acceptedTerms
                              ? _primary.withValues(alpha: 0.4)
                              : _outlineVariant,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _acceptedTerms,
                              activeColor: _primary,
                              checkColor: _onPrimary,
                              side: const BorderSide(
                                  color: _outlineVariant, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5)),
                              onChanged: (val) => setState(
                                  () => _acceptedTerms = val ?? false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  isVi ? 'Tôi đồng ý với ' : 'I agree to the ',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    color: _onSurfaceVariant,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const TermsOfServiceScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    isVi ? 'Điều khoản' : 'Terms',
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _primary,
                                    ),
                                  ),
                                ),
                                Text(
                                  isVi ? ' & ' : ' & ',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    color: _onSurfaceVariant,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PrivacyPolicyScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    isVi ? 'Chính sách bảo mật' : 'Privacy Policy',
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Error message ───────────────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _ErrorMessage(_errorMessage!),
                    ],
                    const SizedBox(height: 20),

                    // ── Primary CTA ─────────────────────────────────────────
                    _PrimaryButton(
                      label: isVi ? 'Tạo Tài Khoản' : 'Create Account',
                      isLoading: _isLoading,
                      onPressed: _register,
                    ),
                    const SizedBox(height: 24),

                    // ── Login link ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isVi ? 'Đã có tài khoản? ' : 'Already have an account? ',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            color: _onSurfaceVariant,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            isVi ? 'Đăng nhập ngay' : 'Sign in',
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

  Widget _buildSuccessVerification(BuildContext context, bool isVi) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Builder(
              builder: (context) {
                final isUsername = !(_registeredEmail?.contains('@') ?? true);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primary.withValues(alpha: 0.15),
                        border: Border.all(color: _primary, width: 2),
                      ),
                      child: Icon(
                        isUsername
                            ? Icons.check_circle_outline_rounded
                            : Icons.mark_email_read_rounded,
                        color: _primary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isUsername
                          ? (isVi ? 'ĐĂNG KÝ THÀNH CÔNG' : 'REGISTRATION SUCCESSFUL')
                          : (isVi ? 'KIỂM TRA HỘP THƯ CỦA BẠN' : 'CHECK YOUR INBOX'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isUsername
                          ? (isVi
                              ? 'Tài khoản của bạn đã được khởi tạo thành công với tên:'
                              : 'Your account has been registered with username:')
                          : (isVi
                              ? 'Chúng tôi đã gửi email xác thực tài khoản tới:'
                              : 'We have sent an account activation link to:'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _surfaceLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _outlineVariant),
                      ),
                      child: Text(
                        _registeredEmail ?? '',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isUsername
                          ? (isVi
                              ? 'Bạn có thể đăng nhập ngay với tên tài khoản này bằng mật khẩu vừa tạo.'
                              : 'You can now sign in with this username using your password.')
                          : (isVi
                              ? 'Vui lòng nhấn vào liên kết trong email để kích hoạt tài khoản của bạn trước khi đăng nhập (kiểm tra cả mục Thư rác/Spam).'
                              : 'Please click the link in your email to activate your account before signing in (check Spam folder as well).'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        color: _onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _PrimaryButton(
                      label: isUsername
                          ? (isVi ? 'Đăng nhập ngay' : 'Sign In Now')
                          : (isVi ? 'Quay lại Đăng nhập' : 'Back to Sign In'),
                      isLoading: false,
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets (same stitch token set) ──────────────────────────────────

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outlineVariant),
        ),
        child: Icon(icon, color: _onSurfaceVariant, size: 20),
      ),
    );
  }
}

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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
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
          const Icon(Icons.error_outline_rounded, color: _error, size: 16),
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
