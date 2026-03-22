import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:fitness_exercise_application/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:fitness_exercise_application/features/profile/data/datasources/local/user_profile_local_datasource.dart';
import 'package:fitness_exercise_application/features/profile/data/datasources/remote/user_profile_remote_datasource.dart';

part 'user_profile_providers.g.dart';

// Local DataSource Provider
@riverpod
UserProfileLocalDataSource userProfileLocalDataSource(
  UserProfileLocalDataSourceRef ref,
) {
  return UserProfileLocalDataSource(ref.watch(databaseHelperProvider));
}

// Remote DataSource Provider
@riverpod
UserProfileRemoteDataSource userProfileRemoteDataSource(
  UserProfileRemoteDataSourceRef ref,
) {
  return UserProfileRemoteDataSource(Supabase.instance.client);
}

// Repository Provider
@riverpod
UserProfileRepository userProfileRepository(UserProfileRepositoryRef ref) {
  return UserProfileRepositoryImpl(
    ref.watch(userProfileLocalDataSourceProvider),
    ref.watch(userProfileRemoteDataSourceProvider),
  );
}

// Get User Profile Provider
@riverpod
Future<UserProfile?> userProfile(UserProfileRef ref, String userId) async {
  final repository = ref.watch(userProfileRepositoryProvider);
  return await repository.getProfile(userId);
}

// Check if user has profile
@riverpod
Future<bool> hasUserProfile(HasUserProfileRef ref, String userId) async {
  final repository = ref.watch(userProfileRepositoryProvider);
  return await repository.hasProfile(userId);
}
