import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class AchievementBadgeItem extends StatelessWidget {
  final AchievementBadge badge;
  final AppLanguage currentLang;
  final VoidCallback onTap;

  const AchievementBadgeItem({
    super.key,
    required this.badge,
    required this.currentLang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tier = badge.tier;
    final isUnlocked = badge.isUnlocked;
    final primaryColor = isUnlocked ? tier.primaryColor : AetronColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnlocked
                ? AetronColors.panelHigh
                : AetronColors.panel.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnlocked
                  ? primaryColor.withValues(alpha: 0.45)
                  : AetronColors.borderSubtle,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              if (isUnlocked)
                BoxShadow(
                  color: tier.glowColor,
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Badge Emblem Icon & Tier Label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Emblem Circle
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked
                              ? primaryColor.withValues(alpha: 0.18)
                              : AetronColors.panelBright.withValues(alpha: 0.3),
                          border: Border.all(
                            color: isUnlocked
                                ? primaryColor.withValues(alpha: 0.6)
                                : AetronColors.borderSubtle,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          badge.icon,
                          size: 22,
                          color: isUnlocked
                              ? primaryColor
                              : AetronColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                      if (!isUnlocked)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AetronColors.voidBlack,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AetronColors.borderSubtle,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: AetronColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Tier Tag Chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      tier.label(currentLang),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Middle: Title
              Text(
                badge.title(currentLang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isUnlocked
                      ? AetronColors.textPrimary
                      : AetronColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),

              // Short Description or remaining
              Text(
                isUnlocked
                    ? (currentLang == AppLanguage.vi ? 'ĐÃ ĐẠT ĐƯỢC' : 'UNLOCKED')
                    : badge.remainingText(currentLang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isUnlocked ? AetronColors.mint : AetronColors.muted,
                  letterSpacing: isUnlocked ? 0.6 : 0.0,
                ),
              ),
              const SizedBox(height: 8),

              // Bottom Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: badge.progress,
                  minHeight: 4,
                  backgroundColor: AetronColors.panelBright.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUnlocked ? AetronColors.mint : primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
