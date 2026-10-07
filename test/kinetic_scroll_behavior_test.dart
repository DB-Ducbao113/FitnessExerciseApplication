import 'package:fitness_exercise_application/shared/kinetic/kinetic_scroll_behavior.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KineticScrollBehavior Tests', () {
    const scrollBehavior = KineticScrollBehavior();

    test('includes mouse and trackpad in dragDevices for desktop interaction', () {
      final devices = scrollBehavior.dragDevices;

      expect(devices, contains(PointerDeviceKind.mouse));
      expect(devices, contains(PointerDeviceKind.trackpad));
      expect(devices, contains(PointerDeviceKind.touch));
      expect(devices, contains(PointerDeviceKind.stylus));
      expect(devices, contains(PointerDeviceKind.invertedStylus));
      expect(devices, contains(PointerDeviceKind.unknown));
    });

    testWidgets('provides bouncing scroll physics with always scrollable parent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: scrollBehavior,
          home: Builder(
            builder: (context) {
              final physics = scrollBehavior.getScrollPhysics(context);
              expect(physics, isA<BouncingScrollPhysics>());
              expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('allows mouse click-and-drag scrolling on a ListView', (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: scrollBehavior,
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 300,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) => SizedBox(
                  height: 50,
                  child: Text('Item $index'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(controller.offset, equals(0.0));

      // Simulate mouse drag
      final gesture = await tester.startGesture(
        const Offset(150, 200),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Controller should have scrolled
      expect(controller.offset, greaterThan(0.0));
    });

    testWidgets('safely handles buildScrollbar without crashing when controller is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: scrollBehavior,
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 300,
              child: ListView(
                children: const [
                  SizedBox(height: 100, child: Text('Row 1')),
                  SizedBox(height: 100, child: Text('Row 2')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Row 1'), findsOneWidget);
    });
  });
}
