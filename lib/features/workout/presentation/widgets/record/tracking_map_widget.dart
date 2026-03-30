import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
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
  static const _routeGlow = Color(0x6600F0FF);
  static const _routeCore = Color(0xFF00E5FF);
  static const _routeHighlight = Color(0xCCB4F7FF);
  static Duration get _cameraThrottle => kDebugLocationMode
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 300);

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

    return Stack(
      children: [
        FlutterMap(
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
                    strokeWidth: 16,
                    color: _routeGlow,
                  ),
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 7,
                    color: _routeCore,
                  ),
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 2,
                    color: _routeHighlight,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.showRoute && widget.routePoints.isNotEmpty)
                  Marker(
                    point: widget.routePoints.first,
                    width: 34,
                    height: 34,
                    child: const _StartMarker(),
                  ),
                if (_markerPosition != null)
                  Marker(
                    point: _markerPosition!,
                    width: 42,
                    height: 42,
                    child: const _CurrentLocationMarker(),
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
                    Colors.black.withValues(alpha: 0.26),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.32),
                  ],
                  stops: const [0.0, 0.18, 0.62, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 1.15,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF05111D).withValues(alpha: 0.18),
                    const Color(0xFF02070D).withValues(alpha: 0.54),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
          ),
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2AF598), Color(0xFF12B886)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2AF598).withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
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
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB5F8FF), Color(0xFF00D8FF)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
