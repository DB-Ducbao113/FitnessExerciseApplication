import "dart:ui" as ui;
import "package:fitness_exercise_application/core/constants/debug_config.dart";
import "package:fitness_exercise_application/core/localization/app_translations.dart";
import "package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kAetronMapTypePrefKey = "aetron_preferred_map_type";

enum AppMapType {
  satellite,
  streets,
}

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
  final ImageProvider? avatarImage;
  final String initials;
  final AppLanguage currentLang;
  final double topControlOffset;

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
    this.avatarImage,
    this.initials = "A",
    this.currentLang = AppLanguage.vi,
    this.topControlOffset = 72,
  });

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _tiltController;
  late final Animation<double> _tiltAnimation;

  DateTime? _lastCameraMove;
  bool _initialCameraSet = false;
  bool _is3DMode = true;
  AppMapType _selectedMapType = AppMapType.satellite;
  List<LatLng> _cachedDisplayRoute = const <LatLng>[];
  List<List<LatLng>> _cachedDisplaySegments = const <List<LatLng>>[];
  int? _zoomBucket;

  static const LatLng _defaultCenter = LatLng(10.7769, 106.7009);

  static const _routeGlow = Color(0x6600E5FF);
  static const _routeCore = Color(0xFF00E5FF);
  static const _routeHighlight = Color(0xFFD4FBFF);
  static const _routeShadow = Color(0x40000000);

  static Duration get _cameraThrottle => kDebugLocationMode
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 160);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.44).animate(
      CurvedAnimation(parent: _tiltController, curve: Curves.easeOutCubic),
    );
    if (_is3DMode) {
      _tiltController.value = 1.0;
    }
    _refreshDisplayRoute();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kAetronMapTypePrefKey);
      if (saved != null && mounted) {
        setState(() {
          _selectedMapType = AppMapType.values.firstWhere(
            (e) => e.name == saved,
            orElse: () => AppMapType.satellite,
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  void _toggle3DMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _is3DMode = !_is3DMode;
      if (_is3DMode) {
        _tiltController.forward();
      } else {
        _tiltController.reverse();
      }
    });
  }

  void _openMapStylePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MapStylePickerSheet(
        currentType: _selectedMapType,
        currentLang: widget.currentLang,
        onSelectType: (type) async {
          setState(() {
            _selectedMapType = type;
          });
          Navigator.of(sheetContext).pop();
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(kAetronMapTypePrefKey, type.name);
          } catch (_) {}
        },
      ),
    );
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

    final target = widget.currentLocation ?? widget.initialPosition;
    final prevTarget = oldWidget.currentLocation ?? oldWidget.initialPosition;

    if (!_initialCameraSet && target != null) {
      _initialCameraSet = true;
      _recenterToCurrent(force: true);
      return;
    }

    if (widget.recenterRequestId != oldWidget.recenterRequestId) {
      _recenterToCurrent(force: true);
      return;
    }

    if (!widget.followUser) return;

    if (target == null || target == prevTarget) return;

    final now = DateTime.now();
    final last = _lastCameraMove;
    if (last == null || now.difference(last) >= _cameraThrottle) {
      _lastCameraMove = now;
      _mapController.move(target, _mapController.camera.zoom);
    }
  }

  void _recenterToCurrent({bool force = false}) {
    final target = widget.currentLocation ?? widget.initialPosition;
    if (target == null) return;
    final now = DateTime.now();
    final last = _lastCameraMove;
    if (!force && last != null && now.difference(last) < _cameraThrottle) {
      return;
    }
    _lastCameraMove = now;
    _initialCameraSet = true;
    final currentZoom = _mapController.camera.zoom;
    final zoom = currentZoom < 14.0 ? 17.2 : currentZoom;
    _mapController.move(target, zoom);
  }

  void _refreshDisplayRoute() {
    final raw = widget.routePoints;
    final rawSegments = widget.routeSegments;
    if (raw.isEmpty) {
      _cachedDisplayRoute = const <LatLng>[];
      _cachedDisplaySegments = const <List<LatLng>>[];
      return;
    }

    final zoom = _zoomBucket ?? 17;
    final tolerance = _simplificationTolerance(zoom);

    if (rawSegments.isNotEmpty) {
      final outSegments = <List<LatLng>>[];
      for (final segment in rawSegments) {
        if (segment.isEmpty) continue;
        final simplified = _simplifyPoints(segment, tolerance);
        if (simplified.isNotEmpty) {
          outSegments.add(simplified);
        }
      }
      _cachedDisplaySegments = outSegments;
      _cachedDisplayRoute = outSegments.isNotEmpty
          ? outSegments.expand((element) => element).toList()
          : _simplifyPoints(raw, tolerance);
      return;
    }

    _cachedDisplayRoute = _simplifyPoints(raw, tolerance);
    _cachedDisplaySegments = _cachedDisplayRoute.isNotEmpty
        ? <List<LatLng>>[_cachedDisplayRoute]
        : const <List<LatLng>>[];
  }

  bool _segmentsEqual(List<List<LatLng>> a, List<List<LatLng>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  double _simplificationTolerance(int zoom) {
    if (zoom >= 18) return 0.000006;
    if (zoom >= 16) return 0.000015;
    if (zoom >= 14) return 0.000035;
    return 0.00008;
  }

  List<LatLng> _simplifyPoints(List<LatLng> points, double tolerance) {
    if (points.length <= 2) return points;
    final sqTolerance = tolerance * tolerance;
    final result = <LatLng>[points.first];
    _douglasPeucker(
      points,
      0,
      points.length - 1,
      sqTolerance,
      result,
    );
    result.add(points.last);
    return result;
  }

  void _douglasPeucker(
    List<LatLng> points,
    int first,
    int last,
    double sqTolerance,
    List<LatLng> result,
  ) {
    var maxSqDist = 0.0;
    var index = first;

    final p1 = points[first];
    final p2 = points[last];

    for (var i = first + 1; i < last; i++) {
      final sqDist = _pointToSegmentDistanceSq(points[i], p1, p2);
      if (sqDist > maxSqDist) {
        maxSqDist = sqDist;
        index = i;
      }
    }

    if (maxSqDist > sqTolerance) {
      if (index - first > 1) {
        _douglasPeucker(points, first, index, sqTolerance, result);
      }
      result.add(points[index]);
      if (last - index > 1) {
        _douglasPeucker(points, index, last, sqTolerance, result);
      }
    }
  }

  double _pointToSegmentDistanceSq(LatLng p, LatLng p1, LatLng p2) {
    final x = p.longitude;
    final y = p.latitude;
    final x1 = p1.longitude;
    final y1 = p1.latitude;
    final x2 = p2.longitude;
    final y2 = p2.latitude;

    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      final px = x - x1;
      final py = y - y1;
      return px * px + py * py;
    }

    final t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);

    if (t < 0) {
      final px = x - x1;
      final py = y - y1;
      return px * px + py * py;
    }
    if (t > 1) {
      final px = x - x2;
      final py = y - y2;
      return px * px + py * py;
    }

    final projX = x1 + t * dx;
    final projY = y1 + t * dy;
    final px = x - projX;
    final py = y - projY;
    return px * px + py * py;
  }

  List<LatLng> _offsetShadowPoints(List<LatLng> pts) {
    return pts
        .map((p) => LatLng(p.latitude - 0.000035, p.longitude + 0.000025))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.currentLocation ??
        widget.initialPosition ??
        (widget.routePoints.isNotEmpty
            ? widget.routePoints.last
            : _defaultCenter);

    final displayRoute = _cachedDisplayRoute;
    final displaySegments = _cachedDisplaySegments.isNotEmpty
        ? _cachedDisplaySegments
        : (displayRoute.isNotEmpty
            ? <List<LatLng>>[displayRoute]
            : const <List<LatLng>>[]);

    final markerPos = widget.currentLocation ?? widget.initialPosition;
    final useLitePolyline =
        widget.routePoints.length > (kDebugLocationMode ? 250 : 700);

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _tiltAnimation,
          builder: (context, child) {
            final tilt = _tiltAnimation.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(tilt),
              child: child,
            );
          },
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 17.2,
              minZoom: 4,
              maxZoom: 20,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                final nextZoomBucket = camera.zoom.round();
                if (nextZoomBucket != _zoomBucket) {
                  setState(() {
                    _zoomBucket = nextZoomBucket;
                    _refreshDisplayRoute();
                  });
                }
                if (hasGesture) {
                  widget.onUserGesturePan?.call();
                }
              },
            ),
            children: [
              ..._buildMapTileLayers(_selectedMapType),
              if (widget.showRoute && displaySegments.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final segment in displaySegments) ...[
                      if (!useLitePolyline)
                        Polyline(
                          points: _offsetShadowPoints(segment),
                          strokeWidth: 9,
                          color: _routeShadow,
                        ),
                      if (!useLitePolyline)
                        Polyline(
                          points: segment,
                          strokeWidth: 16,
                          color: _routeGlow,
                        ),
                      Polyline(
                        points: segment,
                        strokeWidth: useLitePolyline ? 5.5 : 7.5,
                        gradientColors: useLitePolyline
                            ? null
                            : const [
                                Color(0xFF00E5FF),
                                Color(0xFF39F2B8),
                                Color(0xFF00E5FF),
                              ],
                        color: _routeCore,
                      ),
                      if (!useLitePolyline)
                        Polyline(
                          points: segment,
                          strokeWidth: 2.2,
                          color: _routeHighlight,
                        ),
                    ],
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (widget.showRoute && displayRoute.isNotEmpty)
                    Marker(
                      point: displayRoute.first,
                      width: 24,
                      height: 32,
                      alignment: Alignment.topCenter,
                      child: const _Start3DPinMarker(),
                    ),
                  if (markerPos != null)
                    Marker(
                      point: markerPos,
                      width: 40,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: _Aetron3DUserAvatarMarker(
                        avatarImage: widget.avatarImage,
                        initials: widget.initials,
                      ),
                    ),
                  if (widget.gpsGapMarker != null)
                    Marker(
                      point: widget.gpsGapMarker!,
                      width: 20,
                      height: 20,
                      child: const _GpsGapMarker(),
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: widget.topControlOffset,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Map3DPerspectiveOrb(
                is3D: _is3DMode,
                onTap: _toggle3DMode,
              ),
              const SizedBox(height: 10),
              _MapLayerPickerOrb(
                selectedType: _selectedMapType,
                onTap: _openMapStylePicker,
              ),
              if (widget.isGpsSignalWeak) ...[
                const SizedBox(height: 10),
                const _GpsWeakBadge(),
              ],
            ],
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
                    Colors.black.withValues(alpha: 0.32),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.40),
                  ],
                  stops: const [0.0, 0.14, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<Widget> _buildMapTileLayers(AppMapType type) {
  switch (type) {
    case AppMapType.satellite:
      return [
        TileLayer(
          urlTemplate:
              "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxZoom: 20,
          maxNativeZoom: 19,
        ),
        TileLayer(
          urlTemplate:
              "https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxZoom: 20,
          maxNativeZoom: 19,
        ),
      ];
    case AppMapType.streets:
      return [
        TileLayer(
          urlTemplate:
              "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxZoom: 20,
          maxNativeZoom: 19,
        ),
      ];
  }
}

class _Map3DPerspectiveOrb extends StatelessWidget {
  final bool is3D;
  final VoidCallback onTap;

  const _Map3DPerspectiveOrb({
    required this.is3D,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xE60A1320),
            border: Border.all(
              color: is3D
                  ? const Color(0xFF00E5FF)
                  : Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              if (is3D)
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              is3D ? "3D" : "2D",
              style: TextStyle(
                fontFamily: "Outfit",
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: is3D ? const Color(0xFF00E5FF) : Colors.white70,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLayerPickerOrb extends StatelessWidget {
  final AppMapType selectedType;
  final VoidCallback onTap;

  const _MapLayerPickerOrb({
    required this.selectedType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xE60A1320),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.layers_rounded,
              color: Color(0xFF00E5FF),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStylePickerSheet extends ConsumerWidget {
  final AppMapType currentType;
  final AppLanguage currentLang;
  final ValueChanged<AppMapType> onSelectType;

  const _MapStylePickerSheet({
    required this.currentType,
    required this.currentLang,
    required this.onSelectType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLang = ref.watch(appLanguageProvider);
    final isVi = activeLang == AppLanguage.vi;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1624),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0x4400E5FF), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.layers_rounded,
                  color: Color(0xFF00E5FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isVi ? "CHỌN KIỂU BẢN ĐỒ" : "SELECT MAP STYLE",
                style: const TextStyle(
                  fontFamily: "Outfit",
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isVi
                ? "Tùy chỉnh góc nhìn bản đồ phù hợp với sở thích của bạn:"
                : "Customize your map style to match your preference:",
            style: const TextStyle(
              fontFamily: "Outfit",
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          _buildMapOption(
            type: AppMapType.satellite,
            title: isVi ? "Ảnh Vệ Tinh 3D" : "3D Satellite Imagery",
            subtitle: isVi
                ? "Ảnh chụp thực tế độ phân giải cao"
                : "Photorealistic aerial satellite imagery",
            icon: Icons.satellite_alt_rounded,
            badge: isVi ? "CHÂN THỰC" : "REALISTIC",
          ),
          const SizedBox(height: 12),
          _buildMapOption(
            type: AppMapType.streets,
            title: isVi ? "Đường Phố Rõ Nét" : "Clean Street Map",
            subtitle: isVi
                ? "Bản đồ đường xá, công viên tinh tế"
                : "Clean minimal street & sports map",
            icon: Icons.map_rounded,
            badge: isVi ? "RÕ NÉT" : "CLEAN",
          ),
        ],
      ),
    );
  }

  Widget _buildMapOption({
    required AppMapType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
  }) {
    final isSelected = currentType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelectType(type);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                : const Color(0xFF131D2D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : const Color(0x3300E5FF),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF07101C),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00E5FF)
                        : Colors.white24,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isSelected
                        ? const Color(0xFF00E5FF)
                        : Colors.white70,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: "Outfit",
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF00E5FF)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontFamily: "Outfit",
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF00E5FF),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Aetron3DUserAvatarMarker extends StatefulWidget {
  final ImageProvider? avatarImage;
  final String initials;

  const _Aetron3DUserAvatarMarker({
    this.avatarImage,
    required this.initials,
  });

  @override
  State<_Aetron3DUserAvatarMarker> createState() =>
      _Aetron3DUserAvatarMarkerState();
}

class _Aetron3DUserAvatarMarkerState extends State<_Aetron3DUserAvatarMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final val = _pulseController.value;
            return Positioned(
              bottom: 0,
              child: Container(
                width: 32 + (val * 24),
                height: 10 + (val * 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(
                      alpha: (1.0 - val).clamp(0.0, 1.0) * 0.7,
                    ),
                    width: 1.5,
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.avatarImage != null
                      ? Image(image: widget.avatarImage!, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFF07101C),
                          child: Center(
                            child: Text(
                              widget.initials,
                              style: const TextStyle(
                                fontFamily: "Outfit",
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              CustomPaint(
                size: const Size(12, 7),
                painter: const _PinTipPainter(color: Color(0xFF00E5FF)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  const _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Start3DPinMarker extends StatelessWidget {
  const _Start3DPinMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: 14,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Positioned(
          top: 4,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2AF598), Color(0xFF00B86B)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2AF598).withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Colors.white,
              size: 16,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00E5FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.sensors_rounded,
        color: Color(0xFF00E5FF),
        size: 18,
      ),
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
              "Weak GPS",
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
