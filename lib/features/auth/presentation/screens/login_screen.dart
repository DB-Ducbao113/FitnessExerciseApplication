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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

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
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // If user returns from external browser without completing login, reset spinner
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted &&
            Supabase.instance.client.auth.currentSession == null &&
            _isGoogleLoading) {
          setState(() {
            _isGoogleLoading = false;
          });
        }
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

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // ── 1. Top Section: Cyber Scenic Athlete Header ───────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.42,
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
              ],
            ),
          ),

          // ── 2. Bottom Section: Cyber Dark Glassmorphic Card ───────────────
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0A111E),
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
                          isVi
                              ? 'Đăng Nhập Vào Aetron'
                              : 'Login to Access Your\nWorkout Dashboard',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),

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
                                  : 'Enter your password';
                            }
                            if (value.length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hintText: isVi
                                ? 'Nhập mật khẩu của bạn'
                                : 'Enter your password',
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
                        const SizedBox(height: 12),

                        // Remember Me & Forgot Password Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _rememberMe,
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
                                          _rememberMe = val ?? true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isVi ? 'Ghi nhớ đăng nhập' : 'Remember me',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      initialEmail: _emailController.text
                                              .trim()
                                              .isNotEmpty
                                          ? _emailController.text.trim()
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                isVi ? 'Quên mật khẩu?' : 'Forgot password?',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _AuthMessage(_errorMessage!),
                        ],

                        const SizedBox(height: 20),

                        // Vibrant Cyber Gradient Login Button
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
                            onPressed: _isLoading || _isGoogleLoading
                                ? null
                                : _login,
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
                                    isVi ? 'Đăng Nhập' : 'Login',
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
                        const SizedBox(height: 20),

                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0x2200E5FF))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                isVi ? 'Hoặc tiếp tục với' : 'Or sign in with',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Color(0x2200E5FF))),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Social Auth (Google)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_isGoogleLoading || _isLoading)
                                ? null
                                : _loginWithGoogle,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF101B2B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0x3300E5FF),
                                ),
                              ),
                              child: _isGoogleLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF00E5FF),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/GoogleLogo.jpg',
                                          width: 20,
                                          height: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          isVi
                                              ? 'Tiếp tục với Google'
                                              : 'Continue with Google',
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Create Account Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isVi
                                  ? 'Chưa có tài khoản? '
                                  : 'Don\'t have an account? ',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: Colors.white60,
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
                                isVi ? 'Tạo tài khoản' : 'Create an account',
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
      fillColor: const Color(0xFF101B2B),
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
