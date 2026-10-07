import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_activity_quick_switch.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_hero_card.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_home_top_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kinetic HomeScreen Refinements Widget Tests', () {
    testWidgets('KineticHomeTopBar does not render AETRON brand text but renders greeting and name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticHomeTopBar(
              avatarImage: null,
              initials: 'DB',
              displayName: 'Duc Bao',
              greeting: 'Chào buổi sáng,',
              streakCount: 5,
              onAvatarTap: () {},
              onStreakTap: () {},
              onNotificationTap: () {},
            ),
          ),
        ),
      );

      // Verify AETRON brand text is NOT present
      expect(find.text('AETRON'), findsNothing);

      // Verify athlete greetings & streak are present
      expect(find.text('Chào buổi sáng,'), findsOneWidget);
      expect(find.text('Duc Bao'), findsOneWidget);
      expect(find.text('5 ngày'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      // Verify avatar initials circle is no longer rendered
      expect(find.text('DB'), findsNothing);
    });

    testWidgets('KineticHeroCard does not display overlay GPS and category badges on top of image', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: KineticHeroCard(
                title: 'Bứt phá tốc độ cùng buổi chạy bộ!',
                categoryName: 'Chạy bộ ngoài trời',
                weeklyProgressText: 'Tuần này: 12.5 km',
                targetGoalText: 'Mục tiêu: 50 km',
                ctaLabel: 'Bắt đầu chạy bộ',
                imageAsset: 'assets/running_real.jpg',
                onStartTap: () {},
                onGoalTap: () {},
              ),
            ),
          ),
        ),
      );

      // Verify overlay badges are removed
      expect(find.text('GPS SẴN SÀNG'), findsNothing);
      expect(find.text('CHẠY BỘ NGOÀI TRỜI'), findsNothing);
      expect(find.text('ĐẠP XE NGOÀI TRỜI'), findsNothing);
      expect(find.text('ĐI BỘ THỂ THAO'), findsNothing);

      // Verify content is clean and present
      expect(find.text('Bứt phá tốc độ cùng buổi chạy bộ!'), findsOneWidget);
      expect(find.text('Tuần này: 12.5 km'), findsOneWidget);
      expect(find.text('Mục tiêu: 50 km'), findsOneWidget);
      expect(find.text('Bắt đầu chạy bộ'), findsOneWidget);
    });

    testWidgets('KineticActivityQuickSwitch renders sports chips cleanly without Tùy biến', (tester) async {
      String selected = 'running';

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return KineticActivityQuickSwitch(
                  selectedActivity: selected,
                  onSelected: (val) {
                    setState(() {
                      selected = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('CHỌN BỘ MÔN NHANH'), findsOneWidget);
      expect(find.text('Tùy biến'), findsNothing);
      expect(find.text('Đạp xe'), findsOneWidget);
      expect(find.text('Chạy bộ'), findsOneWidget);
      expect(find.text('Đi bộ'), findsOneWidget);

      await tester.tap(find.text('Đạp xe'));
      await tester.pumpAndSettle();
      expect(selected, 'cycling');
    });
  });
}
