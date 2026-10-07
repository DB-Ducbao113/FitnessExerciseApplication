import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/register_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith((ref) => AppLanguageNotifier()..state = AppLanguage.vi),
      ],
      child: MaterialApp(
        theme: KineticTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Kinetic RegisterScreen Widget Tests', () {
    testWidgets('renders register screen header and form fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      expect(find.text('Theo dõi hành trình fitness'), findsOneWidget);
      expect(find.text('Tạo Tài Khoản'), findsOneWidget);
      expect(find.text('Đăng nhập ngay'), findsOneWidget);
    });

    testWidgets('shows terms validation error when tapping register without checking terms', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      // Enter valid email and matching passwords
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'runner@gmail.com');
      await tester.enterText(textFields.at(1), 'Password123!');
      await tester.enterText(textFields.at(2), 'Password123!');
      await tester.pump();

      // Do NOT check terms checkbox
      final regBtn = find.text('Tạo Tài Khoản');
      expect(regBtn, findsOneWidget);
      await tester.tap(regBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Điều khoản'), findsWidgets);
    });

    testWidgets('accepts username format such as user1 without email validation error', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      // Enter username "user1" and matching passwords
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'user1');
      await tester.enterText(textFields.at(1), 'Password123!');
      await tester.enterText(textFields.at(2), 'Password123!');
      await tester.pump();

      // Tap submit without terms checked to verify validator passes on username
      final regBtn = find.text('Tạo Tài Khoản');
      await tester.tap(regBtn);
      await tester.pumpAndSettle();

      // Username "user1" should NOT trigger "Email không hợp lệ"
      expect(find.text('Email không hợp lệ'), findsNothing);
      expect(find.text('Địa chỉ email không hợp lệ'), findsNothing);
      // It should proceed past username field validation to terms check
      expect(find.textContaining('Điều khoản'), findsWidgets);
    });
  });
}
