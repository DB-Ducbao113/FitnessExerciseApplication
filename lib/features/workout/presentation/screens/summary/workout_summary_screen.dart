import 'dart:ui' as ui;

import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/workout_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

class WorkoutSummaryScreen extends StatelessWidget {
  final String sessionId;
  final String activityType;
  final String trackingMode;
  final int durationSeconds;
  final double distanceMeters;
  final double avgSpeedKmh;
  final int calories;
  final List<LatLng> routePoints;
  final List<WorkoutLapSplit> lapSplits;

  const WorkoutSummaryScreen({
    super.key,
    required this.sessionId,
    required this.activityType,
    required this.trackingMode,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.calories,
    this.routePoints = const [],
    this.lapSplits = const [],
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = distanceMeters / 1000;
    final isOutdoor = trackingMode == 'outdoor';

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
                durationSeconds: durationSeconds,
                avgSpeedKmh: avgSpeedKmh,
                calories: calories,
                showRouteMap: isOutdoor && routePoints.length >= 2,
                routePoints: routePoints,
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
                        _SplitRow(split: split),
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
                    'View Analysis',
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
    required this.durationSeconds,
    required this.avgSpeedKmh,
    required this.calories,
    required this.showRouteMap,
    required this.routePoints,
  });

  final String activityType;
  final double distanceKm;
  final int durationSeconds;
  final double avgSpeedKmh;
  final int calories;
  final bool showRouteMap;
  final List<LatLng> routePoints;

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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: showRouteMap
                    ? _RouteMap(
                        routePoints: routePoints,
                        activityType: activityType,
                      )
                    : _IndoorTrailPreview(
                        activityType: activityType,
                        distanceKm: distanceKm,
                        durationSeconds: durationSeconds,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _kNeonCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          _activityIcon(activityType),
                          color: _kNeonCyan,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        activityType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      distanceKm.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.8,
                        height: 0.95,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 10),
                      child: Text(
                        'km',
                        style: TextStyle(
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
                  showRouteMap
                      ? 'Outdoor route captured successfully'
                      : 'Indoor movement shown as an abstract trail',
                  style: const TextStyle(
                    color: _kMutedText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MetricChip(
                        label: 'TIME',
                        value: _formatDuration(durationSeconds),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricChip(
                        label: 'AVG SPEED',
                        value: '${avgSpeedKmh.toStringAsFixed(1)} km/h',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricChip(
                        label: 'CALORIES',
                        value: '$calories kcal',
                      ),
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

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _kMutedText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
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
    required this.durationSeconds,
  });

  final String activityType;
  final double distanceKm;
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
                  '${distanceKm.toStringAsFixed(2)} km  |  ${_formatDuration(durationSeconds)}',
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

class _RouteMap extends StatelessWidget {
  final List<LatLng> routePoints;
  final String activityType;

  const _RouteMap({required this.routePoints, required this.activityType});

  LatLngBounds _computeBounds() {
    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (final pt in routePoints) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    final latPad = (maxLat - minLat) * 0.15 + 0.0005;
    final lngPad = (maxLng - minLng) * 0.15 + 0.0005;

    return LatLngBounds(
      LatLng(minLat - latPad, minLng - lngPad),
      LatLng(maxLat + latPad, maxLng + lngPad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _computeBounds();

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fitness_exercise_application',
              maxZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 16,
                  color: _kMapGlow,
                ),
                Polyline(
                  points: routePoints,
                  strokeWidth: 7,
                  color: _kNeonCyan,
                ),
                Polyline(
                  points: routePoints,
                  strokeWidth: 2,
                  color: _kMapHighlight,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: routePoints.first,
                  width: 42,
                  height: 42,
                  child: const _RouteStartMarker(),
                ),
                Marker(
                  point: routePoints.last,
                  width: 42,
                  height: 42,
                  child: const _RouteFinishMarker(),
                ),
              ],
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.26),
                  ],
                  stops: const [0.0, 0.22, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xC0152232),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_activityIcon(activityType), color: _kNeonCyan, size: 16),
                const SizedBox(width: 6),
                Text(
                  activityType.toUpperCase(),
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
      ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kPanelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SplitRow extends StatelessWidget {
  final WorkoutLapSplit split;

  const _SplitRow({required this.split});

  @override
  Widget build(BuildContext context) {
    final paceMinutes = split.paceMinPerKm.floor();
    var paceSeconds = ((split.paceMinPerKm - paceMinutes) * 60).round();
    var minutes = paceMinutes;
    if (paceSeconds == 60) {
      minutes += 1;
      paceSeconds = 0;
    }

    return Row(
      children: [
        Text(
          'KM ${split.index}',
          style: const TextStyle(
            color: _kNeonCyan,
            fontSize: 13,
            fontWeight: FontWeight.w800,
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
          '$minutes:${paceSeconds.toString().padLeft(2, '0')}/km',
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

String _formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
