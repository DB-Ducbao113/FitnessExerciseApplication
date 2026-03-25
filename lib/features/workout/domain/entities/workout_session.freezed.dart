// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$WorkoutSession {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get activityType => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  DateTime get endedAt => throw _privateConstructorUsedError;
  int get durationSec => throw _privateConstructorUsedError;
  double get distanceKm => throw _privateConstructorUsedError;
  int get steps => throw _privateConstructorUsedError;
  double get avgSpeedKmh => throw _privateConstructorUsedError;
  double get caloriesKcal => throw _privateConstructorUsedError;
  String get mode => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  List<WorkoutLapSplit> get lapSplits => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WorkoutSessionCopyWith<WorkoutSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutSessionCopyWith<$Res> {
  factory $WorkoutSessionCopyWith(
          WorkoutSession value, $Res Function(WorkoutSession) then) =
      _$WorkoutSessionCopyWithImpl<$Res, WorkoutSession>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String activityType,
      DateTime startedAt,
      DateTime endedAt,
      int durationSec,
      double distanceKm,
      int steps,
      double avgSpeedKmh,
      double caloriesKcal,
      String mode,
      DateTime createdAt,
      List<WorkoutLapSplit> lapSplits});
}

/// @nodoc
class _$WorkoutSessionCopyWithImpl<$Res, $Val extends WorkoutSession>
    implements $WorkoutSessionCopyWith<$Res> {
  _$WorkoutSessionCopyWithImpl(this._value, this._then);

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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WorkoutSessionImplCopyWith<$Res>
    implements $WorkoutSessionCopyWith<$Res> {
  factory _$$WorkoutSessionImplCopyWith(_$WorkoutSessionImpl value,
          $Res Function(_$WorkoutSessionImpl) then) =
      __$$WorkoutSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String activityType,
      DateTime startedAt,
      DateTime endedAt,
      int durationSec,
      double distanceKm,
      int steps,
      double avgSpeedKmh,
      double caloriesKcal,
      String mode,
      DateTime createdAt,
      List<WorkoutLapSplit> lapSplits});
}

/// @nodoc
class __$$WorkoutSessionImplCopyWithImpl<$Res>
    extends _$WorkoutSessionCopyWithImpl<$Res, _$WorkoutSessionImpl>
    implements _$$WorkoutSessionImplCopyWith<$Res> {
  __$$WorkoutSessionImplCopyWithImpl(
      _$WorkoutSessionImpl _value, $Res Function(_$WorkoutSessionImpl) _then)
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
  }) {
    return _then(_$WorkoutSessionImpl(
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
    ));
  }
}

/// @nodoc

class _$WorkoutSessionImpl implements _WorkoutSession {
  const _$WorkoutSessionImpl(
      {required this.id,
      required this.userId,
      required this.activityType,
      required this.startedAt,
      required this.endedAt,
      required this.durationSec,
      required this.distanceKm,
      required this.steps,
      required this.avgSpeedKmh,
      required this.caloriesKcal,
      required this.mode,
      required this.createdAt,
      final List<WorkoutLapSplit> lapSplits = const <WorkoutLapSplit>[]})
      : _lapSplits = lapSplits;

  @override
  final String id;
  @override
  final String userId;
  @override
  final String activityType;
  @override
  final DateTime startedAt;
  @override
  final DateTime endedAt;
  @override
  final int durationSec;
  @override
  final double distanceKm;
  @override
  final int steps;
  @override
  final double avgSpeedKmh;
  @override
  final double caloriesKcal;
  @override
  final String mode;
  @override
  final DateTime createdAt;
  final List<WorkoutLapSplit> _lapSplits;
  @override
  @JsonKey()
  List<WorkoutLapSplit> get lapSplits {
    if (_lapSplits is EqualUnmodifiableListView) return _lapSplits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_lapSplits);
  }

  @override
  String toString() {
    return 'WorkoutSession(id: $id, userId: $userId, activityType: $activityType, startedAt: $startedAt, endedAt: $endedAt, durationSec: $durationSec, distanceKm: $distanceKm, steps: $steps, avgSpeedKmh: $avgSpeedKmh, caloriesKcal: $caloriesKcal, mode: $mode, createdAt: $createdAt, lapSplits: $lapSplits)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutSessionImpl &&
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
                .equals(other._lapSplits, _lapSplits));
  }

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
      const DeepCollectionEquality().hash(_lapSplits));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutSessionImplCopyWith<_$WorkoutSessionImpl> get copyWith =>
      __$$WorkoutSessionImplCopyWithImpl<_$WorkoutSessionImpl>(
          this, _$identity);
}

abstract class _WorkoutSession implements WorkoutSession {
  const factory _WorkoutSession(
      {required final String id,
      required final String userId,
      required final String activityType,
      required final DateTime startedAt,
      required final DateTime endedAt,
      required final int durationSec,
      required final double distanceKm,
      required final int steps,
      required final double avgSpeedKmh,
      required final double caloriesKcal,
      required final String mode,
      required final DateTime createdAt,
      final List<WorkoutLapSplit> lapSplits}) = _$WorkoutSessionImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get activityType;
  @override
  DateTime get startedAt;
  @override
  DateTime get endedAt;
  @override
  int get durationSec;
  @override
  double get distanceKm;
  @override
  int get steps;
  @override
  double get avgSpeedKmh;
  @override
  double get caloriesKcal;
  @override
  String get mode;
  @override
  DateTime get createdAt;
  @override
  List<WorkoutLapSplit> get lapSplits;
  @override
  @JsonKey(ignore: true)
  _$$WorkoutSessionImplCopyWith<_$WorkoutSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
