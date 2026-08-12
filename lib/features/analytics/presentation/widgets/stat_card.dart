import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class StatCardWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const StatCardWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StatCard(
      label: label,
      value: value,
      icon: icon,
      accentColor: color ?? AetronColors.cyan,
    );
  }
}
