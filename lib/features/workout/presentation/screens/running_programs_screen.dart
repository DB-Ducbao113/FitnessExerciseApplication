import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RunningProgramsScreen extends ConsumerWidget {
  const RunningProgramsScreen({super.key});

  static const List<Map<String, dynamic>> _programs = [
    {
      'id': 'couch_to_5k',
      'titleKey': 'couch_to_5k',
      'badgeEn': 'BEGINNER • 4 WEEKS',
      'badgeVi': 'NGƯỜI MỚI • 4 TUẦN',
      'targetDistance': '5.0 km',
      'targetPace': '6:45 - 7:30 min/km',
      'targetZone': 'Zone 2 (125-140 bpm)',
      'cadence': '165-170 spm',
      'descriptionEn': 'Ideal for beginners building endurance from zero to running 5km continuously without fatigue.',
      'descriptionVi': 'Giáo án chuẩn cho người mới bắt đầu luyện tập sức bền từ 0 đến chạy liên tục 5km không mệt mỏi.',
      'instructionsEn': [
        '1. Warm Up: 5 minutes walking + dynamic leg swings.',
        '2. Interval Routine: Run 1 minute, walk 1.5 minutes (Repeat 8 times).',
        '3. Form Tip: Maintain upright posture and midfoot landing.',
        '4. Cool Down: 5 minutes slow walk & calf stretching.',
      ],
      'instructionsVi': [
        '1. Khởi động: 5 phút đi bộ nhẹ nhàng + xoay khớp gối, cổ chân.',
        '2. Tiến trình: Chạy 1 phút, đi bộ 1.5 phút (Lặp lại 8 hiệp).',
        '3. Kỹ thuật: Giữ tư thế thẳng người, tiếp đất bằng giữa bàn chân.',
        '4. Thả lỏng: 5 phút đi bộ chậm & giãn cơ bắp chân.',
      ],
    },
    {
      'id': 'easy_base_run',
      'titleKey': 'easy_base_run',
      'badgeEn': 'RECOVERY • ZONE 2 BASE',
      'badgeVi': 'PHỤC HỒI • ZONE 2 BASE',
      'targetDistance': '3.0 - 5.0 km',
      'targetPace': '7:00 - 8:00 min/km',
      'targetZone': 'Zone 2 Low HR',
      'cadence': '160-165 spm',
      'descriptionEn': 'Conversational pace recovery run to strengthen aerobic base and burn fat with low joint stress.',
      'descriptionVi': 'Bài chạy thả lỏng tốc độ nói chuyện giúp củng cố tim mạch Zone 2, đốt mỡ hiệu quả và giảm áp lực lên khớp.',
      'instructionsEn': [
        '1. Warm Up: 3 minutes light jog.',
        '2. Main Run: Maintain steady Zone 2 heart rate (able to speak full sentences).',
        '3. Breathing: Deep 2:2 nasal-diaphragmatic breathing.',
        '4. Cool Down: 3 minutes walk.',
      ],
      'instructionsVi': [
        '1. Khởi động: 3 phút chạy chậm thả lỏng.',
        '2. Bài chạy chính: Giữ nhịp tim Zone 2 ổn định (vừa chạy vừa nói chuyện bình thường).',
        '3. Nhịp thở: Hít thở sâu 2 nhịp vào, 2 nhịp ra bằng cơ hoành.',
        '4. Thả lỏng: 3 phút đi bộ.',
      ],
    },
    {
      'id': 'pace_builder_10k',
      'titleKey': 'pace_builder_10k',
      'badgeEn': 'INTERMEDIATE • 6 WEEKS',
      'badgeVi': 'TRUNG CẤP • 6 TUẦN',
      'targetDistance': '10.0 km',
      'targetPace': '5:45 - 6:30 min/km',
      'targetZone': 'Zone 3 Tempo Pace',
      'cadence': '170-178 spm',
      'descriptionEn': 'Build stamina and sustain a faster 10K race pace with structured tempo runs and progressive volume.',
      'descriptionVi': 'Rèn luyện khả năng duy trì tốc độ cho cự ly 10km thông qua các bài Tempo run nâng dần khối lượng.',
      'instructionsEn': [
        '1. Warm Up: 10 minutes easy jog + 3 strides.',
        '2. Main Workout: 6 km Tempo run at target 10K race pace.',
        '3. Cadence Tip: Keep quick compact steps at ~175 spm.',
        '4. Cool Down: 5 minutes light jog.',
      ],
      'instructionsVi': [
        '1. Khởi động: 10 phút chạy nhẹ + 3 nhịp tăng tốc ngắn.',
        '2. Bài chính: 6 km Tempo run ở tốc độ mục tiêu 10km.',
        '3. Mẹo sải chân: Duy trì nhịp chân nhanh guồng ~175 spm.',
        '4. Thả lỏng: 5 phút chạy thả lỏng.',
      ],
    },
    {
      'id': 'speed_intervals',
      'titleKey': 'speed_intervals',
      'badgeEn': 'ADVANCED • SPEEDWORK',
      'badgeVi': 'TỐC ĐỘ • NÂNG CAO',
      'targetDistance': '6.0 km Total',
      'targetPace': '4:30 - 5:15 min/km',
      'targetZone': 'Zone 4-5 High HR',
      'cadence': '180+ spm',
      'descriptionEn': 'High intensity interval training (400m reps) to boost VO2 max and explosive running speed.',
      'descriptionVi': 'Bài tập biến tốc cường độ cao 400m giúp gia tăng VO2 Max và bứt phá tốc độ chạy.',
      'instructionsEn': [
        '1. Warm Up: 12 minutes jog + dynamic mobility drills.',
        '2. Main Intervals: 6 x 400m fast sprints with 90 sec rest walk.',
        '3. Form Tip: High knee drive and strong arm swing.',
        '4. Cool Down: 8 minutes walk.',
      ],
      'instructionsVi': [
        '1. Khởi động: 12 phút chạy nhẹ + ép dẻo cơ động.',
        '2. Bài chính: 6 x 400m bứt tốc kèm 90 giây đi bộ thả lỏng.',
        '3. Kỹ thuật: Đánh tay mạnh mẽ, nâng cao đùi nhịp nhàng.',
        '4. Thả lỏng: 8 phút đi bộ thả lỏng.',
      ],
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: AetronColors.cyanSoft,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppTranslations.get('runner_programs', currentLang),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AetronColors.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _programs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final prog = _programs[index];
                  final title = AppTranslations.get(prog['titleKey'] as String, currentLang);
                  final badge = currentLang == AppLanguage.vi ? prog['badgeVi'] : prog['badgeEn'];
                  final desc = currentLang == AppLanguage.vi ? prog['descriptionVi'] : prog['descriptionEn'];

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AetronColors.panelHigh,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AetronColors.cyan.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: AetronColors.cyan.withValues(alpha: 0.12),
                          blurRadius: 14,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AetronColors.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            badge as String,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AetronColors.cyan,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Title
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AetronColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Description
                        Text(
                          desc as String,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            color: AetronColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Targets metrics preview bar
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1524),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AetronColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _MetricTile(
                                label: currentLang == AppLanguage.vi ? 'KHOẢNG CÁCH' : 'TARGET DISTANCE',
                                value: prog['targetDistance'] as String,
                                icon: Icons.route_rounded,
                              ),
                              Container(width: 1, height: 24, color: AetronColors.borderSubtle),
                              _MetricTile(
                                label: currentLang == AppLanguage.vi ? 'NHỊP TIM' : 'HR ZONE',
                                value: prog['targetZone'] as String,
                                icon: Icons.favorite_border_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // CTA Button to Open Coaching Guide Sheet
                        Aetron3DPrimaryButton(
                          label: AppTranslations.get('coaching_guide', currentLang),
                          icon: Icons.menu_book_rounded,
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => _ProgramGuideSheet(program: prog),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AetronColors.cyanSoft),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AetronColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AetronColors.cyan,
          ),
        ),
      ],
    );
  }
}

/// Modal Bottom Sheet showing Step-by-Step Coaching Instructions & Start CTA
class _ProgramGuideSheet extends ConsumerWidget {
  const _ProgramGuideSheet({required this.program});

  final Map<String, dynamic> program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final title = AppTranslations.get(program['titleKey'] as String, currentLang);
    final instructions = (currentLang == AppLanguage.vi
        ? program['instructionsVi']
        : program['instructionsEn']) as List<String>;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: AetronColors.borderAccent, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AetronColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Title
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AetronColors.space,
                    border: Border.all(color: AetronColors.cyan),
                  ),
                  child: const Icon(
                    Icons.directions_run_rounded,
                    color: AetronColors.cyan,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.textPrimary,
                        ),
                      ),
                      Text(
                        AppTranslations.get('how_to_execute', currentLang),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: AetronColors.cyanSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Target Parameters Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1524),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AetronColors.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GuideParam(
                        label: currentLang == AppLanguage.vi ? 'PACE MỤC TIÊU' : 'TARGET PACE',
                        val: program['targetPace'] as String,
                      ),
                      _GuideParam(
                        label: currentLang == AppLanguage.vi ? 'GUỒNG CHÂN' : 'CADENCE',
                        val: program['cadence'] as String,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Coaching Steps Title
            Text(
              AppTranslations.get('coaching_guide', currentLang),
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AetronColors.cyan,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),

            // Step by Step List
            Column(
              children: instructions.map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AetronColors.space,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AetronColors.borderSubtle),
                    ),
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: AetronColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // START PROGRAM NOW CTA
            Aetron3DPrimaryButton(
              label: AppTranslations.get('start_program', currentLang),
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecordScreen(
                      activityType: 'running',
                      requireGps: true,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideParam extends StatelessWidget {
  const _GuideParam({required this.label, required this.val});

  final String label;
  final String val;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AetronColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AetronColors.cyan,
          ),
        ),
      ],
    );
  }
}
