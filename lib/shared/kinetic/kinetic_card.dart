import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:flutter/material.dart';

class KineticCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? topAccentColor;
  final double borderRadius;
  final String? semanticLabel;

  const KineticCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.topAccentColor,
    this.borderRadius = 8,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final bg = backgroundColor ?? colors.surface1;
    final border = borderColor ?? colors.borderSubtle;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );

    if (topAccentColor != null) {
      content = Stack(
        children: [
          content,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
              child: Container(color: topAccentColor),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: colors.primary.withValues(alpha: 0.12),
          highlightColor: colors.primary.withValues(alpha: 0.06),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: content,
      );
    }

    return content;
  }
}
