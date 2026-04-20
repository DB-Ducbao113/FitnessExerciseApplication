import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackingMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String activityType;
  final LatLng? initialPosition;
  final LatLng? currentLocation;
  final LatLng? gpsGapMarker;
  final List<GpsGapSegment> gpsGapSegments;
  final bool isGpsSignalWeak;
  final bool followUser;
  final int recenterRequestId;
  final bool showRoute;
  final VoidCallback? onUserGesturePan;

  const TrackingMapWidget({
    super.key,
    required this.routePoints,
    this.routeSegments = const [],
    required this.activityType,
    this.initialPosition,
    this.currentLocation,
    this.gpsGapMarker,
    this.gpsGapSegments = const [],
    this.isGpsSignalWeak = false,
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
  List<LatLng> _cachedDisplayRoute = const <LatLng>[];
  List<List<LatLng>> _cachedDisplaySegments = const <List<LatLng>>[];
  int? _zoomBucket;

  static const LatLng _defaultCenter = LatLng(10.7769, 106.7009);
  static const _routeGlow = Color(0x6600F0FF);
  static const _routeCore = Color(0xFF00E5FF);
  static const _routeHighlight = Color(0xCCB4F7FF);
  static const _gapRoute = Color(0x99C7D0DB);
  static const _gapRouteHighlight = Color(0xCCEEF2F7);
  static Duration get _cameraThrottle => kDebugLocationMode
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 160);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _refreshDisplayRoute();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TrackingMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showRoute != oldWidget.showRoute ||
        widget.activityType != oldWidget.activityType ||
        !listEquals(widget.routePoints, oldWidget.routePoints) ||
        !_segmentsEqual(widget.routeSegments, oldWidget.routeSegments)) {
      _refreshDisplayRoute();
    }

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
    _mapController.move(target, _targetZoom);
  }

  double get _targetZoom {
    final activity = widget.activityType.toLowerCase();
    final hasRoute = widget.showRoute && widget.routePoints.length > 2;

    switch (activity) {
      case 'walking':
        return hasRoute ? 18.7 : 18.95;
      case 'cycling':
        return hasRoute ? 17.75 : 18.05;
      case 'running':
      default:
        return hasRoute ? 18.3 : 18.6;
    }
  }

  LatLng get _initialCenter =>
      widget.currentLocation ??
      widget.initialPosition ??
      (widget.routePoints.isNotEmpty
          ? widget.routePoints.last
          : _defaultCenter);

  LatLng? get _markerPosition =>
      widget.currentLocation ?? widget.initialPosition;

  void _refreshDisplayRoute() {
    if (!widget.showRoute || widget.routePoints.length < 2) {
      _cachedDisplayRoute = widget.routePoints;
      _cachedDisplaySegments = widget.routeSegments;
      return;
    }

    final liveRoute = List<LatLng>.from(widget.routePoints);
    _cachedDisplayRoute = _downsampleForRender(
      liveRoute,
      zoomBucket: _zoomBucket ?? _zoomBucketFor(_targetZoom),
    );
    if (widget.routeSegments.isEmpty) {
      _cachedDisplaySegments = [_cachedDisplayRoute];
      return;
    }
    _cachedDisplaySegments = widget.routeSegments
        .map(
          (segment) => _downsampleForRender(
            List<LatLng>.from(segment),
            zoomBucket: _zoomBucket ?? _zoomBucketFor(_targetZoom),
          ),
        )
        .where((segment) => segment.length >= 2)
        .toList();
  }

  bool _segmentsEqual(List<List<LatLng>> a, List<List<LatLng>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  int _zoomBucketFor(double zoom) {
    if (zoom >= 18.5) return 4;
    if (zoom >= 17.0) return 3;
    if (zoom >= 15.0) return 2;
    if (zoom >= 13.0) return 1;
    return 0;
  }

  List<LatLng> _downsampleForRender(
    List<LatLng> points, {
    required int zoomBucket,
  }) {
    if (points.length <= 1400) return List<LatLng>.from(points);

    final targetCount = switch (zoomBucket) {
      4 =>
        points.length > 1600
            ? 160
            : points.length > 900
            ? 200
            : 260,
      3 =>
        points.length > 1600
            ? 220
            : points.length > 900
            ? 280
            : 340,
      2 =>
        points.length > 1600
            ? 300
            : points.length > 900
            ? 360
            : 430,
      1 =>
        points.length > 1600
            ? 380
            : points.length > 900
            ? 460
            : 560,
      _ =>
        points.length > 1600
            ? 480
            : points.length > 900
            ? 560
            : 680,
    };
    final stride = (points.length / targetCount).ceil();
    final reduced = <LatLng>[];
    for (var i = 0; i < points.length; i += stride) {
      reduced.add(points[i]);
    }
    if (reduced.last != points.last) {
      reduced.add(points.last);
    }
    return reduced;
  }

  @override
  Widget build(BuildContext context) {
    final displayRoute = widget.showRoute
        ? _cachedDisplayRoute
        : const <LatLng>[];
    final displaySegments = widget.showRoute
        ? _cachedDisplaySegments
        : const <List<LatLng>>[];
    final useLitePolyline = displayRoute.length > 450;

    if (kDebugMode) {
      debugPrint(
        '[Map] rebuild marker=${_markerPosition != null} routePoints=${widget.routePoints.length} displayRoute=${displayRoute.length} showRoute=${widget.showRoute} follow=${widget.followUser}',
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _targetZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapEvent: (event) {
              final nextZoomBucket = _zoomBucketFor(event.camera.zoom);
              if (nextZoomBucket != _zoomBucket) {
                setState(() {
                  _zoomBucket = nextZoomBucket;
                  _refreshDisplayRoute();
                });
              }
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
              maxZoom: 20,
            ),
            if (widget.showRoute && displaySegments.isNotEmpty)
              PolylineLayer(
                polylines: [
                  for (final segment in displaySegments) ...[
                    if (!useLitePolyline)
                      Polyline(
                        points: segment,
                        strokeWidth: 16,
                        color: _routeGlow,
                      ),
                    Polyline(
                      points: segment,
                      strokeWidth: useLitePolyline ? 5 : 7,
                      color: _routeCore,
                    ),
                    if (!useLitePolyline)
                      Polyline(
                        points: segment,
                        strokeWidth: 2,
                        color: _routeHighlight,
                      ),
                  ],
                  for (final gap in widget.gpsGapSegments) ...[
                    Polyline(
                      points: [gap.start, gap.end],
                      strokeWidth: 5,
                      color: _gapRoute,
                    ),
                    if (!useLitePolyline)
                      Polyline(
                        points: [gap.start, gap.end],
                        strokeWidth: 1.6,
                        color: _gapRouteHighlight,
                      ),
                  ],
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.showRoute && displayRoute.isNotEmpty)
                  Marker(
                    point: displayRoute.first,
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
                if (widget.gpsGapMarker != null)
                  Marker(
                    point: widget.gpsGapMarker!,
                    width: 38,
                    height: 38,
                    child: const _GpsGapMarker(),
                  ),
              ],
            ),
          ],
        ),
        if (widget.isGpsSignalWeak)
          const Positioned(top: 18, right: 18, child: _GpsWeakBadge()),
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

class _GpsGapMarker extends StatelessWidget {
  const _GpsGapMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF5).withValues(alpha: 0.94),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCFD8E3).withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.bolt_rounded, color: Color(0xFF6C7A89), size: 18),
    );
  }
}

class _GpsWeakBadge extends StatelessWidget {
  const _GpsWeakBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE61E2834),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x55FFB85C)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_off_rounded, size: 14, color: Color(0xFFFFB85C)),
            SizedBox(width: 6),
            Text(
              'Weak GPS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
