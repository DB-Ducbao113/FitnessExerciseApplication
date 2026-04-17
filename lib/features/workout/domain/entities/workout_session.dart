import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_session.freezed.dart';

enum WorkoutSegmentStatus { valid, suspicious, invalid }

enum WorkoutValidityFlag { verified, partial, unverified }

class WorkoutFlaggedSegment {
  final DateTime startTimestamp;
  final DateTime endTimestamp;
  final double distanceM;
  final double durationSec;
  final double paceSecPerKm;
  final double avgSpeedMs;
  final double avgAccuracy;
  final WorkoutSegmentStatus status;
  final String reason;

  const WorkoutFlaggedSegment({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.distanceM,
    required this.durationSec,
    required this.paceSecPerKm,
    required this.avgSpeedMs,
    required this.avgAccuracy,
    required this.status,
    required this.reason,
  });

  factory WorkoutFlaggedSegment.fromJson(Map<String, dynamic> json) {
    return WorkoutFlaggedSegment(
      startTimestamp:
          DateTime.tryParse(json['startTimestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endTimestamp:
          DateTime.tryParse(json['endTimestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      distanceM: (json['distanceM'] as num?)?.toDouble() ?? 0,
      durationSec: (json['durationSec'] as num?)?.toDouble() ?? 0,
      paceSecPerKm: (json['paceSecPerKm'] as num?)?.toDouble() ?? 0,
      avgSpeedMs: (json['avgSpeedMs'] as num?)?.toDouble() ?? 0,
      avgAccuracy: (json['avgAccuracy'] as num?)?.toDouble() ?? 0,
      status: _segmentStatusFromString(json['status'] as String?),
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'startTimestamp': startTimestamp.toUtc().toIso8601String(),
    'endTimestamp': endTimestamp.toUtc().toIso8601String(),
    'distanceM': distanceM,
    'durationSec': durationSec,
    'paceSecPerKm': paceSecPerKm,
    'avgSpeedMs': avgSpeedMs,
    'avgAccuracy': avgAccuracy,
    'status': status.name,
    'reason': reason,
  };
}

class WorkoutGpsAnalysis {
  final double totalDistanceKm;
  final double validDistanceKm;
  final double suspiciousDistanceKm;
  final double invalidDistanceKm;
  final int restDurationSec;
  final int gpsGapCount;
  final int gpsGapDurationSec;
  final double? effectivePaceSecPerKm;
  final double suspiciousRatio;
  final WorkoutValidityFlag validityFlag;
  final List<WorkoutFlaggedSegment> flaggedSegments;

  const WorkoutGpsAnalysis({
    this.totalDistanceKm = 0,
    this.validDistanceKm = 0,
    this.suspiciousDistanceKm = 0,
    this.invalidDistanceKm = 0,
    this.restDurationSec = 0,
    this.gpsGapCount = 0,
    this.gpsGapDurationSec = 0,
    this.effectivePaceSecPerKm,
    this.suspiciousRatio = 0,
    this.validityFlag = WorkoutValidityFlag.verified,
    this.flaggedSegments = const <WorkoutFlaggedSegment>[],
  });

  bool get hasFlags => flaggedSegments.isNotEmpty;

  factory WorkoutGpsAnalysis.fromJson(Map<String, dynamic> json) {
    return WorkoutGpsAnalysis(
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      validDistanceKm: (json['validDistanceKm'] as num?)?.toDouble() ?? 0,
      suspiciousDistanceKm:
          (json['suspiciousDistanceKm'] as num?)?.toDouble() ?? 0,
      invalidDistanceKm: (json['invalidDistanceKm'] as num?)?.toDouble() ?? 0,
      restDurationSec: json['restDurationSec'] as int? ?? 0,
      gpsGapCount: json['gpsGapCount'] as int? ?? 0,
      gpsGapDurationSec: json['gpsGapDurationSec'] as int? ?? 0,
      effectivePaceSecPerKm: (json['effectivePaceSecPerKm'] as num?)
          ?.toDouble(),
      suspiciousRatio: (json['suspiciousRatio'] as num?)?.toDouble() ?? 0,
      validityFlag: _validityFlagFromString(json['validityFlag'] as String?),
      flaggedSegments: _flaggedSegmentsFromJson(json['flaggedSegments']),
    );
  }

  Map<String, dynamic> toJson() => {
    'totalDistanceKm': totalDistanceKm,
    'validDistanceKm': validDistanceKm,
    'suspiciousDistanceKm': suspiciousDistanceKm,
    'invalidDistanceKm': invalidDistanceKm,
    'restDurationSec': restDurationSec,
    'gpsGapCount': gpsGapCount,
    'gpsGapDurationSec': gpsGapDurationSec,
    'effectivePaceSecPerKm': effectivePaceSecPerKm,
    'suspiciousRatio': suspiciousRatio,
    'validityFlag': validityFlag.name,
    'flaggedSegments': flaggedSegments
        .map((segment) => segment.toJson())
        .toList(),
  };
}

class WorkoutLapSplit {
  final int index;
  final double distanceKm;
  final int durationSeconds;
  final double paceMinPerKm;

  const WorkoutLapSplit({
    required this.index,
    required this.distanceKm,
    required this.durationSeconds,
    required this.paceMinPerKm,
  });

  factory WorkoutLapSplit.fromJson(Map<String, dynamic> json) {
    return WorkoutLapSplit(
      index: json['index'] as int? ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      paceMinPerKm: (json['paceMinPerKm'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'paceMinPerKm': paceMinPerKm,
  };
}

@freezed
class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required String userId,
    required String activityType,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSec,
    required double distanceKm,
    required int steps,
    required double avgSpeedKmh,
    required double caloriesKcal,
    required String mode,
    required DateTime createdAt,
    @Default(<WorkoutLapSplit>[]) List<WorkoutLapSplit> lapSplits,
    @Default(WorkoutGpsAnalysis()) WorkoutGpsAnalysis gpsAnalysis,
  }) = _WorkoutSession;
}

List<WorkoutFlaggedSegment> _flaggedSegmentsFromJson(dynamic json) {
  if (json is! List) return const <WorkoutFlaggedSegment>[];
  return json
      .whereType<Map>()
      .map(
        (item) =>
            WorkoutFlaggedSegment.fromJson(Map<String, dynamic>.from(item)),
      )
      .toList();
}

WorkoutSegmentStatus _segmentStatusFromString(String? raw) {
  return WorkoutSegmentStatus.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => WorkoutSegmentStatus.valid,
  );
}

WorkoutValidityFlag _validityFlagFromString(String? raw) {
  return WorkoutValidityFlag.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => WorkoutValidityFlag.verified,
  );
}
