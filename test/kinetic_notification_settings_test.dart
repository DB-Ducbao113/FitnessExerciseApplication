import 'package:fitness_exercise_application/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationSettingsScreen Streamlined Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'settings.notifications.enabled': true,
        'settings.notifications.workout_reminders': true,
        'settings.notifications.morning_time': '08:00',
        'settings.notifications.goal_progress': true,
        'settings.notifications.achievement': true,
        'settings.notifications.streak_reminders': true,
        'settings.notifications.inactivity_reminders': true,
        'settings.notifications.quiet_hours': true,
        'settings.notifications.quiet_hours_start': '22:00',
        'settings.notifications.quiet_hours_end': '07:00',
      });
    });

    testWidgets('renders streamlined 3 consolidated groups in dark mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('THÔNG BÁO'), findsOneWidget);
      expect(find.text('NHẮC NHỞ LUYỆN TẬP'), findsOneWidget);

      // Master switch card
      expect(find.text('Nhận thông báo'), findsOneWidget);

      // Section label
      expect(find.text('TÙY CHỌN NHẮC NHỞ'), findsOneWidget);

      // 3 Consolidated Groups
      expect(find.text('Luyện tập & Chuỗi ngày'), findsOneWidget);
      expect(find.text('Mục tiêu & Thành tích'), findsOneWidget);
      expect(find.text('Khung giờ yên tĩnh'), findsOneWidget);

      // Time configurations
      expect(find.text('Giờ nhắc tập mỗi ngày'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);

      // Verify the removed noisy items are NOT present
      expect(find.text('XEM TRƯỚC THÔNG BÁO'), findsNothing);
      expect(find.text('Ready to move? 🏃'), findsNothing);
      expect(find.text('DANH MỤC NHẮC NHỞ'), findsNothing);
      expect(find.text('Cảnh báo bảo vệ chuỗi (Streak)'), findsNothing);
      expect(find.text('Nhắc nhở khi ngưng luyện tập'), findsNothing);
    });

    testWidgets('renders cleanly in light mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: KineticTheme.lightTheme,
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('THÔNG BÁO'), findsOneWidget);
      expect(find.text('Nhận thông báo'), findsOneWidget);
      expect(find.text('Luyện tập & Chuỗi ngày'), findsOneWidget);
      expect(find.text('Mục tiêu & Thành tích'), findsOneWidget);
      expect(find.text('Khung giờ yên tĩnh'), findsOneWidget);
    });

    testWidgets('master toggle disables all notification options', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final masterSwitch = find.byType(Switch).first;
      await tester.tap(masterSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // SharedPreferences should reflect disabled
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.notifications.enabled'), false);
    });

    testWidgets('back button navigates back', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationSettingsScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationSettingsScreen), findsNothing);
    });
  });
}
