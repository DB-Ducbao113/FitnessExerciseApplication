import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_hero_card.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_your_week_bento.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_globe_orbit_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildTestable(Widget child, {ThemeData? theme}) {
  return ProviderScope(
    child: MaterialApp(
      theme: theme ?? KineticTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('KineticYourWeekBento Goal Entry Point Tests', () {
    testWidgets('renders interactive goal chip in header and invokes onSetGoalTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticYourWeekBento(
            weeklyDistanceKm: 25.0,
            workoutCount: 3,
            targetDistanceKm: 50.0,
            dateRangeText: '01 Th10 - 07 Th10',
            isVi: true,
            useMetricUnits: true,
            onSetGoalTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Mục tiêu: 50%'), findsOneWidget);
      expect(find.byIcon(Icons.track_changes_rounded), findsOneWidget);

      await tester.tap(find.text('Mục tiêu: 50%'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders adjust goal footer action button and invokes onSetGoalTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticYourWeekBento(
            weeklyDistanceKm: 10.0,
            workoutCount: 2,
            targetDistanceKm: 40.0,
            dateRangeText: 'Oct 01 - Oct 07',
            isVi: false,
            useMetricUnits: false,
            onSetGoalTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Adjust your fitness goals'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      await tester.tap(find.text('Adjust your fitness goals'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('KineticHeroCard Goal Entry Point Tests', () {
    testWidgets('renders clickable targetGoalText when onGoalTap is provided', (tester) async {
      bool goalTapped = false;
      bool startTapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticHeroCard(
            title: 'Chạy Buổi Sáng',
            categoryName: 'Chạy Bộ',
            weeklyProgressText: 'Tuần này: 15 km',
            targetGoalText: 'Mục tiêu: 50 km',
            ctaLabel: 'BẮT ĐẦU CHẠY',
            onStartTap: () => startTapped = true,
            onGoalTap: () => goalTapped = true,
          ),
        ),
      );

      expect(find.text('Mục tiêu: 50 km'), findsOneWidget);

      await tester.tap(find.text('Mục tiêu: 50 km'));
      await tester.pump();
      expect(goalTapped, isTrue);

      await tester.tap(find.text('BẮT ĐẦU CHẠY'));
      await tester.pump();
      expect(startTapped, isTrue);
    });
  });

  group('AetronGlobeOrbitScreen Visualizer Tests', () {
    testWidgets('renders 3D orbit telemetry HUD and brand typography in dark theme', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const AetronGlobeOrbitScreen(
            customTitle: 'Aetron Orbit',
            customSubtitle: 'Mạng lưới định vị vệ tinh GPS',
          ),
        ),
      );

      expect(find.text('Aetron Orbit'), findsOneWidget);
      expect(find.text('Mạng lưới định vị vệ tinh GPS'), findsOneWidget);
      expect(find.text('12 VỆ TINH GPS'), findsOneWidget);
      expect(find.text('ĐỘ CAO 20,200 KM'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('supports horizontal drag gesture on 3D globe without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const AetronGlobeOrbitScreen(
            customTitle: 'Telemetry Test',
          ),
        ),
      );

      final customPaintFinder = find.byType(CustomPaint).first;
      expect(customPaintFinder, findsOneWidget);

      // Drag horizontally to rotate 3D Earth
      await tester.drag(customPaintFinder, const Offset(-100, 0));
      await tester.pump();
      await tester.drag(customPaintFinder, const Offset(60, 0));
      await tester.pump();

      expect(find.text('Telemetry Test'), findsOneWidget);
    });
  });
}
