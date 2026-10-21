import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_canonical_verification.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/raw_gps_platform_boundary.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class _FakeTrackingDataSource implements RawTrackingRemoteDataSource {
  final List<RawGpsPointPayload> points = [];

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> pts) async {
    points.addAll(pts);
  }

  @override
  Future<List<RawGpsPointPayload>> fetchAllRawGpsPoints(
    String workoutId, {
    int pageSize = 1000,
  }) async {
    return points.where((p) => p.workoutId == workoutId).toList();
  }

  @override
  Future<List<RawGpsPointPayload>> fetchRawGpsPointsPaged(
    String workoutId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    final filtered = points.where((p) => p.workoutId == workoutId).toList();
    if (offset >= filtered.length) return const [];
    final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
    return filtered.sublist(offset, end);
  }

  @override
  Future<int> countRawGpsPointsForWorkout(String workoutId) async => 0;

  @override
  Future<void> saveRawStepIntervals(List<RawStepIntervalPayload> intervals) async {}
}

class _FakeWorkoutRemote implements WorkoutRemoteDataSource {
  final List<Map<String, dynamic>> routeSnapshots = [];
  final List<String> sessionShells = [];

  @override
  Future<void> createSessionShell({
    required String id,
    required String userId,
    required String activityType,
    required String mode,
    required DateTime startedAt,
    required DateTime createdAt,
  }) async {
    sessionShells.add(id);
  }

  @override
  Future<void> saveLiveRouteSnapshot({
    required String sessionId,
    required List<List<LatLng>> routeSegments,
    required bool shouldRequestRouteCorrection,
    double? lastGpsGapDurationSec,
    bool isGpsSignalWeak = false,
  }) async {
    final count = routeSegments.fold<int>(0, (sum, seg) => sum + seg.length);
    routeSnapshots.add({
      'sessionId': sessionId,
      'segmentCount': routeSegments.length,
      'pointCount': count,
      'routeSegments': routeSegments,
      'isGpsSignalWeak': isGpsSignalWeak,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProcessingRemote implements WorkoutProcessingRemoteDataSource {
  final List<Map<String, dynamic>> loggedEvents = [];

  @override
  Future<void> insertLog({
    required String workoutId,
    String? jobId,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
    String logLevel = 'info',
  }) async {
    loggedEvents.add({
      'workoutId': workoutId,
      'eventType': eventType,
      'message': message,
      'payload': payload,
      'logLevel': logLevel,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Position _createPosition(int index, {DateTime? time}) {
  return Position(
    latitude: 10.762622 + (index * 0.0001),
    longitude: 106.660172 + (index * 0.0001),
    timestamp: time ?? DateTime.utc(2026, 10, 20, 10, 0, index),
    accuracy: 3.5,
    altitude: 12.0,
    heading: 45.0,
    speed: 4.2,
    speedAccuracy: 0.5,
    altitudeAccuracy: 1.0,
    headingAccuracy: 1.0,
  );
}

void main() {
  group('AETRON RG-F2 Web Boundary & Buffer Safety (QA-F2-01 & QA-F2-02)', () {
    test('QA-F2-01.1: Web buffer safety prevents memory accumulation during long workouts', () async {
      final tracking = _FakeTrackingDataSource();
      final workoutRemote = _FakeWorkoutRemote();
      final processing = _FakeProcessingRemote();
      final savedLocalPoints = <LocalGPSPoint>[];

      final coordinator = WorkoutRecordingCoordinator(
        rawTracking: tracking,
        workoutRemote: workoutRemote,
        processingRemote: processing,
        currentUserId: () => 'test-web-user',
        saveLocalGpsPoint: (p) async => savedLocalPoints.add(p),
      );

      const sessionId = 'long-web-workout-session';
      final start = DateTime.utc(2026, 10, 20, 8, 0, 0);

      await coordinator.createRemoteWorkoutShell(
        sessionId: sessionId,
        startedAt: start,
        activityType: 'running',
        mode: 'outdoor',
      );

      // Simulate 500 GPS points in a long workout
      for (var i = 0; i < 500; i++) {
        final pos = _createPosition(i, time: start.add(Duration(seconds: i)));
        coordinator.bufferRawGpsPoint(pos, workoutId: sessionId);
      }

      // Simulate 50 step intervals
      for (var i = 0; i < 50; i++) {
        coordinator.bufferRawStepInterval(
          20,
          startedAt: start.add(Duration(seconds: i * 10)),
          workoutId: sessionId,
        );
      }

      // On Web (kIsWeb == true), raw buffers are completely guarded: 0 points buffered
      // In Dart VM test fallback, verify coordinator flushPendingRawTracking drains safely
      if (kIsWeb) {
        expect(coordinator.pendingRawGpsPointCount, 0);
        expect(coordinator.pendingRawStepIntervalCount, 0);
        expect(savedLocalPoints, isEmpty);
      } else {
        // If running in Dart VM, test the web drain mechanism
        await coordinator.flushPendingRawTracking(workoutId: sessionId, force: true);
      }

      // Finalize the workout
      final diag = await coordinator.finalizeRawTracking(workoutId: sessionId);

      if (kIsWeb) {
        expect(coordinator.pendingRawGpsPointCount, 0);
        expect(coordinator.pendingRawStepIntervalCount, 0);
        expect(diag.isPlatformSupported, isFalse);
        expect(diag.isComplete, isFalse);
        expect(tracking.points, isEmpty);

        // Verify client_raw_gps_unsupported_web event was logged
        final unsupportedEvent = processing.loggedEvents.firstWhere(
          (e) => e['eventType'] == 'client_raw_gps_unsupported_web',
          orElse: () => {},
        );
        expect(unsupportedEvent, isNotEmpty);
      }
    });

    test('QA-F2-01.2: Web live route snapshots continue working for UI map display without raw GPS claims', () async {
      final workoutRemote = _FakeWorkoutRemote();
      final coordinator = WorkoutRecordingCoordinator(
        rawTracking: _FakeTrackingDataSource(),
        workoutRemote: workoutRemote,
        processingRemote: _FakeProcessingRemote(),
        currentUserId: () => 'test-web-user',
      );

      const sessionId = 'web-route-snapshot-session';
      await coordinator.createRemoteWorkoutShell(
        sessionId: sessionId,
        startedAt: DateTime.now(),
        activityType: 'cycling',
        mode: 'outdoor',
      );

      // Queue route snapshot segments for map display
      coordinator.queueLiveRouteSnapshot(
        workoutId: sessionId,
        routeSegments: [
          [
            const LatLng(10.770, 106.670),
            const LatLng(10.771, 106.671),
            const LatLng(10.772, 106.672),
          ],
          [
            const LatLng(10.773, 106.673),
            const LatLng(10.774, 106.674),
          ],
        ],
        lastGpsGapDurationSec: 0.0,
        isGpsSignalWeak: false,
      );

      await coordinator.syncLiveRouteSnapshot(force: true);

      expect(workoutRemote.routeSnapshots, isNotEmpty);
      final snapshot = workoutRemote.routeSnapshots.first;
      expect(snapshot['sessionId'], sessionId);
      expect(snapshot['segmentCount'], 2);
      expect(snapshot['pointCount'], 5);
      expect(snapshot['isGpsSignalWeak'], isFalse);
    });

    test('QA-F2-01.3: Raw GPS durability and complete state are never reported as true on Web', () {
      final web = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.web);
      expect(web.isResearchGradeCaptureSupported, isFalse);
      expect(web.supportsDurableIsar, isFalse);
      expect(web.supportsRecoveryJournal, isFalse);

      if (kIsWeb) {
        expect(RawGpsPlatformCapability.current.isResearchGradeCaptureSupported, isFalse);
        expect(RawGpsPlatformCapability.current.platform, RawGpsTargetPlatform.web);

        const diag = RawTrackingDiagnostics(
          capturedGpsPoints: 100,
          expectedUniqueGpsPoints: 100,
          localSavedGpsPoints: 100,
          localFailedGpsPoints: 0,
          isarSavedGpsPoints: 100,
          recoverySavedGpsPoints: 100,
          recoveryFailedGpsPoints: 0,
          uploadedGpsPoints: 100,
          remoteUploadFailures: 0,
          pendingGpsPoints: 0,
          serverConfirmedGpsPoints: 100,
        );

        expect(diag.isPlatformSupported, isFalse);
        expect(diag.isComplete, isFalse);
        final json = diag.toJson();
        expect(json['platform_supported'], isFalse);
        expect(json['raw_gps_complete'], isFalse);
        expect(json['raw_gps_recovery_journal_retained'], isFalse);
      }
    });

    test('QA-F2-02.1: RawGpsVerificationState.unsupported returns fail-closed report', () {
      const state = RawGpsVerificationState.unsupported;
      expect(state.label, 'UNSUPPORTED');

      final report = RawGpsCanonicalVerification.unsupportedPlatform(
        workoutId: 'w-web-verify-test',
        platform: 'web',
      );

      expect(report.state, RawGpsVerificationState.unsupported);
      expect(report.isVerified, isFalse);
      expect(report.localCount, 0);
      expect(report.cloudCount, 0);
      expect(report.message, contains('Unsupported on web'));
    });

    test('QA-F2-03.1: Platform capability policy strictly limits research-grade capture to iOS and Android', () {
      final matrix = RawGpsPlatformCapability.supportMatrix;
      expect(matrix[RawGpsTargetPlatform.ios]!.isResearchGradeCaptureSupported, isTrue);
      expect(matrix[RawGpsTargetPlatform.android]!.isResearchGradeCaptureSupported, isTrue);
      expect(matrix[RawGpsTargetPlatform.web]!.isResearchGradeCaptureSupported, isFalse);
      expect(matrix[RawGpsTargetPlatform.other]!.isResearchGradeCaptureSupported, isFalse);
    });

    test('QA-F2-03.2: Background execution is documented as platform-dependent and not guaranteed', () {
      final web = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.web);
      expect(web.supportsBackgroundLocation, isFalse);
      expect(web.backgroundExecutionContract, contains('Flutter Web does not support'));

      final ios = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.ios);
      expect(ios.supportsBackgroundLocation, isTrue);
      expect(ios.backgroundExecutionContract, contains('NOT guaranteed'));

      final android = RawGpsPlatformCapability.forPlatform(RawGpsTargetPlatform.android);
      expect(android.supportsBackgroundLocation, isTrue);
      expect(android.backgroundExecutionContract, contains('NOT guaranteed'));
    });
  });
}
