import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      setState(() {
        _errorMessage = 'Please accept the Terms & Privacy Policy.';
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
      final resolvedEmail =
          input.contains('@') ? input : internalEmailForUsername(input);

      final response = await auth.signUp(
        email: resolvedEmail,
        password: _passwordController.text,
      );

      if (response.user != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage =
            'Registration could not be completed. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // ── 1. Top Section: Cyber Scenic Header Artwork ───────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/login_header.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF070B14).withValues(alpha: 0.4),
                          Colors.transparent,
                          const Color(0xFF070B14).withValues(alpha: 0.85),
                          const Color(0xFF070B14),
                        ],
                        stops: const [0.0, 0.4, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),

                // Back Button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: Material(
                    color: const Color(0xFF101B2B),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0x3300E5FF),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF00E5FF),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Bottom Section: Cyber Dark Form Card ───────────────────────
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0A111E), // Deep Cyber Obsidian Slate
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3300E5FF),
                    blurRadius: 28,
                    offset: Offset(0, -6),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 36,
                    offset: Offset(0, -10),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF00E5FF),
                    width: 1.5,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title
                        Text(
                          isVi ? 'Tạo Tài Khoản Mới' : 'Create an Account',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isVi
                              ? 'Bắt đầu hành trình theo dõi bài tập của bạn'
                              : 'Start tracking your fitness journey today',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          validator: validateUsername,
                          decoration: _inputDecoration(
                            hintText: isVi
                                ? 'Nhập email hoặc tên tài khoản'
                                : 'Enter your email',
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return isVi
                                  ? 'Vui lòng nhập mật khẩu'
                                  : 'Enter a password';
                            }
                            if (value.length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hintText: isVi
                                ? 'Mật khẩu (tối thiểu 6 ký tự)'
                                : 'Password (min 6 chars)',
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
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Confirm Password Field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return isVi
                                  ? 'Mật khẩu không khớp'
                                  : 'Passwords do not match';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hintText: isVi
                                ? 'Xác nhận lại mật khẩu'
                                : 'Confirm password',
                            prefixIcon: Icons.lock_reset_rounded,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Terms and Privacy Policy Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _acceptedTerms,
                                activeColor: const Color(0xFF00E5FF),
                                checkColor: const Color(0xFF070B14),
                                side: const BorderSide(
                                  color: Color(0x6600E5FF),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _acceptedTerms = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    isVi ? 'Tôi đồng ý với ' : 'I agree to the ',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.white70,
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
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00E5FF),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    isVi ? ' & ' : ' & ',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.white70,
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
                                      isVi
                                          ? 'Chính sách bảo mật'
                                          : 'Privacy Policy',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00E5FF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _AuthMessage(_errorMessage!),
                        ],

                        const SizedBox(height: 20),

                        // Vibrant Cyber Gradient Register Button
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00E5FF),
                                Color(0xFF0072FF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: const Color(0xFF070B14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF070B14),
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : Text(
                                    isVi ? 'Đăng Ký' : 'Create Account',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF070B14),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Back to Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isVi
                                  ? 'Đã có tài khoản? '
                                  : 'Already have an account? ',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: Colors.white60,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Text(
                                isVi ? 'Đăng nhập ngay' : 'Login here',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF00E5FF),
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
            ),
          ),
        ],
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
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 13,
      ),
      filled: true,
      fillColor: const Color(0xFF101B2B), // Deep Cyber Obsidian Slate
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF00E5FF), size: 18),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF00E5FF),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF4B6E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF4B6E), width: 1.5),
      ),
    );
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x22FF4B6E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66FF4B6E)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFF4B6E),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Outfit',
                color: Color(0xFFFFB3C3),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
