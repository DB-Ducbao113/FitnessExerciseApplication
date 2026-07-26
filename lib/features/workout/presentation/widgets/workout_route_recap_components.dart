import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/utils/activity_consistency_feedback.dart';
import 'package:fitness_exercise_application/features/workout/presentation/utils/route_display_sanitizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class WorkoutValidityBadge extends StatelessWidget {
  const WorkoutValidityBadge({
    super.key,
    required this.flag,
    required this.verifiedColor,
    required this.warningColor,
    required this.dangerColor,
  });

  final WorkoutValidityFlag flag;
  final Color verifiedColor;
  final Color warningColor;
  final Color dangerColor;

  @override
  Widget build(BuildContext context) {
    final color = switch (flag) {
      WorkoutValidityFlag.verified => verifiedColor,
      WorkoutValidityFlag.partial => warningColor,
      WorkoutValidityFlag.unverified => dangerColor,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        workoutValidityLabel(flag),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class WorkoutHeroMetricChip extends StatelessWidget {
  const WorkoutHeroMetricChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGlassBadge extends StatelessWidget {
  const _MapGlassBadge({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xC0152232),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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

class WorkoutRoutePreviewMap extends StatelessWidget {
  const WorkoutRoutePreviewMap({
    super.key,
    required this.routePoints,
    this.routeSegments = const [],
    required this.activityType,
    required this.icon,
    required this.accentColor,
    required this.glowColor,
    required this.highlightColor,
    required this.startColor,
    required this.endColor,
    required this.badgeText,
    this.footerText,
  });

  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String activityType;
  final IconData icon;
  final Color accentColor;
  final Color glowColor;
  final Color highlightColor;
  final Color startColor;
  final Color endColor;
  final String badgeText;
  final String? footerText;

  LatLngBounds _computeBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final pt in points) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final latPad = math.max(latSpan * 0.12, 0.00028);
    final lngPad = math.max(lngSpan * 0.12, 0.00028);

    return LatLngBounds(
      LatLng(minLat - latPad, minLng - lngPad),
      LatLng(maxLat + latPad, maxLng + lngPad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayRoute = refineRouteForSavedDisplay(
      routePoints,
      activityType: activityType,
    );
    final displaySegments = refineRouteSegmentsForSavedDisplay(
      routePoints: routePoints,
      routeSegments: routeSegments,
      activityType: activityType,
    );
    final bounds = _computeBounds(displayRoute);
    final routeForArt = displaySegments.isNotEmpty
        ? displaySegments.expand((segment) => segment).toList()
        : displayRoute;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 16),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.aetron.app',
              maxZoom: 20,
            ),
            PolygonLayer(
              polygons: [
                for (final segment in displaySegments)
                  if (segment.length >= 3)
                    Polygon(
                      points: segment,
                      color: accentColor.withValues(alpha: 0.08),
                      borderColor: Colors.transparent,
                    ),
              ],
            ),
            PolylineLayer(
              polylines: [
                for (final segment in displaySegments) ...[
                  Polyline(
                    points: segment,
                    strokeWidth: 24,
                    color: Colors.black.withValues(alpha: 0.34),
                  ),
                  Polyline(points: segment, strokeWidth: 20, color: glowColor),
                  Polyline(
                    points: segment,
                    strokeWidth: 11,
                    color: accentColor.withValues(alpha: 0.88),
                  ),
                  Polyline(
                    points: segment,
                    strokeWidth: 6,
                    color: const Color(0xff0b314d).withValues(alpha: 0.72),
                  ),
                  Polyline(
                    points: segment,
                    strokeWidth: 2,
                    color: highlightColor,
                  ),
                ],
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: displayRoute.first,
                  width: 42,
                  height: 42,
                  child: _RouteOrb(color: startColor, icon: Icons.flag_rounded),
                ),
                Marker(
                  point: displayRoute.last,
                  width: 46,
                  height: 46,
                  child: _RouteOrb(
                    color: endColor,
                    icon: Icons.sports_score_rounded,
                    large: true,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RouteHudOverlayPainter(
                accent: accentColor,
                route: routeForArt,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    const Color(0xff07121f).withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.36),
                  ],
                  stops: const [0.0, 0.24, 0.68, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: 14,
          child: _MapGlassBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accentColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (footerText != null)
          Positioned(
            right: 14,
            bottom: 14,
            child: _MapGlassBadge(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Text(
                footerText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: IgnorePointer(
            child: _RouteElevationStrip(
              route: routeForArt,
              accent: accentColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteOrb extends StatelessWidget {
  const _RouteOrb({
    required this.color,
    required this.icon,
    this.large = false,
  });

  final Color color;
  final IconData icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.42),
            blurRadius: large ? 24 : 18,
            spreadRadius: large ? 4 : 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: large ? 27 : 23,
          height: large ? 27 : 23,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: large ? 13 : 11),
        ),
      ),
    );
  }
}

class _RouteHudOverlayPainter extends CustomPainter {
  const _RouteHudOverlayPainter({required this.accent, required this.route});

  final Color accent;
  final List<LatLng> route;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = accent.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 34.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x - 24, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 12), gridPaint);
    }

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      24,
      Paint()..color = accent.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = accent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
        const Radius.circular(14),
      ),
      frame,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteHudOverlayPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.route != route;
}

class _RouteElevationStrip extends StatelessWidget {
  const _RouteElevationStrip({required this.route, required this.accent});

  final List<LatLng> route;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: 120,
          height: 28,
          child: CustomPaint(
            painter: _ElevationPainter(route: route, accent: accent),
          ),
        ),
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  const _ElevationPainter({required this.route, required this.accent});

  final List<LatLng> route;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;
    final points = route.length > 48
        ? [
            for (var i = 0; i < route.length; i += (route.length / 48).ceil())
              route[i],
          ]
        : route;
    final path = ui.Path();
    for (var i = 0; i < points.length; i++) {
      final t = i / math.max(1, points.length - 1);
      final wave = math.sin(t * math.pi * 3) * 0.18;
      final latNorm = (points[i].latitude - points.first.latitude).abs() * 1200;
      final y = size.height * (0.62 - wave - (latNorm % 0.22));
      final p = Offset(t * size.width, y.clamp(4, size.height - 4));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.9),
    );
    canvas.drawLine(
      Offset(0, size.height - 2),
      Offset(size.width, size.height - 2),
      Paint()
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) =>
      oldDelegate.route != route || oldDelegate.accent != accent;
}
