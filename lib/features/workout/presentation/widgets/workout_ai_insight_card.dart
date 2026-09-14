import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_insight.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_ai_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_ai_insight_detail_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact 3D Cyberpunk AI Post-Workout Insight Card for Aetron
class WorkoutAiInsightCard extends ConsumerWidget {
  final String workoutId;
  final bool hasMargin;

  const WorkoutAiInsightCard({
    super.key,
    required this.workoutId,
    this.hasMargin = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final insightAsync = ref.watch(workoutAiInsightProvider(workoutId));

    return insightAsync.when(
      data: (insight) {
        if (insight == null) {
          return const SizedBox.shrink();
        }
        return _CompactAiInsightCard(
          insight: insight,
          currentLang: currentLang,
          hasMargin: hasMargin,
        );
      },
      loading: () => _AiInsightLoadingCard(
        currentLang: currentLang,
        hasMargin: hasMargin,
      ),
      error: (error, _) => _AiInsightErrorCard(
        currentLang: currentLang,
        hasMargin: hasMargin,
        onRetry: () => ref.invalidate(workoutAiInsightProvider(workoutId)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact Main AI Insight Display Card
// ---------------------------------------------------------------------------
class _CompactAiInsightCard extends StatelessWidget {
  final WorkoutAiInsight insight;
  final AppLanguage currentLang;
  final bool hasMargin;

  const _CompactAiInsightCard({
    required this.insight,
    required this.currentLang,
    required this.hasMargin,
  });

  IconData _getActivityIcon(String activity) {
    switch (activity.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  String _formatActivityLabel(String activity, AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      switch (activity.toLowerCase()) {
        case 'running':
          return 'CHẠY BỘ';
        case 'walking':
          return 'ĐI BỘ';
        case 'cycling':
          return 'ĐẠP XE';
        case 'rest':
          return 'NGHỈ NGƠI';
        default:
          return activity.toUpperCase();
      }
    }
    return activity.toUpperCase();
  }

  String _formatIntensityLabel(String intensity, AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      switch (intensity.toLowerCase()) {
        case 'recovery':
          return 'PHỤC HỒI';
        case 'aerobic':
          return 'AEROBIC';
        case 'tempo':
          return 'TEMPO';
        case 'interval':
          return 'INTERVAL';
        default:
          return intensity.toUpperCase();
      }
    }
    return intensity.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;
    final isLlm = insight.source == 'llm';
    final accentColor = isLlm ? AetronColors.cyan : AetronColors.mint;

    return Container(
      margin: hasMargin ? const EdgeInsets.symmetric(vertical: AetronSpacing.xs) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.40),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutAiInsightDetailScreen(insight: insight),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Header & Status Badge ────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        isLlm ? Icons.auto_awesome_rounded : Icons.psychology_rounded,
                        color: accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isVi ? 'AI COACH INSIGHT' : 'AI COACH INSIGHT',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AetronRadius.pill),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isLlm ? 'AI ACTIVE' : 'SMART OFFLINE',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: accentColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Headline & Short Insight ──────────────────────────────────
                if (insight.headline.isNotEmpty) ...[
                  Text(
                    insight.headline,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: AetronColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  insight.mainInsight,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textPrimary.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // ── Bottom Row: Next Session Tag + View More CTA ──────────────
                Row(
                  children: [
                    // Next session mini pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1B2B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AetronColors.cyan.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getActivityIcon(insight.nextSessionSuggestion.recommendedActivity),
                            size: 13,
                            color: AetronColors.cyan,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_formatActivityLabel(insight.nextSessionSuggestion.recommendedActivity, currentLang)} • ${insight.nextSessionSuggestion.targetDurationMin} ${isVi ? 'phút' : 'min'} • ${_formatIntensityLabel(insight.nextSessionSuggestion.targetIntensity, currentLang)}',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.cyanSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // View Full Analysis link
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isVi ? 'Chi tiết' : 'Details',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Loading State Widget (Pulsing Scanner Shimmer)
// ---------------------------------------------------------------------------
class _AiInsightLoadingCard extends StatefulWidget {
  final AppLanguage currentLang;
  final bool hasMargin;

  const _AiInsightLoadingCard({
    required this.currentLang,
    required this.hasMargin,
  });

  @override
  State<_AiInsightLoadingCard> createState() => _AiInsightLoadingCardState();
}

class _AiInsightLoadingCardState extends State<_AiInsightLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.currentLang == AppLanguage.vi;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: widget.hasMargin
              ? const EdgeInsets.symmetric(vertical: AetronSpacing.xs)
              : EdgeInsets.zero,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AetronColors.panelHigh,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AetronColors.cyan.withValues(alpha: _pulseAnimation.value * 0.5),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AetronColors.cyan.withValues(alpha: _pulseAnimation.value * 0.15),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AetronColors.cyan.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AetronColors.cyan,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isVi
                        ? 'AI COACH ĐANG PHÂN TÍCH...'
                        : 'AI COACH IS ANALYZING...',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: AetronColors.cyan,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AetronColors.panelBright.withValues(alpha: _pulseAnimation.value),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 12,
                width: 180,
                decoration: BoxDecoration(
                  color: AetronColors.panelBright.withValues(alpha: _pulseAnimation.value * 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// AI Error / Retry State Widget
// ---------------------------------------------------------------------------
class _AiInsightErrorCard extends StatelessWidget {
  final AppLanguage currentLang;
  final bool hasMargin;
  final VoidCallback onRetry;

  const _AiInsightErrorCard({
    required this.currentLang,
    required this.hasMargin,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;

    return Container(
      margin: hasMargin ? const EdgeInsets.symmetric(vertical: AetronSpacing.xs) : EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AetronColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AetronColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVi ? 'Không thể tải AI insight' : 'Unable to load AI insight',
              style: const TextStyle(
                fontFamily: 'Outfit',
                color: AetronColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              isVi ? 'Thử lại' : 'Retry',
              style: const TextStyle(
                fontFamily: 'Outfit',
                color: AetronColors.cyan,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
