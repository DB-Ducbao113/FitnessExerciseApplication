import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bgTop = Color(0xFF101827);
const _bgBottom = Color(0xFF070B18);
const _panel = Color(0xFF0D1524);
const _field = Color(0xFF112033);
const _cyan = Color(0xFF13DFF7);
const _cyanSoft = Color(0xFFC3F5FF);
const _muted = Color(0xFF7D8DA6);
const _border = Color(0x4413DFF7);
const _danger = Color(0xFFFF7A8A);
const _success = Color(0xFF65F2BF);

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
  String? _errorMessage;
  String? _successMessage;

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
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
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
        data: {'username': normalizeUsername(_usernameController.text)},
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
        _successMessage = 'Registration successful. Preparing your profile.';
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
      backgroundColor: _bgBottom,
      body: _RegisterBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.chevron_left_rounded),
                            color: _cyanSoft,
                            iconSize: 30,
                          ),
                          const Spacer(),
                          const _RegisterLogo(size: 44),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _RegisterPanel(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                AppTranslations.get('register', currentLang).toUpperCase(),
                                style: const TextStyle(
                                  color: _cyanSoft,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.2,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                AppTranslations.get('register', currentLang).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 48,
                                  height: 3,
                                  color: _cyan,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _RegisterLabel(AppTranslations.get('username', currentLang).toUpperCase()),
                              const SizedBox(height: 8),
                              _RegisterTextField(
                                controller: _usernameController,
                                hintText: AppTranslations.get('enter_email', currentLang).toUpperCase(),
                                prefixIcon: Icons.person_outline_rounded,
                                validator: validateUsername,
                              ),
                              const SizedBox(height: 16),
                              _RegisterLabel(AppTranslations.get('password', currentLang).toUpperCase()),
                              const SizedBox(height: 8),
                              _RegisterTextField(
                                controller: _passwordController,
                                hintText: '********',
                                obscureText: true,
                                prefixIcon: Icons.lock_outline_rounded,
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
                              const SizedBox(height: 16),
                              _RegisterLabel(AppTranslations.get('confirm_password', currentLang).toUpperCase()),
                              const SizedBox(height: 8),
                              _RegisterTextField(
                                controller: _confirmPasswordController,
                                hintText: '********',
                                obscureText: true,
                                prefixIcon: Icons.verified_user_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return AppTranslations.get('confirm_password', currentLang);
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              _TermsRow(
                                value: _acceptedTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _acceptedTerms = value ?? false;
                                  });
                                },
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                _RegisterMessage.error(_errorMessage!),
                              ],
                              if (_successMessage != null) ...[
                                const SizedBox(height: 14),
                                _RegisterMessage.success(_successMessage!),
                              ],
                              const SizedBox(height: 22),
                              _RegisterPrimaryButton(
                                isLoading: _isLoading,
                                onPressed: _isLoading ? null : _register,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${AppTranslations.get('already_have_account', currentLang)} ',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Text(
                                      AppTranslations.get('login', currentLang),
                                      style: const TextStyle(
                                        color: _cyanSoft,
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
                    ],
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

class _RegisterBackdrop extends StatelessWidget {
  const _RegisterBackdrop({required this.child});

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
          const Positioned.fill(child: _RegisterGrid()),
          Positioned(
            left: -60,
            right: -60,
            bottom: -60,
            height: 190,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [_cyan.withValues(alpha: 0.13), Colors.transparent],
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

class _RegisterGrid extends StatelessWidget {
  const _RegisterGrid();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _RegisterGridPainter()));
  }
}

class _RegisterGridPainter extends CustomPainter {
  const _RegisterGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cyan.withValues(alpha: 0.05)
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

class _RegisterLogo extends StatelessWidget {
  const _RegisterLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: _cyan.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(color: _cyan.withValues(alpha: 0.22), blurRadius: 20),
        ],
      ),
      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
    );
  }
}

class _RegisterPanel extends StatelessWidget {
  const _RegisterPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: _cyan.withValues(alpha: 0.07), blurRadius: 28),
        ],
      ),
      child: child,
    );
  }
}

class _RegisterLabel extends StatelessWidget {
  const _RegisterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _cyanSoft,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.1,
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
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?) validator;
  final bool obscureText;

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
          color: _muted.withValues(alpha: 0.55),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
        filled: true,
        fillColor: _field.withValues(alpha: 0.9),
        prefixIcon: Icon(prefixIcon, color: _cyanSoft.withValues(alpha: 0.72)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
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

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            side: const BorderSide(color: _cyanSoft),
            checkColor: _bgBottom,
            activeColor: _cyan,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'I agree to the Terms & Privacy Policy',
            style: TextStyle(
              color: _cyanSoft,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RegisterPrimaryButton extends StatelessWidget {
  const _RegisterPrimaryButton({
    required this.onPressed,
    this.isLoading = false,
  });

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
        padding: const EdgeInsets.symmetric(vertical: 18),
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
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SIGN UP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(width: 12),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
    );
  }
}

class _RegisterMessage extends StatelessWidget {
  const _RegisterMessage._(this.message, this.color, this.background);

  const _RegisterMessage.error(String message)
    : this._(message, const Color(0xFFFFB3C3), const Color(0xFF401A24));

  const _RegisterMessage.success(String message)
    : this._(message, _success, const Color(0xFF103125));

  final String message;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(message, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
