import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('WorkoutRecordingCoordinator raw GPS durability', () {
    test(
      'finalization reports captured, local, uploaded and server-confirmed counts',
      () async {
        final rawTracking = _FakeRawTrackingRemoteDataSource();
        final processing = _FakeWorkoutProcessingRemoteDataSource();
        final locallySaved = <LocalGPSPoint>[];
        final recoverySaved = <LocalGPSPoint>[];
        var recoveryDeleted = false;
        final coordinator = WorkoutRecordingCoordinator(
          rawTracking: rawTracking,
          workoutRemote: _FakeWorkoutRemoteDataSource(),
          processingRemote: processing,
          currentUserId: () => 'user-1',
          saveLocalGpsPoint: (point) async => locallySaved.add(point),
          saveRecoveryGpsPoint: (point) async => recoverySaved.add(point),
          deleteRecoveryGpsJournal: (_) async => recoveryDeleted = true,
        );
        addTearDown(coordinator.dispose);

        coordinator.bufferRawGpsPoint(_position(0), workoutId: _workoutId);
        coordinator.bufferRawGpsPoint(_position(1), workoutId: _workoutId);

        final result = await coordinator.finalizeRawTracking(
          workoutId: _workoutId,
        );

        expect(locallySaved, hasLength(2));
        expect(recoverySaved, hasLength(2));
        expect(recoveryDeleted, isFalse);
        expect(rawTracking.savedGpsPoints, hasLength(2));
        expect(result.capturedGpsPoints, 2);
        expect(result.localSavedGpsPoints, 2);
        expect(result.recoverySavedGpsPoints, 2);
        expect(result.localFailedGpsPoints, 0);
        expect(result.uploadedGpsPoints, 2);
        expect(result.pendingGpsPoints, 0);
        expect(result.serverConfirmedGpsPoints, 2);
        expect(result.isComplete, isTrue);
        expect(processing.logs.single.eventType, 'client_raw_gps_complete');
        expect(processing.logs.single.logLevel, 'info');
      },
    );

    test(
      'finalization preserves pending points and exposes every failure',
      () async {
        final rawTracking = _FakeRawTrackingRemoteDataSource(failUploads: true);
        final processing = _FakeWorkoutProcessingRemoteDataSource();
        final coordinator = WorkoutRecordingCoordinator(
          rawTracking: rawTracking,
          workoutRemote: _FakeWorkoutRemoteDataSource(),
          processingRemote: processing,
          currentUserId: () => 'user-1',
          saveLocalGpsPoint: (_) async => throw StateError('isar unavailable'),
          saveRecoveryGpsPoint: (_) async =>
              throw StateError('journal unavailable'),
          deleteRecoveryGpsJournal: (_) async {},
        );
        addTearDown(coordinator.dispose);

        coordinator.bufferRawGpsPoint(_position(0), workoutId: _workoutId);

        final result = await coordinator.finalizeRawTracking(
          workoutId: _workoutId,
        );

        expect(result.capturedGpsPoints, 1);
        expect(result.localSavedGpsPoints, 0);
        expect(result.localFailedGpsPoints, 1);
        expect(result.uploadedGpsPoints, 0);
        expect(result.remoteUploadFailures, 1);
        expect(result.pendingGpsPoints, 1);
        expect(result.serverConfirmedGpsPoints, 0);
        expect(result.isComplete, isFalse);
        expect(processing.logs.single.eventType, 'client_raw_gps_incomplete');
        expect(processing.logs.single.logLevel, 'warning');
      },
    );

    test(
      'processing payload carries unambiguous raw GPS diagnostics',
      () async {
        final rawTracking = _FakeRawTrackingRemoteDataSource();
        final processing = _FakeWorkoutProcessingRemoteDataSource();
        final coordinator = WorkoutRecordingCoordinator(
          rawTracking: rawTracking,
          workoutRemote: _FakeWorkoutRemoteDataSource(),
          processingRemote: processing,
          currentUserId: () => 'user-1',
          saveLocalGpsPoint: (_) async {},
          saveRecoveryGpsPoint: (_) async {},
          deleteRecoveryGpsJournal: (_) async {},
        );
        addTearDown(coordinator.dispose);

        coordinator.bufferRawGpsPoint(_position(0), workoutId: _workoutId);
        await coordinator.finalizeRawTracking(workoutId: _workoutId);
        await coordinator.enqueueProcessingForSession(_session());

        final payload = processing.enqueuedPayloads.single;
        expect(payload['raw_gps_captured_points'], 1);
        expect(payload['raw_gps_local_saved_points'], 1);
        expect(payload['raw_gps_pending_points'], 0);
        expect(payload['raw_gps_server_confirmed_points'], 1);
        expect(payload['raw_gps_complete'], isTrue);
      },
    );
  });
}

const _workoutId = '11111111-1111-4111-8111-111111111111';

Position _position(int seconds) {
  return Position(
    latitude: 10.738 + seconds * 0.00001,
    longitude: 106.625 + seconds * 0.00001,
    timestamp: DateTime.utc(2026, 10, 14, 1, 0, seconds),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 90,
    headingAccuracy: 0,
    speed: 4,
    speedAccuracy: 0,
  );
}

WorkoutSession _session() => WorkoutSession(
  id: _workoutId,
  userId: 'user-1',
  activityType: 'cycling',
  startedAt: DateTime.utc(2026, 10, 14, 1),
  endedAt: DateTime.utc(2026, 10, 14, 1, 5),
  durationSec: 300,
  movingTimeSec: 295,
  distanceKm: 1.5,
  steps: 0,
  avgSpeedKmh: 18,
  caloriesKcal: 80,
  mode: 'outdoor',
  createdAt: DateTime.utc(2026, 10, 14, 1),
);

SupabaseClient _client() =>
    SupabaseClient('https://example.supabase.co', 'test-anon-key');

class _FakeRawTrackingRemoteDataSource extends RawTrackingRemoteDataSource {
  _FakeRawTrackingRemoteDataSource({this.failUploads = false})
    : super(_client());

  final bool failUploads;
  final List<RawGpsPointPayload> savedGpsPoints = [];

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) async {
    if (failUploads) throw StateError('network unavailable');
    savedGpsPoints.addAll(points);
  }

  @override
  Future<int> countRawGpsPointsForWorkout(String workoutId) async {
    return savedGpsPoints.where((point) => point.workoutId == workoutId).length;
  }
}

class _FakeWorkoutRemoteDataSource extends WorkoutRemoteDataSource {
  _FakeWorkoutRemoteDataSource() : super(_client());
}

class _FakeWorkoutProcessingRemoteDataSource
    extends WorkoutProcessingRemoteDataSource {
  _FakeWorkoutProcessingRemoteDataSource() : super(_client());

  final List<_ProcessingLog> logs = [];
  final List<Map<String, dynamic>> enqueuedPayloads = [];

  @override
  Future<String?> enqueueDeterministicJob({
    required String workoutId,
    required Map<String, dynamic> payload,
  }) async {
    enqueuedPayloads.add(payload);
    return 'job-1';
  }

  @override
  Future<void> insertLog({
    required String workoutId,
    String? jobId,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
    String logLevel = 'info',
  }) async {
    logs.add(
      _ProcessingLog(
        eventType: eventType,
        logLevel: logLevel,
        payload: payload,
      ),
    );
  }
}

class _ProcessingLog {
  const _ProcessingLog({
    required this.eventType,
    required this.logLevel,
    required this.payload,
  });

  final String eventType;
  final String logLevel;
  final Map<String, dynamic> payload;
}
