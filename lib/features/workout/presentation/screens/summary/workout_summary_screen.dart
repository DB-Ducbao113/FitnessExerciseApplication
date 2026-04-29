import 'dart:ui' as ui;

import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

const _kBgTop = Color(0xFF050816);
const _kBgBottom = Color(0xFF0B1A29);
const _kSurface = Color(0xCC121B2C);
const _kPanelBorder = Color(0x3300E5FF);
const _kMutedText = Color(0xFF7D8DA6);
const _kNeonCyan = Color(0xFF00E5FF);
const _kNeonBlue = Color(0xFF00BFFF);
const _kMapGlow = Color(0x6600F0FF);
const _kMapHighlight = Color(0xCCB4F7FF);
const _kValidGreen = Color(0xFF6BE39B);
const _kDangerRed = Color(0xFFFF7A8A);

class WorkoutSummaryScreen extends ConsumerWidget {
  final String sessionId;
  final String activityType;
  final String trackingMode;
  final int durationSeconds;
  final int movingTimeSeconds;
  final double distanceMeters;
  final double avgSpeedKmh;
  final int calories;
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
    this.gpsAnalysis = const WorkoutGpsAnalysis(),
    this.routePoints = const [],
    this.routeSegments = const [],
    this.lapSplits = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final List<List<LatLng>> effectiveRouteSegments = routeSegments.isNotEmpty
        ? routeSegments
        : (routePoints.isNotEmpty
              ? <List<LatLng>>[routePoints]
              : const <List<LatLng>>[]);
    final List<LatLng> effectiveRoutePoints = effectiveRouteSegments.isNotEmpty
        ? effectiveRouteSegments.expand((segment) => segment).toList()
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

    return Scaffold(
      backgroundColor: _kBgTop,
      appBar: AppBar(
        title: const Text('Summary'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            children: [
              _SummaryHeroCard(
                activityType: activityType,
                distanceKm: distanceKm,
                useMetricUnits: useMetricUnits,
                durationSeconds: durationSeconds,
                movingTimeSeconds: movingTimeSeconds,
                avgSpeedKmh: avgSpeedKmh,
                calories: calories,
                gpsAnalysis: gpsAnalysis,
                showRouteMap: effectiveRoutePoints.length >= 2,
                routePoints: effectiveRoutePoints,
                routeSegments: effectiveRouteSegments,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryStatCard(
                            label: 'Distance',
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
                          child: _SummaryStatCard(
                            label: 'Duration',
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
                          child: _SummaryStatCard(
                            label: 'Avg Pace',
                            value: avgPace,
                            accent: const Color(0xFFF8C15C),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryStatCard(
                            label: 'Moving Pace',
                            value: movingPace,
                            accent: _kValidGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryStatCard(
                            label: 'Calories',
                            value: '$calories kcal',
                            accent: const Color(0xFFFF8CA1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryStatCard(
                            label: 'Rest Time',
                            value: WorkoutFormatters.formatElapsedClock(
                              gpsAnalysis.restDurationSec,
                            ),
                            accent: _kNeonBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (lapSplits.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lap Splits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                  child: const Text(
                    'Back To History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                    child: const Text(
                      'View Details',
                      style: TextStyle(
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

class _SummaryHeroCard extends StatelessWidget {
  const _SummaryHeroCard({
    required this.activityType,
    required this.distanceKm,
    required this.useMetricUnits,
    required this.durationSeconds,
    required this.movingTimeSeconds,
    required this.avgSpeedKmh,
    required this.calories,
    required this.gpsAnalysis,
    required this.showRouteMap,
    required this.routePoints,
    required this.routeSegments,
  });

  final String activityType;
  final double distanceKm;
  final bool useMetricUnits;
  final int durationSeconds;
  final int movingTimeSeconds;
  final double avgSpeedKmh;
  final int calories;
  final WorkoutGpsAnalysis gpsAnalysis;
  final bool showRouteMap;
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
                        footerText: '${routePoints.length} points recorded',
                        routeSegments: routeSegments,
                      )
                    : _IndoorTrailPreview(
                        activityType: activityType,
                        distanceKm: distanceKm,
                        useMetricUnits: useMetricUnits,
                        durationSeconds: durationSeconds,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _kNeonCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _activityIcon(activityType),
                        color: _kNeonCyan,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activityType.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            showRouteMap
                                ? 'Route recorded on this workout'
                                : 'Workout captured without route map',
                            style: const TextStyle(
                              color: _kMutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (useMetricUnits
                              ? distanceKm
                              : WorkoutFormatters.kmToMi(distanceKm))
                          .toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.8,
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
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _summarySubtitle(
                    distanceKm: distanceKm,
                    useMetricUnits: useMetricUnits,
                    durationSeconds: durationSeconds,
                    avgSpeedKmh: avgSpeedKmh,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kMutedText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    WorkoutHeroMetricChip(
                      label: 'Duration',
                      value: WorkoutFormatters.formatElapsedClock(
                        durationSeconds,
                      ),
                    ),
                    WorkoutHeroMetricChip(label: 'Avg Pace', value: avgPace),
                    WorkoutHeroMetricChip(
                      label: 'Moving Pace',
                      value: movingPace,
                    ),
                    WorkoutHeroMetricChip(
                      label: 'Calories',
                      value: '$calories kcal',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndoorTrailPreview extends StatelessWidget {
  const _IndoorTrailPreview({
    required this.activityType,
    required this.distanceKm,
    required this.useMetricUnits,
    required this.durationSeconds,
  });

  final String activityType;
  final double distanceKm;
  final bool useMetricUnits;
  final int durationSeconds;

  List<Offset> _buildTrail() {
    final points = <Offset>[];
    final loops = (distanceKm * 10).clamp(2, 7).round();
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
  Widget build(BuildContext context) {
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
                    const Text(
                      'INDOOR MOVEMENT',
                      style: TextStyle(
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
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
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
                  '${WorkoutFormatters.formatDistance(distanceKm, useMetric: useMetricUnits, decimals: 2)}  |  ${WorkoutFormatters.formatElapsedClock(durationSeconds)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 16
      ..color = _kMapGlow;

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7
      ..color = _kNeonCyan;

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2
      ..color = _kMapHighlight;

    canvas.drawPath(trailPath, glowPaint);
    canvas.drawPath(trailPath, corePaint);
    canvas.drawPath(trailPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _IndoorTrailPainter oldDelegate) {
    return oldDelegate.points != points;
  }
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
      padding: const EdgeInsets.all(22),
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

String _summarySubtitle({
  required double distanceKm,
  required bool useMetricUnits,
  required int durationSeconds,
  required double avgSpeedKmh,
}) {
  final duration = WorkoutFormatters.formatElapsedClock(durationSeconds);
  final pace = WorkoutFormatters.formatPaceFromSpeedKmh(
    avgSpeedKmh,
    useMetric: useMetricUnits,
  );
  return '$duration total  •  $pace average  •  ${WorkoutFormatters.formatDistance(distanceKm, useMetric: useMetricUnits, decimals: 2)}';
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
