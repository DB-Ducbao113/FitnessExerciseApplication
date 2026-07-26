import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';

class AppBootstrapService {
  final Ref ref;

  AppBootstrapService(this.ref);

  static const _profileHydrationTimeout = Duration(seconds: 8);
  static const _workoutHydrationTimeout = Duration(seconds: 12);

  /// Called upon successful login or app startup with an active session.
  /// Fetches the remote truth and hydrates the local caches.
  Future<void> hydrateUser(String userId) async {
    // 1. Hydrate User Profile
    try {
      final profileRepo = ref.read(userProfileRepositoryProvider);
      final remoteProfile = await profileRepo
          .fetchRemote(userId)
          .timeout(_profileHydrationTimeout);
      if (remoteProfile != null) {
        await profileRepo.cacheLocal(remoteProfile);
      }
    } catch (e) {
      debugPrint('[AppBootstrapService] Failed to hydrate User Profile: $e');
    }

    // 2. Hydrate Workout History
    try {
      final workoutRepo = ref.read(workoutRepositoryProvider);
      await workoutRepo.syncFromCloud().timeout(_workoutHydrationTimeout);
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
