import 'dart:async';

import 'package:fitness_exercise_application/app/bootstrap.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/google_oauth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/register_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/widgets/google_auth_button.dart';
import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bgTop = Color(0xFF101827);
const _bgBottom = Color(0xFF070B18);
const _field = Color(0xFF112033);
const _cyan = Color(0xFF13DFF7);
const _cyanSoft = Color(0xFFC3F5FF);
const _muted = Color(0xFF7D8DA6);
const _border = Color(0x4413DFF7);
const _danger = Color(0xFFFF7A8A);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
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
      setState(() {
        _isGoogleLoading = false;
        if (!launched) {
          _errorMessage = 'Could not open Google sign-in. Please try again.';
        }
      });
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
      backgroundColor: _bgBottom,
      body: _AuthBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Form(
                    key: _formKey,
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          const _BrandLogo(size: 86),
                          const SizedBox(height: 22),
                          const Text(
                            'AETRON',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _cyanSoft,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _HudFrame(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FieldLabel(AppTranslations.get('username', currentLang).toUpperCase()),
                                const SizedBox(height: 8),
                                _HudTextField(
                                  controller: _emailController,
                                  hintText: AppTranslations.get('enter_email', currentLang).toUpperCase(),
                                  prefixIcon: Icons.person_outline_rounded,
                                  validator: validateUsername,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: _FieldLabel(AppTranslations.get('password', currentLang).toUpperCase())),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _HudTextField(
                                  controller: _passwordController,
                                  hintText: '********',
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
                                      color: _muted,
                                      size: 20,
                                    ),
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
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  _AuthMessage(_errorMessage!),
                                ],
                                const SizedBox(height: 22),
                                _PrimaryAuthButton(
                                  label: AppTranslations.get('login', currentLang).toUpperCase(),
                                  icon: Icons.login_rounded,
                                  isLoading: _isLoading,
                                  onPressed: _isLoading || _isGoogleLoading
                                      ? null
                                      : _login,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _IconOrb(
                                icon: Icons.alternate_email_rounded,
                                onTap: _isLoading ? null : _loginWithGoogle,
                              ),
                              const SizedBox(width: 16),
                              _IconOrb(
                                icon: Icons.phone_iphone_rounded,
                                onTap: null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GoogleAuthButton(
                            label: AppTranslations.get('sign_in_google', currentLang).toUpperCase(),
                            isLoading: _isGoogleLoading,
                            onPressed: _isLoading ? null : _loginWithGoogle,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '${AppTranslations.get('dont_have_account', currentLang)} ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _cyanSoft,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                                child: Text(
                                  AppTranslations.get('register', currentLang),
                                  style: const TextStyle(
                                    color: _cyan,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _AuthGrid()),
          Positioned(
            left: -48,
            right: -48,
            bottom: -20,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [_cyan.withValues(alpha: 0.18), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AuthGrid extends StatelessWidget {
  const _AuthGrid();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _AuthGridPainter()));
  }
}

class _AuthGridPainter extends CustomPainter {
  const _AuthGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cyan.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 34.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: _cyan.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: _cyan.withValues(alpha: 0.28),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
      ),
    );
  }
}

class _HudFrame extends StatelessWidget {
  const _HudFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HudFramePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 18),
        child: child,
      ),
    );
  }
}

class _HudFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cyan.withValues(alpha: 0.78)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const l = 22.0;
    canvas.drawLine(Offset(0, l), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(l, 0), paint);
    canvas.drawLine(Offset(size.width - l, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, l), paint);
    canvas.drawLine(Offset(0, size.height - l), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(l, size.height), paint);
    canvas.drawLine(
      Offset(size.width - l, size.height),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - l),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _cyanSoft,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.4,
      ),
    );
  }
}

class _HudTextField extends StatelessWidget {
  const _HudTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.validator,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?) validator;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: _muted.withValues(alpha: 0.5),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
        filled: true,
        fillColor: _field.withValues(alpha: 0.9),
        prefixIcon: Icon(prefixIcon, color: _cyanSoft.withValues(alpha: 0.72)),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: _border.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _cyan, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _danger),
        ),
      ),
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _cyan,
        foregroundColor: const Color(0xFF00272D),
        disabledBackgroundColor: _cyan.withValues(alpha: 0.55),
        elevation: 0,
        shadowColor: _cyan.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 19),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00272D)),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, size: 20),
              ],
            ),
    );
  }
}

class _IconOrb extends StatelessWidget {
  const _IconOrb({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _field.withValues(alpha: 0.82),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(color: _cyan.withValues(alpha: 0.12), blurRadius: 18),
          ],
        ),
        child: Icon(icon, color: onTap == null ? _muted : _cyan, size: 20),
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
        color: const Color(0xFF401A24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _danger.withValues(alpha: 0.45)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFFFB3C3), fontSize: 13),
      ),
    );
  }
}
