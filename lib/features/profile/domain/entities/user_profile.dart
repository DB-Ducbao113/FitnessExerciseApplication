import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String userId,
    required double weightKg,
    required double heightM, // Changed from cm to meters
    required int age,
    required String gender, // 'male' or 'female'
    required DateTime createdAt,
    required DateTime updatedAt,
    String? avatarUrl, // Supabase Storage public URL, null until uploaded
  }) = _UserProfile;

  const UserProfile._();

  // Calculate BMI
  double get bmi => weightKg / (heightM * heightM);

  // Calculate BMR (Basal Metabolic Rate) using Mifflin-St Jeor Equation
  double get bmr {
    final heightCm = heightM * 100;
    if (gender.toLowerCase() == 'male') {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }
  }

  // Calculate calories burned for an activity
  // Formula: MET × weight (kg) × duration (hours)
  double calculateCalories({
    required String activityType,
    required double durationMinutes,
  }) {
    final met = _getMetValue(activityType);
    final durationHours = durationMinutes / 60;
    final genderFactor = gender.toLowerCase() == 'female' ? 0.95 : 1.0;
    return met * weightKg * durationHours * genderFactor;
  }

  double _getMetValue(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'running':
        return 8.0;
      case 'cycling':
        return 6.0;
      case 'walking':
        return 3.5;
      case 'swimming':
        return 7.0;
      case 'weights':
        return 5.0;
      case 'yoga':
        return 3.0;
      default:
        return 4.0;
    }
  }
}
