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
    );
  }

  Future<void> saveRawStepIntervals(List<RawStepIntervalPayload> intervals) {
    return _insertChunked(
      table: DbTables.rawStepIntervals,
      rows: intervals
          .map((interval) => interval.toJson())
          .toList(growable: false),
      debugLabel: 'raw step intervals',
    );
  }

  Future<void> _insertChunked({
    required String table,
    required List<Map<String, dynamic>> rows,
    required String debugLabel,
  }) async {
    if (rows.isEmpty) return;

    for (var i = 0; i < rows.length; i += _kRawTrackingInsertChunkSize) {
      final end = (i + _kRawTrackingInsertChunkSize < rows.length)
          ? i + _kRawTrackingInsertChunkSize
          : rows.length;
      final chunk = rows.sublist(i, end);

      try {
        await _supabase.from(table).insert(chunk);
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
