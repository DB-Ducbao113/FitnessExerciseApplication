import 'package:latlong2/latlong.dart';

class WorkoutResult {
  final double totalDistanceKm;
  final double averageSpeedKmH;
  final Duration duration;
  final List<LatLng> route;

  const WorkoutResult({
    required this.totalDistanceKm,
    required this.averageSpeedKmH,
    required this.duration,
    required this.route,
  });

  @override
  String toString() {
    return 'WorkoutResult(distance: ${totalDistanceKm.toStringAsFixed(2)}km, '
        'avgSpeed: ${averageSpeedKmH.toStringAsFixed(2)}km/h, '
        'duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s, '
        'points: ${route.length})';
  }
}
