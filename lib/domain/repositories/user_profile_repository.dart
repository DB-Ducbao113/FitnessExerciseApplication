import 'package:fitness_exercise_application/domain/entities/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> fetchRemote(String userId);
  Future<void> saveRemote(UserProfile profile);
  Future<void> cacheLocal(UserProfile profile);
  Future<UserProfile?> getLocal(String userId);

  // Still needed for local checking
  Future<bool> hasProfile(String userId);

  Future<UserProfile?> getProfile(String userId);
  Future<void> updateProfile(UserProfile profile);
  Future<void> createProfile(UserProfile profile);
}
