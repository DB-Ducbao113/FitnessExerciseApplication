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
  Future<UserProfile?> fetchRemote(String userId) async {
    final remoteProfile = await _remoteDataSource.getProfile(userId);
    return remoteProfile?.toEntity();
  }

  @override
  Future<void> saveRemote(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);
    // Determine whether to create or update based on existence locally or remotely
    // For simplicity, we can rely on `updateProfile` and `createProfile` remotely
    // Let's assume updating an upsert on supabase, or we try update and fallback to create.
    await _remoteDataSource.createProfile(
      model,
    ); // In Supabase, upsert is usually preferred if they share ID.
  }

  @override
  Future<void> cacheLocal(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);
    // Try to update, if missing insert. The local data source handles this via insert/update
    await _localDataSource.insertProfile(model);
  }

  @override
  Future<UserProfile?> getLocal(String userId) async {
    final localProfile = await _localDataSource.getProfile(userId);
    return localProfile?.toEntity();
  }

  @override
  Future<UserProfile?> getProfile(String userId) async {
    // Try local first
    final localProfile = await getLocal(userId);
    if (localProfile != null) {
      return localProfile;
    }

    // Fallback to remote
    try {
      final remoteProfile = await fetchRemote(userId);
      if (remoteProfile != null) {
        // Save to local
        await cacheLocal(remoteProfile);
        return remoteProfile;
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
    // 1. Fast path: local SQLite check
    final localResult = await _localDataSource.hasProfile(userId);
    if (localResult) return true;

    // 2. Fallback: check remote (covers fresh-install / cleared-storage case)
    try {
      final remoteProfile = await fetchRemote(userId);
      if (remoteProfile != null) {
        await cacheLocal(remoteProfile);
        return true;
      }
    } catch (_) {
      // Offline or error
    }
    return false;
  }
}
