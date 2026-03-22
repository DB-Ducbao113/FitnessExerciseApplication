import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

@freezed
class UserProfileModel with _$UserProfileModel {
  const factory UserProfileModel({
    required String id,
    required String userId,
    required double weightKg,
    required double heightM,
    required int age,
    required String gender,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? avatarUrl,
  }) = _UserProfileModel;

  const UserProfileModel._();

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  // Convert to domain entity
  UserProfile toEntity() {
    return UserProfile(
      id: id,
      userId: userId,
      weightKg: weightKg,
      heightM: heightM,
      age: age,
      gender: gender,
      createdAt: createdAt,
      updatedAt: updatedAt,
      avatarUrl: avatarUrl,
    );
  }

  // Create from domain entity
  factory UserProfileModel.fromEntity(UserProfile profile) {
    return UserProfileModel(
      id: profile.id,
      userId: profile.userId,
      weightKg: profile.weightKg,
      heightM: profile.heightM,
      age: profile.age,
      gender: profile.gender,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
      avatarUrl: profile.avatarUrl,
    );
  }
}
