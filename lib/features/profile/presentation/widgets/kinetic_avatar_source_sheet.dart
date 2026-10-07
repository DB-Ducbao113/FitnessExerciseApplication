import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class KineticAvatarSourceSheet extends ConsumerWidget {
  final bool hasAvatar;
  final AppLanguage currentLang;

  const KineticAvatarSourceSheet({
    super.key,
    required this.hasAvatar,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: colors.borderSubtle),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              currentLang == AppLanguage.vi
                  ? 'ẢNH ĐẠI DIỆN'
                  : 'PROFILE AVATAR',
              style: KineticTypography.unitLabel.copyWith(
                color: colors.primary,
                letterSpacing: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Pick from Gallery
            _SheetActionTile(
              icon: Icons.photo_library_outlined,
              label: AppTranslations.get('choose_from_gallery', currentLang),
              color: colors.textPrimary,
              onTap: () {
                Navigator.pop(context);
                ref.read(avatarUploadProvider.notifier).pickAndUpload(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),

            // Take a Photo
            _SheetActionTile(
              icon: Icons.camera_alt_outlined,
              label: AppTranslations.get('take_a_photo', currentLang),
              color: colors.textPrimary,
              onTap: () {
                Navigator.pop(context);
                ref.read(avatarUploadProvider.notifier).pickAndUpload(ImageSource.camera);
              },
            ),

            // Remove photo if hasAvatar
            if (hasAvatar) ...[
              const SizedBox(height: 8),
              _SheetActionTile(
                icon: Icons.delete_outline_rounded,
                label: AppTranslations.get('remove_current_photo', currentLang),
                color: colors.error,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(avatarUploadProvider.notifier).removeAvatar();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: KineticTypography.label.copyWith(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
