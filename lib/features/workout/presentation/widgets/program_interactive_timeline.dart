import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/structured_running_program.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';

/// 3D Interactive Timeline Roadmap for Structured Running Programs.
class ProgramInteractiveTimeline extends StatelessWidget {
  final StructuredRunningProgram program;
  final AppLanguage currentLang;

  const ProgramInteractiveTimeline({
    super.key,
    required this.program,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;
    final steps = program.steps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineStepNode(
            step: steps[i],
            index: i + 1,
            totalSteps: steps.length,
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            isVi: isVi,
          ),
      ],
    );
  }
}

class _TimelineStepNode extends StatelessWidget {
  final ProgramStep step;
  final int index;
  final int totalSteps;
  final bool isFirst;
  final bool isLast;
  final bool isVi;

  const _TimelineStepNode({
    required this.step,
    required this.index,
    required this.totalSteps,
    required this.isFirst,
    required this.isLast,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final color = step.phaseColor;
    final title = isVi ? step.titleVi : step.titleEn;
    final tip = isVi ? step.tipVi : step.tipEn;
    final durStr = WorkoutFormatters.formatDurationFromSeconds(step.durationSeconds);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Node Icon + Vertical Glowing Circuit Line
          Column(
            children: [
              // Glowing Node Orb
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(color: color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    step.phaseIcon,
                    color: color,
                    size: 15,
                  ),
                ),
              ),
              // Connecting Line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.6),
                          AetronColors.borderSubtle,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Right Column: Step Info Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1524),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Header: Name & Duration Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          durStr,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Metrics Badges: Pace & HR Zone
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _StepPill(
                        icon: Icons.speed_rounded,
                        label: 'Pace: ${step.targetPaceDisplay}',
                        color: color,
                      ),
                      _StepPill(
                        icon: Icons.favorite_rounded,
                        label: step.targetHrZone,
                        color: AetronColors.cyanSoft,
                      ),
                    ],
                  ),

                  // Coaching Form Tip
                  if (tip.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 13,
                          color: AetronColors.gold.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: AetronColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StepPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
