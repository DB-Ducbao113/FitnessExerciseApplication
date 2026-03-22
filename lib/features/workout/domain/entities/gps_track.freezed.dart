// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gps_track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GPSTrack {
  int? get id => throw _privateConstructorUsedError;
  String get workoutId => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  DateTime get recordedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $GPSTrackCopyWith<GPSTrack> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GPSTrackCopyWith<$Res> {
  factory $GPSTrackCopyWith(GPSTrack value, $Res Function(GPSTrack) then) =
      _$GPSTrackCopyWithImpl<$Res, GPSTrack>;
  @useResult
  $Res call({
    int? id,
    String workoutId,
    double latitude,
    double longitude,
    DateTime recordedAt,
  });
}

/// @nodoc
class _$GPSTrackCopyWithImpl<$Res, $Val extends GPSTrack>
    implements $GPSTrackCopyWith<$Res> {
  _$GPSTrackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? workoutId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? recordedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int?,
            workoutId: null == workoutId
                ? _value.workoutId
                : workoutId // ignore: cast_nullable_to_non_nullable
                      as String,
            latitude: null == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double,
            longitude: null == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double,
            recordedAt: null == recordedAt
                ? _value.recordedAt
                : recordedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GPSTrackImplCopyWith<$Res>
    implements $GPSTrackCopyWith<$Res> {
  factory _$$GPSTrackImplCopyWith(
    _$GPSTrackImpl value,
    $Res Function(_$GPSTrackImpl) then,
  ) = __$$GPSTrackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    String workoutId,
    double latitude,
    double longitude,
    DateTime recordedAt,
  });
}

/// @nodoc
class __$$GPSTrackImplCopyWithImpl<$Res>
    extends _$GPSTrackCopyWithImpl<$Res, _$GPSTrackImpl>
    implements _$$GPSTrackImplCopyWith<$Res> {
  __$$GPSTrackImplCopyWithImpl(
    _$GPSTrackImpl _value,
    $Res Function(_$GPSTrackImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? workoutId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? recordedAt = null,
  }) {
    return _then(
      _$GPSTrackImpl(
        id: freezed == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int?,
        workoutId: null == workoutId
            ? _value.workoutId
            : workoutId // ignore: cast_nullable_to_non_nullable
                  as String,
        latitude: null == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double,
        longitude: null == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double,
        recordedAt: null == recordedAt
            ? _value.recordedAt
            : recordedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$GPSTrackImpl implements _GPSTrack {
  const _$GPSTrackImpl({
    required this.id,
    required this.workoutId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  @override
  final int? id;
  @override
  final String workoutId;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final DateTime recordedAt;

  @override
  String toString() {
    return 'GPSTrack(id: $id, workoutId: $workoutId, latitude: $latitude, longitude: $longitude, recordedAt: $recordedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GPSTrackImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workoutId, workoutId) ||
                other.workoutId == workoutId) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.recordedAt, recordedAt) ||
                other.recordedAt == recordedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, workoutId, latitude, longitude, recordedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GPSTrackImplCopyWith<_$GPSTrackImpl> get copyWith =>
      __$$GPSTrackImplCopyWithImpl<_$GPSTrackImpl>(this, _$identity);
}

abstract class _GPSTrack implements GPSTrack {
  const factory _GPSTrack({
    required final int? id,
    required final String workoutId,
    required final double latitude,
    required final double longitude,
    required final DateTime recordedAt,
  }) = _$GPSTrackImpl;

  @override
  int? get id;
  @override
  String get workoutId;
  @override
  double get latitude;
  @override
  double get longitude;
  @override
  DateTime get recordedAt;
  @override
  @JsonKey(ignore: true)
  _$$GPSTrackImplCopyWith<_$GPSTrackImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
