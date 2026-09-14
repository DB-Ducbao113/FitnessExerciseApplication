import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_insight.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-Page 3D AI Coach Insight & Telemetry Analytics Screen
class WorkoutAiInsightDetailScreen extends ConsumerWidget {
  final WorkoutAiInsight insight;

  const WorkoutAiInsightDetailScreen({
    super.key,
    required this.insight,
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

  String _formatSignalName(String signalKey, AppLanguage lang) {
    switch (signalKey) {
      case 'pace_fatigue_slope':
        return lang == AppLanguage.vi ? 'Độ dốc suy giảm Pace (Fatigue Slope)' : 'Pace Fatigue Slope';
      case 'pace_consistency_cv':
        return lang == AppLanguage.vi ? 'Hệ số biến thiên nhịp (Consistency CV)' : 'Pace Consistency CV';
      case 'rest_ratio':
        return lang == AppLanguage.vi ? 'Tỷ lệ thời gian nghỉ (Rest Ratio)' : 'Rest Ratio %';
      case 'gps_reliability_score':
        return lang == AppLanguage.vi ? 'Độ tin cậy vị trí GPS' : 'GPS Reliability Score';
      case 'baseline_pace_zscore':
        return lang == AppLanguage.vi ? 'Lệch chuẩn Pace so với 30 ngày (Z-Score)' : '30-Day Pace Z-Score';
      case 'baseline_distance_zscore':
        return lang == AppLanguage.vi ? 'Lệch chuẩn quãng đường so với 30 ngày' : '30-Day Distance Z-Score';
      case 'recent_7d_volume_km':
        return lang == AppLanguage.vi ? 'Tổng khối lượng vận động 7 ngày gần nhất' : 'Recent 7-Day Training Volume';
      case 'goal_alignment':
        return lang == AppLanguage.vi ? 'Mức độ phù hợp với mục tiêu' : 'Goal Alignment Status';
      default:
        return signalKey.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final isLlm = insight.source == 'llm';
    final accentColor = isLlm ? AetronColors.cyan : AetronColors.mint;

    return Scaffold(
      backgroundColor: AetronColors.background,
      body: SafeArea(
        top: false,
        child: AetronBackground(
          child: Column(
            children: [
              // ── 3D Top Navigation Bar ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AetronSpacing.page,
                  AetronSpacing.lg + 8,
                  AetronSpacing.page,
                  AetronSpacing.xs,
                ),
                child: Row(
                  children: [
                    Aetron3DOrbButton(
                      icon: Icons.arrow_back_rounded,
                      size: 44,
                      iconSize: 20,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVi ? 'PHÂN TÍCH TỪ AI COACH' : 'AI COACH ANALYSIS',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLlm ? 'Google Gemini 1.5 Flash • Active' : 'Adaptive Smart Engine • Active',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable Body ───────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AetronSpacing.page,
                    AetronSpacing.sm,
                    AetronSpacing.page,
                    AetronSpacing.xxl,
                  ),
                  children: [
                    // 1. Hero Summary Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AetronColors.panelHigh,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.35),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isLlm ? Icons.auto_awesome_rounded : Icons.psychology_rounded,
                                  color: accentColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVi ? 'TỔNG QUAN HIỆU SUẤT' : 'PERFORMANCE OVERVIEW',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        color: accentColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isVi
                                          ? 'Độ chuẩn xác tín hiệu: 100%'
                                          : 'Signal Match Confidence: 100%',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        color: AetronColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (insight.headline.isNotEmpty) ...[
                            Text(
                              insight.headline,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                color: AetronColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            insight.mainInsight,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.textPrimary.withValues(alpha: 0.9),
                              fontSize: 14.5,
                              height: 1.5,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AetronSpacing.lg),

                    // 2. Strengths Section Card
                    if (insight.strengths.isNotEmpty) ...[
                      _DetailCardSection(
                        title: isVi ? 'ĐIỂM NỔI BẬT ĐẠT ĐƯỢC' : 'KEY STRENGTHS ACHIEVED',
                        icon: Icons.check_circle_rounded,
                        accentColor: AetronColors.mint,
                        items: insight.strengths,
                      ),
                      const SizedBox(height: AetronSpacing.lg),
                    ],

                    // 3. Watchouts / Focus Areas Card
                    if (insight.watchouts.isNotEmpty) ...[
                      _DetailCardSection(
                        title: isVi ? 'LƯU Ý VỀ THỂ LỰC & CẢI THIỆN' : 'PHYSIOLOGICAL FOCUS AREAS',
                        icon: Icons.lightbulb_rounded,
                        accentColor: AetronColors.gold,
                        items: insight.watchouts,
                      ),
                      const SizedBox(height: AetronSpacing.lg),
                    ],

                    // 4. Next Session Blueprint Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1726),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: AetronColors.cyan.withValues(alpha: 0.4),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AetronColors.cyan.withValues(alpha: 0.12),
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AetronColors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.track_changes_rounded,
                                  size: 20,
                                  color: AetronColors.cyan,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVi ? 'KẾ HOẠCH BUỔI TẬP KẾ TIẾP' : 'NEXT SESSION BLUEPRINT',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        color: AetronColors.cyan,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isVi
                                          ? 'Được AI Coach đề xuất dựa trên tải vận động'
                                          : 'Prescribed by AI Coach based on training load',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        color: AetronColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 3 Metric Pills
                          Row(
                            children: [
                              Expanded(
                                child: _MetricPillBox(
                                  label: isVi ? 'HOẠT ĐỘNG' : 'ACTIVITY',
                                  value: _formatActivityLabel(
                                    insight.nextSessionSuggestion.recommendedActivity,
                                    currentLang,
                                  ),
                                  icon: _getActivityIcon(insight.nextSessionSuggestion.recommendedActivity),
                                  accentColor: AetronColors.cyan,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricPillBox(
                                  label: isVi ? 'THỜI LƯỢNG' : 'DURATION',
                                  value: '${insight.nextSessionSuggestion.targetDurationMin} ${isVi ? 'phút' : 'min'}',
                                  icon: Icons.timer_rounded,
                                  accentColor: AetronColors.mint,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricPillBox(
                                  label: isVi ? 'CƯỜNG ĐỘ' : 'INTENSITY',
                                  value: _formatIntensityLabel(
                                    insight.nextSessionSuggestion.targetIntensity,
                                    currentLang,
                                  ),
                                  icon: Icons.bolt_rounded,
                                  accentColor: AetronColors.gold,
                                ),
                              ),
                            ],
                          ),

                          if (insight.nextSessionSuggestion.reason.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AetronColors.space.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AetronColors.borderSubtle,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.format_quote_rounded,
                                    color: AetronColors.cyanSoft,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      insight.nextSessionSuggestion.reason,
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        color: AetronColors.textPrimary,
                                        fontSize: 13,
                                        height: 1.4,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AetronSpacing.lg),

                    // 5. Mathematical Telemetry Signals Card
                    if (insight.usedSignals.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AetronColors.panel,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AetronColors.borderSubtle,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.data_usage_rounded,
                                  size: 16,
                                  color: AetronColors.cyanSoft,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isVi ? 'CƠ SỞ TÍN HIỆU TOÁN HỌC ĐÃ PHÂN TÍCH' : 'TELEMETRY SIGNALS ANALYZED',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    color: AetronColors.cyanSoft,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...insight.usedSignals.map((sig) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AetronColors.cyan,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _formatSignalName(sig, currentLang),
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          color: AetronColors.textSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: AetronSpacing.xl),
                    ],

                    // 6. Done Button
                    AppButton(
                      label: isVi ? 'QUAY LẠI' : 'BACK TO WORKOUT',
                      icon: Icons.check_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable Detail Section Card for Strengths & Watchouts
// ---------------------------------------------------------------------------
class _DetailCardSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<String> items;

  const _DetailCardSection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AetronColors.textPrimary,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric Pill Box inside Blueprint Card
// ---------------------------------------------------------------------------
class _MetricPillBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _MetricPillBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              color: accentColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
