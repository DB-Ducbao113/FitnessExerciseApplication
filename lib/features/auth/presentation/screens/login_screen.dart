import 'dart:async';

import 'package:fitness_exercise_application/app/bootstrap.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/google_oauth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/force_password_upgrade_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/register_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/widgets/google_auth_button.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session ?? Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        unawaited(ref.read(appBootstrapServiceProvider).hydrateUser(session.user.id));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (_) => false,
        );
      }
    });
  }

  @override
  void dispose() {
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
      await Supabase.instance.client.auth.signInWithPassword(
        email: internalEmailForUsername(_emailController.text),
        password: _passwordController.text,
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        unawaited(ref.read(appBootstrapServiceProvider).hydrateUser(user.id));
      }

      if (!mounted) return;

      final passwordSec = evaluatePasswordSecurity(_passwordController.text);
      if (!passwordSec.isValid) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ForcePasswordUpgradeScreen()),
          (_) => false,
        );
        return;
      }

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final launched = await startGoogleOAuthSignIn();
      if (!mounted) return;
      if (!launched) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = 'Could not open Google sign-in. Please try again.';
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isGoogleLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not start Google sign-in. Please try again.';
        _isGoogleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: Stack(
        children: [
          // Background Grid & Radial Glow (Top Section)
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Upper Visual Header (Image 2 & 3 inspired)
                  Container(
                    width: double.infinity,
                    height: 310,
                    decoration: const BoxDecoration(
                      color: AetronColors.voidBlack,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Radial Cyan Glow behind 3D Floating Hero Asset
                        Positioned(
                          top: 40,
                          child: AetronRadialGlow(
                            glowColor: AetronColors.cyan,
                            glowRadius: 130,
                            alpha: 0.3,
                            child: const SizedBox(),
                          ),
                        ),

                        // Floating 3D Brand Logo Asset
                        Positioned(
                          top: 55,
                          child: Aetron3DFloatingWidget(
                            floatOffset: 12,
                            child: Column(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AetronColors.space,
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: AetronColors.cyan.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AetronColors.cyan.withValues(alpha: 0.35),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'AETRON',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AetronColors.textPrimary,
                                    letterSpacing: 4.0,
                                  ),
                                ),
                                Text(
                                  'PREMIER ATHLETIC TELEMETRY',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Language Switcher (Top Right)
                        Positioned(
                          top: 48,
                          right: 16,
                          child: TextButton.icon(
                            onPressed: () {
                              final next = currentLang == AppLanguage.vi
                                  ? AppLanguage.en
                                  : AppLanguage.vi;
                              ref
                                  .read(appLanguageProvider.notifier)
                                  .setLanguage(next);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: AetronColors.panelHigh.withValues(alpha: 0.8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(color: AetronColors.borderSubtle),
                              ),
                            ),
                            icon: Text(
                              currentLang == AppLanguage.vi ? '🇻🇳' : '🇬🇧',
                              style: const TextStyle(fontSize: 14),
                            ),
                            label: Text(
                              currentLang == AppLanguage.vi ? 'VI' : 'EN',
                              style: const TextStyle(
                                color: AetronColors.cyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Sheet Container (Curved Card - Image 3 Style)
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 290,
                    ),
                    decoration: const BoxDecoration(
                      color: AetronColors.panelHigh,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                      border: Border(
                        top: BorderSide(color: AetronColors.borderAccent, width: 1.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 28,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Segmented Tab Switcher ("Sign in" / "Sign up")
                          AetronSegmentedControl(
                            selectedIndex: 0,
                            tabs: [
                              AppTranslations.get('login', currentLang),
                              AppTranslations.get('register', currentLang),
                            ],
                            onTabChanged: (index) {
                              if (index == 1) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 24),

                          // Welcome Back Title
                          Text(
                            AppTranslations.get('welcome_back', currentLang),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AetronColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppTranslations.get('signin_subtitle', currentLang).isEmpty
                                ? 'Sign in to pick up where you left off.'
                                : AppTranslations.get('signin_subtitle', currentLang),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              color: AetronColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Email / Username Field
                          _FieldLabel(AppTranslations.get('username', currentLang).toUpperCase()),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            validator: validateUsername,
                            decoration: _inputDecoration(
                              hintText: AppTranslations.get('enter_email', currentLang),
                              prefixIcon: Icons.alternate_email_rounded,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Password Field
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _FieldLabel(AppTranslations.get('password', currentLang).toUpperCase()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppTranslations.get('enter_password', currentLang);
                              }
                              if (value.length < 6) {
                                return 'Minimum 6 characters';
                              }
                              return null;
                            },
                            decoration: _inputDecoration(
                              hintText: '••••••••',
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
                                  color: AetronColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Error message if any
                          if (_errorMessage != null) ...[
                            _AuthMessage(_errorMessage!),
                            const SizedBox(height: 14),
                          ],

                          const SizedBox(height: 14),

                          // Primary CTA Button (Aetron 3D High Contrast Pill Button)
                          Aetron3DPrimaryButton(
                            label: AppTranslations.get('login', currentLang).toUpperCase(),
                            icon: Icons.arrow_forward_rounded,
                            isLoading: _isLoading,
                            onPressed: _isLoading || _isGoogleLoading ? null : _login,
                          ),
                          const SizedBox(height: 24),

                          // Divider
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AetronColors.borderSubtle)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AetronColors.textSecondary.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: AetronColors.borderSubtle)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Google Auth Button
                          GoogleAuthButton(
                            label: AppTranslations.get('sign_in_google', currentLang).toUpperCase(),
                            isLoading: _isGoogleLoading,
                            onPressed: _isLoading ? null : _loginWithGoogle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

class _AuthMessage extends StatelessWidget {
  const _AuthMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AetronColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AetronColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AetronColors.danger, size: 18),
          const SizedBox(width: 10),
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
