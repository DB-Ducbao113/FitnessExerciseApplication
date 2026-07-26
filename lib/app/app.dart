import 'package:fitness_exercise_application/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aetron',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AetronColors.voidBlack,
        colorScheme: const ColorScheme.dark(
          surface: AetronColors.space,
          primary: AetronColors.cyan,
          secondary: AetronColors.blue,
          tertiary: AetronColors.gold,
          onSurface: AetronColors.text,
        ),
        fontFamily: 'Outfit',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AetronColors.text,
          elevation: 0,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 14,
            color: AetronColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const WelcomeGate(),
    );
  }
}
