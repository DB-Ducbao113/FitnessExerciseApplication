import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';

class AppBootstrapService {
  final Ref ref;

  AppBootstrapService(this.ref);

  /// Called upon successful login or app startup with an active session.
  /// Fetches the remote truth and hydrates the local caches.
  Future<void> hydrateUser(String userId) async {
    // 1. Hydrate User Profile
    try {
      final profileRepo = ref.read(userProfileRepositoryProvider);
      final remoteProfile = await profileRepo.fetchRemote(userId);
      if (remoteProfile != null) {
        await profileRepo.cacheLocal(remoteProfile);
      }
    } catch (e) {
      debugPrint('[AppBootstrapService] Failed to hydrate User Profile: $e');
    }

    // 2. Hydrate Workout History
    try {
      final workoutRepo = ref.read(workoutRepositoryProvider);
      final remoteWorkouts = await workoutRepo.fetchSessionsRemote(userId);
      // This explicitly replaces the local cache for this user with the remote truth
      await workoutRepo.replaceLocalCache(userId, remoteWorkouts);
    } catch (e) {
      debugPrint('[AppBootstrapService] Failed to hydrate Workout History: $e');
    }

    // Invalidate providers so UI refreshes with the newly hydrated data
    try {
      ref.invalidate(userProfileProvider(userId));
      ref.invalidate(workoutListProvider);
    } catch (e) {
      debugPrint('[AppBootstrapService] Error invalidating providers: $e');
    }
  }
}

final appBootstrapServiceProvider = Provider.autoDispose<AppBootstrapService>((
  ref,
) {
  return AppBootstrapService(ref);
});
