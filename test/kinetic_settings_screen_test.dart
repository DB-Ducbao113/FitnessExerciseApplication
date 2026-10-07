import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_section.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_top_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kinetic Settings Widgets Tests', () {
    testWidgets('KineticSettingsTopBar displays system tag and title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(
            body: KineticSettingsTopBar(
              currentLang: AppLanguage.vi,
            ),
          ),
        ),
      );

      expect(find.text('AETRON SYSTEM'), findsNothing);
      expect(find.text('Cài đặt'), findsOneWidget);
    });

    testWidgets('KineticSettingsSectionGroup renders title and tiles', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticSettingsSectionGroup(
              title: 'CẤU HÌNH ỨNG DỤNG',
              children: [
                KineticSettingsTile(
                  icon: Icons.language_rounded,
                  title: 'Ngôn ngữ ứng dụng',
                  subtitle: '🇻🇳 Tiếng Việt',
                  onTap: () {},
                ),
                KineticSettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Giao diện',
                  subtitle: 'Tối • Kinetic Telemetry',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CẤU HÌNH ỨNG DỤNG'), findsOneWidget);
      expect(find.text('Ngôn ngữ ứng dụng'), findsOneWidget);
      expect(find.text('Giao diện'), findsOneWidget);
    });

    testWidgets('KineticSettingsTile triggers onTap when clicked', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticSettingsTile(
              icon: Icons.straighten_rounded,
              title: 'Đơn vị đo',
              subtitle: 'Hệ mét (km, m, km/h)',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Đơn vị đo'));
      expect(tapped, isTrue);
    });

    testWidgets('SettingsScreen permissions switches are OFF when permissions are not granted', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const ProviderScope(
            child: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, equals(4));
      for (final s in switches) {
        expect(s.value, isFalse, reason: 'Permission switch must be OFF when not granted');
      }
    });
  });
}


