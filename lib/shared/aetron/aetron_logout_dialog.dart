import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'aetron_ui.dart';
import 'aetron_3d_decorations.dart';

class AetronLogoutDialog extends ConsumerWidget {
  const AetronLogoutDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AetronLogoutDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: AetronColors.borderAccent, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AetronColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // 3D Danger Glow Icon
            AetronRadialGlow(
              glowColor: AetronColors.danger,
              glowRadius: 50,
              alpha: 0.3,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AetronColors.voidBlack,
                  border: Border.all(color: AetronColors.danger.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AetronColors.danger.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AetronColors.danger,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              AppTranslations.get('logout_title', currentLang),
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AetronColors.textPrimary,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              AppTranslations.get('logout_sub', currentLang),
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: AetronColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Row(
              children: [
                // Cancel
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AetronColors.textPrimary,
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: AetronColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      AppTranslations.get('cancel', currentLang).toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Logout CTA
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AetronColors.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 6,
                      shadowColor: AetronColors.danger.withValues(alpha: 0.5),
                    ),
                    child: Text(
                      AppTranslations.get('logout', currentLang).toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
