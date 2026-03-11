import 'package:fitness_exercise_application/utils/helpers.dart';
import 'package:flutter/material.dart';

class Steps extends StatelessWidget {
  const Steps({super.key});

  @override
  Widget build(BuildContext context) {
    
    String steps = formatNumber(randBetween(3000, 6000));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            steps, 
            style: const TextStyle(
              fontSize: 33, 
              fontWeight: FontWeight.w900,
              ),
            ),
          Text(
            'Total Steps',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 2,
            ),
          ),
        ],
      ),
    );
  }
}