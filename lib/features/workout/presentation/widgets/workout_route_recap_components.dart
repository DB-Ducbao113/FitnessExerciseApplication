import 'dart:math' as math;

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
    required this.footerText,
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
  final String footerText;

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
    final displaySegments = routeSegments.isEmpty
        ? [displayRoute]
        : routeSegments
              .where((segment) => segment.length >= 2)
              .map(
                (segment) => refineRouteForSavedDisplay(
                  segment,
                  activityType: activityType,
                ),
              )
              .toList();
    final bounds = _computeBounds(displayRoute);

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
            PolylineLayer(
              polylines: [
                for (final segment in displaySegments) ...[
                  Polyline(points: segment, strokeWidth: 18, color: glowColor),
                  Polyline(points: segment, strokeWidth: 8, color: accentColor),
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
                  width: 38,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      color: startColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
                Marker(
                  point: displayRoute.last,
                  width: 42,
                  height: 42,
                  child: Container(
                    decoration: BoxDecoration(
                      color: endColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
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
                    Colors.black.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.24),
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
        Positioned(
          right: 14,
          bottom: 14,
          child: _MapGlassBadge(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Text(
              footerText,
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
  }
}
