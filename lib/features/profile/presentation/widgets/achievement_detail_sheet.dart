import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AchievementDetailSheet extends StatelessWidget {
  final AchievementBadge badge;
  final AppLanguage currentLang;

  const AchievementDetailSheet({
    super.key,
    required this.badge,
    required this.currentLang,
  });

  static Future<void> show(
    BuildContext context, {
    required AchievementBadge badge,
    required AppLanguage currentLang,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AchievementDetailSheet(
        badge: badge,
        currentLang: currentLang,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = badge.tier;
    final isUnlocked = badge.isUnlocked;
    final primaryColor = isUnlocked ? tier.primaryColor : AetronColors.muted;
    final glowColor = isUnlocked ? tier.glowColor : Colors.transparent;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AetronColors.space.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isUnlocked
                ? primaryColor.withValues(alpha: 0.6)
                : AetronColors.borderSubtle,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            if (isUnlocked)
              BoxShadow(
                color: glowColor,
                blurRadius: 24,
                spreadRadius: -2,
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AetronColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Large Glowing 3D Emblem Container
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Halo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (isUnlocked)
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                  ),

                  // Emblem Body
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isUnlocked
                            ? [
                                tier.primaryColor.withValues(alpha: 0.35),
                                tier.secondaryColor.withValues(alpha: 0.20),
                                AetronColors.panelHigh,
                              ]
                            : [
                                AetronColors.panelBright.withValues(alpha: 0.3),
                                AetronColors.panelHigh,
                              ],
                      ),
                      border: Border.all(
                        color: isUnlocked
                            ? tier.primaryColor
                            : AetronColors.borderSubtle,
                        width: 2.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        badge.icon,
                        size: 44,
                        color: isUnlocked
                            ? tier.primaryColor
                            : AetronColors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),

                  // Locked Badge Icon Overlay
                  if (!isUnlocked)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AetronColors.voidBlack,
                          shape: BoxShape.circle,
                          border: Border.all(color: AetronColors.borderSubtle),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: AetronColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Tier & Category Chips Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tier.tierIcon, size: 13, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          tier.label(currentLang),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AetronColors.panelHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AetronColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          badge.category.icon,
                          size: 13,
                          color: AetronColors.cyanSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          badge.category.label(currentLang).toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AetronColors.cyanSoft,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Badge Title
              Text(
                badge.title(currentLang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                badge.description(currentLang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AetronColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Inspiration Quote Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AetronColors.panelHigh.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked
                        ? tier.primaryColor.withValues(alpha: 0.25)
                        : AetronColors.borderSubtle,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 20,
                      color: isUnlocked
                          ? tier.primaryColor
                          : AetronColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        badge.quote(currentLang),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: isUnlocked
                              ? AetronColors.textPrimary
                              : AetronColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Progress Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AetronColors.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AetronColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isUnlocked
                              ? (currentLang == AppLanguage.vi
                                  ? 'TRẠNG THÁI'
                                  : 'STATUS')
                              : (currentLang == AppLanguage.vi
                                  ? 'TIẾN ĐỘ THỰC HIỆN'
                                  : 'PROGRESS'),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isUnlocked
                                ? AetronColors.mint
                                : AetronColors.cyanSoft,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          isUnlocked
                              ? (currentLang == AppLanguage.vi
                                  ? '100% HOÀN THÀNH'
                                  : '100% CONQUERED')
                              : '${badge.progressPercent}%',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isUnlocked
                                ? AetronColors.mint
                                : tier.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: badge.progress,
                        minHeight: 8,
                        backgroundColor: AetronColors.panelHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isUnlocked ? AetronColors.mint : tier.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          badge.formattedProgress(currentLang),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AetronColors.textPrimary,
                          ),
                        ),
                        Text(
                          badge.remainingText(currentLang),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isUnlocked
                                ? AetronColors.mint
                                : AetronColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Button
              AppButton(
                label: currentLang == AppLanguage.vi ? 'ĐÓNG' : 'CLOSE',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
