import 'package:fitness_exercise_application/features/home/screens/widgets/activity.dart';
import 'package:fitness_exercise_application/features/home/screens/widgets/current.dart';
import 'package:fitness_exercise_application/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'widgets/header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const [
          AppHeader(),
          CurrentPrograms(),
          RecentActivities(),
          BottomNavigation(),
        ],
      ),
    );
  }
}
