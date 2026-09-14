import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/structured_running_program.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class GuidedProgramHud extends StatelessWidget {
  final StructuredRunningProgram program;
  final int currentStepIndex;
  final int stepRemainingSeconds;
  final int stepElapsedSeconds;
  final double currentPaceMinSecKm;
  final AppLanguage currentLang;
  final VoidCallback onSkipStep;

  const GuidedProgramHud({
    super.key,
    required this.program,
    required this.currentStepIndex,
    required this.stepRemainingSeconds,
    required this.stepElapsedSeconds,
    required this.currentPaceMinSecKm,
    required this.currentLang,
    required this.onSkipStep,
  });

  @override
  Widget build(BuildContext context) {
    if (currentStepIndex >= program.steps.length) {
      return const SizedBox.shrink();
    }

    final step = program.steps[currentStepIndex];
    final totalSteps = program.steps.length;
    final stepProgress = (stepElapsedSeconds / step.durationSeconds).clamp(0.0, 1.0);
    final isVi = currentLang == AppLanguage.vi;
    final stepTitle = isVi ? step.titleVi : step.titleEn;
    final stepTip = isVi ? step.tipVi : step.tipEn;

    // Pace Feedback Evaluation
    final paceFeedback = _evaluatePace(step, currentPaceMinSecKm, isVi);

    final minutes = (stepRemainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (stepRemainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xF00B1320),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: step.phaseColor.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: step.phaseColor.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Phase Tag, Step Index & Skip Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: step.phaseColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: step.phaseColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(step.phaseIcon, size: 14, color: step.phaseColor),
                    const SizedBox(width: 5),
                    Text(
                      '${isVi ? "HIỆP" : "STEP"} ${currentStepIndex + 1}/$totalSteps',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: step.phaseColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stepTitle,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Skip to next step button
              if (currentStepIndex < totalSteps - 1)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSkipStep,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isVi ? 'BỎ QUA' : 'SKIP',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AetronColors.cyanSoft,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.skip_next_rounded,
                            size: 16,
                            color: AetronColors.cyanSoft,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Countdown Timer & Real-time Pace Evaluation
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Countdown
              Text(
                '$minutes:$seconds',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: stepRemainingSeconds <= 5
                      ? const Color(0xFFFF5252)
                      : Colors.white,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 14),

              // Target & Feedback
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isVi ? "Mục tiêu" : "Target"}: ${step.targetPaceDisplay}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AetronColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: paceFeedback.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: paceFeedback.color.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            paceFeedback.label,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: paceFeedback.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Step Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: stepProgress,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(step.phaseColor),
            ),
          ),
          const SizedBox(height: 6),

          // Coaching Tip text
          Text(
            '💡 $stepTip',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  _PaceFeedback _evaluatePace(ProgramStep step, double currentPaceSecKm, bool isVi) {
    if (currentPaceSecKm <= 0 || currentPaceSecKm > 1200) {
      return _PaceFeedback(
        label: isVi ? 'ĐANG BẮT TỐC ĐỘ' : 'ACQUIRING PACE',
        color: AetronColors.cyanSoft,
      );
    }

    final minPace = step.targetPaceMinSecKm;
    final maxPace = step.targetPaceMaxSecKm;

    if (minPace == null || maxPace == null) {
      return _PaceFeedback(
        label: isVi ? 'DUY TRÌ ĐỀU' : 'KEEP STEADY',
        color: const Color(0xFF00E5FF),
      );
    }

    if (currentPaceSecKm < minPace - 30) {
      return _PaceFeedback(
        label: isVi ? '🛑 HÃY CHẬM LẠI' : '🛑 SLOW DOWN',
        color: const Color(0xFFFF5252),
      );
    } else if (currentPaceSecKm > maxPace + 45) {
      return _PaceFeedback(
        label: isVi ? '⚡ TĂNG TỐC LÊN' : '⚡ SPEED UP',
        color: const Color(0xFFFFB85C),
      );
    } else {
      return _PaceFeedback(
        label: isVi ? '✅ PACE ĐẠT CHUẨN' : '✅ ON TARGET PACE',
        color: const Color(0xFF00E676),
      );
    }
  }
}

class _PaceFeedback {
  final String label;
  final Color color;
  const _PaceFeedback({required this.label, required this.color});
}
