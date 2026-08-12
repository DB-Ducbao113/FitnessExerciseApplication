import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.accentColor = AetronColors.cyan,
    this.trend,
    this.trendPositive = true,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color accentColor;
  final String? trend;
  final bool trendPositive;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AetronRadius.small),
                ),
                child: Icon(icon, color: accentColor, size: compact ? 16 : 20),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AetronTypography.label.copyWith(
                  color: AetronColors.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (trend != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (trendPositive ? AetronColors.mint : AetronColors.danger)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AetronRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 12,
                      color: trendPositive ? AetronColors.mint : AetronColors.danger,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend!,
                      style: AetronTypography.caption.copyWith(
                        color: trendPositive ? AetronColors.mint : AetronColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 8 : 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: (compact
                      ? AetronTypography.headingLarge
                      : AetronTypography.display)
                  .copyWith(
                color: AetronColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(
                unit!,
                style: AetronTypography.bodySmall.copyWith(
                  color: AetronColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ],
    );

    return AppCard(
      onTap: onTap,
      radius: AetronRadius.medium,
      borderColor: accentColor.withValues(alpha: 0.25),
      backgroundColor: AetronColors.panelHigh.withValues(alpha: 0.65),
      padding: EdgeInsets.all(compact ? AetronSpacing.sm : AetronSpacing.md),
      child: content,
    );
  }
}
