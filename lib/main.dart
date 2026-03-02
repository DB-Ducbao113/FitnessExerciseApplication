import 'package:fitness_exercise_application/presentation/screens/home/home_screen.dart';
import 'package:fitness_exercise_application/presentation/screens/auth/login_screen.dart';
import 'package:fitness_exercise_application/presentation/screens/profile/profile_setup_screen.dart';
import 'package:fitness_exercise_application/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/data/local/local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    ),
  );

  // Initialize Local DB
  await LocalDB.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Exercise Application',
      theme: ThemeData(
        fontFamily: 'Outfit',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const _AuthWrapper(),
    );
  }
}

class _AuthWrapper extends ConsumerWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    // User is logged in, check if they have a profile
    final userId = session.user.id;
    final hasProfileAsync = ref.watch(hasUserProfileProvider(userId));

    return hasProfileAsync.when(
      data: (hasProfile) {
        if (hasProfile) {
          return const HomeScreen();
        } else {
          return const ProfileSetupScreen();
        }
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => const ProfileSetupScreen(),
    );
  }
}
