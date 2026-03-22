// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserProfileModelImpl _$$UserProfileModelImplFromJson(
  Map<String, dynamic> json,
) => _$UserProfileModelImpl(
  id: json['id'] as String,
  userId: json['userId'] as String,
  weightKg: (json['weightKg'] as num).toDouble(),
  heightM: (json['heightM'] as num).toDouble(),
  age: (json['age'] as num).toInt(),
  gender: json['gender'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$$UserProfileModelImplToJson(
  _$UserProfileModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'weightKg': instance.weightKg,
  'heightM': instance.heightM,
  'age': instance.age,
  'gender': instance.gender,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'avatarUrl': instance.avatarUrl,
};
