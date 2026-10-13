import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthLanguageToggle extends ConsumerWidget {
  const AuthLanguageToggle({super.key});

  static const _primary = Color(0xFFA8DCE7);
  static const _surface = Color(0xFF11181C);
  static const _outline = Color(0xFF2A3A42);
  static const _muted = Color(0xFF90A2A7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);

    return Semantics(
      container: true,
      label: current == AppLanguage.vi
          ? 'Chọn ngôn ngữ. Hiện tại: Tiếng Việt'
          : 'Choose language. Current: English',
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: 'VI',
              selected: current == AppLanguage.vi,
              onTap: () => _setLanguage(ref, AppLanguage.vi),
            ),
            _LanguageOption(
              label: 'EN',
              selected: current == AppLanguage.en,
              onTap: () => _setLanguage(ref, AppLanguage.en),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setLanguage(WidgetRef ref, AppLanguage language) async {
    if (ref.read(appLanguageProvider) == language) return;
    HapticFeedback.selectionClick();
    await ref.read(appLanguageProvider.notifier).setLanguage(language);
  }
}

/// Lets signed-out users choose the same persisted appearance preference that
/// is available in Settings after sign-in.
class AuthThemeToggle extends ConsumerWidget {
  const AuthThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = context.kinetic;

    return Semantics(
      button: true,
      label: isLight ? 'Switch to dark theme' : 'Switch to light theme',
      child: Material(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => ref
              .read(themeModeProvider.notifier)
              .setThemeMode(isLight ? ThemeMode.dark : ThemeMode.light),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 18,
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'VI' ? 'Tiếng Việt' : 'English',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: KineticTokens.motionTab,
            curve: Curves.easeOutCubic,
            width: 34,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AuthLanguageToggle._primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: selected
                  ? Border.all(
                      color: AuthLanguageToggle._primary.withValues(
                        alpha: 0.55,
                      ),
                    )
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? AuthLanguageToggle._primary
                    : AuthLanguageToggle._muted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
