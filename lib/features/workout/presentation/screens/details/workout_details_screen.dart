import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

const _kNeonCyan = Color(0xff00e5ff);
const _kValidGreen = Color(0xFF6BE39B);
const _kDangerRed = Color(0xFFFF7A8A);

// Whether this activity type tracks steps.
bool _hasSteps(String activityType) {
  final t = activityType.toLowerCase();
  return t == 'running' || t == 'walking';
}

class WorkoutDetailsScreen extends ConsumerWidget {
  final String workoutId;

  const WorkoutDetailsScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final workoutAsync = ref.watch(workoutProvider(workoutId));
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

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
                      child: Text(
                        AppTranslations.get('workout_details', currentLang),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AetronColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Aetron3DOrbButton(
                      icon: Icons.delete_outline_rounded,
                      size: 44,
                      iconSize: 20,
                      color: AetronColors.danger,
                      backgroundColor: AetronColors.danger.withValues(alpha: 0.12),
                      onTap: () => _showDeleteConfirmation(context, ref, workoutId),
                    ),
                  ],
                ),
              ),

              // ── Scrollable 3D Body ───────────────────────────────────────
              Expanded(
                child: workoutAsync.when(
                  data: (workout) {
                    if (workout == null) {
                      return Center(
                        child: Text(
                          currentLang == AppLanguage.vi
                              ? 'Không tìm thấy buổi tập'
                              : 'Workout not found',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AetronSpacing.page,
                        AetronSpacing.sm,
                        AetronSpacing.page,
                        AetronSpacing.xxl,
                      ),
                      children: [
                        _WorkoutHeroSection(
                          workoutId: workout.id,
                          workout: workout,
                          useMetricUnits: useMetricUnits,
                          dateLabel: _formatWorkoutDetailsDate(
                            workout.startedAt,
                            currentLang,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: LoadingState(label: 'LOADING WORKOUT DATA'),
                  ),
                  error: (error, _) => Center(
                    child: Text(
                      'Error: $error',
                      style: const TextStyle(color: AetronColors.danger),
                    ),
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

class _WorkoutHeroSection extends ConsumerWidget {
  final String workoutId;
  final WorkoutSession workout;
  final bool useMetricUnits;
  final String dateLabel;

  const _WorkoutHeroSection({
    required this.workoutId,
    required this.workout,
    required this.useMetricUnits,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final routeAsync = ref.watch(workoutRoutePresentationProvider(workoutId));
    final displayDistanceKm = workout.distanceKm;
    final effectiveDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : displayDistanceKm;

    final avgPace = WorkoutFormatters.formatPaceFromDistanceAndDuration(
      distanceKm: displayDistanceKm,
      durationSec: workout.durationSec,
      useMetric: useMetricUnits,
    );
    final movingPace =
        WorkoutFormatters.formatMovingPaceFromDistanceAndDuration(
          distanceKm: effectiveDistanceKm,
          durationSec: workout.movingTimeSec,
          restDurationSec: 0,
          useMetric: useMetricUnits,
        );

    final showSteps = _hasSteps(workout.activityType) && workout.steps > 0;

    return Container(
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AetronColors.cyan.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.16),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── 3D Route Map Container ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AetronColors.cyan.withValues(alpha: 0.30),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AetronColors.cyan.withValues(alpha: 0.18),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: routeAsync.when(
                    data: (routePresentation) =>
                        routePresentation.routePoints.length >= 2
                        ? _DetailsRouteMapHero(
                            routePoints: routePresentation.routePoints,
                            activityType: workout.activityType,
                          )
                        : _DetailsRouteUnavailableState(
                            activityType: workout.activityType,
                            durationSec: workout.durationSec,
                            distanceKm: displayDistanceKm,
                            useMetricUnits: useMetricUnits,
                          ),
                    loading: () => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF122437), Color(0xFF0B1522)],
                        ),
                      ),
                      child: Center(
                        child: LoadingState(label: 'LOADING ROUTE'),
                      ),
                    ),
                    error: (_, _) => _DetailsRouteUnavailableState(
                      activityType: workout.activityType,
                      durationSec: workout.durationSec,
                      distanceKm: displayDistanceKm,
                      useMetricUnits: useMetricUnits,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 3D Activity Icon & Header ──────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AetronColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AetronColors.cyan.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AetronColors.cyan.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _activityIcon(workout.activityType),
                        color: AetronColors.cyan,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WorkoutFormatters.formatActivityType(
                              workout.activityType,
                              currentLang,
                            ).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.cyanSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 3D Distance Hero Display ────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      (useMetricUnits
                              ? displayDistanceKm
                              : WorkoutFormatters.kmToMi(displayDistanceKm))
                          .toStringAsFixed(2),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: AetronColors.textPrimary,
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.0,
                        height: 0.95,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AetronColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AetronRadius.pill),
                        border: Border.all(
                          color: AetronColors.cyan.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        WorkoutFormatters.distanceUnitLabel(
                          useMetric: useMetricUnits,
                        ).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AetronColors.cyan,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  currentLang == AppLanguage.vi
                      ? 'quãng đường ghi nhận'
                      : 'recorded distance',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textSecondary.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Primary 3D Telemetry Cards Grid (2x2) ───────────────────
                Row(
                  children: [
                    Expanded(
                      child: _DetailsPrimary3DCard(
                        id: 'details_stat_duration',
                        icon: Icons.timer_rounded,
                        label: AppTranslations.get('duration', currentLang),
                        value: WorkoutFormatters.formatDurationFromSeconds(
                          workout.durationSec,
                        ),
                        accent: AetronColors.mint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailsPrimary3DCard(
                        id: 'details_stat_avg_pace',
                        icon: Icons.speed_rounded,
                        label: currentLang == AppLanguage.vi ? 'Pace TB' : 'Avg Pace',
                        value: avgPace,
                        accent: AetronColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DetailsPrimary3DCard(
                        id: 'details_stat_calories',
                        icon: Icons.local_fire_department_rounded,
                        label: AppTranslations.get('calories', currentLang),
                        value: '${workout.caloriesKcal.round()} kcal',
                        accent: const Color(0xFFFF7A8A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (showSteps)
                      Expanded(
                        child: _DetailsPrimary3DCard(
                          id: 'details_stat_steps',
                          icon: Icons.transfer_within_a_station_rounded,
                          label: currentLang == AppLanguage.vi ? 'Số bước' : 'Steps',
                          value: _formatSteps(workout.steps),
                          accent: AetronColors.cyan,
                        ),
                      )
                    else
                      Expanded(
                        child: _DetailsPrimary3DCard(
                          id: 'details_stat_moving_pace',
                          icon: Icons.directions_run_rounded,
                          label: currentLang == AppLanguage.vi ? 'Pace di chuyển' : 'Moving Pace',
                          value: movingPace,
                          accent: AetronColors.cyan,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── 3D Secondary Telemetry Panel & Lap Splits ────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AetronColors.space,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AetronColors.borderSubtle,
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (showSteps) ...[
                        _DetailsSecondaryRow(
                          label: currentLang == AppLanguage.vi ? 'Pace di chuyển' : 'Moving Pace',
                          value: movingPace,
                          icon: Icons.directions_run_rounded,
                        ),
                        _detailsDivider(),
                      ],
                      _DetailsSecondaryRow(
                        label: currentLang == AppLanguage.vi ? 'Thời gian di chuyển' : 'Moving Time',
                        value: WorkoutFormatters.formatElapsedClock(
                          workout.movingTimeSec,
                        ),
                        icon: Icons.play_circle_outline_rounded,
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: currentLang == AppLanguage.vi ? 'Thời gian nghỉ' : 'Rest Time',
                        value: WorkoutFormatters.formatElapsedClock(
                          workout.gpsAnalysis.restDurationSec,
                        ),
                        icon: Icons.pause_circle_outline_rounded,
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: currentLang == AppLanguage.vi ? 'Hoạt động' : 'Activity',
                        value: WorkoutFormatters.formatActivityType(
                          workout.activityType,
                          currentLang,
                        ),
                        icon: _activityIcon(workout.activityType),
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: currentLang == AppLanguage.vi ? 'Bắt đầu' : 'Started',
                        value: DateFormat('HH:mm:ss').format(workout.startedAt.toLocal()),
                        icon: Icons.login_rounded,
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: currentLang == AppLanguage.vi ? 'Kết thúc' : 'Finished',
                        value: DateFormat('HH:mm:ss').format(workout.endedAt.toLocal()),
                        icon: Icons.logout_rounded,
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: currentLang == AppLanguage.vi ? 'Đã lưu' : 'Saved',
                        value: DateFormat('dd/MM/yyyy HH:mm').format(workout.createdAt.toLocal()),
                        icon: Icons.save_rounded,
                      ),

                      // ── 3D Lap Splits Section ──────────────────────────────
                      if (workout.lapSplits.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            color: AetronColors.borderSubtle,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            currentLang == AppLanguage.vi ? 'VÒNG LẶP (LAPS)' : 'LAP SPLITS',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AetronColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final split in workout.lapSplits) ...[
                          _LapSplitRow(
                            split: split,
                            useMetricUnits: useMetricUnits,
                          ),
                          if (split != workout.lapSplits.last)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                height: 1,
                                color: AetronColors.borderSubtle,
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primary 3D Stat Card
// ---------------------------------------------------------------------------

class _DetailsPrimary3DCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _DetailsPrimary3DCard({
    required this.id,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(id),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secondary metric row
// ---------------------------------------------------------------------------

Widget _detailsDivider() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        color: AetronColors.borderSubtle,
      ),
    );

class _DetailsSecondaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailsSecondaryRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          child: Icon(icon, size: 16, color: AetronColors.cyanSoft),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Outfit',
            color: AetronColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatSteps(int steps) {
  if (steps >= 1000) {
    return '${(steps / 1000).toStringAsFixed(1)}k';
  }
  return '$steps';
}

// ---------------------------------------------------------------------------
// Route map / 3D unavailable state
// ---------------------------------------------------------------------------

class _DetailsRouteMapHero extends StatelessWidget {
  const _DetailsRouteMapHero({
    required this.routePoints,
    required this.activityType,
  });

  final List<LatLng> routePoints;
  final String activityType;

  @override
  Widget build(BuildContext context) {
    return WorkoutRoutePreviewMap(
      routePoints: routePoints,
      activityType: activityType,
      icon: _activityIcon(activityType),
      accentColor: _kNeonCyan,
      glowColor: _kNeonCyan.withValues(alpha: 0.22),
      highlightColor: Colors.white.withValues(alpha: 0.74),
      startColor: _kValidGreen,
      endColor: _kDangerRed,
      badgeText: 'ROUTE RECAP',
      footerText: '${routePoints.length} points recorded',
    );
  }
}

class _DetailsRouteUnavailableState extends ConsumerWidget {
  const _DetailsRouteUnavailableState({
    required this.activityType,
    required this.durationSec,
    required this.distanceKm,
    required this.useMetricUnits,
  });

  final String activityType;
  final int durationSec;
  final double distanceKm;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13263A), Color(0xFF0B1725)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AetronRadialGlow(
                glowColor: AetronColors.cyan,
                glowRadius: 40,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AetronColors.cyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AetronColors.cyan.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AetronColors.cyan.withValues(alpha: 0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(
                    _activityIcon(activityType),
                    color: AetronColors.cyan,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                currentLang == AppLanguage.vi
                    ? 'Không có dữ liệu lộ trình trên thiết bị này'
                    : 'Route unavailable on this device',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                currentLang == AppLanguage.vi
                    ? 'Buổi tập này vẫn lưu trữ dữ liệu hiệu suất, nhưng chi tiết lộ trình chưa được lưu trên thiết bị.'
                    : 'This workout still keeps its performance data, but detailed route history was not stored locally.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AetronColors.panelHigh,
                  borderRadius: BorderRadius.circular(AetronRadius.pill),
                  border: Border.all(color: AetronColors.borderSubtle),
                ),
                child: Text(
                  '${WorkoutFormatters.formatDistance(distanceKm, useMetric: useMetricUnits, decimals: 2)}  •  ${WorkoutFormatters.formatElapsedClock(durationSec)}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.cyanSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

String _formatWorkoutDetailsDate(DateTime date, AppLanguage lang) {
  final d = date.toLocal();
  if (lang == AppLanguage.vi) {
    const days = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
    final dayName = days[d.weekday % 7];
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$dayName, $day/$month/${d.year}';
  }
  return DateFormat('EEEE, MMM dd, yyyy').format(d);
}

// ---------------------------------------------------------------------------
// Lap split row
// ---------------------------------------------------------------------------

class _LapSplitRow extends StatelessWidget {
  final WorkoutLapSplit split;
  final bool useMetricUnits;

  const _LapSplitRow({required this.split, required this.useMetricUnits});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AetronColors.cyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AetronRadius.pill),
          ),
          child: Text(
            '${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase()} ${split.index}',
            style: const TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Spacer(),
        Text(
          WorkoutFormatters.formatDurationFromSeconds(split.durationSeconds),
          style: const TextStyle(
            fontFamily: 'Outfit',
            color: AetronColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          WorkoutFormatters.formatSplitPace(
            split.paceMinPerKm,
            useMetric: useMetricUnits,
          ),
          style: const TextStyle(
            fontFamily: 'Outfit',
            color: AetronColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

IconData _activityIcon(String activityType) {
  switch (activityType.toLowerCase()) {
    case 'running':
      return Icons.directions_run_rounded;
    case 'cycling':
      return Icons.directions_bike_rounded;
    case 'walking':
      return Icons.directions_walk_rounded;
    default:
      return Icons.bolt_rounded;
  }
}

void _showDeleteConfirmation(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
) {
  final lang = ref.read(appLanguageProvider);

  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AetronColors.panelHigh,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AetronColors.danger.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AetronColors.danger.withValues(alpha: 0.2),
              blurRadius: 24,
            ),
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AetronColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: AetronColors.danger,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppTranslations.get('delete_workout', lang),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: AetronColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              AppTranslations.get('confirm_delete_workout', lang),
              style: const TextStyle(
                fontFamily: 'Outfit',
                color: AetronColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(
                    AppTranslations.get('cancel', lang),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: AetronColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    try {
                      await ref
                          .read(workoutListProvider.notifier)
                          .deleteWorkout(workoutId);

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              lang == AppLanguage.vi
                                  ? 'Đã xóa buổi tập'
                                  : 'Workout deleted',
                              style: const TextStyle(fontFamily: 'Outfit'),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AetronColors.danger,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AetronColors.danger,
                    foregroundColor: AetronColors.space,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AetronRadius.pill),
                    ),
                    elevation: 6,
                    shadowColor: AetronColors.danger.withValues(alpha: 0.5),
                  ),
                  child: Text(
                    AppTranslations.get('delete_workout', lang),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
