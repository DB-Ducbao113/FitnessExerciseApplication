import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticDetailsTopBar extends StatelessWidget {
  final AppLanguage currentLang;
  final VoidCallback onBack;
  final VoidCallback onDelete;

  const KineticDetailsTopBar({
    super.key,
    required this.currentLang,
    required this.onBack,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back Button
          Semantics(
            button: true,
            label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surface1,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Eyebrow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AETRON ARCHIVE',
                  style: KineticTypography.pageEyebrow.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppTranslations.get('workout_details', currentLang),
                  style: KineticTypography.pageTitleCompact.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Delete Button
          Semantics(
            button: true,
            label: currentLang == AppLanguage.vi ? 'Xóa buổi tập' : 'Delete workout',
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
