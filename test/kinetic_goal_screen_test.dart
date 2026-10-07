import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUserGoalNotifier extends UserGoalNotifier {
  FakeUserGoalNotifier([UserGoal? initialGoal]) : super(null) {
    state = AsyncValue.data(initialGoal);
  }

  UserGoal? savedGoal;
  bool deleteCalled = false;

  @override
  Future<void> saveGoal(UserGoal goal) async {
    savedGoal = goal;
    state = AsyncValue.data(goal);
  }

  @override
  Future<void> deleteGoal() async {
    deleteCalled = true;
    state = const AsyncValue.data(null);
  }
}

Widget createGoalScreenTestHarness({
  FakeUserGoalNotifier? goalNotifier,
  AppLanguage language = AppLanguage.vi,
  bool useMetric = true,
}) {
  final notifier = goalNotifier ?? FakeUserGoalNotifier();
  return ProviderScope(
    overrides: [
      userGoalProvider.overrideWith((ref) => notifier),
      appLanguageProvider.overrideWith((ref) => AppLanguageNotifier()..state = language),
      metricUnitsPreferenceProvider.overrideWith((ref) => Future.value(useMetric)),
    ],
    child: MaterialApp(
      theme: KineticTheme.darkTheme,
      home: const GoalScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kinetic GoalScreen Core UI & Structure Tests', () {
    testWidgets('renders hero header, reactor dial, and sticky CTA dock in Vietnamese', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Top bar
      expect(find.text('Mục tiêu rèn luyện'), findsOneWidget);

      // Disciplines
      expect(find.text('Cự ly'), findsOneWidget);
      expect(find.text('Buổi tập'), findsOneWidget);
      expect(find.text('Calo'), findsOneWidget);

      // Cadence tabs
      expect(find.text('Sprint Tuần Này'), findsOneWidget);
      expect(find.text('Chiến Dịch Tháng'), findsOneWidget);

      // Sections
      expect(find.text('Ý NGHĨA & HIỆU QUẢ THỰC TẾ'), findsOneWidget);
      expect(find.text('GÓI MỤC TIÊU ĐỀ XUẤT'), findsOneWidget);

      // Sticky dock button
      expect(find.text('KÍCH HOẠT MỤC TIÊU'), findsOneWidget);
    });

    testWidgets('renders properly in English mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.en));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Top bar & disciplines
      expect(find.text('Fitness Goals'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);

      // Cadence tabs
      expect(find.text('Weekly Sprint'), findsOneWidget);
      expect(find.text('Monthly Campaign'), findsOneWidget);

      // Sections & CTA
      expect(find.text('REAL-WORLD PERFORMANCE IMPACT'), findsOneWidget);
      expect(find.text('RECOMMENDED GOAL PRESETS'), findsOneWidget);
      expect(find.text('ACTIVATE GOAL'), findsOneWidget);
    });
  });

  group('Kinetic GoalScreen Interactivity & Selection Tests', () {
    testWidgets('switches discipline between Distance, Workouts and Calories smoothly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Switch to Workouts (Buổi tập)
      await tester.tap(find.text('Buổi tập'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('buổi'), findsWidgets);

      // Switch to Calories (Calo)
      await tester.tap(find.text('Calo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('kcal'), findsWidgets);
    });

    testWidgets('switches cadence from 7-day to 30-day and updates presets', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Tap Monthly campaign
      await tester.tap(find.text('Chiến Dịch Tháng'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Check cadence selection state
      expect(find.text('Chiến Dịch Tháng'), findsOneWidget);
      expect(find.textContaining('tháng'), findsWidgets);
    });

    testWidgets('preset pills immediately update target value when tapped', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Find preset 'Bứt Phá'
      final butPhaChip = find.text('Bứt Phá');
      expect(butPhaChip, findsOneWidget);

      await tester.tap(butPhaChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Target value should update to 80 (Elite weekly preset)
      expect(find.text('80'), findsWidgets);
    });

    testWidgets('saving goal persists goal entity via notifier', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final ctaButton = find.text('KÍCH HOẠT MỤC TIÊU');
      expect(ctaButton, findsOneWidget);

      await tester.tap(ctaButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(fakeNotifier.savedGoal, isNotNull);
      expect(fakeNotifier.savedGoal!.goalType, equals(GoalType.distance));
      expect(fakeNotifier.savedGoal!.period, equals(GoalPeriod.weekly));
    });

    testWidgets('shows delete action in top bar if active goal exists and triggers confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existingGoal = UserGoal(
        id: 'goal-001',
        userId: 'test-user',
        goalType: GoalType.distance,
        targetValue: 30.0,
        period: GoalPeriod.weekly,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now(),
      );

      final fakeNotifier = FakeUserGoalNotifier(existingGoal);

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // In top bar, delete icon button should exist
      final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteIcon, findsOneWidget);

      // CTA button text is 'LƯU MỤC TIÊU' when goal already exists
      expect(find.text('LƯU MỤC TIÊU'), findsOneWidget);

      // Tap delete icon to open confirmation dialog
      await tester.tap(deleteIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Hủy bỏ mục tiêu này?'), findsOneWidget);
      expect(find.text('Xóa mục tiêu'), findsOneWidget);

      // Tap delete confirmation
      await tester.tap(find.text('Xóa mục tiêu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(fakeNotifier.deleteCalled, isTrue);
    });
  });

  group('Kinetic GoalScreen Non-Dragging Tactile Controls Tests', () {
    testWidgets('contains no draggable Slider widget anywhere on screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createGoalScreenTestHarness(language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('tactile increment and decrement step buttons adjust target without dragging', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createGoalScreenTestHarness(language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Initial default weekly distance is 35
      expect(find.text('35'), findsWidgets);

      // Tap + increment button
      final plusButton = find.byIcon(Icons.add_rounded);
      expect(plusButton, findsOneWidget);
      await tester.tap(plusButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Value should be 37.5
      expect(find.text('37.5'), findsWidgets);

      // Tap - decrement button
      final minusButton = find.byIcon(Icons.remove_rounded);
      expect(minusButton, findsOneWidget);
      await tester.tap(minusButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Back to 35
      expect(find.text('35'), findsWidgets);
    });

    testWidgets('tapping direct input opens numeric sheet and allows entering custom value', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createGoalScreenTestHarness(language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final directTypeButton = find.text('Nhập số');
      expect(directTypeButton, findsOneWidget);

      await tester.tap(directTypeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('NHẬP CHÍNH XÁC MỤC TIÊU'), findsOneWidget);
      expect(find.text('ÁP DỤNG MỤC TIÊU'), findsOneWidget);

      // Enter 42 km
      await tester.enterText(find.byType(TextField), '42');
      await tester.pump();

      await tester.tap(find.text('ÁP DỤNG MỤC TIÊU'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('42'), findsWidgets);
    });
  });
}
