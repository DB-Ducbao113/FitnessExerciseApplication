import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Root auth gate.

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  late final Stream<AuthState> _authStream;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        final event = snapshot.data?.event;
        final currentUserId = session?.user.id;

        if (_lastUserId != currentUserId) {
          final previousUserId = _lastUserId;
          _lastUserId = currentUserId;
          Future.microtask(() {
            if (!mounted) return;
            _resetAccountScopedProviders(
              previousUserId: previousUserId,
              currentUserId: currentUserId,
            );
          });
        }

        // Clear cached workouts on sign-out.
        if (event == AuthChangeEvent.signedOut) {
          Future.microtask(() {
            ref.invalidate(workoutListProvider);
          });
        }

        if (session == null) {
          return const LoginScreen();
        }

        // Route signed-in users by profile state.
        final userId = currentUserId!;
        final hasProfileAsync = ref.watch(hasUserProfileProvider(userId));

        return hasProfileAsync.when(
          data: (hasProfile) =>
              hasProfile ? const MainShell() : const ProfileSetupScreen(),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) => const ProfileSetupScreen(),
        );
      },
    );
  }

  void _resetAccountScopedProviders({
    required String? previousUserId,
    required String? currentUserId,
  }) {
    ref.invalidate(currentUserIdProvider);
    ref.invalidate(workoutListProvider);
    ref.invalidate(activeWorkoutProvider);
    ref.invalidate(userGoalProvider);
    ref.invalidate(avatarUploadProvider);
    ref.invalidate(currentAvatarDisplayProvider);

    if (previousUserId != null) {
      ref.invalidate(userProfileProvider(previousUserId));
      ref.invalidate(hasUserProfileProvider(previousUserId));
    }

    if (currentUserId != null) {
      ref.invalidate(userProfileProvider(currentUserId));
      ref.invalidate(hasUserProfileProvider(currentUserId));
    }
  }
}
