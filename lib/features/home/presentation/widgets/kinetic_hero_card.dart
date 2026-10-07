import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticHeroCard extends StatelessWidget {
  final String title;
  final String categoryName;
  final String weeklyProgressText;
  final String targetGoalText;
  final String ctaLabel;
  final String imageAsset;
  final VoidCallback onStartTap;
  final VoidCallback? onGoalTap;

  const KineticHeroCard({
    super.key,
    required this.title,
    required this.categoryName,
    required this.weeklyProgressText,
    required this.targetGoalText,
    required this.ctaLabel,
    this.imageAsset = 'assets/home_hero_runner.jpg',
    required this.onStartTap,
    this.onGoalTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Semantics(
      label: '$title, $weeklyProgressText',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderSubtle, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Photo
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: colors.surface2,
                ),
              ),

              // 2. High-contrast Scrim Gradient
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      colors.background.withValues(alpha: 0.65),
                      colors.background.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.45, 0.9],
                  ),
                ),
              ),

              // 3. Bottom Content Overlay
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: KineticTypography.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.route_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          weeklyProgressText,
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: colors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        if (onGoalTap != null)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onGoalTap,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flag_rounded,
                                      size: 14,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      targetGoalText,
                                      style: KineticTypography.bodySmall.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: colors.primary.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 13,
                                      color: colors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag_rounded,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                targetGoalText,
                                style: KineticTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Primary Action CTA
                    KineticButton(
                      label: ctaLabel,
                      icon: Icons.play_arrow_rounded,
                      variant: KineticButtonVariant.primary,
                      height: 50,
                      onPressed: onStartTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
