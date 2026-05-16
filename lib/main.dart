import 'package:fitness_exercise_application/app/app.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  debugPrint('[Startup] begin');

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  debugPrint(
    '[Startup] supabase config present=${supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty}',
  );

  try {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw const _AppStartupException(
        'Missing Supabase config. Run with SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    debugPrint('[Startup] supabase initialized');

    await LocalDB.init();
    debugPrint('[Startup] local db initialized');

    runApp(const ProviderScope(child: MyApp()));
    debugPrint('[Startup] runApp');
  } catch (error) {
    runApp(_StartupErrorApp(message: error.toString()));
  }
}

class _AppStartupException implements Exception {
  const _AppStartupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'App startup failed',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'If you launched from Xcode, add the required dart-defines before running.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
