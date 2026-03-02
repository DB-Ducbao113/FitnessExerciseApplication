import 'package:fitness_exercise_application/pages/home/widgets/activity.dart';
import 'package:fitness_exercise_application/pages/home/widgets/current.dart';
import 'package:fitness_exercise_application/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'widgets/header.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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