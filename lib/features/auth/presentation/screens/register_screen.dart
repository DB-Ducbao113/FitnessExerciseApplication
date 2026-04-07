import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';

const _kRegisterBgTop = Color(0xFF10283D);
const _kRegisterBgBottom = Color(0xFF091521);
const _kRegisterNeonBlue = Color(0xFF00D1FF);
const _kRegisterActionBlue = Color(0xFF007BFF);
const _kRegisterMutedText = Color(0xFF8C97AA);
const _kRegisterLabelText = Color(0xFF7E8798);
const _kRegisterFieldColor = Color(0xFF101C2C);
const _kRegisterBorderColor = Color(0xFF123A57);
const _kRegisterHintColor = Color(0xFF7F889B);

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
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Registration successful! Setting up your profile…';
          _isLoading = false;
        });

        // Navigate to AuthWrapper which detects no profile and routes
        // to ProfileSetupScreen automatically. No artificial delay needed.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kRegisterBgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kRegisterBgTop, _kRegisterBgBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _RegisterGlowOrb(
                alignment: Alignment.topCenter,
                color: _kRegisterNeonBlue,
                size: 220,
                topOffset: -40,
              ),
              const _RegisterCornerAccent(alignment: Alignment.topLeft),
              const _RegisterCornerAccent(alignment: Alignment.topRight),
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                              color: _kRegisterNeonBlue.withValues(alpha: 0.55),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _kRegisterNeonBlue.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 28,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: _kRegisterNeonBlue,
                            size: 44,
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
                          color: _kRegisterActionBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create Account',
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
                        'Start your fitness journey with a profile built for your progress',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: _kRegisterMutedText,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'EMAIL',
                        style: TextStyle(
                          color: _kRegisterLabelText,
                          fontSize: 20,
                          letterSpacing: 2.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RegisterTextField(
                        controller: _emailController,
                        hintText: 'your.email@example.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'PASSWORD',
                        style: TextStyle(
                          color: _kRegisterLabelText,
                          fontSize: 20,
                          letterSpacing: 2.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RegisterTextField(
                        controller: _passwordController,
                        hintText: 'At least 6 characters',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
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
                          color: _kRegisterLabelText,
                          fontSize: 20,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RegisterTextField(
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
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF401A24),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFFFF6B8A,
                              ).withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFFFB3C3),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF103125),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFF4DE6B3,
                              ).withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: Color(0xFFA9F5D8),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _kRegisterNeonBlue.withValues(alpha: 0.18),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF08111B),
                            foregroundColor: _kRegisterNeonBlue,
                            disabledBackgroundColor: const Color(0xFF08111B),
                            disabledForegroundColor: _kRegisterNeonBlue
                                .withValues(alpha: 0.6),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(
                                color: _kRegisterActionBlue,
                                width: 2.2,
                              ),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _kRegisterNeonBlue,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'CREATE ACCOUNT',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2.2,
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 18,
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
        ),
      ),
    );
  }
}

class _RegisterTextField extends StatelessWidget {
  const _RegisterTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: _kRegisterHintColor,
          fontSize: 18,
          fontWeight: FontWeight.w300,
        ),
        filled: true,
        fillColor: _kRegisterFieldColor,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(prefixIcon),
        ),
        prefixIconColor: _kRegisterHintColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 24,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _kRegisterBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _kRegisterNeonBlue, width: 1.4),
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

class _RegisterGlowOrb extends StatelessWidget {
  const _RegisterGlowOrb({
    required this.alignment,
    required this.color,
    required this.size,
    this.topOffset = 0,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(0, topOffset),
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 120,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterCornerAccent extends StatelessWidget {
  const _RegisterCornerAccent({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.topLeft;

    return Align(
      alignment: alignment,
      child: Container(
        width: 92,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isLeft ? 0 : 28),
            topRight: Radius.circular(isLeft ? 28 : 0),
          ),
          border: Border(
            top: const BorderSide(color: _kRegisterNeonBlue, width: 2),
            left: isLeft
                ? const BorderSide(color: _kRegisterNeonBlue, width: 2)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: _kRegisterNeonBlue, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
