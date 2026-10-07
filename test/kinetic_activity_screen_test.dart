import 'package:fitness_exercise_application/features/activity/presentation/widgets/kinetic_activity_card.dart';
import 'package:fitness_exercise_application/features/activity/presentation/widgets/kinetic_activity_cockpit.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kinetic Activity Widgets Tests', () {
    testWidgets('KineticActivityCard displays name and stats without gray tag badges', (tester) async {
      const option = ActivityOptionItem(
        type: 'running',
        nameVi: 'Chạy bộ',
        nameEn: 'Running',
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

      // Verify activity title is displayed cleanly
      expect(find.text('Chạy bộ'), findsOneWidget);
      // Verify gray environment tags are NOT rendered
      expect(find.text('Ngoài trời / Máy chạy'), findsNothing);
      expect(find.text('Ngoài trời'), findsNothing);
      // Verify valid stats are shown
      expect(find.text('5.0 km / buổi'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('KineticActivityCard does not show 0.0km/buoi or TB hoat dong on 0km sessions', (tester) async {
      const walkingOption = ActivityOptionItem(
        type: 'walking',
        nameVi: 'Đi bộ',
        nameEn: 'Walking',
        imagePath: 'assets/walking_real.jpg',
        icon: Icons.directions_walk_rounded,
        accentColor: Color(0xFF4EBE9E),
        requireGps: true,
      );

      // Workouts with 0km distance
      final zeroKmWorkouts = [
        WorkoutSession(
          id: 'w_walk_0',
          userId: 'u1',
          activityType: 'walking',
          startedAt: DateTime(2026, 10, 1, 6, 0),
          endedAt: DateTime(2026, 10, 1, 6, 5),
          durationSec: 300,
          distanceKm: 0.0,
          steps: 0,
          avgSpeedKmh: 0.0,
          caloriesKcal: 0.0,
          mode: 'outdoor',
          createdAt: DateTime(2026, 10, 1, 6, 5),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticActivityCard(
              option: walkingOption,
              isSelected: false,
              workouts: zeroKmWorkouts,
              isVi: true,
              onSelect: () {},
            ),
          ),
        ),
      );

      expect(find.text('Đi bộ'), findsOneWidget);
      // Ensure 0.0 km / buổi and TB hoạt động are NEVER shown
      expect(find.text('0.0 km / buổi'), findsNothing);
      expect(find.text('TB hoạt động'), findsNothing);
      expect(find.textContaining('Hiking'), findsNothing);
    });

    testWidgets('KineticActivityCockpit renders GPS status and start button without targets or indoor sensors', (tester) async {
      bool started = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: KineticActivityCockpit(
                  activityName: 'Đi bộ',
                  isOutdoor: true,
                  gpsEnabled: true,
                  checkingLocation: false,
                  hasLocationPermission: true,
                  gpsAccuracyM: 3.2,
                  isVi: true,
                  onRefreshGps: () {},
                  onStartTap: () {
                    started = true;
                  },
                ),
              );
            },
          ),
        ),
      );

      // Verify GPS status is displayed without < ...m badge
      expect(find.text('GPS sẵn sàng'), findsOneWidget);
      expect(find.textContaining('<'), findsNothing);

      // Verify "Cảm biến trong nhà" is NEVER displayed
      expect(find.text('Cảm biến trong nhà'), findsNothing);

      // Verify target section & quick chips are NOT present
      expect(find.text('MỤC TIÊU BUỔI TẬP'), findsNothing);
      expect(find.text('Tự do'), findsNothing);
      expect(find.text('5.0 km'), findsNothing);

      // Verify start button has no "hiking"
      expect(find.text('BẮT ĐẦU ĐI BỘ'), findsOneWidget);
      expect(find.textContaining('HIKING'), findsNothing);

      await tester.tap(find.text('BẮT ĐẦU ĐI BỘ'));
      await tester.pumpAndSettle();

      expect(started, isTrue);
    });
  });
}
