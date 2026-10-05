import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSettingsTopBar extends StatelessWidget {
  final AppLanguage currentLang;

  const KineticSettingsTopBar({
    super.key,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Row(
      children: [
        // Back Button
        Semantics(
          button: true,
          label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Eyebrow & Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AETRON SYSTEM',
                style: KineticTypography.pageEyebrow.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppTranslations.get('settings', currentLang),
                style: KineticTypography.pageTitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
