import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

bool _hasSteps(String activityType) {
  final t = activityType.toLowerCase();
  return t == 'running' || t == 'walking';
}

class WorkoutSummaryScreen extends ConsumerWidget {
  final String sessionId;
  final String activityType;
  final String trackingMode;
  final int durationSeconds;
  final int movingTimeSeconds;
  final double distanceMeters;
  final double avgSpeedKmh;
  final int calories;
  final int steps;
  final WorkoutGpsAnalysis gpsAnalysis;
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final List<WorkoutLapSplit> lapSplits;

  const WorkoutSummaryScreen({
    super.key,
    required this.sessionId,
    required this.activityType,
    required this.trackingMode,
    required this.durationSeconds,
    required this.movingTimeSeconds,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.calories,
    this.steps = 0,
    this.gpsAnalysis = const WorkoutGpsAnalysis(),
    this.routePoints = const [],
    this.routeSegments = const [],
    this.lapSplits = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    final List<List<LatLng>> effectiveRouteSegments = routeSegments.isNotEmpty
        ? routeSegments
        : (routePoints.isNotEmpty
              ? <List<LatLng>>[routePoints]
              : const <List<LatLng>>[]);
    final List<LatLng> effectiveRoutePoints = effectiveRouteSegments.isNotEmpty
        ? effectiveRouteSegments.expand((s) => s).toList()
        : routePoints;

    final distanceKm = distanceMeters / 1000;
    final effectiveDistanceKm = gpsAnalysis.validDistanceKm > 0
        ? gpsAnalysis.validDistanceKm
        : distanceKm;

    final avgPace = gpsAnalysis.effectivePaceSecPerKm != null
        ? WorkoutFormatters.formatPaceFromSecondsPerKm(
            gpsAnalysis.effectivePaceSecPerKm!,
            useMetric: useMetricUnits,
          )
        : WorkoutFormatters.formatPaceFromSpeedKmh(
            avgSpeedKmh,
            useMetric: useMetricUnits,
          );

    final showSteps = _hasSteps(activityType) && steps > 0;
    final paceUnit = useMetricUnits ? 'min/km' : 'min/mi';

    return Scaffold(
      backgroundColor: AetronColors.background,
      body: AetronBackground(
        child: SafeArea(
          child: Column(
            children: [
              AetronHeader(
                title: AppTranslations.get('workout_summary', currentLang),
                eyebrow: currentLang == AppLanguage.vi ? 'HOÀN THÀNH BUỔI TẬP' : 'WORKOUT COMPLETED',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AetronSpacing.page),
                  child: Column(
                    children: [
                      // Celebration Banner
                      AppCard(
                        padding: const EdgeInsets.all(AetronSpacing.lg),
                        hasGlow: true,
                        glowColor: AetronColors.mint,
                        borderColor: AetronColors.mint.withValues(alpha: 0.45),
                        backgroundColor: AetronColors.panelHigh,
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AetronColors.mint.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(color: AetronColors.mint.withValues(alpha: 0.5)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AetronColors.mint.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.emoji_events_rounded,
                                color: AetronColors.mint,
                                size: 34,
                              ),
                            ),
                            const SizedBox(width: AetronSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentLang == AppLanguage.vi ? 'XUẤT SẮC!' : 'GREAT WORK!',
                                    style: AetronTypography.headingLarge.copyWith(
                                      color: AetronColors.mint,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    currentLang == AppLanguage.vi ? 'Đã lưu buổi tập thành công' : 'Workout saved successfully',
                                    style: AetronTypography.bodySmall.copyWith(
                                      color: AetronColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AetronSpacing.lg),

                      // Route Map Recap
                      if (effectiveRoutePoints.length >= 2) ...[
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AetronRadius.large),
                            child: SizedBox(
                              height: 220,
                              child: WorkoutRoutePreviewMap(
                                routePoints: effectiveRoutePoints,
                                routeSegments: effectiveRouteSegments,
                                activityType: activityType,
                                icon: Icons.directions_run_rounded,
                                accentColor: AetronColors.cyan,
                                glowColor: AetronColors.cyan.withValues(alpha: 0.3),
                                highlightColor: AetronColors.cyanSoft,
                                startColor: AetronColors.mint,
                                endColor: AetronColors.danger,
                                badgeText: activityType.toUpperCase(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AetronSpacing.lg),
                      ],

                      // Key Telemetry Stats
                      SectionHeader(
                        title: currentLang == AppLanguage.vi ? 'TỔNG QUAN DỮ LIỆU' : 'TELEMETRY OVERVIEW',
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: AetronSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: AppTranslations.get('distance', currentLang),
                              value: WorkoutFormatters.formatDistance(
                                effectiveDistanceKm,
                                useMetric: useMetricUnits,
                                decimals: 2,
                              ),
                              icon: Icons.route_rounded,
                              accentColor: AetronColors.cyan,
                            ),
                          ),
                          const SizedBox(width: AetronSpacing.sm),
                          Expanded(
                            child: StatCard(
                              label: AppTranslations.get('duration', currentLang),
                              value: WorkoutFormatters.formatDurationFromSeconds(durationSeconds),
                              icon: Icons.timer_rounded,
                              accentColor: AetronColors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AetronSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: AppTranslations.get('avg_pace', currentLang),
                              value: avgPace,
                              unit: paceUnit,
                              icon: Icons.speed_rounded,
                              accentColor: AetronColors.mint,
                            ),
                          ),
                          const SizedBox(width: AetronSpacing.sm),
                          Expanded(
                            child: StatCard(
                              label: AppTranslations.get('calories', currentLang),
                              value: '$calories',
                              unit: 'kcal',
                              icon: Icons.local_fire_department_rounded,
                              accentColor: AetronColors.gold,
                            ),
                          ),
                        ],
                      ),
                      if (showSteps) ...[
                        const SizedBox(height: AetronSpacing.sm),
                        StatCard(
                          label: currentLang == AppLanguage.vi ? 'Tổng số bước' : 'Total Steps',
                          value: '$steps',
                          unit: currentLang == AppLanguage.vi ? 'bước' : 'steps',
                          icon: Icons.directions_walk_rounded,
                          accentColor: AetronColors.cyanSoft,
                        ),
                      ],
                      const SizedBox(height: AetronSpacing.xl),

                      // Primary Done Action
                      AppButton(
                        label: currentLang == AppLanguage.vi ? 'HOÀN THÀNH' : 'DONE',
                        icon: Icons.check_rounded,
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const MainShell()),
                            (_) => false,
                          );
                        },
                      ),
                      const SizedBox(height: AetronSpacing.sm),
                      AppButton(
                        label: currentLang == AppLanguage.vi ? 'XEM CHI TIẾT' : 'VIEW FULL DETAILS',
                        variant: AppButtonVariant.outlined,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WorkoutDetailsScreen(workoutId: sessionId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
