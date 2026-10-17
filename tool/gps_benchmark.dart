import 'dart:io';

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/gps_benchmark_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runGpsBenchmarkCli(arguments);
}
