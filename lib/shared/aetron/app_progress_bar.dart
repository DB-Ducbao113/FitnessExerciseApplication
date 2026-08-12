import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.progress,
    this.color = AetronColors.cyan,
    this.trackColor,
    this.height = 6.0,
    this.borderRadius = AetronRadius.pill,
    this.showPercentage = false,
  });

  final double progress; // 0.0 to 1.0
  final Color color;
  final Color? trackColor;
  final double height;
  final double borderRadius;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final effectiveTrack = trackColor ?? AetronColors.panelBright.withValues(alpha: 0.4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPercentage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESS',
                style: AetronTypography.label.copyWith(
                  color: AetronColors.textSecondary,
                ),
              ),
              Text(
                '${(clampedProgress * 100).toInt()}%',
                style: AetronTypography.label.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: effectiveTrack,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clampedProgress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
