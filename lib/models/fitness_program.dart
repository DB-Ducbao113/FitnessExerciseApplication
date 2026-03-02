import 'package:flutter/material.dart';

enum ProgramType {
  cardio,
  lift,
}

class FitnessProgram {

  final AssetImage image;
  final String name;
  final String calories;
  final String time;
  final ProgramType? type;

  FitnessProgram({
    required this.image,
    required this.name,
    required this.calories,
    required this.time,
    required this.type,
  });
}

final List<FitnessProgram> fitnessPrograms = [
  FitnessProgram(image: AssetImage('assets/running.jpg'), name: 'Running', calories: '300', time: '30 mins', type: ProgramType.cardio),
  FitnessProgram(image: AssetImage('assets/weights.jpg'), name: 'Workout', calories: '300', time: '30 mins', type: ProgramType.lift),
];

