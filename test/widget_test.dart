import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_exercise_application/app/app.dart';

void main() {
  testWidgets('App widget can be constructed', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  }, skip: true);
}
