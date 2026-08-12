import 'dart:io';

import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Redesigned Home header adhering to Aetron design system.
class AppHeader extends ConsumerWidget {
  const AppHeader({super.key, this.onMenuTap});

  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatar = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? avatarImage = avatar.localPath != null
        ? FileImage(File(avatar.localPath!))
        : avatar.remoteUrl != null && avatar.remoteUrl!.isNotEmpty
        ? NetworkImage(avatar.remoteUrl!)
        : null;
    final displayName = (user?.userMetadata?['display_name'] as String?)?.trim() ??
        (user?.email ?? 'Athlete').split('@').first;
    final initials = _initialsFromEmail(user?.email);

    return AppCard(
      radius: AetronRadius.extraLarge,
      padding: const EdgeInsets.all(AetronSpacing.lg),
      backgroundColor: AetronColors.panel.withValues(alpha: 0.9),
      borderColor: AetronColors.borderAccent,
      hasGlow: true,
      child: Row(
        children: [
          AetronAvatar(
            image: avatarImage,
            label: initials,
            size: 52,
            onTap: onMenuTap,
          ),
          const SizedBox(width: AetronSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'WELCOME BACK',
                  style: AetronTypography.label.copyWith(
                    color: AetronColors.cyanSoft,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AetronTypography.headingLarge.copyWith(
                    color: AetronColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onMenuTap != null)
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.tune_rounded, color: AetronColors.cyanSoft),
            ),
        ],
      ),
    );
  }

  String _initialsFromEmail(String? email) {
    final source = (email ?? 'User').split('@').first.trim();
    if (source.isEmpty) return 'U';
    final parts = source
        .split(RegExp(r'[._\-\s]+'))
        .where((element) => element.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
