import 'package:fitness_exercise_application/domain/entities/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> getProfile(String userId);
  Future<void> createProfile(UserProfile profile);
  Future<void> updateProfile(UserProfile profile);
  Future<bool> hasProfile(String userId);
}
