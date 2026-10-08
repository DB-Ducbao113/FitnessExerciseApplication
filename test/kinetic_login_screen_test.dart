import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          (ref) => AppLanguageNotifier()..state = AppLanguage.vi,
        ),
      ],
      child: MaterialApp(theme: KineticTheme.darkTheme, home: child),
    );
  }

  group('Kinetic LoginScreen Widget Tests', () {
    testWidgets('renders login header artwork, title and form fields', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      expect(find.textContaining('Đăng Nhập'), findsWidgets);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.text('TÊN ĐĂNG NHẬP'), findsOneWidget);
      expect(find.text('Nhập tên đăng nhập'), findsOneWidget);
      expect(find.text('VI'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.textContaining('EMAIL'), findsNothing);
      expect(find.textContaining('email'), findsNothing);
    });

    testWidgets(
      'switches the public login screen between Vietnamese and English',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const LoginScreen()));
        await tester.pump();

        await tester.tap(find.text('EN'));
        await tester.pump();

        expect(find.text('Sign In'), findsWidgets);
        expect(find.text('USERNAME'), findsOneWidget);
        expect(find.text('Enter your username'), findsOneWidget);
      },
    );

    testWidgets('validates empty inputs on login button tap', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      final loginBtn = find.text('Đăng Nhập').last;
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập tên tài khoản'), findsOneWidget);
    });

    testWidgets('rejects email input because login is username-only', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'runner@gmail.com');
      await tester.enterText(textFields.at(1), 'Password123!');
      await tester.tap(find.text('Đăng Nhập').last);
      await tester.pump();

      expect(
        find.text('Dùng 3-24 chữ cái thường, số, dấu chấm (.) hoặc (_)'),
        findsOneWidget,
      );
    });
  });
}
