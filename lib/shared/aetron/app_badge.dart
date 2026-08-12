import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = AetronColors.cyan,
    this.icon,
    this.isFilled = false,
    this.fontSize = 11,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool isFilled;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bg = isFilled ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.12);
    final border = isFilled ? color : color.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AetronRadius.pill),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: AetronTypography.label.copyWith(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
