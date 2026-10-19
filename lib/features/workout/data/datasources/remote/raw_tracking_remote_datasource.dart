import 'package:fitness_exercise_application/core/constants/db_tables.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const int _kRawTrackingInsertChunkSize = 250;

final rawTrackingRemoteDataSourceProvider =
    Provider<RawTrackingRemoteDataSource>((ref) {
      final supabase = ref.watch(supabaseClientProvider);
      return RawTrackingRemoteDataSource(supabase);
    });

class RawGpsPointPayload {
  final String workoutId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? heading;
  final String? deviceSource;

  const RawGpsPointPayload({
    required this.workoutId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    this.heading,
    this.deviceSource,
  });

  Map<String, dynamic> toJson() {
    return {
      'workout_id': workoutId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'accuracy': accuracy,
      'heading': heading,
      'device_source': deviceSource,
    };
  }

  factory RawGpsPointPayload.fromJson(Map<String, dynamic> json) {
    return RawGpsPointPayload(
      workoutId: (json['workout_id'] ?? json['sessionId'] ?? '') as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      deviceSource: json['device_source'] as String?,
    );
  }
}

class RawStepIntervalPayload {
  final String workoutId;
  final DateTime intervalStart;
  final DateTime intervalEnd;
  final int stepsCount;
  final String? deviceSource;

  const RawStepIntervalPayload({
    required this.workoutId,
    required this.intervalStart,
    required this.intervalEnd,
    required this.stepsCount,
    this.deviceSource,
  });

  Map<String, dynamic> toJson() {
    return {
      'workout_id': workoutId,
      'interval_start': intervalStart.toUtc().toIso8601String(),
      'interval_end': intervalEnd.toUtc().toIso8601String(),
      'steps_count': stepsCount,
      'device_source': deviceSource,
    };
  }
}

class RawTrackingRemoteDataSource {
  final SupabaseClient _supabase;

  RawTrackingRemoteDataSource(this._supabase);

  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) {
    return _insertChunked(
      table: DbTables.rawGpsPoints,
      rows: points.map((point) => point.toJson()).toList(growable: false),
      debugLabel: 'raw GPS points',
      onConflict: 'workout_id,timestamp,latitude,longitude',
    );
  }

  Future<void> saveRawStepIntervals(List<RawStepIntervalPayload> intervals) {
    return _insertChunked(
      table: DbTables.rawStepIntervals,
      rows: intervals
          .map((interval) => interval.toJson())
          .toList(growable: false),
      debugLabel: 'raw step intervals',
      onConflict: 'workout_id,interval_start,interval_end',
    );
  }

  /// Returns the server-visible number of raw GPS samples for [workoutId].
  ///
  /// This is intentionally queried only when a workout finishes. An insert
  /// completing without throwing proves that PostgREST accepted the request;
  /// this count proves that RLS and conflict handling left queryable rows for
  /// the current user.
  Future<int> countRawGpsPointsForWorkout(String workoutId) {
    return _supabase
        .from(DbTables.rawGpsPoints)
        .count(CountOption.exact)
        .eq('workout_id', workoutId);
  }

  /// Fetches a paginated batch of raw GPS points for [workoutId], ordered by timestamp ascending.
  Future<List<RawGpsPointPayload>> fetchRawGpsPointsPaged(
    String workoutId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    final response = await _supabase
        .from(DbTables.rawGpsPoints)
        .select()
        .eq('workout_id', workoutId)
        .order('timestamp', ascending: true)
        .order('latitude', ascending: true)
        .order('longitude', ascending: true)
        .range(offset, offset + limit - 1);

    final list = response as List;
    return list
        .map((row) => RawGpsPointPayload.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Fetches all raw GPS points for [workoutId] by paging through the database.
  Future<List<RawGpsPointPayload>> fetchAllRawGpsPoints(
    String workoutId, {
    int pageSize = 1000,
  }) async {
    final allPoints = <RawGpsPointPayload>[];
    var offset = 0;
    while (true) {
      final page = await fetchRawGpsPointsPaged(
        workoutId,
        offset: offset,
        limit: pageSize,
      );
      allPoints.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }
    return allPoints;
  }

  Future<void> _insertChunked({
    required String table,
    required List<Map<String, dynamic>> rows,
    required String debugLabel,
    required String onConflict,
  }) async {
    if (rows.isEmpty) return;

    for (var i = 0; i < rows.length; i += _kRawTrackingInsertChunkSize) {
      final end = (i + _kRawTrackingInsertChunkSize < rows.length)
          ? i + _kRawTrackingInsertChunkSize
          : rows.length;
      final chunk = rows.sublist(i, end);

      try {
        await _supabase
            .from(table)
            .upsert(chunk, onConflict: onConflict, ignoreDuplicates: true);
      } on PostgrestException catch (e) {
        debugPrint(
          '[RawTrackingRemoteDataSource] save $debugLabel failed: ${e.message}',
        );
        rethrow;
      } catch (e) {
        debugPrint(
          '[RawTrackingRemoteDataSource] save $debugLabel unexpected error: $e',
        );
        rethrow;
      }
    }
  }
}
