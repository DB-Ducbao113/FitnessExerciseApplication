// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gps_track_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GPSTrackModel _$GPSTrackModelFromJson(Map<String, dynamic> json) {
  return _GPSTrackModel.fromJson(json);
}

/// @nodoc
mixin _$GPSTrackModel {
  int? get id => throw _privateConstructorUsedError;
  String get workoutId => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  DateTime get recordedAt => throw _privateConstructorUsedError;
  bool get synced => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $GPSTrackModelCopyWith<GPSTrackModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GPSTrackModelCopyWith<$Res> {
  factory $GPSTrackModelCopyWith(
    GPSTrackModel value,
    $Res Function(GPSTrackModel) then,
  ) = _$GPSTrackModelCopyWithImpl<$Res, GPSTrackModel>;
  @useResult
  $Res call({
    int? id,
    String workoutId,
    double latitude,
    double longitude,
    DateTime recordedAt,
    bool synced,
  });
}

/// @nodoc
class _$GPSTrackModelCopyWithImpl<$Res, $Val extends GPSTrackModel>
    implements $GPSTrackModelCopyWith<$Res> {
  _$GPSTrackModelCopyWithImpl(this._value, this._then);

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
    Object? synced = null,
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
            synced: null == synced
                ? _value.synced
                : synced // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GPSTrackModelImplCopyWith<$Res>
    implements $GPSTrackModelCopyWith<$Res> {
  factory _$$GPSTrackModelImplCopyWith(
    _$GPSTrackModelImpl value,
    $Res Function(_$GPSTrackModelImpl) then,
  ) = __$$GPSTrackModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    String workoutId,
    double latitude,
    double longitude,
    DateTime recordedAt,
    bool synced,
  });
}

/// @nodoc
class __$$GPSTrackModelImplCopyWithImpl<$Res>
    extends _$GPSTrackModelCopyWithImpl<$Res, _$GPSTrackModelImpl>
    implements _$$GPSTrackModelImplCopyWith<$Res> {
  __$$GPSTrackModelImplCopyWithImpl(
    _$GPSTrackModelImpl _value,
    $Res Function(_$GPSTrackModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? workoutId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? recordedAt = null,
    Object? synced = null,
  }) {
    return _then(
      _$GPSTrackModelImpl(
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
        synced: null == synced
            ? _value.synced
            : synced // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GPSTrackModelImpl extends _GPSTrackModel {
  const _$GPSTrackModelImpl({
    this.id,
    required this.workoutId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.synced = false,
  }) : super._();

  factory _$GPSTrackModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GPSTrackModelImplFromJson(json);

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
  @JsonKey()
  final bool synced;

  @override
  String toString() {
    return 'GPSTrackModel(id: $id, workoutId: $workoutId, latitude: $latitude, longitude: $longitude, recordedAt: $recordedAt, synced: $synced)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GPSTrackModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workoutId, workoutId) ||
                other.workoutId == workoutId) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.recordedAt, recordedAt) ||
                other.recordedAt == recordedAt) &&
            (identical(other.synced, synced) || other.synced == synced));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    workoutId,
    latitude,
    longitude,
    recordedAt,
    synced,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GPSTrackModelImplCopyWith<_$GPSTrackModelImpl> get copyWith =>
      __$$GPSTrackModelImplCopyWithImpl<_$GPSTrackModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GPSTrackModelImplToJson(this);
  }
}

abstract class _GPSTrackModel extends GPSTrackModel {
  const factory _GPSTrackModel({
    final int? id,
    required final String workoutId,
    required final double latitude,
    required final double longitude,
    required final DateTime recordedAt,
    final bool synced,
  }) = _$GPSTrackModelImpl;
  const _GPSTrackModel._() : super._();

  factory _GPSTrackModel.fromJson(Map<String, dynamic> json) =
      _$GPSTrackModelImpl.fromJson;

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
  bool get synced;
  @override
  @JsonKey(ignore: true)
  _$$GPSTrackModelImplCopyWith<_$GPSTrackModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
