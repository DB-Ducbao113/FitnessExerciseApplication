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

  // Calculate calories burned for distance-based activities.
  double calculateCalories({
    required String activityType,
    required double distanceKm,
    double speedKmh = 0,
  }) {
    final genderFactor = gender.toLowerCase() == 'female' ? 0.95 : 1.0;
    if (distanceKm <= 0) return 0;
    if (!_isDistanceBasedActivity(activityType)) return 0;
    final k = _getDistanceCalorieFactor(activityType, speedKmh);
    return weightKg * distanceKm * k * genderFactor;
  }

  bool _isDistanceBasedActivity(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'running':
      case 'walking':
      case 'cycling':
        return true;
      default:
        return false;
    }
  }

  double _getDistanceCalorieFactor(String activityType, double speedKmh) {
    final isRunning = activityType.toLowerCase().contains('run');
    double k = isRunning ? 1.05 : 0.92;
    if (speedKmh > 10) k += 0.05;
    if (speedKmh > 15) k += 0.05;
    return k;
  }
}
