import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_action_dock.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_header.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_hero_distance.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_route_recap.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_splits_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_telemetry_grid.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_share_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

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

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  void _openShareSheet(
    BuildContext context, {
    required double effectiveDistanceKm,
    required bool useMetricUnits,
    required AppLanguage currentLang,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WorkoutShareCardSheet(
        activityType: activityType,
        distanceKm: effectiveDistanceKm,
        durationSeconds: durationSeconds,
        avgSpeedKmh: avgSpeedKmh,
        calories: calories,
        steps: steps,
        useMetricUnits: useMetricUnits,
        currentLang: currentLang,
      ),
    );
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailsScreen(workoutId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigateToHome(context);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top Sticky Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: KineticSummaryHeader(
                  activityType: activityType,
                  trackingMode: trackingMode,
                  currentLang: currentLang,
                  onBackToHome: () => _navigateToHome(context),
                ),
              ),

              // Scrollable Telemetry Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Hero Distance & Celebration Bento
                      KineticSummaryHeroDistance(
                        distanceKm: effectiveDistanceKm,
                        activityType: activityType,
                        useMetricUnits: useMetricUnits,
                        validityFlag: gpsAnalysis.validityFlag,
                        currentLang: currentLang,
                      ),
                      const SizedBox(height: 12),

                      // 2. Telemetry Grid (4 Bento Cards)
                      KineticSummaryTelemetryGrid(
                        activityType: activityType,
                        durationSeconds: durationSeconds,
                        movingTimeSeconds: movingTimeSeconds,
                        avgSpeedKmh: avgSpeedKmh,
                        effectivePaceSecPerKm: gpsAnalysis.effectivePaceSecPerKm,
                        calories: calories,
                        steps: steps,
                        useMetricUnits: useMetricUnits,
                        currentLang: currentLang,
                      ),
                      const SizedBox(height: 12),

                      // 3. Route Map Recap (Outdoor GPS routes)
                      if (effectiveRoutePoints.length >= 2) ...[
                        KineticSummaryRouteRecap(
                          routePoints: effectiveRoutePoints,
                          routeSegments: effectiveRouteSegments,
                          activityType: activityType,
                          currentLang: currentLang,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 4. Lap Splits Breakdown (If available)
                      if (lapSplits.isNotEmpty) ...[
                        KineticSummarySplitsCard(
                          lapSplits: lapSplits,
                          useMetricUnits: useMetricUnits,
                          currentLang: currentLang,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 5. Action Dock (Share, Done, Details)
                      KineticSummaryActionDock(
                        currentLang: currentLang,
                        onShare: () => _openShareSheet(
                          context,
                          effectiveDistanceKm: effectiveDistanceKm,
                          useMetricUnits: useMetricUnits,
                          currentLang: currentLang,
                        ),
                        onDone: () => _navigateToHome(context),
                        onViewDetails: () => _navigateToDetails(context),
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
