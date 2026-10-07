import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? badgeText;
  final Color? iconColor;
  final VoidCallback onTap;
  final bool isDestructive;

  const KineticProfileActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.badgeText,
    this.iconColor,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final effectiveColor = isDestructive
        ? colors.error
        : (iconColor ?? colors.primary);

    return KineticCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, size: 18, color: effectiveColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: KineticTypography.label.copyWith(
                    color: isDestructive ? colors.error : colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: KineticTypography.bodySmall.copyWith(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badgeText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                badgeText!,
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}
