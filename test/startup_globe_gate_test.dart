import 'package:fitness_exercise_application/features/auth/presentation/screens/startup_globe_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the native globe visible until startup completes', () {
    final gate = StartupGlobeGate();

    expect(gate.shouldShow, isTrue);

    gate.complete();

    expect(gate.shouldShow, isFalse);
  });
}
