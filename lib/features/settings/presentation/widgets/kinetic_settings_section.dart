import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSettingsSectionGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const KineticSettingsSectionGroup({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: KineticTypography.unitLabel.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Material(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.borderSubtle,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class KineticSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const KineticSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accentColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final effectiveColor = accentColor ?? colors.primary;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface2,
            border: Border.all(color: effectiveColor.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: effectiveColor, size: 18),
        ),
        title: Text(
          title,
          style: KineticTypography.headlineSmall.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: KineticTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              )
            : null,
        trailing: trailing,
      ),
    );
  }
}
