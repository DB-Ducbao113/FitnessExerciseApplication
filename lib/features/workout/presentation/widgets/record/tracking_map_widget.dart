import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackingMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng? initialPosition;
  final LatLng? currentLocation;
  final bool followUser;
  final int recenterRequestId;
  final bool showRoute;
  final VoidCallback? onUserGesturePan;

  const TrackingMapWidget({
    super.key,
    required this.routePoints,
    this.initialPosition,
    this.currentLocation,
    this.followUser = true,
    this.recenterRequestId = 0,
    this.showRoute = true,
    this.onUserGesturePan,
  });

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget> {
  late final MapController _mapController;
  DateTime? _lastCameraMove;
  bool _initialCameraSet = false;

  static const double _defaultZoom = 17.0;
  static const LatLng _defaultCenter = LatLng(10.7769, 106.7009);
  static const Duration _cameraThrottle = Duration(milliseconds: 400);

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

    if (!_initialCameraSet &&
        widget.initialPosition != null &&
        oldWidget.initialPosition == null) {
      _initialCameraSet = true;
      _recenterToCurrent(force: true);
      return;
    }

    if (widget.recenterRequestId != oldWidget.recenterRequestId) {
      _recenterToCurrent(force: true);
      return;
    }

    if (!widget.followUser) return;

    final target = widget.currentLocation ?? widget.initialPosition;
    final prevTarget = oldWidget.currentLocation ?? oldWidget.initialPosition;
    if (target == null || target == prevTarget) return;

    _recenterToCurrent();
  }

  void _recenterToCurrent({bool force = false}) {
    final target = widget.currentLocation ?? widget.initialPosition;
    if (target == null) return;

    final now = DateTime.now();
    if (!force &&
        _lastCameraMove != null &&
        now.difference(_lastCameraMove!) < _cameraThrottle) {
      return;
    }

    _lastCameraMove = now;
    _mapController.move(target, _defaultZoom);
  }

  LatLng get _initialCenter =>
      widget.currentLocation ??
      widget.initialPosition ??
      (widget.routePoints.isNotEmpty
          ? widget.routePoints.last
          : _defaultCenter);

  LatLng? get _markerPosition =>
      widget.currentLocation ?? widget.initialPosition;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint(
        '[Map] rebuild marker=${_markerPosition != null} routePoints=${widget.routePoints.length} showRoute=${widget.showRoute} follow=${widget.followUser}',
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _defaultZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapEvent: (event) {
          if (event is MapEventMove &&
              event.source != MapEventSource.mapController) {
            widget.onUserGesturePan?.call();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fitness_exercise_application',
          maxZoom: 19,
        ),
        if (widget.showRoute && widget.routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints,
                strokeWidth: 5,
                color: const Color(0xff18b0e8),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.showRoute && widget.routePoints.isNotEmpty)
              Marker(
                point: widget.routePoints.first,
                width: 28,
                height: 28,
                child: const _StartMarker(),
              ),
            if (_markerPosition != null)
              Marker(
                point: _markerPosition!,
                width: 26,
                height: 26,
                child: const _CurrentLocationMarker(),
              ),
          ],
        ),
      ],
    );
  }
}

class _StartMarker extends StatelessWidget {
  const _StartMarker();

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
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Accuracy ring
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xff18b0e8).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        // Center blue dot
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xff18b0e8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff18b0e8).withValues(alpha: 0.45),
                blurRadius: 6,
                spreadRadius: 1.5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
