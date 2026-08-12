import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AetronSpacing.md),
    this.margin,
    this.radius = AetronRadius.large,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.hasGlow = false,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool hasGlow;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? AetronColors.borderAccent;
    final effectiveBg = backgroundColor ?? AetronColors.panel.withValues(alpha: 0.85);

    final cardContent = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: effectiveBorder),
        boxShadow: [
          if (hasGlow)
            BoxShadow(
              color: (glowColor ?? AetronColors.cyan).withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return cardContent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: cardContent,
      ),
    );
  }
}
