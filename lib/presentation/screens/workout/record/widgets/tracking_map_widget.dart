import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Map widget that always renders, regardless of indoor/outdoor mode.
/// [showRoute] controls whether the polyline is drawn (outdoor) or hidden (indoor).
/// [currentLocation] is always shown as a marker when not null.
class TrackingMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng? currentLocation;
  final bool isAutoFollow;
  final bool showRoute; // false in indoor mode
  final VoidCallback? onPan;

  const TrackingMapWidget({
    super.key,
    required this.routePoints,
    this.currentLocation,
    this.isAutoFollow = true,
    this.showRoute = true,
    this.onPan,
  });

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget> {
  late final MapController _mapController;
  DateTime? _lastCameraMove;

  static const double _defaultZoom = 17.0;
  static const LatLng _defaultCenter = LatLng(
    10.7769,
    106.7009,
  ); // HCMC fallback
  static const Duration _cameraThrottle = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TrackingMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isAutoFollow) return;
    if (widget.currentLocation == null) return;
    if (widget.currentLocation == oldWidget.currentLocation) return;

    // Throttle camera moves to max once per 2 seconds
    final now = DateTime.now();
    if (_lastCameraMove != null &&
        now.difference(_lastCameraMove!) < _cameraThrottle) {
      return;
    }
    _lastCameraMove = now;
    _mapController.move(widget.currentLocation!, _defaultZoom);
  }

  LatLng get _center =>
      widget.currentLocation ??
      (widget.routePoints.isNotEmpty
          ? widget.routePoints.last
          : _defaultCenter);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: _defaultZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapEvent: (event) {
          if (event is MapEventMove &&
              event.source != MapEventSource.mapController) {
            widget.onPan?.call();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fitness_exercise_application',
          maxZoom: 19,
        ),

        // Polyline — only in outdoor mode
        if (widget.showRoute && widget.routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints,
                strokeWidth: 5.0,
                color: const Color(0xff18b0e8),
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            // Start marker — shown only when outdoor route exists
            if (widget.showRoute && widget.routePoints.isNotEmpty)
              Marker(
                point: widget.routePoints.first,
                width: 36,
                height: 36,
                child: _StartMarker(),
              ),

            // Current position — always shown when available
            if (widget.currentLocation != null)
              Marker(
                point: widget.currentLocation!,
                width: 44,
                height: 44,
                child: _CurrentLocationMarker(),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Marker widgets ───────────────────────────────────────────────────────────

class _StartMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.flag, color: Colors.white, size: 18),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff18b0e8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff18b0e8).withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 3,
          ),
        ],
      ),
    );
  }
}
