import 'package:fitness_exercise_application/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  debugPrint('[Startup] begin');

  final supabaseUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  final supabaseAnonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  debugPrint('[Startup] supabase config present=${supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty}');

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  debugPrint('[Startup] supabase initialized');

  await LocalDB.init();
  debugPrint('[Startup] local db initialized');

  runApp(const ProviderScope(child: MyApp()));
  debugPrint('[Startup] runApp');
}
