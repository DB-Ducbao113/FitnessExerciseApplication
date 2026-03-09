import 'package:fitness_exercise_application/presentation/screens/home/home_screen.dart';
import 'package:fitness_exercise_application/presentation/screens/auth/login_screen.dart';
import 'package:fitness_exercise_application/presentation/screens/profile/profile_setup_screen.dart';
import 'package:fitness_exercise_application/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/presentation/providers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Public auth wrapper ──────────────────────────────────────────────────────
//
// Navigation is driven entirely by the Supabase auth-state stream — not by
// manual Navigator.pushReplacement calls in individual screens.
//
// Every login / logout / token-refresh fires the StreamBuilder, and Riverpod
// providers are invalidated so each account always sees only its own data.
//
// Screens import this widget and call:
//   Navigator.of(context).pushAndRemoveUntil(
//     MaterialPageRoute(builder: (_) => const AuthWrapper()),
//     (_) => false,
//   );
// to reset the navigation stack to the root gate.

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  late final Stream<AuthState> _authStream;

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

        // On sign-out: purge cached workout list so stale data is never shown
        if (event == AuthChangeEvent.signedOut) {
          Future.microtask(() {
            ref.invalidate(workoutListProvider);
          });
        }

        // ── No session → Login ──────────────────────────────────────────────
        if (session == null) {
          return const LoginScreen();
        }

        // ── Session → check profile ─────────────────────────────────────────
        final userId = session.user.id;
        final hasProfileAsync = ref.watch(hasUserProfileProvider(userId));

        return hasProfileAsync.when(
          data: (hasProfile) =>
              hasProfile ? const HomeScreen() : const ProfileSetupScreen(),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          // Offline / Supabase error → fallback to profile setup (safe default)
          error: (_, __) => const ProfileSetupScreen(),
        );
      },
    );
  }
}
