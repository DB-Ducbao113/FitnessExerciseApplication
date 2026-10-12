import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:flutter/material.dart';

/// Unified Kinetic Card — the single card component for the app.
///
/// Features:
/// - Consistent border radius from KineticTokens
/// - Optional top accent bar
/// - Optional glow shadow
/// - Built-in semantics for accessibility
/// - Material ink ripple feedback
class KineticCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? topAccentColor;
  final Color? glowColor;
  final bool hasGlow;
  final double borderRadius;
  final String? semanticLabel;

  const KineticCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KineticTokens.spaceMD),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.topAccentColor,
    this.glowColor,
    this.hasGlow = false,
    this.borderRadius = KineticTokens.radiusSM,
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
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: (glowColor ?? colors.primary).withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ]
            : null,
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
