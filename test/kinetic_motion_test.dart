import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_hero_distance.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestable(Widget child, {bool disableAnimations = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        theme: KineticTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('Motion System — Workout Summary', () {
    testWidgets('hero count-up starts at 0.00 and reaches final value',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticSummaryHeroDistance(
            distanceKm: 12.45,
            activityType: 'running',
            useMetricUnits: true,
            validityFlag: WorkoutValidityFlag.verified,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      // First frame: count-up begins at 0.00
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('12.45'), findsNothing);

      // Mid-animation: value is between 0 and final
      await tester.pump(const Duration(milliseconds: 225));
      expect(find.text('12.45'), findsNothing);

      // After 450ms (motionCounter): final value reached
      await tester.pump(const Duration(milliseconds: 225));
      expect(find.text('12.45'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
    });

    testWidgets('hero shows final value instantly under Reduce Motion',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticSummaryHeroDistance(
            distanceKm: 12.45,
            activityType: 'running',
            useMetricUnits: true,
            validityFlag: WorkoutValidityFlag.verified,
            currentLang: AppLanguage.vi,
          ),
          disableAnimations: true,
        ),
      );

      // Reduce Motion: no animation, final value on first frame
      expect(find.text('12.45'), findsOneWidget);
      expect(find.text('0.00'), findsNothing);
    });

    testWidgets('hero re-counts when distance changes', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticSummaryHeroDistance(
            distanceKm: 5.0,
            activityType: 'running',
            useMetricUnits: true,
            validityFlag: WorkoutValidityFlag.verified,
            currentLang: AppLanguage.vi,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('5.00'), findsOneWidget);

      // Rebuild with a new distance → count-up restarts from 0.00
      await tester.pumpWidget(
        buildTestable(
          const KineticSummaryHeroDistance(
            distanceKm: 9.0,
            activityType: 'running',
            useMetricUnits: true,
            validityFlag: WorkoutValidityFlag.verified,
            currentLang: AppLanguage.vi,
          ),
        ),
      );
      expect(find.text('0.00'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('9.00'), findsOneWidget);
    });

    testWidgets('entrance keeps content in the tree for accessibility',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticEntrance(
            index: 2,
            child: Text('ENTRANCE_CONTENT'),
          ),
        ),
      );

      // Text is findable immediately even before the staggered delay fires —
      // semantics/accessibility never wait on animation.
      expect(find.text('ENTRANCE_CONTENT'), findsOneWidget);

      // After stagger (2 × 60ms) + entrance (320ms): fully settled
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('entrance is instant under Reduce Motion', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticEntrance(
            index: 3,
            child: Text('ENTRANCE_CONTENT'),
          ),
          disableAnimations: true,
        ),
      );
      expect(find.text('ENTRANCE_CONTENT'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('miles conversion still animates correctly', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticSummaryHeroDistance(
            distanceKm: 10.0,
            activityType: 'walking',
            useMetricUnits: false,
            validityFlag: WorkoutValidityFlag.partial,
            currentLang: AppLanguage.en,
          ),
        ),
      );
      expect(find.text('0.00'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      // 10 km * 0.621371 = 6.21 mi
      expect(find.text('6.21'), findsOneWidget);
      expect(find.text('MI'), findsOneWidget);
    });
  });

  group('Motion System — Button Press', () {
    testWidgets('KineticButton taps through press-scale animation',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildTestable(
          KineticButton(
            label: 'PRESS_ME',
            onPressed: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('PRESS_ME'));
      await tester.pump();
      expect(tapped, isTrue);

      // Press-scale (120ms) settles cleanly
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
    });
  });
}
