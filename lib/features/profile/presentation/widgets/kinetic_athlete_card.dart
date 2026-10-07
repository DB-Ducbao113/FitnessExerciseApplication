import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/edit_display_name_sheet.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KineticAthleteCard extends ConsumerWidget {
  final User? user;
  final UserProfile? profile;
  final AvatarState avatarState;
  final int currentStreak;
  final VoidCallback onCameraTap;
  final AppLanguage currentLang;

  const KineticAthleteCard({
    super.key,
    required this.user,
    required this.profile,
    required this.avatarState,
    required this.currentStreak,
    required this.onCameraTap,
    required this.currentLang,
  });

  String _getAthleteDisplayName() {
    final userMetadata = user?.userMetadata;
    final metaName = (userMetadata?['display_name'] ??
            userMetadata?['full_name'] ??
            userMetadata?['name'])
        ?.toString()
        .trim();
    if (metaName != null && metaName.isNotEmpty) return metaName;

    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return currentLang == AppLanguage.vi ? 'Thành viên Aetron' : 'Aetron Member';
  }

  String _formatMemberSince() {
    final rawDate = profile?.createdAt ??
        (user?.createdAt != null ? DateTime.tryParse(user!.createdAt) : null);
    if (rawDate == null) return '--';

    final local = rawDate.toLocal();
    return currentLang == AppLanguage.vi
        ? '${local.month.toString().padLeft(2, '0')}/${local.year}'
        : DateFormat('MMM yyyy').format(local);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final avatarDisplay = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? imageProvider = avatarDisplay.imageProvider;
    final displayName = _getAthleteDisplayName();
    final memberSince = _formatMemberSince();

    return KineticCard(
      padding: const EdgeInsets.all(18),
      topAccentColor: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Stack (Left-aligned)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface2,
                      border: Border.all(color: colors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.22),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surface1,
                          image: imageProvider != null
                              ? DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageProvider == null
                            ? Icon(Icons.person_rounded, size: 36, color: colors.textMuted)
                            : null,
                      ),
                    ),
                  ),

                  // Uploading indicator
                  if (avatarState.isUploading)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Camera action button
                  if (!avatarState.isUploading)
                    Positioned(
                      right: -2,
                      bottom: 0,
                      child: Semantics(
                        button: true,
                        label: currentLang == AppLanguage.vi ? 'Đổi ảnh đại diện' : 'Change avatar',
                        child: InkWell(
                          onTap: onCameraTap,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.background, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: colors.onPrimary,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Athlete Info (Right-aligned details)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Display Name & Edit Button
                    InkWell(
                      onTap: () async {
                        final updated = await showEditDisplayNameSheet(context, currentName: displayName);
                        if (updated == true) {
                          ref.invalidate(currentUserProfileProvider);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: KineticTypography.headlineMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.edit_outlined, size: 14, color: colors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Member Since
                    Text(
                      '${AppTranslations.get('member_since', currentLang)}: $memberSince',
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Streak Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.tertiary.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded, size: 14, color: colors.tertiary),
                          const SizedBox(width: 4),
                          Text(
                            '$currentStreak ${currentLang == AppLanguage.vi ? 'NGÀY LIÊN TIẾP' : 'DAY STREAK'}',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.tertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (avatarState.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              avatarState.errorMessage!,
              style: KineticTypography.bodySmall.copyWith(
                color: colors.error,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
