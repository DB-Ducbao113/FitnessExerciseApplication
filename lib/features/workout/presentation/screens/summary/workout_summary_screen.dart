import 'dart:ui' as ui;

import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

const _kBgTop = Color(0xFF050816);
const _kSurface = Color(0xCC121B2C);
const _kPanelBorder = Color(0x3300E5FF);
const _kMutedText = Color(0xFF7D8DA6);
const _kNeonCyan = Color(0xFF00E5FF);
const _kNeonBlue = Color(0xFF00BFFF);
const _kMapGlow = Color(0x6600F0FF);
const _kMapHighlight = Color(0xCCB4F7FF);
const _kValidGreen = Color(0xFF6BE39B);
const _kDangerRed = Color(0xFFFF7A8A);

// Whether this activity type tracks steps.
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

    final movingPace =
        WorkoutFormatters.formatMovingPaceFromDistanceAndDuration(
          distanceKm: effectiveDistanceKm,
          durationSec: movingTimeSeconds,
          restDurationSec: 0,
          useMetric: useMetricUnits,
        );

    final showSteps = _hasSteps(activityType) && steps > 0;

    return Scaffold(
      backgroundColor: _kBgTop,
      appBar: AppBar(
        title: Text(
          AppTranslations.get('workout_summary', currentLang).toUpperCase(),
          style: TextStyle(
            color: AetronColors.cyanSoft,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: AetronBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            children: [
              // ── Route map / indoor trail ──────────────────────────────────
              _CompletionBanner(
                activityType: activityType,
                distanceLabel: WorkoutFormatters.formatDistance(
                  effectiveDistanceKm,
                  useMetric: useMetricUnits,
                  decimals: 2,
                ),
              ),
              const SizedBox(height: 14),
              _SummaryHeroCard(
                activityType: activityType,
                showRouteMap: effectiveRoutePoints.length >= 2,
                routePoints: effectiveRoutePoints,
                routeSegments: effectiveRouteSegments,
              ),
              const SizedBox(height: 16),

              // ── Primary stats: Distance · Duration · Calories · Avg Pace ─
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(AppTranslations.get('overview', currentLang)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PrimaryStatCard(
                            id: 'summary_stat_distance',
                            icon: Icons.straighten_rounded,
                            label: AppTranslations.get('distance', currentLang),
                            value: WorkoutFormatters.formatDistance(
                              gpsAnalysis.totalDistanceKm > 0
                                  ? gpsAnalysis.totalDistanceKm
                                  : distanceKm,
                              useMetric: useMetricUnits,
                              decimals: 2,
                            ),
                            accent: _kNeonCyan,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrimaryStatCard(
                            id: 'summary_stat_duration',
                            icon: Icons.timer_rounded,
                            label: AppTranslations.get('duration', currentLang),
                            value: WorkoutFormatters.formatElapsedClock(
                              durationSeconds,
                            ),
                            accent: _kNeonBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PrimaryStatCard(
                            id: 'summary_stat_calories',
                            icon: Icons.local_fire_department_rounded,
                            label: AppTranslations.get('calories', currentLang),
                            value: '$calories kcal',
                            accent: const Color(0xFFFF8CA1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrimaryStatCard(
                            id: 'summary_stat_avg_pace',
                            icon: Icons.speed_rounded,
                            label: AppTranslations.get('best_pace', currentLang),
                            value: avgPace,
                            accent: const Color(0xFFF8C15C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Secondary stats ───────────────────────────────────────────
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(AppTranslations.get('details', currentLang)),
                    const SizedBox(height: 12),
                    _SecondaryRow(
                      label: AppTranslations.get('moving_pace', currentLang),
                      value: movingPace,
                      icon: Icons.directions_run_rounded,
                    ),
                    _divider(),
                    _SecondaryRow(
                      label: AppTranslations.get('moving_time', currentLang),
                      value: WorkoutFormatters.formatElapsedClock(
                        movingTimeSeconds,
                      ),
                      icon: Icons.play_circle_outline_rounded,
                    ),
                    _divider(),
                    _SecondaryRow(
                      label: AppTranslations.get('rest_time', currentLang),
                      value: WorkoutFormatters.formatElapsedClock(
                        gpsAnalysis.restDurationSec,
                      ),
                      icon: Icons.pause_circle_outline_rounded,
                    ),
                    if (showSteps) ...[
                      _divider(),
                      _SecondaryRow(
                        label: 'Steps',
                        value: _formatSteps(steps),
                        icon: Icons.transfer_within_a_station_rounded,
                        accent: _kValidGreen,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Lap splits ────────────────────────────────────────────────
              if (lapSplits.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(AppTranslations.get('lap_splits', currentLang)),
                      const SizedBox(height: 14),
                      for (final split in lapSplits) ...[
                        _SplitRow(split: split, useMetricUnits: useMetricUnits),
                        if (split != lapSplits.last)
                          Divider(
                            height: 18,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                      ],
                    ],
                  ),
                ),
              ],

              // ── Action buttons ────────────────────────────────────────────
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const MainShell(initialIndex: 3),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNeonCyan,
                    side: const BorderSide(color: _kNeonCyan, width: 1.6),
                    backgroundColor: const Color(0x80081624),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    AppTranslations.get('back_to_history', currentLang),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kNeonBlue, _kNeonCyan],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _kNeonCyan.withValues(alpha: 0.24),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkoutDetailsScreen(workoutId: sessionId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: _kBgTop,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      AppTranslations.get('view_details', currentLang),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _divider() =>
    Divider(height: 18, color: Colors.white.withValues(alpha: 0.07));

String _formatSteps(int steps) {
  if (steps >= 1000) {
    return '${(steps / 1000).toStringAsFixed(1)}k';
  }
  return '$steps';
}

class _CompletionBanner extends ConsumerWidget {
  const _CompletionBanner({
    required this.activityType,
    required this.distanceLabel,
  });

  final String activityType;
  final String distanceLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AetronColors.mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AetronColors.mint.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AetronColors.mint.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: AetronColors.mint.withValues(alpha: 0.52),
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AetronColors.mint,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.get('workout_saved', currentLang),
                  style: const TextStyle(
                    color: AetronColors.mint,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppTranslations.get(activityType, currentLang)} / $distanceLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AetronColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: AetronColors.cyan,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primary stat card — prominent 2×2 grid for the 4 hero metrics
// ---------------------------------------------------------------------------

class _PrimaryStatCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _PrimaryStatCard({
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secondary metric row — compact label/value list for supporting metrics
// ---------------------------------------------------------------------------

class _SecondaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _SecondaryRow({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = _kMutedText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Existing widgets preserved unchanged
// ---------------------------------------------------------------------------

class _SummaryHeroCard extends StatelessWidget {
  const _SummaryHeroCard({
    required this.activityType,
    required this.showRouteMap,
    required this.routePoints,
    required this.routeSegments,
  });

  final String activityType;
  final bool showRouteMap;
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _kPanelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 286,
                width: double.infinity,
                child: showRouteMap
                    ? WorkoutRoutePreviewMap(
                        routePoints: routePoints,
                        activityType: activityType,
                        icon: _activityIcon(activityType),
                        accentColor: _kNeonCyan,
                        glowColor: _kNeonCyan.withValues(alpha: 0.22),
                        highlightColor: Colors.white.withValues(alpha: 0.74),
                        startColor: _kValidGreen,
                        endColor: _kDangerRed,
                        badgeText: 'ROUTE RECAP',
                        routeSegments: routeSegments,
                      )
                    : _IndoorTrailPreview(activityType: activityType),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndoorTrailPreview extends ConsumerWidget {
  const _IndoorTrailPreview({required this.activityType});

  final String activityType;

  List<Offset> _buildTrail() {
    final points = <Offset>[];
    const loops = 4;
    const segmentsPerLoop = 18;
    final seed = activityType.toLowerCase().codeUnits.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final wobble = 0.04 + (seed % 7) * 0.004;
    final verticalBias = 0.50 + (seed % 5 - 2) * 0.015;

    for (var loop = 0; loop < loops; loop++) {
      final baseY = verticalBias + ((loop % 3) - 1) * 0.08;
      final progressY = loop / (loops == 1 ? 1 : loops - 1);
      final y = (baseY + (progressY - 0.5) * 0.18).clamp(0.18, 0.82);

      for (var i = 0; i <= segmentsPerLoop; i++) {
        final t = i / segmentsPerLoop;
        final movingRight = loop.isEven;
        final x = movingRight ? t : 1 - t;
        final wave =
            ((i.isEven ? 1 : -1) * wobble) +
            (movingRight ? loop * 0.006 : -loop * 0.006);
        points.add(
          Offset(
            0.12 + x * 0.76,
            (y + wave + (t - 0.5) * 0.02).clamp(0.14, 0.86),
          ),
        );
      }

      if (loop != loops - 1) {
        final connectorX = loop.isEven ? 0.88 : 0.12;
        final nextY = (y + 0.10).clamp(0.18, 0.86);
        points.add(Offset(connectorX, nextY));
      }
    }

    return points;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final trail = _buildTrail();
    final start = trail.first;
    final end = trail.last;

    return LayoutBuilder(
      builder: (context, constraints) {
        const markerSize = 42.0;
        final startLeft = (start.dx * constraints.maxWidth - markerSize / 2)
            .clamp(8.0, constraints.maxWidth - markerSize - 8);
        final startTop = (start.dy * constraints.maxHeight - markerSize / 2)
            .clamp(8.0, constraints.maxHeight - markerSize - 8);
        final endLeft = (end.dx * constraints.maxWidth - markerSize / 2).clamp(
          8.0,
          constraints.maxWidth - markerSize - 8,
        );
        final endTop = (end.dy * constraints.maxHeight - markerSize / 2).clamp(
          8.0,
          constraints.maxHeight - markerSize - 8,
        );

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF13263A), Color(0xFF0B1725)],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _IndoorTrailPainter(points: trail)),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xC0152232),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _activityIcon(activityType),
                      color: _kNeonCyan,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppTranslations.get('indoor_movement', currentLang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: startLeft,
              top: startTop,
              child: const SizedBox(
                width: markerSize,
                height: markerSize,
                child: _RouteStartMarker(),
              ),
            ),
            Positioned(
              left: endLeft,
              top: endTop,
              child: const SizedBox(
                width: markerSize,
                height: markerSize,
                child: _RouteFinishMarker(),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  AppTranslations.get('route_not_available', currentLang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IndoorTrailPainter extends CustomPainter {
  const _IndoorTrailPainter({required this.points});

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const columns = 6;
    const rows = 4;

    for (var i = 1; i < columns; i++) {
      final x = size.width * i / columns;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final trailPath = ui.Path();
    for (var i = 0; i < points.length; i++) {
      final point = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      if (i == 0) {
        trailPath.moveTo(point.dx, point.dy);
      } else {
        trailPath.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(
      trailPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 16
        ..color = _kMapGlow,
    );
    canvas.drawPath(
      trailPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 7
        ..color = _kNeonCyan,
    );
    canvas.drawPath(
      trailPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2
        ..color = _kMapHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant _IndoorTrailPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _RouteStartMarker extends StatelessWidget {
  const _RouteStartMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2AF598), Color(0xFF12B886)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2AF598).withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
    );
  }
}

class _RouteFinishMarker extends StatelessWidget {
  const _RouteFinishMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kNeonBlue, _kNeonCyan],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _kNeonCyan.withValues(alpha: 0.30),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.sports_score, color: Colors.white, size: 18),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCC121B2C), Color(0xCC162436)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _kPanelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SplitRow extends StatelessWidget {
  final WorkoutLapSplit split;
  final bool useMetricUnits;

  const _SplitRow({required this.split, this.useMetricUnits = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kNeonCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kNeonCyan.withValues(alpha: 0.18)),
          ),
          child: Text(
            '${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase()} ${split.index}',
            style: const TextStyle(
              color: _kNeonCyan,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const Spacer(),
        Text(
          _formatSplitDuration(split.durationSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
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

String _formatSplitDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

IconData _activityIcon(String type) {
  switch (type.toLowerCase()) {
    case 'running':
      return Icons.directions_run_rounded;
    case 'cycling':
      return Icons.directions_bike_rounded;
    case 'walking':
      return Icons.directions_walk_rounded;
    default:
      return Icons.fitness_center_rounded;
  }
}
