import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Next streak target calculator
int calculateNextStreakTarget(int days) {
  if (days < 3) return 3;
  if (days < 7) return 7;
  if (days < 14) return 14;
  if (days < 30) return 30;
  if (days < 100) return 100;
  return days + 50;
}

/// Dynamic Streak Tier metadata
(Color, String) getStreakTierInfo(int days, bool isVi, KineticColors colors) {
  if (days == 0) {
    return (
      colors.textMuted,
      isVi ? 'Khởi động chuỗi' : 'Dormant Spark',
    );
  }
  if (days < 3) {
    return (
      const Color(0xFFFF9F43),
      isVi ? 'Tia lửa khởi động' : 'Spark Initiator',
    );
  }
  if (days < 7) {
    return (
      colors.primary,
      isVi ? 'Ngọn lửa rực cháy' : 'Blaze Runner',
    );
  }
  if (days < 14) {
    return (
      const Color(0xFFFF7A00),
      isVi ? 'Hỏa tiễn bền bỉ' : 'Inferno Streak',
    );
  }
  if (days < 30) {
    return (
      const Color(0xFFFF3366),
      isVi ? 'Chiến binh Titan' : 'Titan Flame',
    );
  }
  return (
    const Color(0xFFA855F7),
    isVi ? 'Huyền thoại vũ trụ' : 'Supernova Legend',
  );
}

/// Streamlined, light/dark theme adaptive Streak Details Modal Sheet
class KineticStreakDetailsSheet extends ConsumerWidget {
  final StreakData streak;

  const KineticStreakDetailsSheet({
    super.key,
    required this.streak,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final workouts = ref.watch(workoutListProvider).valueOrNull ?? const <WorkoutSession>[];

    final days = streak.currentStreak;
    final longestDays = math.max(streak.longestStreak, days);
    final targetDays = calculateNextStreakTarget(days);

    final today = DateTimeHelper.localDateOnly(DateTime.now());
    final activeDates = workouts
        .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
        .toSet();
    final isTodayCompleted = activeDates.contains(today);

    final (tierColor, tierTitle) = getStreakTierInfo(days, isVi, colors);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: tierColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: tierColor.withValues(alpha: isDark ? 0.14 : 0.08),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
              BoxShadow(
                color: isDark ? Colors.black54 : Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle & Navigation Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                child: Column(
                  children: [
                    // Handle Pill
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tierColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            color: tierColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppTranslations.get('aetron_streak', currentLang),
                                style: KineticTypography.headlineSmall.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                tierTitle.toUpperCase(),
                                style: KineticTypography.unitLabel.copyWith(
                                  color: tierColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.textSecondary,
                            size: 22,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable Clean Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Tinh gọn Hero: Biểu tượng ngọn lửa & Số ngày rực rỡ
                      _StreakHeroCard(
                        days: days,
                        tierColor: tierColor,
                        isTodayCompleted: isTodayCompleted,
                        isVi: isVi,
                      ),
                      const SizedBox(height: 14),

                      // 2. Thanh 7 ngày trong tuần trực quan (This Week Strip)
                      _StreakWeekStrip(
                        today: today,
                        activeDates: activeDates,
                        tierColor: tierColor,
                        isVi: isVi,
                      ),
                      const SizedBox(height: 14),

                      // 3. Hai chỉ số cốt lõi: Kỷ lục tốt nhất & Mốc tiếp theo
                      _StreakCoreMetricsRow(
                        days: days,
                        longestDays: longestDays,
                        targetDays: targetDays,
                        tierColor: tierColor,
                        isVi: isVi,
                      ),
                      const SizedBox(height: 18),

                      // 4. Lời nhắc giữ chuỗi tinh tế
                      Row(
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 15,
                            color: tierColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isVi
                                  ? 'Tập luyện ít nhất 1 buổi/ngày để duy trì chuỗi và bảo vệ ngọn lửa của bạn.'
                                  : 'Record at least 1 workout daily to sustain your streak and keep your flame alive.',
                              style: KineticTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 5. Nút hành động CTA duy nhất
                      KineticButton(
                        label: isTodayCompleted
                            ? (isVi ? 'TIẾP TỤC TẬP LUYỆN 🔥' : 'CONTINUE WORKOUT 🔥')
                            : (isVi ? 'BẮT ĐẦU TẬP ĐỂ GIỮ CHUỖI 🔥' : 'START WORKOUT FOR STREAK 🔥'),
                        icon: Icons.play_arrow_rounded,
                        onPressed: () {
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => const ActivityScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact Hero Card with Dynamic Flame & Days Metric
class _StreakHeroCard extends StatelessWidget {
  final int days;
  final Color tierColor;
  final bool isTodayCompleted;
  final bool isVi;

  const _StreakHeroCard({
    required this.days,
    required this.tierColor,
    required this.isTodayCompleted,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final greenColor = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
    final warningColor = isDark ? const Color(0xFFFFBA20) : const Color(0xFFD97706);
    final activeStatusColor = isTodayCompleted ? greenColor : warningColor;

    return KineticCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      topAccentColor: tierColor,
      child: Column(
        children: [
          // Flame Icon Badge & Big Days Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.45),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tierColor.withValues(alpha: isDark ? 0.35 : 0.2),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 36,
                  color: tierColor,
                ),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$days',
                    style: KineticTypography.metricHero.copyWith(
                      color: colors.textPrimary,
                      fontSize: 48,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVi ? 'NGÀY LIÊN TIẾP' : 'DAYS STREAK',
                    style: KineticTypography.unitLabel.copyWith(
                      color: tierColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Today Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: activeStatusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: activeStatusColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTodayCompleted ? Icons.check_circle_rounded : Icons.bolt_rounded,
                  size: 14,
                  color: activeStatusColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isTodayCompleted
                        ? (isVi ? 'Hôm nay: Đã hoàn thành' : 'Today secured')
                        : (isVi ? 'Hôm nay: Cần 1 buổi tập' : '1 workout needed today'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: activeStatusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 7-Day Matrix Strip Widget
class _StreakWeekStrip extends StatelessWidget {
  final DateTime today;
  final Set<DateTime> activeDates;
  final Color tierColor;
  final bool isVi;

  const _StreakWeekStrip({
    required this.today,
    required this.activeDates,
    required this.tierColor,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final labelsVi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final labelsEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final labels = isVi ? labelsVi : labelsEn;

    var activeThisWeek = 0;
    for (var i = 0; i < 7; i++) {
      if (activeDates.contains(startOfWeek.add(Duration(days: i)))) {
        activeThisWeek++;
      }
    }

    return KineticCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: colors.primary, size: 15),
              const SizedBox(width: 6),
              Text(
                isVi ? 'TUẦN NÀY' : 'THIS WEEK',
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$activeThisWeek/7 ${isVi ? 'ngày' : 'days'}',
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 7 Capsule Day Blocks
          Row(
            children: [
              for (var index = 0; index < 7; index++) ...[
                Expanded(
                  child: _StreakDayCapsule(
                    label: labels[index],
                    date: startOfWeek.add(Duration(days: index)),
                    today: today,
                    isActive: activeDates.contains(
                      startOfWeek.add(Duration(days: index)),
                    ),
                    tierColor: tierColor,
                  ),
                ),
                if (index < 6) const SizedBox(width: 5),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakDayCapsule extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateTime today;
  final bool isActive;
  final Color tierColor;

  const _StreakDayCapsule({
    required this.label,
    required this.date,
    required this.today,
    required this.isActive,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isToday = date == today;
    final isFuture = date.isAfter(today);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? tierColor.withValues(alpha: 0.16)
            : isToday
                ? colors.surface2
                : colors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? colors.primary
              : isActive
                  ? tierColor.withValues(alpha: 0.5)
                  : colors.borderSubtle,
          width: isToday ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: KineticTypography.unitLabel.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isToday
                  ? colors.primary
                  : isActive
                      ? colors.textPrimary
                      : colors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${date.day}',
            style: KineticTypography.bodySmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isToday ? colors.primary : colors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? tierColor
                  : isToday
                      ? colors.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
            ),
            child: isActive
                ? Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 12,
                  )
                : isToday
                    ? Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                        ),
                      )
                    : Icon(
                        isFuture ? Icons.circle_outlined : Icons.remove_rounded,
                        color: colors.textMuted,
                        size: 9,
                      ),
          ),
        ],
      ),
    );
  }
}

/// 2-Card Core Metrics Bento Row
class _StreakCoreMetricsRow extends StatelessWidget {
  final int days;
  final int longestDays;
  final int targetDays;
  final Color tierColor;
  final bool isVi;

  const _StreakCoreMetricsRow({
    required this.days,
    required this.longestDays,
    required this.targetDays,
    required this.tierColor,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final remainingDays = math.max(0, targetDays - days);

    return Row(
      children: [
        // Card 1: Kỷ lục chuỗi dài nhất
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFBA20).withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFBA20).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFBA20),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (isVi ? 'Kỷ lục tốt nhất' : 'Best Streak').toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$longestDays ${isVi ? 'Ngày' : 'Days'}',
                  style: KineticTypography.headlineSmall.copyWith(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isVi ? 'Kỷ lục cá nhân' : 'Personal record',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: const Color(0xFFFFBA20).withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Card 2: Cột mốc tiếp theo
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.flag_rounded,
                        color: colors.primary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (isVi ? 'Mốc tiếp theo' : 'Next Target').toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$targetDays ${isVi ? 'Ngày' : 'Days'}',
                  style: KineticTypography.headlineSmall.copyWith(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isVi ? 'Còn $remainingDays ngày' : '$remainingDays days left',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: colors.primary.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
