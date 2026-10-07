import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

enum KineticButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
}

class KineticButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final KineticButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final String? semanticLabel;

  const KineticButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = KineticButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isDisabled = onPressed == null || isLoading;

    final Color bgColor;
    final Color fgColor;
    final BorderSide? border;
    final List<BoxShadow>? shadows;

    switch (variant) {
      case KineticButtonVariant.primary:
        bgColor = isDisabled ? colors.surface3 : colors.primary;
        fgColor = isDisabled ? colors.textMuted : colors.onPrimary;
        border = null;
        shadows = isDisabled
            ? null
            : [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ];
        break;
      case KineticButtonVariant.secondary:
        bgColor = isDisabled ? colors.surface1 : colors.surface2;
        fgColor = isDisabled ? colors.textMuted : colors.textPrimary;
        border = BorderSide(color: colors.borderAccent, width: 1);
        shadows = null;
        break;
      case KineticButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = isDisabled ? colors.textMuted : colors.textSecondary;
        border = null;
        shadows = null;
        break;
      case KineticButtonVariant.danger:
        bgColor = isDisabled ? colors.surface1 : colors.error.withValues(alpha: 0.15);
        fgColor = isDisabled ? colors.textMuted : colors.error;
        border = BorderSide(color: colors.error.withValues(alpha: 0.4), width: 1);
        shadows = null;
        break;
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KineticTypography.label.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 48,
          minWidth: isFullWidth ? double.infinity : 48,
        ),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: border != null ? Border.fromBorderSide(border) : null,
            boxShadow: shadows,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : onPressed,
              borderRadius: BorderRadius.circular(8),
              splashColor: fgColor.withValues(alpha: 0.12),
              highlightColor: fgColor.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
