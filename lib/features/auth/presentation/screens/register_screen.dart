import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
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
    _usernameController.dispose();
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

      final response = await auth.signUp(
        email: internalEmailForUsername(_usernameController.text),
        password: _passwordController.text,
        data: {
          'username': normalizeUsername(_usernameController.text),
          'password_upgraded_v1': true,
        },
      );

      if (!mounted) return;
      final requiresEmailConfirmation = response.session == null;
      if (requiresEmailConfirmation) {
        setState(() {
          _errorMessage =
              'Username accounts require Confirm email to be disabled in Supabase Auth.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
      });
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
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
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
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Upper Visual Header (Image 2 & 3 style)
                  Container(
                    width: double.infinity,
                    height: 290,
                    decoration: const BoxDecoration(
                      color: AetronColors.voidBlack,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Radial Cyan Glow behind 3D Hero
                        Positioned(
                          top: 30,
                          child: AetronRadialGlow(
                            glowColor: AetronColors.cyan,
                            glowRadius: 120,
                            alpha: 0.3,
                            child: const SizedBox(),
                          ),
                        ),

                        // Floating 3D Brand Logo Asset
                        Positioned(
                          top: 45,
                          child: Aetron3DFloatingWidget(
                            floatOffset: 10,
                            child: Column(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: AetronColors.space,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AetronColors.cyan.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AetronColors.cyan.withValues(alpha: 0.35),
                                        blurRadius: 28,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'AETRON',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AetronColors.textPrimary,
                                    letterSpacing: 4.0,
                                  ),
                                ),
                                Text(
                                  'CREATE NEW ATHLETE ACCOUNT',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Back Button (Top Left)
                        Positioned(
                          top: 44,
                          left: 16,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: AetronColors.cyanSoft,
                            iconSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Sheet Container
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 270,
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
                            selectedIndex: 1,
                            tabs: [
                              AppTranslations.get('login', currentLang),
                              AppTranslations.get('register', currentLang),
                            ],
                            onTabChanged: (index) {
                              if (index == 0) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          const SizedBox(height: 24),

                          Text(
                            AppTranslations.get('create_account', currentLang).isEmpty
                                ? 'Create Account'
                                : AppTranslations.get('create_account', currentLang),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AetronColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppTranslations.get('register_subtitle', currentLang),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              color: AetronColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Username / Email
                          _FieldLabel(AppTranslations.get('username', currentLang).toUpperCase()),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            validator: validateUsername,
                            decoration: _inputDecoration(
                              hintText: AppTranslations.get('enter_username', currentLang),
                              prefixIcon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          _FieldLabel(AppTranslations.get('password', currentLang).toUpperCase()),
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
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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

                          // Confirm Password
                          _FieldLabel(AppTranslations.get('confirm_password', currentLang).toUpperCase()),
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
                                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AetronColors.cyanSoft,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Terms Checkbox
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _acceptedTerms,
                                  activeColor: AetronColors.cyan,
                                  checkColor: AetronColors.space,
                                  onChanged: (val) {
                                    setState(() {
                                      _acceptedTerms = val ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'I accept ',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        color: AetronColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const TermsOfServiceScreen(),
                                        ),
                                      ),
                                      child: const Text(
                                        'Terms of Service',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          color: AetronColors.cyan,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      ' & ',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        color: AetronColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const PrivacyPolicyScreen(),
                                        ),
                                      ),
                                      child: const Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          color: AetronColors.cyan,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (_errorMessage != null) ...[
                            _AuthMessage(_errorMessage!),
                            const SizedBox(height: 14),
                          ],

                          // Submit Button
                          Aetron3DPrimaryButton(
                            label: AppTranslations.get('create_account', currentLang).toUpperCase(),
                            icon: Icons.person_add_alt_1_rounded,
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _register,
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
