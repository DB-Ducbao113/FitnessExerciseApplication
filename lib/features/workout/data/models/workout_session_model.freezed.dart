// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_session_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

WorkoutSessionModel _$WorkoutSessionModelFromJson(Map<String, dynamic> json) {
  return _WorkoutSessionModel.fromJson(json);
}

/// @nodoc
mixin _$WorkoutSessionModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'activity_type')
  String get activityType => throw _privateConstructorUsedError;
  @JsonKey(name: 'started_at')
  DateTime get startedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'ended_at')
  DateTime get endedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_sec')
  int get durationSec => throw _privateConstructorUsedError;
  @JsonKey(name: 'distance_km')
  double get distanceKm => throw _privateConstructorUsedError;
  int get steps => throw _privateConstructorUsedError;
  @JsonKey(name: 'avg_speed_kmh')
  double get avgSpeedKmh => throw _privateConstructorUsedError;
  @JsonKey(name: 'calories_kcal')
  double get caloriesKcal => throw _privateConstructorUsedError;
  String get mode => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'lap_splits',
      fromJson: _lapSplitsFromJson,
      toJson: _lapSplitsToJson)
  List<WorkoutLapSplit> get lapSplits => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'gps_analysis',
      fromJson: _gpsAnalysisFromJson,
      toJson: _gpsAnalysisToJson)
  WorkoutGpsAnalysis get gpsAnalysis => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $WorkoutSessionModelCopyWith<WorkoutSessionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutSessionModelCopyWith<$Res> {
  factory $WorkoutSessionModelCopyWith(
          WorkoutSessionModel value, $Res Function(WorkoutSessionModel) then) =
      _$WorkoutSessionModelCopyWithImpl<$Res, WorkoutSessionModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'activity_type') String activityType,
      @JsonKey(name: 'started_at') DateTime startedAt,
      @JsonKey(name: 'ended_at') DateTime endedAt,
      @JsonKey(name: 'duration_sec') int durationSec,
      @JsonKey(name: 'distance_km') double distanceKm,
      int steps,
      @JsonKey(name: 'avg_speed_kmh') double avgSpeedKmh,
      @JsonKey(name: 'calories_kcal') double caloriesKcal,
      String mode,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(
          name: 'lap_splits',
          fromJson: _lapSplitsFromJson,
          toJson: _lapSplitsToJson)
      List<WorkoutLapSplit> lapSplits,
      @JsonKey(
          name: 'gps_analysis',
          fromJson: _gpsAnalysisFromJson,
          toJson: _gpsAnalysisToJson)
      WorkoutGpsAnalysis gpsAnalysis});
}

/// @nodoc
class _$WorkoutSessionModelCopyWithImpl<$Res, $Val extends WorkoutSessionModel>
    implements $WorkoutSessionModelCopyWith<$Res> {
  _$WorkoutSessionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? activityType = null,
    Object? startedAt = null,
    Object? endedAt = null,
    Object? durationSec = null,
    Object? distanceKm = null,
    Object? steps = null,
    Object? avgSpeedKmh = null,
    Object? caloriesKcal = null,
    Object? mode = null,
    Object? createdAt = null,
    Object? lapSplits = null,
    Object? gpsAnalysis = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      activityType: null == activityType
          ? _value.activityType
          : activityType // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endedAt: null == endedAt
          ? _value.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      durationSec: null == durationSec
          ? _value.durationSec
          : durationSec // ignore: cast_nullable_to_non_nullable
              as int,
      distanceKm: null == distanceKm
          ? _value.distanceKm
          : distanceKm // ignore: cast_nullable_to_non_nullable
              as double,
      steps: null == steps
          ? _value.steps
          : steps // ignore: cast_nullable_to_non_nullable
              as int,
      avgSpeedKmh: null == avgSpeedKmh
          ? _value.avgSpeedKmh
          : avgSpeedKmh // ignore: cast_nullable_to_non_nullable
              as double,
      caloriesKcal: null == caloriesKcal
          ? _value.caloriesKcal
          : caloriesKcal // ignore: cast_nullable_to_non_nullable
              as double,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lapSplits: null == lapSplits
          ? _value.lapSplits
          : lapSplits // ignore: cast_nullable_to_non_nullable
              as List<WorkoutLapSplit>,
      gpsAnalysis: null == gpsAnalysis
          ? _value.gpsAnalysis
          : gpsAnalysis // ignore: cast_nullable_to_non_nullable
              as WorkoutGpsAnalysis,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WorkoutSessionModelImplCopyWith<$Res>
    implements $WorkoutSessionModelCopyWith<$Res> {
  factory _$$WorkoutSessionModelImplCopyWith(_$WorkoutSessionModelImpl value,
          $Res Function(_$WorkoutSessionModelImpl) then) =
      __$$WorkoutSessionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'activity_type') String activityType,
      @JsonKey(name: 'started_at') DateTime startedAt,
      @JsonKey(name: 'ended_at') DateTime endedAt,
      @JsonKey(name: 'duration_sec') int durationSec,
      @JsonKey(name: 'distance_km') double distanceKm,
      int steps,
      @JsonKey(name: 'avg_speed_kmh') double avgSpeedKmh,
      @JsonKey(name: 'calories_kcal') double caloriesKcal,
      String mode,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(
          name: 'lap_splits',
          fromJson: _lapSplitsFromJson,
          toJson: _lapSplitsToJson)
      List<WorkoutLapSplit> lapSplits,
      @JsonKey(
          name: 'gps_analysis',
          fromJson: _gpsAnalysisFromJson,
          toJson: _gpsAnalysisToJson)
      WorkoutGpsAnalysis gpsAnalysis});
}

/// @nodoc
class __$$WorkoutSessionModelImplCopyWithImpl<$Res>
    extends _$WorkoutSessionModelCopyWithImpl<$Res, _$WorkoutSessionModelImpl>
    implements _$$WorkoutSessionModelImplCopyWith<$Res> {
  __$$WorkoutSessionModelImplCopyWithImpl(_$WorkoutSessionModelImpl _value,
      $Res Function(_$WorkoutSessionModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? activityType = null,
    Object? startedAt = null,
    Object? endedAt = null,
    Object? durationSec = null,
    Object? distanceKm = null,
    Object? steps = null,
    Object? avgSpeedKmh = null,
    Object? caloriesKcal = null,
    Object? mode = null,
    Object? createdAt = null,
    Object? lapSplits = null,
    Object? gpsAnalysis = null,
  }) {
    return _then(_$WorkoutSessionModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      activityType: null == activityType
          ? _value.activityType
          : activityType // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endedAt: null == endedAt
          ? _value.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      durationSec: null == durationSec
          ? _value.durationSec
          : durationSec // ignore: cast_nullable_to_non_nullable
              as int,
      distanceKm: null == distanceKm
          ? _value.distanceKm
          : distanceKm // ignore: cast_nullable_to_non_nullable
              as double,
      steps: null == steps
          ? _value.steps
          : steps // ignore: cast_nullable_to_non_nullable
              as int,
      avgSpeedKmh: null == avgSpeedKmh
          ? _value.avgSpeedKmh
          : avgSpeedKmh // ignore: cast_nullable_to_non_nullable
              as double,
      caloriesKcal: null == caloriesKcal
          ? _value.caloriesKcal
          : caloriesKcal // ignore: cast_nullable_to_non_nullable
              as double,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lapSplits: null == lapSplits
          ? _value._lapSplits
          : lapSplits // ignore: cast_nullable_to_non_nullable
              as List<WorkoutLapSplit>,
      gpsAnalysis: null == gpsAnalysis
          ? _value.gpsAnalysis
          : gpsAnalysis // ignore: cast_nullable_to_non_nullable
              as WorkoutGpsAnalysis,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkoutSessionModelImpl extends _WorkoutSessionModel {
  const _$WorkoutSessionModelImpl(
      {required this.id,
      @JsonKey(name: 'user_id') required this.userId,
      @JsonKey(name: 'activity_type') required this.activityType,
      @JsonKey(name: 'started_at') required this.startedAt,
      @JsonKey(name: 'ended_at') required this.endedAt,
      @JsonKey(name: 'duration_sec') required this.durationSec,
      @JsonKey(name: 'distance_km') required this.distanceKm,
      required this.steps,
      @JsonKey(name: 'avg_speed_kmh') required this.avgSpeedKmh,
      @JsonKey(name: 'calories_kcal') required this.caloriesKcal,
      required this.mode,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(
          name: 'lap_splits',
          fromJson: _lapSplitsFromJson,
          toJson: _lapSplitsToJson)
      final List<WorkoutLapSplit> lapSplits = const <WorkoutLapSplit>[],
      @JsonKey(
          name: 'gps_analysis',
          fromJson: _gpsAnalysisFromJson,
          toJson: _gpsAnalysisToJson)
      this.gpsAnalysis = const WorkoutGpsAnalysis()})
      : _lapSplits = lapSplits,
        super._();

  factory _$WorkoutSessionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutSessionModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'activity_type')
  final String activityType;
  @override
  @JsonKey(name: 'started_at')
  final DateTime startedAt;
  @override
  @JsonKey(name: 'ended_at')
  final DateTime endedAt;
  @override
  @JsonKey(name: 'duration_sec')
  final int durationSec;
  @override
  @JsonKey(name: 'distance_km')
  final double distanceKm;
  @override
  final int steps;
  @override
  @JsonKey(name: 'avg_speed_kmh')
  final double avgSpeedKmh;
  @override
  @JsonKey(name: 'calories_kcal')
  final double caloriesKcal;
  @override
  final String mode;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final List<WorkoutLapSplit> _lapSplits;
  @override
  @JsonKey(
      name: 'lap_splits',
      fromJson: _lapSplitsFromJson,
      toJson: _lapSplitsToJson)
  List<WorkoutLapSplit> get lapSplits {
    if (_lapSplits is EqualUnmodifiableListView) return _lapSplits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_lapSplits);
  }

  @override
  @JsonKey(
      name: 'gps_analysis',
      fromJson: _gpsAnalysisFromJson,
      toJson: _gpsAnalysisToJson)
  final WorkoutGpsAnalysis gpsAnalysis;

  @override
  String toString() {
    return 'WorkoutSessionModel(id: $id, userId: $userId, activityType: $activityType, startedAt: $startedAt, endedAt: $endedAt, durationSec: $durationSec, distanceKm: $distanceKm, steps: $steps, avgSpeedKmh: $avgSpeedKmh, caloriesKcal: $caloriesKcal, mode: $mode, createdAt: $createdAt, lapSplits: $lapSplits, gpsAnalysis: $gpsAnalysis)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutSessionModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.activityType, activityType) ||
                other.activityType == activityType) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
            (identical(other.durationSec, durationSec) ||
                other.durationSec == durationSec) &&
            (identical(other.distanceKm, distanceKm) ||
                other.distanceKm == distanceKm) &&
            (identical(other.steps, steps) || other.steps == steps) &&
            (identical(other.avgSpeedKmh, avgSpeedKmh) ||
                other.avgSpeedKmh == avgSpeedKmh) &&
            (identical(other.caloriesKcal, caloriesKcal) ||
                other.caloriesKcal == caloriesKcal) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality()
                .equals(other._lapSplits, _lapSplits) &&
            (identical(other.gpsAnalysis, gpsAnalysis) ||
                other.gpsAnalysis == gpsAnalysis));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      activityType,
      startedAt,
      endedAt,
      durationSec,
      distanceKm,
      steps,
      avgSpeedKmh,
      caloriesKcal,
      mode,
      createdAt,
      const DeepCollectionEquality().hash(_lapSplits),
      gpsAnalysis);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutSessionModelImplCopyWith<_$WorkoutSessionModelImpl> get copyWith =>
      __$$WorkoutSessionModelImplCopyWithImpl<_$WorkoutSessionModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkoutSessionModelImplToJson(
      this,
    );
  }
}

abstract class _WorkoutSessionModel extends WorkoutSessionModel {
  const factory _WorkoutSessionModel(
      {required final String id,
      @JsonKey(name: 'user_id') required final String userId,
      @JsonKey(name: 'activity_type') required final String activityType,
      @JsonKey(name: 'started_at') required final DateTime startedAt,
      @JsonKey(name: 'ended_at') required final DateTime endedAt,
      @JsonKey(name: 'duration_sec') required final int durationSec,
      @JsonKey(name: 'distance_km') required final double distanceKm,
      required final int steps,
      @JsonKey(name: 'avg_speed_kmh') required final double avgSpeedKmh,
      @JsonKey(name: 'calories_kcal') required final double caloriesKcal,
      required final String mode,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(
          name: 'lap_splits',
          fromJson: _lapSplitsFromJson,
          toJson: _lapSplitsToJson)
      final List<WorkoutLapSplit> lapSplits,
      @JsonKey(
          name: 'gps_analysis',
          fromJson: _gpsAnalysisFromJson,
          toJson: _gpsAnalysisToJson)
      final WorkoutGpsAnalysis gpsAnalysis}) = _$WorkoutSessionModelImpl;
  const _WorkoutSessionModel._() : super._();

  factory _WorkoutSessionModel.fromJson(Map<String, dynamic> json) =
      _$WorkoutSessionModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'activity_type')
  String get activityType;
  @override
  @JsonKey(name: 'started_at')
  DateTime get startedAt;
  @override
  @JsonKey(name: 'ended_at')
  DateTime get endedAt;
  @override
  @JsonKey(name: 'duration_sec')
  int get durationSec;
  @override
  @JsonKey(name: 'distance_km')
  double get distanceKm;
  @override
  int get steps;
  @override
  @JsonKey(name: 'avg_speed_kmh')
  double get avgSpeedKmh;
  @override
  @JsonKey(name: 'calories_kcal')
  double get caloriesKcal;
  @override
  String get mode;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'lap_splits',
      fromJson: _lapSplitsFromJson,
      toJson: _lapSplitsToJson)
  List<WorkoutLapSplit> get lapSplits;
  @override
  @JsonKey(
      name: 'gps_analysis',
      fromJson: _gpsAnalysisFromJson,
      toJson: _gpsAnalysisToJson)
  WorkoutGpsAnalysis get gpsAnalysis;
  @override
  @JsonKey(ignore: true)
  _$$WorkoutSessionModelImplCopyWith<_$WorkoutSessionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
