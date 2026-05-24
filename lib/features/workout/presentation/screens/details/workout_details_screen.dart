import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

const _kBgTop = Color(0xff0a0e1a);
const _kBgBottom = Color(0xff0d1b2a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
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
    final workoutAsync = ref.watch(workoutProvider(workoutId));
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: _kBgTop,
      appBar: AppBar(
        title: const Text('Details'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _showDeleteConfirmation(context, ref, workoutId),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: workoutAsync.when(
          data: (workout) {
            if (workout == null) {
              return const Center(
                child: Text(
                  'Workout not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _WorkoutHeroSection(
                  workoutId: workout.id,
                  workout: workout,
                  useMetricUnits: useMetricUnits,
                  dateLabel: DateFormat(
                    'EEEE, MMM dd, yyyy',
                  ).format(workout.startedAt.toLocal()),
                ),
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _kNeonCyan)),
          error: (error, _) => Center(
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white),
            ),
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
        color: _kCardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Route map ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
                      child: CircularProgressIndicator(color: _kNeonCyan),
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

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Activity header ────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _kNeonCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        _activityIcon(workout.activityType),
                        color: _kNeonCyan,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WorkoutFormatters.formatActivityType(
                              workout.activityType,
                            ).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              color: _kMutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Distance hero ──────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (useMetricUnits
                              ? displayDistanceKm
                              : WorkoutFormatters.kmToMi(displayDistanceKm))
                          .toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.6,
                        height: 0.95,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 10),
                      child: Text(
                        WorkoutFormatters.distanceUnitLabel(
                          useMetric: useMetricUnits,
                        ),
                        style: const TextStyle(
                          color: _kMutedText,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'recorded distance',
                  style: TextStyle(
                    color: _kMutedText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Primary stats 2×2 ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _DetailsPrimaryCard(
                        id: 'details_stat_duration',
                        icon: Icons.timer_rounded,
                        label: 'Duration',
                        value: WorkoutFormatters.formatDurationFromSeconds(
                          workout.durationSec,
                        ),
                        accent: _kNeonCyan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DetailsPrimaryCard(
                        id: 'details_stat_avg_pace',
                        icon: Icons.speed_rounded,
                        label: 'Avg Pace',
                        value: avgPace,
                        accent: const Color(0xFFF8C15C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DetailsPrimaryCard(
                        id: 'details_stat_calories',
                        icon: Icons.local_fire_department_rounded,
                        label: 'Calories',
                        value: '${workout.caloriesKcal.round()} kcal',
                        accent: const Color(0xFFFF8CA1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (showSteps)
                      Expanded(
                        child: _DetailsPrimaryCard(
                          id: 'details_stat_steps',
                          icon: Icons.transfer_within_a_station_rounded,
                          label: 'Steps',
                          value: _formatSteps(workout.steps),
                          accent: _kValidGreen,
                        ),
                      )
                    else
                      Expanded(
                        child: _DetailsPrimaryCard(
                          id: 'details_stat_moving_pace',
                          icon: Icons.directions_run_rounded,
                          label: 'Moving Pace',
                          value: movingPace,
                          accent: _kValidGreen,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Secondary details ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    children: [
                      // If steps are shown in primary, show moving pace here
                      if (showSteps) ...[
                        _DetailsSecondaryRow(
                          label: 'Moving Pace',
                          value: movingPace,
                          icon: Icons.directions_run_rounded,
                        ),
                        _detailsDivider(),
                      ],
                      _DetailsSecondaryRow(
                        label: 'Moving Time',
                        value: WorkoutFormatters.formatElapsedClock(
                          workout.movingTimeSec,
                        ),
                        icon: Icons.play_circle_outline_rounded,
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: 'Rest Time',
                        value: WorkoutFormatters.formatElapsedClock(
                          workout.gpsAnalysis.restDurationSec,
                        ),
                        icon: Icons.pause_circle_outline_rounded,
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: 'Activity',
                        value: WorkoutFormatters.formatActivityType(
                          workout.activityType,
                        ),
                        icon: _activityIcon(workout.activityType),
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: 'Started',
                        value: DateFormat(
                          'HH:mm:ss',
                        ).format(workout.startedAt.toLocal()),
                        icon: Icons.login_rounded,
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: 'Finished',
                        value: DateFormat(
                          'HH:mm:ss',
                        ).format(workout.endedAt.toLocal()),
                        icon: Icons.logout_rounded,
                      ),
                      _detailsDivider(),
                      _DetailsSecondaryRow(
                        label: 'Saved',
                        value: DateFormat(
                          'MMM dd, yyyy HH:mm',
                        ).format(workout.createdAt.toLocal()),
                        icon: Icons.save_rounded,
                      ),

                      // ── Lap splits ───────────────────────────────────────
                      if (workout.lapSplits.isNotEmpty) ...[
                        Divider(
                          height: 24,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Lap Splits',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
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
                            Divider(
                              height: 18,
                              color: Colors.white.withValues(alpha: 0.06),
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
// Primary stat card (details) — same visual language as summary
// ---------------------------------------------------------------------------

class _DetailsPrimaryCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _DetailsPrimaryCard({
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
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
// Secondary metric row (details)
// ---------------------------------------------------------------------------

Widget _detailsDivider() => Divider(
  height: 16,
  color: Colors.white.withValues(alpha: 0.06),
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
      children: [
        Icon(icon, size: 14, color: _kMutedText),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: _kMutedText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
// Route map / unavailable state
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

class _DetailsRouteUnavailableState extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  _activityIcon(activityType),
                  color: _kNeonCyan,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Route unavailable on this device',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This workout still keeps its performance data, but detailed route history was not stored locally.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kMutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${WorkoutFormatters.formatDistance(distanceKm, useMetric: useMetricUnits, decimals: 2)}  •  ${WorkoutFormatters.formatElapsedClock(durationSec)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
        Text(
          '${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase()} ${split.index}',
          style: const TextStyle(
            color: _kNeonCyan,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          WorkoutFormatters.formatDurationFromSeconds(split.durationSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          WorkoutFormatters.formatSplitPace(
            split.paceMinPerKm,
            useMetric: useMetricUnits,
          ),
          style: const TextStyle(
            color: _kMutedText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xff0f1726),
      title: const Text('Delete Workout'),
      content: const Text(
        'Are you sure you want to delete this workout? This action cannot be undone.',
        style: TextStyle(color: _kMutedText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel', style: TextStyle(color: _kMutedText)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            try {
              await ref
                  .read(workoutListProvider.notifier)
                  .deleteWorkout(workoutId);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Workout deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
