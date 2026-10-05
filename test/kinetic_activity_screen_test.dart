import 'package:fitness_exercise_application/features/activity/presentation/widgets/kinetic_activity_card.dart';
import 'package:fitness_exercise_application/features/activity/presentation/widgets/kinetic_activity_cockpit.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kinetic Activity Widgets Tests', () {
    testWidgets('KineticActivityCard displays name and stats', (tester) async {
      const option = ActivityOptionItem(
        type: 'running',
        nameVi: 'Chạy bộ',
        nameEn: 'Running',
        tagVi: 'Ngoài trời',
        tagEn: 'Outdoor',
        imagePath: 'assets/running_real.jpg',
        icon: Icons.directions_run_rounded,
        accentColor: Color(0xFFA8DCE7),
        requireGps: true,
      );

      final fakeWorkouts = [
        WorkoutSession(
          id: 'w1',
          userId: 'u1',
          activityType: 'running',
          startedAt: DateTime(2026, 10, 1, 6, 0),
          endedAt: DateTime(2026, 10, 1, 6, 30),
          durationSec: 1800,
          distanceKm: 5.0,
          steps: 5000,
          avgSpeedKmh: 10.0,
          caloriesKcal: 350.0,
          mode: 'outdoor',
          createdAt: DateTime(2026, 10, 1, 6, 30),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticActivityCard(
              option: option,
              isSelected: true,
              workouts: fakeWorkouts,
              isVi: true,
              onSelect: () {},
            ),
          ),
        ),
      );

      expect(find.text('Chạy bộ'), findsOneWidget);
      expect(find.text('Ngoài trời'), findsOneWidget);
      expect(find.text('5.0 km / buổi'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('KineticActivityCockpit selects quick targets', (tester) async {
      WorkoutTarget target = WorkoutTarget.free;
      bool started = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: KineticActivityCockpit(
                  activityName: 'Chạy bộ',
                  isOutdoor: true,
                  gpsEnabled: true,
                  checkingLocation: false,
                  hasLocationPermission: true,
                  gpsAccuracyM: 3.2,
                  selectedTarget: target,
                  isVi: true,
                  onRefreshGps: () {},
                  onTargetCustomizeTap: () {},
                  onTargetChanged: (t) {
                    setState(() => target = t);
                  },
                  onStartTap: () {
                    started = true;
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('GPS sẵn sàng'), findsOneWidget);
      expect(find.text('< 3.2m'), findsOneWidget);
      expect(find.text('5.0 km'), findsOneWidget);

      await tester.tap(find.text('5.0 km'));
      await tester.pumpAndSettle();

      expect(target.type, WorkoutTargetType.distance);
      expect(target.value, 5.0);

      await tester.tap(find.text('BẮT ĐẦU CHẠY BỘ'));
      await tester.pumpAndSettle();

      expect(started, isTrue);
    });
  });
}
