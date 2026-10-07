import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticOfflineBanner extends StatelessWidget {
  const KineticOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.tertiary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'OFFLINE MODE — SHOWING SAVED DATA',
              style: KineticTypography.unitLabel.copyWith(
                color: colors.tertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
