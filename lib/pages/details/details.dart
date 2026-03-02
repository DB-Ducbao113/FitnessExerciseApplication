import 'package:fitness_exercise_application/pages/details/widgets/stats.dart';
import 'package:fitness_exercise_application/pages/details/widgets/appbar.dart';
import 'package:fitness_exercise_application/pages/details/widgets/dates.dart';
import 'package:fitness_exercise_application/pages/details/widgets/graph.dart';
import 'package:fitness_exercise_application/pages/details/widgets/info.dart'
    hide Stats;
import 'package:fitness_exercise_application/pages/details/widgets/steps.dart';
import 'package:fitness_exercise_application/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const MainAppBar(),
      body: Column(
        children: const [
          Dates(),
          Steps(),
          Graph(),
          Info(),
          Divider(height: 30),
          Stats(),
          SizedBox(height: 30),
          BottomNavigation(),
        ],
      ),
    );
  }
}
