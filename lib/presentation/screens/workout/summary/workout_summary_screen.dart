import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final String sessionId;
  final String activityType;
  final String trackingMode;
  final int durationSeconds;
  final double distanceMeters;

  /// Session-average speed in km/h — the same value shown on the record screen.
  final double avgSpeedKmh;
  final int calories;

  /// GPS route collected during the session (outdoor only).
  /// Defaults to empty so existing callers don’t break.
  final List<LatLng> routePoints;

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
  });

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = distanceMeters / 1000;
    final isOutdoor = trackingMode == 'outdoor';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Workout Summary'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Activity Icon / Map Header
            SizedBox(
              height: 250,
              width: double.infinity,
              child: isOutdoor && routePoints.length >= 2
                  ? _RouteMap(routePoints: routePoints)
                  : Container(
                      color: Colors.blue[50],
                      child: Center(
                        child: Icon(
                          _getActivityIcon(activityType),
                          size: 120,
                          color: Colors.blue[300],
                        ),
                      ),
                    ),
            ),

            // Main Stats Card
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getActivityIcon(activityType),
                          color: const Color(0xff18b0e8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activityType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Hero: distance
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          distanceKm.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, left: 8),
                          child: Text(
                            'km',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Secondary stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'TIME',
                          value: _formatDuration(durationSeconds),
                        ),
                        _StatItem(
                          label: 'AVG SPEED',
                          // Display in km/h with 1 decimal — same format as record screen.
                          value: '${avgSpeedKmh.toStringAsFixed(1)} km/h',
                        ),
                        _StatItem(label: 'CALORIES', value: '$calories kcal'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Navigate to detailed analysis screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Detailed view coming soon!'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff18b0e8),
                        side: const BorderSide(
                          color: Color(0xff18b0e8),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'View Analysis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Saved to Server! 🎉'),
                            backgroundColor: Colors.green[600],
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff18b0e8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Save to Server',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ─── Route map widget ─────────────────────────────────────────────────────────

/// Renders the GPS route recorded during an outdoor workout session.
/// Auto-fits the camera to show the entire polyline with padding.
class _RouteMap extends StatelessWidget {
  final List<LatLng> routePoints;

  const _RouteMap({required this.routePoints});

  /// Compute a bounding box from the route points and add padding.
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

    // Add ~10% padding around the bounding box
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

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(20),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none, // static snapshot — no pan/zoom
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fitness_exercise_application',
          maxZoom: 19,
        ),

        // Route polyline
        PolylineLayer(
          polylines: [
            Polyline(
              points: routePoints,
              strokeWidth: 5.0,
              color: const Color(0xff18b0e8),
            ),
          ],
        ),

        // Start + end markers
        MarkerLayer(
          markers: [
            // Start marker (green flag)
            Marker(
              point: routePoints.first,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.flag, color: Colors.white, size: 18),
              ),
            ),

            // End marker (blue dot)
            Marker(
              point: routePoints.last,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xff18b0e8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff18b0e8).withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_score,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
