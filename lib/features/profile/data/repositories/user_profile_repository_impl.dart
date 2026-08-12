import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:fitness_exercise_application/features/profile/data/models/user_profile_model.dart';
import 'package:fitness_exercise_application/features/profile/data/datasources/local/user_profile_local_datasource.dart';
import 'package:fitness_exercise_application/features/profile/data/datasources/remote/user_profile_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileLocalDataSource _localDataSource;
  final UserProfileRemoteDataSource _remoteDataSource;

  UserProfileRepositoryImpl(this._localDataSource, this._remoteDataSource);

  static const _remoteProfileTimeout = Duration(seconds: 8);

  @override
  Future<UserProfile?> fetchRemote(String userId) async {
    final remoteProfile = await _remoteDataSource
        .getProfile(userId)
        .timeout(_remoteProfileTimeout);
    return remoteProfile?.toEntity();
  }

  @override
  Future<void> saveRemote(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);
    await _remoteDataSource.updateProfile(model);
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
    // 1. Try remote truth first to ensure real-time multi-device sync
    try {
      final remoteProfile = await fetchRemote(userId);
      if (remoteProfile != null) {
        await cacheLocal(remoteProfile);
        return remoteProfile;
      }
    } catch (e) {
      // Offline or cloud fetch error, fall back to local cache
    }

    // 2. Fallback to local SQLite cache
    return await getLocal(userId);
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
      debugPrint('[UserProfileRepositoryImpl] Failed to sync remote profile during creation: $e');
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

  @override
  Future<void> deleteAccount(String userId) async {
    // 1. Wipe all remote data
    await _remoteDataSource.deleteAllUserData(userId);

    // 2. Wipe all local Isar workout data
    await LocalDB.clearAllForUser(userId);

    // 3. Sign out from Supabase auth
    await Supabase.instance.client.auth.signOut();
  }
}
