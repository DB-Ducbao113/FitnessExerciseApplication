import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

@freezed
class UserProfileModel with _$UserProfileModel {
  const factory UserProfileModel({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'weight_kg') required double weightKg,
    @JsonKey(name: 'height_cm') required double heightCm,
    @JsonKey(name: 'date_of_birth') DateTime? dateOfBirth,
    @JsonKey(name: 'age') @Default(0) int legacyAge,
    required String gender,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
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
      heightCm: heightCm,
      dateOfBirth: dateOfBirth,
      legacyAge: legacyAge,
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
      heightCm: profile.heightCm,
      dateOfBirth: profile.dateOfBirth,
      legacyAge: profile.legacyAge,
      gender: profile.gender,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
      avatarUrl: profile.avatarUrl,
    );
  }
}
