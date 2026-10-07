import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/structured_running_program.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/guided_program_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StructuredRunningProgram Tests', () {
    test('All programs have valid structured intervals and total duration > 0', () {
      final programs = RunningProgramsScreen.programs;
      expect(programs.length, 4);

      for (final prog in programs) {
        expect(prog.steps.isNotEmpty, true, reason: '${prog.id} has no steps');
        expect(prog.totalDurationSeconds > 0, true, reason: '${prog.id} duration is 0');
        expect(prog.titleKey.isNotEmpty, true);
        expect(prog.badgeVi.isNotEmpty, true);
        expect(prog.badgeEn.isNotEmpty, true);
        expect(prog.imageAsset.isNotEmpty, true, reason: '${prog.id} missing imageAsset');
        expect(prog.imageAsset.startsWith('assets/'), true);
      }

      // Ensure all programs have distinct, dedicated realistic plan images
      final imageAssets = programs.map((p) => p.imageAsset).toSet();
      expect(imageAssets.length, programs.length, reason: 'Program images must not be duplicated');
      expect(programs.firstWhere((p) => p.id == 'couch_to_5k').imageAsset, 'assets/plan_couch_to_5k.jpg');
      expect(programs.firstWhere((p) => p.id == 'easy_base_run').imageAsset, 'assets/plan_easy_base_run.jpg');
      expect(programs.firstWhere((p) => p.id == 'pace_builder_10k').imageAsset, 'assets/plan_pace_builder_10k.jpg');
      expect(programs.firstWhere((p) => p.id == 'speed_intervals').imageAsset, 'assets/plan_speed_intervals.jpg');
    });

    test('Couch to 5K contains Warmup, 8 Run/Walk intervals, and Cooldown', () {
      final c25k = RunningProgramsScreen.programs.firstWhere((p) => p.id == 'couch_to_5k');
      expect(c25k.steps.first.phaseType, ProgramPhaseType.warmup);
      expect(c25k.steps.last.phaseType, ProgramPhaseType.cooldown);
      // 1 warmup + 8*(1 run + 1 walk) + 1 cooldown = 1 + 16 + 1 = 18 steps
      expect(c25k.steps.length, 18);
    });

    testWidgets('GuidedProgramHud renders step information correctly', (tester) async {
      final program = RunningProgramsScreen.programs.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuidedProgramHud(
              program: program,
              currentStepIndex: 0,
              stepRemainingSeconds: 280,
              stepElapsedSeconds: 20,
              currentPaceMinSecKm: 660, // 11:00/km (inside 10:00-12:00 target)
              currentLang: AppLanguage.vi,
              onSkipStep: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('HIỆP 1/18'), findsOneWidget);
      expect(find.text('04:40'), findsOneWidget);
      expect(find.text('✅ PACE ĐẠT CHUẨN'), findsOneWidget);
    });
  });
}
