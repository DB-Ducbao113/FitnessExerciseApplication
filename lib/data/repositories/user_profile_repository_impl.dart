import 'package:fitness_exercise_application/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/domain/repositories/user_profile_repository.dart';
import 'package:fitness_exercise_application/data/models/user_profile_model.dart';
import 'package:fitness_exercise_application/data/datasources/local/user_profile_local_datasource.dart';
import 'package:fitness_exercise_application/data/datasources/remote/user_profile_remote_datasource.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileLocalDataSource _localDataSource;
  final UserProfileRemoteDataSource _remoteDataSource;

  UserProfileRepositoryImpl(this._localDataSource, this._remoteDataSource);

  @override
  Future<UserProfile?> getProfile(String userId) async {
    // Try local first
    final localProfile = await _localDataSource.getProfile(userId);
    if (localProfile != null) {
      return localProfile.toEntity();
    }

    // Fallback to remote
    try {
      final remoteProfile = await _remoteDataSource.getProfile(userId);
      if (remoteProfile != null) {
        // Save to local
        await _localDataSource.insertProfile(remoteProfile);
        return remoteProfile.toEntity();
      }
    } catch (e) {
      // Offline or error, return null
    }

    return null;
  }

  @override
  Future<void> createProfile(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);

    // Save locally
    await _localDataSource.insertProfile(model);

    // Sync to remote
    try {
      await _remoteDataSource.createProfile(model);
    } catch (e) {
      // Will sync later
    }
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);

    // Update locally
    await _localDataSource.updateProfile(model);

    // Sync to remote
    try {
      await _remoteDataSource.updateProfile(model);
    } catch (e) {
      // Will sync later
    }
  }

  @override
  Future<bool> hasProfile(String userId) async {
    return await _localDataSource.hasProfile(userId);
  }
}
