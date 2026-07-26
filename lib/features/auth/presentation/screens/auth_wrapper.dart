import 'package:fitness_exercise_application/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:fitness_exercise_application/features/onboarding/presentation/screens/account_onboarding_gate.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/athlete_setup_flow.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
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
  bool _isPasswordRecovery = false;
  bool _passwordRecoveryCompleted = false;
  String? _activeUserId;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  void _resetAccountScopedState({String? previousUserId, String? userId}) {
    Future.microtask(() {
      ref.invalidate(workoutListProvider);
      ref.invalidate(userGoalProvider);
      ref.invalidate(avatarUploadProvider);
      if (previousUserId != null) {
        ref.invalidate(userProfileProvider(previousUserId));
        ref.invalidate(hasUserProfileProvider(previousUserId));
      }
      if (userId != null) {
        ref.invalidate(userProfileProvider(userId));
        ref.invalidate(hasUserProfileProvider(userId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        final event = snapshot.data?.event;

        if (event == AuthChangeEvent.passwordRecovery &&
            !_passwordRecoveryCompleted) {
          _isPasswordRecovery = true;
        }

        if (session == null) {
          if (_activeUserId != null) {
            _resetAccountScopedState(previousUserId: _activeUserId);
            _activeUserId = null;
          }
          _isPasswordRecovery = false;
          _passwordRecoveryCompleted = false;
          return const LoginScreen();
        }

        if (_isPasswordRecovery) {
          return ResetPasswordScreen(
            onPasswordUpdated: () {
              if (mounted) {
                setState(() {
                  _isPasswordRecovery = false;
                  _passwordRecoveryCompleted = true;
                });
              }
            },
          );
        }

        // Route signed-in users by profile state.
        final userId = session.user.id;
        if (_activeUserId != userId) {
          final previousUserId = _activeUserId;
          _activeUserId = userId;
          _resetAccountScopedState(
            previousUserId: previousUserId,
            userId: userId,
          );
        }
        final hasProfileAsync = ref.watch(hasUserProfileProvider(userId));

        return hasProfileAsync.when(
          data: (hasProfile) => AccountOnboardingGate(
            userId: userId,
            child: hasProfile ? const MainShell() : const AthleteSetupFlow(),
          ),
          loading: () => const AetronLoadingScaffold(
            label: 'SYNCING PROFILE',
            message: 'Preparing your Aetron telemetry.',
            withGrid: false,
          ),
          error: (error, stackTrace) {
            debugPrint('[AuthWrapper] hasProfile error: $error');
            return const ProfileSetupScreen();
          },
        );
      },
    );
  }
}
