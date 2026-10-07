import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_time_input_sheet.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KineticTimeInputSheet Widget Tests', () {
    testWidgets('renders initial time, preset chips, and confirm/cancel buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(
            body: KineticTimeInputSheet(
              initialTime: '08:30',
              isVi: true,
            ),
          ),
        ),
      );

      // Verify Title and Subtitle
      expect(find.text('CÀI ĐẶT THỜI GIAN'), findsOneWidget);
      expect(find.text('GIỜ'), findsOneWidget);
      expect(find.text('PHÚT'), findsOneWidget);

      // Verify Text fields
      expect(find.text('08'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);

      // Verify Preset chips are visible
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);

      // Verify Buttons
      expect(find.text('XÁC NHẬN'), findsOneWidget);
      expect(find.text('HỦY'), findsOneWidget);
    });

    testWidgets('tapping preset chip updates time and confirm returns updated time', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showKineticTimeInputSheet(
                    context,
                    initialTime: '08:00',
                    isVi: true,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Tap preset chip 18:00
      await tester.tap(find.text('18:00'));
      await tester.pumpAndSettle();

      // Tap Confirm
      await tester.tap(find.text('XÁC NHẬN'));
      await tester.pumpAndSettle();

      expect(result, '18:00');
    });

    testWidgets('stepper arrows adjust hour and minute', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showKineticTimeInputSheet(
                    context,
                    initialTime: '08:00',
                    isVi: true,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Tap Up arrow on hour (first up arrow)
      final upArrows = find.byIcon(Icons.keyboard_arrow_up_rounded);
      await tester.tap(upArrows.first);
      await tester.pumpAndSettle();

      // Tap Up arrow on minute (second up arrow) -> adds 5
      await tester.tap(upArrows.last);
      await tester.pumpAndSettle();

      // Tap Confirm
      await tester.tap(find.text('XÁC NHẬN'));
      await tester.pumpAndSettle();

      expect(result, '09:05');
    });

    testWidgets('cancelling returns null', (tester) async {
      String? result = 'initial';

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showKineticTimeInputSheet(
                    context,
                    initialTime: '08:00',
                    isVi: true,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('HỦY'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
