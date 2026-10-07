import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:latlong2/latlong.dart';

/// Container mutable hiệu năng cao quản lý pipeline tọa độ GPS theo thời gian thực (1Hz)
/// với chi phí thêm điểm O(1), phục vụ snapshot định kỳ (mỗi 5s) cho UI/Map
/// và chuẩn bị sẵn hạ tầng tích hợp EKF state (x, P).
class GpsPipeline {
  // Bộ đệm mutable O(1)
  final List<LatLng> _filteredRoutePoints = [];
  final List<LatLng> _smoothedRoutePoints = [];
  final List<LatLng> _routePoints = [];
  final List<List<LatLng>> _routeSegments = [];
  final List<List<LatLng>> _smoothedRouteSegments = [];
  final List<GpsGapSegment> _gpsGapSegments = [];
  final List<GpsValidationDebugEntry> _gpsDebugEntries = [];

  // EKF state container (x, P)
  final ExtendedKalmanFilter _ekf = ExtendedKalmanFilter();
  ExtendedKalmanFilter get ekf => _ekf;

  bool _hasPendingChanges = false;
  bool get hasPendingChanges => _hasPendingChanges;

  List<LatLng> get filteredRoutePoints => _filteredRoutePoints;
  List<LatLng> get smoothedRoutePoints => _smoothedRoutePoints;
  List<LatLng> get routePoints => _routePoints;
  List<List<LatLng>> get routeSegments => _routeSegments;
  List<List<LatLng>> get smoothedRouteSegments => _smoothedRouteSegments;
  List<GpsGapSegment> get gpsGapSegments => _gpsGapSegments;
  List<GpsValidationDebugEntry> get gpsDebugEntries => _gpsDebugEntries;

  int get totalRoutePointsCount => _routePoints.length;

  /// Khởi tạo hoặc re-seed điểm đầu tiên cho pipeline
  void seedRoute(LatLng initialPoint) {
    _filteredRoutePoints.clear();
    _smoothedRoutePoints.clear();
    _routePoints.clear();
    _routeSegments.clear();
    _smoothedRouteSegments.clear();
    _gpsGapSegments.clear();
    _gpsDebugEntries.clear();

    _filteredRoutePoints.add(initialPoint);
    _smoothedRoutePoints.add(initialPoint);
    _routePoints.add(initialPoint);
    _routeSegments.add([initialPoint]);
    _smoothedRouteSegments.add([initialPoint]);

    _ekf.init(initialPoint: initialPoint);
    _hasPendingChanges = true;
  }

  /// Thêm điểm GPS đã được duyệt vào bộ đệm nội bộ với độ phức tạp O(1)
  void appendAcceptedSegment({
    required LatLng routeCandidate,
    required LatLng displayRoutePoint,
    required bool shouldBreakRouteForDisplay,
    required double gpsGapDurationSec,
    required bool shouldAppendSmoothedPoint,
  }) {
    final lastRoutePoint = _filteredRoutePoints.isNotEmpty
        ? _filteredRoutePoints.last
        : null;

    _filteredRoutePoints.add(routeCandidate);
    _routePoints.add(routeCandidate);

    if (shouldBreakRouteForDisplay && lastRoutePoint != null) {
      _gpsGapSegments.add(
        GpsGapSegment(
          start: lastRoutePoint,
          end: routeCandidate,
          durationSec: gpsGapDurationSec,
        ),
      );
      _routeSegments.add([routeCandidate]);
      _smoothedRouteSegments.add([displayRoutePoint]);
    } else if (_routeSegments.isEmpty) {
      _routeSegments.add([routeCandidate]);
      _smoothedRouteSegments.add([displayRoutePoint]);
    } else {
      _routeSegments.last.add(routeCandidate);
      if (_smoothedRouteSegments.isEmpty) {
        _smoothedRouteSegments.add([displayRoutePoint]);
      } else if (shouldAppendSmoothedPoint) {
        _smoothedRouteSegments.last.add(displayRoutePoint);
      }
    }

    if (_smoothedRoutePoints.isEmpty ||
        shouldAppendSmoothedPoint ||
        shouldBreakRouteForDisplay) {
      _smoothedRoutePoints.add(displayRoutePoint);
    }

    _hasPendingChanges = true;
  }

  /// Thêm debug entry (giới hạn tối đa entry để tránh leak bộ nhớ)
  void addDebugEntry(GpsValidationDebugEntry entry, {int maxEntries = 80}) {
    _gpsDebugEntries.add(entry);
    if (_gpsDebugEntries.length > maxEntries) {
      _gpsDebugEntries.removeRange(0, _gpsDebugEntries.length - maxEntries);
    }
  }

  /// Tạo snapshot bất biến (unmodifiable / deep copy an toàn) để đồng bộ vào Riverpod State
  GpsRouteSnapshot createSnapshot() {
    _hasPendingChanges = false;
    return GpsRouteSnapshot(
      filteredRoutePoints: List<LatLng>.unmodifiable(_filteredRoutePoints),
      smoothedRoutePoints: List<LatLng>.unmodifiable(_smoothedRoutePoints),
      routePoints: List<LatLng>.unmodifiable(_routePoints),
      routeSegments: List<List<LatLng>>.unmodifiable(
        _routeSegments
            .where((s) => s.isNotEmpty)
            .map((s) => List<LatLng>.unmodifiable(s)),
      ),
      smoothedRouteSegments: List<List<LatLng>>.unmodifiable(
        _smoothedRouteSegments
            .where((s) => s.isNotEmpty)
            .map((s) => List<LatLng>.unmodifiable(s)),
      ),
      gpsGapSegments: List<GpsGapSegment>.unmodifiable(_gpsGapSegments),
      gpsDebugEntries: List<GpsValidationDebugEntry>.unmodifiable(
        _gpsDebugEntries,
      ),
    );
  }

  /// Đặt lại toàn bộ pipeline
  void reset() {
    _filteredRoutePoints.clear();
    _smoothedRoutePoints.clear();
    _routePoints.clear();
    _routeSegments.clear();
    _smoothedRouteSegments.clear();
    _gpsGapSegments.clear();
    _gpsDebugEntries.clear();
    _ekf.reset();
    _hasPendingChanges = false;
  }
}

/// Dữ liệu snapshot bất biến của tuyến đường phục vụ UI và Finalizer
class GpsRouteSnapshot {
  final List<LatLng> filteredRoutePoints;
  final List<LatLng> smoothedRoutePoints;
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final List<List<LatLng>> smoothedRouteSegments;
  final List<GpsGapSegment> gpsGapSegments;
  final List<GpsValidationDebugEntry> gpsDebugEntries;

  const GpsRouteSnapshot({
    required this.filteredRoutePoints,
    required this.smoothedRoutePoints,
    required this.routePoints,
    required this.routeSegments,
    required this.smoothedRouteSegments,
    required this.gpsGapSegments,
    required this.gpsDebugEntries,
  });
}
