import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteSetupFlow extends StatefulWidget {
  const AthleteSetupFlow({super.key});

  @override
  State<AthleteSetupFlow> createState() => _AthleteSetupFlowState();
}

class _AthleteSetupFlowState extends State<AthleteSetupFlow> {
  bool? _hasDisplayName;

  @override
  void initState() {
    super.initState();
    final displayName =
        Supabase.instance.client.auth.currentUser?.userMetadata?['display_name']
            as String?;
    _hasDisplayName = displayName != null && displayName.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasDisplayName == null) {
      return const AetronLoadingScaffold(
        label: 'PREPARING SETUP',
        message: 'Loading athlete identity.',
        withGrid: false,
      );
    }
    return _hasDisplayName!
        ? const ProfileSetupScreen()
        : _AthleteNameScreen(
            onComplete: () => setState(() => _hasDisplayName = true),
          );
  }
}

class _AthleteNameScreen extends StatefulWidget {
  const _AthleteNameScreen({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_AthleteNameScreen> createState() => _AthleteNameScreenState();
}

class _AthleteNameScreenState extends State<_AthleteNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'display_name': _nameController.text.trim()}),
      );
      if (mounted) widget.onComplete();
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not save your name. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: AetronBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AetronHeader(
                  title: 'Athlete Setup',
                  eyebrow: 'Identity calibration',
                  compact: true,
                  titleSize: 22,
                ),
                const Spacer(),
                Container(
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AetronColors.cyan.withValues(alpha: 0.12),
                    border: Border.all(color: AetronColors.cyan),
                    boxShadow: [
                      BoxShadow(
                        color: AetronColors.cyan.withValues(alpha: 0.18),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AetronColors.cyan,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'WHAT SHOULD\nWE CALL YOU?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This is how Aetron will greet you during your training.',
                  style: TextStyle(
                    color: AetronColors.muted,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _continue(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.length < 2) return 'Enter at least 2 characters';
                      if (name.length > 24) return 'Use 24 characters or fewer';
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'YOUR NAME',
                      hintStyle: const TextStyle(
                        color: AetronColors.muted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                      prefixIcon: const Icon(
                        Icons.badge_outlined,
                        color: AetronColors.cyan,
                      ),
                      filled: true,
                      fillColor: AetronColors.panel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AetronColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AetronColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AetronColors.cyan,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AetronColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(flex: 2),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AetronColors.cyan,
                      foregroundColor: AetronColors.voidBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AetronColors.voidBlack,
                              strokeWidth: 2.4,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'CONTINUE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
