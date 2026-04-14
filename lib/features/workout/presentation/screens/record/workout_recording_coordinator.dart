import 'dart:async';

import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final workoutRecordingCoordinatorProvider =
    Provider.autoDispose<WorkoutRecordingCoordinator>((ref) {
      return WorkoutRecordingCoordinator(
        rawTracking: ref.watch(rawTrackingRemoteDataSourceProvider),
        workoutRemote: ref.watch(workoutRemoteDataSourceProvider),
        processingRemote: ref.watch(workoutProcessingRemoteDataSourceProvider),
        currentUserId: () => ref.read(currentUserIdProvider),
      );
    });

class WorkoutRecordingCoordinator {
  WorkoutRecordingCoordinator({
    required RawTrackingRemoteDataSource rawTracking,
    required WorkoutRemoteDataSource workoutRemote,
    required WorkoutProcessingRemoteDataSource processingRemote,
    required String? Function() currentUserId,
  }) : _rawTracking = rawTracking,
       _workoutRemote = workoutRemote,
       _processingRemote = processingRemote,
       _currentUserId = currentUserId;

  final RawTrackingRemoteDataSource _rawTracking;
  final WorkoutRemoteDataSource _workoutRemote;
  final WorkoutProcessingRemoteDataSource _processingRemote;
  final String? Function() _currentUserId;

  static const int _kRawGpsFlushThreshold = 24;
  static const int _kRawStepFlushThreshold = 6;

  final List<_BufferedRawGpsPoint> _pendingRawGpsPoints = [];
  final List<_BufferedRawStepInterval> _pendingRawStepIntervals = [];

  DateTime? _lastRawStepIntervalEnd;
  bool _remoteWorkoutShellReady = false;
  bool _isFlushingRawGpsPoints = false;
  bool _isFlushingRawStepIntervals = false;

  int get pendingRawGpsPointCount => _pendingRawGpsPoints.length;
  int get pendingRawStepIntervalCount => _pendingRawStepIntervals.length;

  void reset() {
    _pendingRawGpsPoints.clear();
    _pendingRawStepIntervals.clear();
    _lastRawStepIntervalEnd = null;
    _remoteWorkoutShellReady = false;
    _isFlushingRawGpsPoints = false;
    _isFlushingRawStepIntervals = false;
  }

  Future<void> createRemoteWorkoutShell({
    required String? sessionId,
    required DateTime? startedAt,
    required String activityType,
    required String mode,
  }) async {
    final userId = _currentUserId();
    if (sessionId == null || startedAt == null || userId == null) return;

    try {
      await _workoutRemote.createSessionShell(
        id: sessionId,
        userId: userId,
        activityType: activityType,
        mode: mode,
        startedAt: startedAt,
        createdAt: startedAt,
      );
      _remoteWorkoutShellReady = true;
      debugPrint('[Workout][RemoteShell] ready for session $sessionId');
      await flushPendingRawTracking(workoutId: sessionId, force: true);
    } catch (e) {
      debugPrint('[Workout][RemoteShell] create failed for $sessionId: $e');
    }
  }

  void bufferRawGpsPoint(Position position, {required String? workoutId}) {
    _pendingRawGpsPoints.add(
      _BufferedRawGpsPoint(
        timestamp: position.timestamp.toUtc(),
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speed: position.speed >= 0 ? position.speed : null,
        accuracy: position.accuracy >= 0 ? position.accuracy : null,
        heading: position.heading >= 0 ? position.heading : null,
        deviceSource: 'geolocator_position_stream',
      ),
    );
    _maybeFlushRawTrackingBuffers(workoutId);
  }

  void bufferRawStepInterval(
    int stepsCount, {
    required DateTime? startedAt,
    required String? workoutId,
  }) {
    final nowUtc = DateTime.now().toUtc();
    final intervalStart = (_lastRawStepIntervalEnd ?? startedAt ?? nowUtc)
        .toUtc();
    final intervalEnd = nowUtc.isAfter(intervalStart)
        ? nowUtc
        : intervalStart.add(const Duration(milliseconds: 1));
    _pendingRawStepIntervals.add(
      _BufferedRawStepInterval(
        intervalStart: intervalStart,
        intervalEnd: intervalEnd,
        stepsCount: stepsCount,
        deviceSource: 'pedometer_step_count_stream',
      ),
    );
    _lastRawStepIntervalEnd = intervalEnd;
    _maybeFlushRawTrackingBuffers(workoutId);
  }

  void markRemoteWorkoutShellReady() {
    _remoteWorkoutShellReady = true;
  }

  Future<void> flushPendingRawTracking({
    required String workoutId,
    required bool force,
  }) async {
    if (!_remoteWorkoutShellReady) return;
    if (_pendingRawGpsPoints.isEmpty && _pendingRawStepIntervals.isEmpty) {
      return;
    }

    if ((force || _pendingRawGpsPoints.length >= _kRawGpsFlushThreshold) &&
        _pendingRawGpsPoints.isNotEmpty &&
        !_isFlushingRawGpsPoints) {
      final gpsBatch = List<_BufferedRawGpsPoint>.from(_pendingRawGpsPoints);
      _pendingRawGpsPoints.clear();
      _isFlushingRawGpsPoints = true;
      try {
        await _rawTracking.saveRawGpsPoints(
          gpsBatch
              .map((point) => point.toPayload(workoutId))
              .toList(growable: false),
        );
        debugPrint(
          '[Workout][RawTracking] uploaded ${gpsBatch.length} raw GPS points',
        );
      } catch (e) {
        _pendingRawGpsPoints.insertAll(0, gpsBatch);
        debugPrint('[Workout][RawTracking] GPS upload failed for $workoutId: $e');
      } finally {
        _isFlushingRawGpsPoints = false;
      }
    }

    if ((force || _pendingRawStepIntervals.length >= _kRawStepFlushThreshold) &&
        _pendingRawStepIntervals.isNotEmpty &&
        !_isFlushingRawStepIntervals) {
      final stepBatch = List<_BufferedRawStepInterval>.from(
        _pendingRawStepIntervals,
      );
      _pendingRawStepIntervals.clear();
      _isFlushingRawStepIntervals = true;
      try {
        await _rawTracking.saveRawStepIntervals(
          stepBatch
              .map((interval) => interval.toPayload(workoutId))
              .toList(growable: false),
        );
        debugPrint(
          '[Workout][RawTracking] uploaded ${stepBatch.length} raw step intervals',
        );
      } catch (e) {
        _pendingRawStepIntervals.insertAll(0, stepBatch);
        debugPrint(
          '[Workout][RawTracking] step upload failed for $workoutId: $e',
        );
      } finally {
        _isFlushingRawStepIntervals = false;
      }
    }
  }

  Future<void> enqueueProcessingForSession(WorkoutSession session) async {
    try {
      await _processingRemote.enqueueDeterministicJob(
        workoutId: session.id,
        payload: {
          'activity_type': session.activityType,
          'mode': session.mode,
          'duration_sec': session.durationSec,
          'distance_km': session.distanceKm,
          'steps': session.steps,
          'avg_speed_kmh': session.avgSpeedKmh,
          'calories_kcal': session.caloriesKcal,
          'raw_gps_buffered_points': pendingRawGpsPointCount,
          'raw_step_buffered_intervals': pendingRawStepIntervalCount,
        },
      );
    } catch (e) {
      debugPrint('[Workout][Processing] enqueue failed for ${session.id}: $e');
    }
  }

  void dispose() {
    reset();
  }

  void _maybeFlushRawTrackingBuffers(String? workoutId) {
    if (!_remoteWorkoutShellReady || workoutId == null) return;

    final gpsReady = _pendingRawGpsPoints.length >= _kRawGpsFlushThreshold;
    final stepReady =
        _pendingRawStepIntervals.length >= _kRawStepFlushThreshold;
    if (!gpsReady && !stepReady) return;

    unawaited(flushPendingRawTracking(workoutId: workoutId, force: false));
  }
}

class _BufferedRawGpsPoint {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? heading;
  final String? deviceSource;

  const _BufferedRawGpsPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    this.heading,
    this.deviceSource,
  });

  RawGpsPointPayload toPayload(String workoutId) {
    return RawGpsPointPayload(
      workoutId: workoutId,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      speed: speed,
      accuracy: accuracy,
      heading: heading,
      deviceSource: deviceSource,
    );
  }
}

class _BufferedRawStepInterval {
  final DateTime intervalStart;
  final DateTime intervalEnd;
  final int stepsCount;
  final String? deviceSource;

  const _BufferedRawStepInterval({
    required this.intervalStart,
    required this.intervalEnd,
    required this.stepsCount,
    this.deviceSource,
  });

  RawStepIntervalPayload toPayload(String workoutId) {
    return RawStepIntervalPayload(
      workoutId: workoutId,
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      stepsCount: stepsCount,
      deviceSource: deviceSource,
    );
  }
}
