import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_state_panel.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// --- Helper Data Classes ---
class _WeeklyHomeStats {
  final DateTime startOfWeek;
  final double weeklyDistanceKm;
  final double weeklyCalories;
  final int weeklyWorkoutsDurationSec;
  final int workoutCount;
  final int activeDayCount;

  const _WeeklyHomeStats({
    required this.startOfWeek,
    required this.weeklyDistanceKm,
    required this.weeklyCalories,
    required this.weeklyWorkoutsDurationSec,
    required this.workoutCount,
    required this.activeDayCount,
  });
}



class _WeeklyHeroData {
  final int weekNumber;
  final double current;
  final double target;
  final String unit;
  final String badgeLabel;
  final String helperLabel;

  const _WeeklyHeroData({
    required this.weekNumber,
    required this.current,
    required this.target,
    required this.unit,
    required this.badgeLabel,
    required this.helperLabel,
  });
}

// --- Business Providers (PRESERVED) ---
final _weeklyHomeStatsProvider = Provider<_WeeklyHomeStats>((ref) {
  final workouts =
      ref.watch(workoutListProvider).valueOrNull ?? <WorkoutSession>[];
  final start = _startOfWeek(DateTime.now());
  final end = start.add(const Duration(days: 6));

  final weeklyWorkouts = workouts.where((workout) {
    final date = DateTimeHelper.localDateOnly(workout.startedAt);
    return !date.isBefore(start) && !date.isAfter(end);
  }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final activeDates = weeklyWorkouts
      .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
      .toSet();

  double effectiveDistance(WorkoutSession w) {
    return w.gpsAnalysis.validDistanceKm > 0
        ? w.gpsAnalysis.validDistanceKm
        : w.distanceKm;
  }

  return _WeeklyHomeStats(
    startOfWeek: start,
    weeklyDistanceKm: weeklyWorkouts.fold(
      0.0,
      (sum, w) => sum + effectiveDistance(w),
    ),
    weeklyCalories: weeklyWorkouts.fold(0.0, (sum, w) => sum + w.caloriesKcal),
    weeklyWorkoutsDurationSec: weeklyWorkouts.fold(
      0,
      (sum, w) => sum + w.durationSec,
    ),
    workoutCount: weeklyWorkouts.length,
    activeDayCount: activeDates.length,
  );
});



final _weeklyHeroProvider = Provider<_WeeklyHeroData>((ref) {
  final currentLang = ref.watch(appLanguageProvider);
  final weekly = ref.watch(_weeklyHomeStatsProvider);
  final goal = ref.watch(userGoalProvider).valueOrNull;
  final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

  double current;
  double target;
  String unit;
  String badgeLabel;
  String helperLabel;

  if (goal != null) {
    switch (goal.goalType) {
      case GoalType.distance:
        current = weekly.weeklyDistanceKm;
        unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
        break;
      case GoalType.workouts:
        current = weekly.workoutCount.toDouble();
        unit = currentLang == AppLanguage.vi ? 'buổi' : 'sessions';
        break;
      case GoalType.calories:
        current = weekly.weeklyCalories;
        unit = 'kcal';
        break;
    }
    target = goal.period == GoalPeriod.weekly
        ? goal.targetValue
        : _monthlyTargetToWeeklyTarget(goal.targetValue, weekly.startOfWeek);
    target = target <= 0 ? 1 : target;
    final displayUnit = (unit == 'kcal' && currentLang == AppLanguage.vi) ? 'CALO' : unit.toUpperCase();
    badgeLabel =
        '${_formatMetric(current, unit)} / ${_formatMetric(target, unit)} $displayUnit';
    helperLabel = goal.period == GoalPeriod.weekly
        ? (currentLang == AppLanguage.vi
            ? 'Liên kết với mục tiêu tuần của bạn'
            : 'Linked to your weekly goal')
        : (currentLang == AppLanguage.vi
            ? 'Dựa trên mục tiêu tháng của bạn'
            : 'Based on your monthly goal');
  } else {
    current = weekly.weeklyCalories;
    target = math.max(4200.0, current <= 0 ? 4200.0 : current * 1.35);
    unit = 'kcal';
    final displayUnit = currentLang == AppLanguage.vi ? 'CALO' : 'KCAL';
    badgeLabel =
        '${_formatMetric(current, unit)} / ${_formatMetric(target, unit)} $displayUnit';
    helperLabel = currentLang == AppLanguage.vi
        ? 'Nhấn để đặt mục tiêu'
        : 'Tap to set your goal';
  }

  return _WeeklyHeroData(
    weekNumber: _weekNumber(weekly.startOfWeek),
    current: current,
    target: target,
    unit: unit,
    badgeLabel: badgeLabel,
    helperLabel: helperLabel,
  );
});

int _nextStreakTarget(int days) {
  if (days < 7) return 7;
  if (days < 30) return 30;
  if (days < 90) return 90;
  if (days < 365) return 365;
  return 730;
}

// --- REDESIGNED HOME SCREEN ---
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutListProvider);
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;

    return Scaffold(
      backgroundColor: AetronColors.background,
      body: SafeArea(
        top: true,
        child: RefreshIndicator(
          color: AetronColors.primary,
          backgroundColor: AetronColors.surface,
          onRefresh: () async {
            await ref.read(workoutListProvider.notifier).refresh();
            final userId = ref.read(currentUserIdProvider);
            if (userId != null) {
              ref.invalidate(userProfileProvider(userId));
            }
            await ref.read(userGoalProvider.notifier).refresh();
          },
          child: AetronBackground(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _HomeTopBar()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AetronSpacing.page,
                    AetronSpacing.md,
                    AetronSpacing.page,
                    100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (isOffline) ...[
                        const AetronOfflineBanner(),
                        const SizedBox(height: AetronSpacing.md),
                      ],
                      workoutsAsync.when(
                        loading: () => const HomeSkeletonView(),
                        error: (err, stack) => ErrorState(
                          title: 'Dashboard unavailable',
                          message: 'Could not refresh your workout metrics right now.',
                          onRetry: () =>
                              ref.read(workoutListProvider.notifier).refresh(),
                        ),
                        data: (workouts) {
                          return const _HomePopulatedView();
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- SECTION 1: HEADER & TOP BAR ---

/// Returns contextual greeting info based on the hour of day.
_TimeContext _buildTimeContext(int hour, AppLanguage lang) {
  if (hour >= 5 && hour < 12) {
    return _TimeContext(
      greeting: lang == AppLanguage.vi ? 'Chào buổi sáng' : 'Good morning',
      emoji: '☀️',
      pillColor: const Color(0xFFFFBB57),
      glowColor: const Color(0xFFFFD580),
    );
  } else if (hour >= 12 && hour < 17) {
    return _TimeContext(
      greeting: lang == AppLanguage.vi ? 'Chào buổi chiều' : 'Good afternoon',
      emoji: '🌤️',
      pillColor: const Color(0xFF39B5F2),
      glowColor: AetronColors.cyan,
    );
  } else if (hour >= 17 && hour < 21) {
    return _TimeContext(
      greeting: lang == AppLanguage.vi ? 'Chào buổi tối' : 'Good evening',
      emoji: '🌇',
      pillColor: const Color(0xFFFF7E4F),
      glowColor: const Color(0xFFFFAA80),
    );
  } else {
    return _TimeContext(
      greeting: lang == AppLanguage.vi ? 'Đêm khuya rồi' : 'Burning midnight oil',
      emoji: '🌙',
      pillColor: const Color(0xFF9B7EFF),
      glowColor: const Color(0xFFCBB2FF),
    );
  }
}

class _TimeContext {
  final String greeting;
  final String emoji;
  final Color pillColor;
  final Color glowColor;
  const _TimeContext({required this.greeting, required this.emoji, required this.pillColor, required this.glowColor});
}

class _ContextualStatusPill extends StatelessWidget {
  final AppLanguage currentLang;
  const _ContextualStatusPill({required this.currentLang});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final ctx = _buildTimeContext(hour, currentLang);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ctx.pillColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ctx.pillColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: ctx.glowColor.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ctx.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            ctx.greeting.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: ctx.pillColor,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final avatar = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? avatarImage = avatar.imageProvider;
    final streak = ref.watch(streakProvider);
    final initials = _initialsFromEmail(user?.email);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AetronSpacing.page,
        AetronSpacing.sm,
        AetronSpacing.page,
        AetronSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Pill row (contextual greeting)
          _ContextualStatusPill(currentLang: currentLang),
          const SizedBox(height: 10),
          Row(
            children: [
              // 3D Avatar Container
              AetronAvatar(
                image: avatarImage,
                label: initials,
                size: 46,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              const SizedBox(width: 12),

              // User Name
              Expanded(
                child: Text(
                  _homeDisplayName(user),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Streak Pill
              AetronStreakPill(
                streak: streak.currentStreak,
                compact: true,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _StreakDetailsSheet(streak: streak),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- POPULATED HOME VIEW ---
class _HomePopulatedView extends StatelessWidget {
  const _HomePopulatedView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Weekly Goal Progress (Weekly Progress first)
        RepaintBoundary(child: _WeeklyGoalSection()),
        SizedBox(height: AetronSpacing.lg),

        // 2. Recent Workout Log (Recent Workout second)
        RepaintBoundary(child: _RecentWorkoutSection()),
        SizedBox(height: AetronSpacing.lg),

        // 3. Running Series (Running Series third)
        RepaintBoundary(child: _SpotlightWorkoutSection()),
        SizedBox(height: AetronSpacing.lg),

        // 4. Start Workout Banner (Start Workout last)
        RepaintBoundary(child: _StartWorkout3DHeroCard()),
      ],
    );
  }
}

// --- SPOTLIGHT WORKOUT SECTION (RUNNING SERIES FOR RUNNERS) ---
class _SpotlightWorkoutSection extends ConsumerWidget {
  const _SpotlightWorkoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final programs = RunningProgramsScreen.programs;

    final icons = {
      'couch_to_5k': Icons.directions_run_rounded,
      'easy_base_run': Icons.favorite_border_rounded,
      'pace_builder_10k': Icons.speed_rounded,
      'speed_intervals': Icons.bolt_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppTranslations.get('running_series', currentLang),
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AetronColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RunningProgramsScreen()),
                );
              },
              child: Text(
                AppTranslations.get('see_all', currentLang),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AetronColors.cyan,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: programs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final prog = programs[index];
              final title = AppTranslations.get(prog.titleKey, currentLang);
              final badge = currentLang == AppLanguage.vi ? prog.badgeVi : prog.badgeEn;
              final iconData = icons[prog.id] ?? Icons.directions_run_rounded;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    RunningProgramsScreen.showProgramGuide(context, prog);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AetronColors.panelHigh,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AetronColors.cyan.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 18,
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
                        // Top Row: Category Tag & Icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AetronColors.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AetronColors.cyan,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Icon(iconData, size: 20, color: AetronColors.cyanSoft),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AetronColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Target Info
                        Text(
                          '${prog.targetDistance} • ${prog.targetZone}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: AetronColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),

                        // Bottom Action CTA
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AetronColors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AetronRadius.pill),
                            border: Border.all(
                              color: AetronColors.cyan.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currentLang == AppLanguage.vi ? 'XEM GIÁO ÁN' : 'VIEW GUIDE',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AetronColors.cyan,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: AetronColors.cyan,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- 3. WEEKLY GOAL SECTION WITH ANIMATED GLOWING ACTIVITY RING ---
class _WeeklyGoalSection extends ConsumerWidget {
  const _WeeklyGoalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final hero = ref.watch(_weeklyHeroProvider);
    final progress = (hero.target > 0 ? (hero.current / hero.target) : 0.0).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    // Color mapping based on goal completion
    final ringColor = percent >= 100
        ? AetronColors.gold
        : percent >= 70
            ? AetronColors.mint
            : AetronColors.cyan;
    final glowColor = percent >= 100
        ? AetronColors.gold
        : percent >= 70
            ? AetronColors.mint
            : const Color(0xFF00FFFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: currentLang == AppLanguage.vi ? 'MỤC TIÊU TUẦN' : 'WEEKLY PROGRESS',
          subtitle: hero.helperLabel,
          actionLabel: currentLang == AppLanguage.vi ? 'ĐẶT MỤC TIÊU' : 'SET GOAL',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoalScreen()),
          ),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AetronSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AetronSpacing.md + 4),
          backgroundColor: AetronColors.panelHigh,
          borderColor: ringColor.withValues(alpha: 0.35),
          hasGlow: true,
          glowColor: ringColor,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoalScreen()),
          ),
          child: Row(
            children: [
              // Animated Radial Goal Ring
              _AnimatedGoalRing(
                progress: progress,
                percent: percent,
                ringColor: ringColor,
                glowColor: glowColor,
                currentLang: currentLang,
              ),
              const SizedBox(width: AetronSpacing.md),
              // Goal Text Telemetry Metrics
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ringColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AetronRadius.pill),
                            border: Border.all(
                              color: ringColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            currentLang == AppLanguage.vi
                                ? 'TUẦN ${hero.weekNumber}'
                                : 'WEEK ${hero.weekNumber}',
                            style: AetronTypography.caption.copyWith(
                              color: ringColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hero.badgeLabel,
                      style: AetronTypography.headingSmall.copyWith(
                        color: AetronColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      percent >= 100
                          ? (currentLang == AppLanguage.vi
                              ? '🏆 Xuất sắc! Bạn đã hoàn thành mục tiêu!'
                              : '🏆 Goal Completed! Outstanding work!')
                          : percent >= 70
                              ? (currentLang == AppLanguage.vi
                                  ? '🔥 Sắp về đích! Tiếp tục chinh phục!'
                                  : '🔥 Almost there! Keep pushing!')
                              : (currentLang == AppLanguage.vi
                                  ? 'Cố lên! Bạn sắp hoàn thành mục tiêu.'
                                  : 'Keep pushing! Almost at target.'),
                      style: AetronTypography.bodySmall.copyWith(
                        color: percent >= 100
                            ? AetronColors.gold
                            : percent >= 70
                                ? AetronColors.mint
                                : AetronColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AetronColors.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- ANIMATED GOAL RING ---
class _AnimatedGoalRing extends StatefulWidget {
  final double progress;
  final int percent;
  final Color ringColor;
  final Color glowColor;
  final AppLanguage currentLang;

  const _AnimatedGoalRing({
    required this.progress,
    required this.percent,
    required this.ringColor,
    required this.glowColor,
    required this.currentLang,
  });

  @override
  State<_AnimatedGoalRing> createState() => _AnimatedGoalRingState();
}

class _AnimatedGoalRingState extends State<_AnimatedGoalRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedGoalRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final animatedProgress = widget.progress * _anim.value;
        final animatedPercent = (animatedProgress * 100).round();
        return SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(90, 90),
                painter: _ActivityRingPainter(
                  progress: animatedProgress,
                  trackColor: AetronColors.space,
                  ringColor: widget.ringColor,
                  glowColor: widget.glowColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$animatedPercent%',
                    style: AetronTypography.headingMedium.copyWith(
                      color: widget.ringColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    widget.currentLang == AppLanguage.vi ? 'MỤC TIÊU' : 'GOAL',
                    style: AetronTypography.label.copyWith(
                      color: AetronColors.textSecondary,
                      fontSize: 8,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color ringColor;
  final Color glowColor;

  _ActivityRingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width - 10) / 2;
    final innerRadius = outerRadius - 10;
    const outerStroke = 8.0;
    const innerStroke = 3.0;

    // Outer track
    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, outerRadius, trackPaint);

    // Inner subtle track ring
    final innerTrackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, innerRadius, innerTrackPaint);

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress;
    final startAngle = -math.pi / 2;
    final arcRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerArcRect = Rect.fromCircle(center: center, radius: innerRadius);

    // Outer glow blur
    final outerGlowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke + 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, outerGlowPaint);

    // Outer ring with sweep gradient
    final outerRingPaint = Paint()
      ..shader = SweepGradient(
        colors: [ringColor.withValues(alpha: 0.4), ringColor, glowColor],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, outerRingPaint);

    // Inner accent ring
    final innerRingPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(innerArcRect, startAngle, sweepAngle * 0.85, false, innerRingPaint);

    // Endpoint glowing orb dot
    if (progress > 0.02) {
      final endX = center.dx + outerRadius * math.cos(startAngle + sweepAngle);
      final endY = center.dy + outerRadius * math.sin(startAngle + sweepAngle);
      final dotGlowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(endX, endY), 6, dotGlowPaint);
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(endX, endY), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.ringColor != ringColor;
  }
}


// --- REALISTIC ATHLETIC START WORKOUT HERO CARD ---
class _StartWorkout3DHeroCard extends ConsumerWidget {
  const _StartWorkout3DHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => ref.read(mainTabControllerProvider.notifier).state = 1,
        child: Container(
          height: 165,
          decoration: BoxDecoration(
            color: const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AetronColors.cyan.withValues(alpha: 0.40),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AetronColors.cyan.withValues(alpha: 0.15),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Realistic Athlete Photo
                Image.asset(
                  'assets/home_hero_runner.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),

                // 2. High-Contrast Obsidian Gradient Overlay
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF070B14),
                        const Color(0xFF070B14).withValues(alpha: 0.95),
                        const Color(0xFF070B14).withValues(alpha: 0.55),
                        const Color(0xFF070B14).withValues(alpha: 0.10),
                      ],
                      stops: const [0.0, 0.45, 0.70, 1.0],
                    ),
                  ),
                ),

                // 3. Subtle Cyber Glow
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AetronColors.cyan.withValues(alpha: 0.18),
                        Colors.transparent,
                        AetronColors.cyan.withValues(alpha: 0.06),
                      ],
                      stops: const [0.0, 0.50, 1.0],
                    ),
                  ),
                ),

                // 4. Content (Left side)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.get('ready_to_move', currentLang),
                            style: AetronTypography.headingLarge.copyWith(
                              color: AetronColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 170,
                            child: Text(
                              AppTranslations.get('ready_to_move_sub', currentLang),
                              style: AetronTypography.bodySmall.copyWith(
                                color: AetronColors.cyanSoft.withValues(alpha: 0.85),
                                fontSize: 11,
                                height: 1.25,
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AetronColors.cyan,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AetronColors.cyan.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppTranslations.get('start_workout', currentLang),
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF070B14),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: Color(0xFF070B14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- RECENT WORKOUT SECTION ---
class _RecentWorkoutSection extends ConsumerWidget {
  const _RecentWorkoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final workouts = ref.watch(workoutListProvider).valueOrNull ?? [];
    final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

    if (workouts.isEmpty) return const SizedBox.shrink();

    final recent = workouts.first;
    final dateStr =
        '${recent.startedAt.day.toString().padLeft(2, '0')}/${recent.startedAt.month.toString().padLeft(2, '0')}/${recent.startedAt.year}';
    final activityType = WorkoutFormatters.formatActivityType(recent.activityType, currentLang).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: currentLang == AppLanguage.vi ? 'BUỔI TẬP GẦN ĐÂY' : 'RECENT WORKOUT',
          actionLabel: AppTranslations.get('see_all', currentLang),
          onAction: () {
            ref.read(mainTabControllerProvider.notifier).state = 2; // History Tab
          },
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AetronSpacing.sm),
        AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkoutDetailsScreen(workoutId: recent.id),
            ),
          ),
          padding: const EdgeInsets.all(AetronSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AetronColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AetronRadius.medium),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AetronColors.cyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: AetronSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppBadge(label: activityType, color: AetronColors.cyan),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: AetronTypography.caption.copyWith(
                            color: AetronColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          WorkoutFormatters.formatDistance(
                            recent.distanceKm,
                            useMetric: useMetricUnits,
                          ),
                          style: AetronTypography.headingSmall.copyWith(
                            color: AetronColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AetronColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          WorkoutFormatters.formatDurationFromSeconds(recent.durationSec),
                          style: AetronTypography.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.local_fire_department_outlined,
                          size: 14,
                          color: AetronColors.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recent.caloriesKcal.round()} kcal',
                          style: AetronTypography.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AetronColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 3D STREAK DETAILS SHEET ---
// --- 3D STREAK DETAILS SHEET (RE-ENGINEERED ULTRA-PREMIUM) ---
class _StreakDetailsSheet extends ConsumerWidget {
  const _StreakDetailsSheet({required this.streak});

  final StreakData streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final workouts = ref.watch(workoutListProvider).valueOrNull ?? const <WorkoutSession>[];
    final days = streak.currentStreak;
    final longestDays = math.max(streak.longestStreak, days);
    final targetDays = _nextStreakTarget(days);
    final progress = (days / targetDays).clamp(0.0, 1.0);

    final today = DateTimeHelper.localDateOnly(DateTime.now());
    final activeDates = workouts
        .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
        .toSet();
    final isTodayCompleted = activeDates.contains(today);

    // Determine Flame Tier & Colors
    final (tierColor, secondaryTierColor, tierTitle) = _getStreakTier(days, isVi);

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF090D18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border(
              top: BorderSide(
                color: tierColor.withValues(alpha: 0.5),
                width: 1.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: tierColor.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, -10),
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 30,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle & Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AetronColors.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: tierColor.withValues(alpha: 0.4)),
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
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  color: AetronColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                tierTitle.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  color: tierColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Aetron3DOrbButton(
                          icon: Icons.close_rounded,
                          size: 36,
                          iconSize: 18,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    children: [
                      // 1. 3D CYBER FLAME HERO ARENA
                      _Streak3DFlameHero(
                        days: days,
                        progress: progress,
                        tierColor: tierColor,
                        secondaryColor: secondaryTierColor,
                        isTodayCompleted: isTodayCompleted,
                        isVi: isVi,
                      ),
                      const SizedBox(height: 20),

                      // 2. 4-CARD BENTO METRICS GRID
                      _StreakMetricsBentoGrid(
                        days: days,
                        longestDays: longestDays,
                        isTodayCompleted: isTodayCompleted,
                        totalWorkouts: workouts.length,
                        isVi: isVi,
                        tierColor: tierColor,
                      ),
                      const SizedBox(height: 18),

                      // 3. 7-DAY INTERACTIVE STREAK MATRIX STRIP
                      _Streak3DWeekStrip(
                        today: today,
                        activeDates: activeDates,
                        isVi: isVi,
                        tierColor: tierColor,
                      ),
                      const SizedBox(height: 18),

                      // 4. STREAK MILESTONE ROADMAP
                      _StreakMilestonesRoadmap(
                        currentStreak: days,
                        longestStreak: longestDays,
                        isVi: isVi,
                      ),
                      const SizedBox(height: 18),

                      // 5. STREAK SHIELD & PROTECTION INFO
                      _StreakShieldCard(isVi: isVi),
                      const SizedBox(height: 24),

                      // 6. ACTION CTA BUTTON
                      Aetron3DPrimaryButton(
                        label: isVi ? 'BẮT ĐẦU TẬP ĐỂ TĂNG CHUỖI 🔥' : 'START WORKOUT FOR STREAK 🔥',
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

  (Color, Color, String) _getStreakTier(int days, bool isVi) {
    if (days == 0) {
      return (
        AetronColors.cyan,
        const Color(0xFF64748B),
        isVi ? 'Tia lửa khởi đầu (Dormant)' : 'Dormant Spark',
      );
    }
    if (days < 3) {
      return (
        const Color(0xFFFF9F43),
        const Color(0xFF00E5FF),
        isVi ? 'Khởi động chuỗi (Spark)' : 'Spark Initiator',
      );
    }
    if (days < 7) {
      return (
        const Color(0xFF39F2B8),
        const Color(0xFF00E5FF),
        isVi ? 'Ngọn lửa rực cháy (Blaze)' : 'Blaze Runner',
      );
    }
    if (days < 14) {
      return (
        const Color(0xFFFFBA20),
        const Color(0xFFFF7A00),
        isVi ? 'Hỏa tiễn bền bỉ (Inferno)' : 'Inferno Streak',
      );
    }
    if (days < 30) {
      return (
        const Color(0xFFFF4F57),
        const Color(0xFFFFBA20),
        isVi ? 'Chiến binh Titan (Titan)' : 'Titan Flame',
      );
    }
    return (
      const Color(0xFFA55EEA),
      const Color(0xFF00E5FF),
      isVi ? 'Huyền thoại vũ trụ (Supernova)' : 'Supernova Legend',
    );
  }
}

// --- 3D CYBER FLAME HERO ---
class _Streak3DFlameHero extends StatelessWidget {
  const _Streak3DFlameHero({
    required this.days,
    required this.progress,
    required this.tierColor,
    required this.secondaryColor,
    required this.isTodayCompleted,
    required this.isVi,
  });

  final int days;
  final double progress;
  final Color tierColor;
  final Color secondaryColor;
  final bool isTodayCompleted;
  final bool isVi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: tierColor.withValues(alpha: 0.35),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Orbital Radial Core
          SizedBox(
            height: 190,
            width: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing Radial Corona
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        tierColor.withValues(alpha: 0.3),
                        secondaryColor.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),

                // Multi-orbit Custom Painter
                CustomPaint(
                  size: const Size.square(185),
                  painter: _Streak3DGlowingOrbPainter(
                    progress: progress,
                    primaryColor: tierColor,
                    secondaryColor: secondaryColor,
                  ),
                ),

                // Central Flame & Number
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: tierColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 26,
                        color: tierColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$days',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        fontSize: 54,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: tierColor.withValues(alpha: 0.6),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      isVi ? 'NGÀY LIÊN TIẾP' : 'DAYS STREAK',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: tierColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isTodayCompleted
                  ? const Color(0xFF39F2B8).withValues(alpha: 0.15)
                  : const Color(0xFFFFBA20).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isTodayCompleted
                    ? const Color(0xFF39F2B8).withValues(alpha: 0.4)
                    : const Color(0xFFFFBA20).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTodayCompleted ? Icons.check_circle_rounded : Icons.bolt_rounded,
                  size: 14,
                  color: isTodayCompleted ? const Color(0xFF39F2B8) : const Color(0xFFFFBA20),
                ),
                const SizedBox(width: 6),
                Text(
                  isTodayCompleted
                      ? (isVi ? 'HÔM NAY ĐÃ TẬP • CHUỖI AN TOÀN ✅' : 'TODAY SECURED • STREAK ACTIVE ✅')
                      : (isVi ? 'HÔM NAY CHƯA TẬP • CẦN 1 BUỔI ĐỂ GIỮ CHUỖI ⚡' : 'NOT COMPLETED TODAY • 1 WORKOUT NEEDED ⚡'),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: isTodayCompleted ? const Color(0xFF39F2B8) : const Color(0xFFFFBA20),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
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

// --- 3D GLOWING ORB PAINTER ---
class _Streak3DGlowingOrbPainter extends CustomPainter {
  const _Streak3DGlowingOrbPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;

    // 1. Outer Track (Background ring)
    final outerTrackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = primaryColor.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, outerTrackPaint);

    // 2. Decorative Orbit Dotted Halo
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = primaryColor.withValues(alpha: 0.25);
    const dashCount = 36;
    const dashRadius = 78.0;
    for (var i = 0; i < dashCount; i++) {
      final angle = (i * 2 * math.pi) / dashCount;
      final x1 = center.dx + (dashRadius - 3) * math.cos(angle);
      final y1 = center.dy + (dashRadius - 3) * math.sin(angle);
      final x2 = center.dx + dashRadius * math.cos(angle);
      final y2 = center.dy + dashRadius * math.sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), dashPaint);
    }

    // 3. Active Glowing Progress Arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [secondaryColor, primaryColor, primaryColor],
        stops: const [0.0, 0.7, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      (progress.clamp(0.04, 1.0)) * math.pi * 2,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _Streak3DGlowingOrbPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.primaryColor != primaryColor;
}

// --- 4-CARD BENTO METRICS GRID ---
class _StreakMetricsBentoGrid extends StatelessWidget {
  const _StreakMetricsBentoGrid({
    required this.days,
    required this.longestDays,
    required this.isTodayCompleted,
    required this.totalWorkouts,
    required this.isVi,
    required this.tierColor,
  });

  final int days;
  final int longestDays;
  final bool isTodayCompleted;
  final int totalWorkouts;
  final bool isVi;
  final Color tierColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: tierColor,
                title: isVi ? 'Chuỗi hiện tại' : 'Current Streak',
                value: '$days ${isVi ? 'Ngày' : 'Days'}',
                subtitle: isVi ? 'Đang cháy rực' : 'Active & burning',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFFFBA20),
                title: isVi ? 'Kỷ lục tốt nhất' : 'Best Record',
                value: '$longestDays ${isVi ? 'Ngày' : 'Days'}',
                subtitle: isVi ? 'Kỷ lục cá nhân' : 'Personal Best',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: isTodayCompleted ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                iconColor: isTodayCompleted ? const Color(0xFF39F2B8) : const Color(0xFFFFBA20),
                title: isVi ? 'Hôm nay' : 'Today Status',
                value: isTodayCompleted ? (isVi ? 'Đã tập' : 'Done') : (isVi ? 'Chưa tập' : 'Pending'),
                subtitle: isTodayCompleted ? (isVi ? 'Chuỗi an toàn' : 'Secured') : (isVi ? 'Cần 1 buổi' : 'Need 1 run'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.fitness_center_rounded,
                iconColor: const Color(0xFF14D1FF),
                title: isVi ? 'Tổng số buổi' : 'Total Sessions',
                value: '$totalWorkouts ${isVi ? 'Buổi' : 'Runs'}',
                subtitle: isVi ? 'Toàn thời gian' : 'All-time total',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Outfit',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Outfit',
              color: iconColor.withValues(alpha: 0.8),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 7-DAY INTERACTIVE STREAK MATRIX STRIP ---
class _Streak3DWeekStrip extends StatelessWidget {
  const _Streak3DWeekStrip({
    required this.today,
    required this.activeDates,
    required this.isVi,
    required this.tierColor,
  });

  final DateTime today;
  final Set<DateTime> activeDates;
  final bool isVi;
  final Color tierColor;

  @override
  Widget build(BuildContext context) {
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: AetronColors.cyan, size: 16),
              const SizedBox(width: 8),
              Text(
                isVi ? 'LƯỚI HOẠT ĐỘNG TUẦN NÀY' : 'THIS WEEK ACTIVITY GRID',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.cyanSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AetronColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$activeThisWeek/7 ${isVi ? 'ngày' : 'days'}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                if (index < 6) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Summary Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: activeThisWeek / 7.0,
              backgroundColor: const Color(0xFF131F33),
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakDayCapsule extends StatelessWidget {
  const _StreakDayCapsule({
    required this.label,
    required this.date,
    required this.today,
    required this.isActive,
    required this.tierColor,
  });

  final String label;
  final DateTime date;
  final DateTime today;
  final bool isActive;
  final Color tierColor;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;
    final isFuture = date.isAfter(today);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? tierColor.withValues(alpha: 0.18)
            : isToday
                ? AetronColors.panelHigh
                : const Color(0xFF080D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? AetronColors.cyan
              : isActive
                  ? tierColor.withValues(alpha: 0.6)
                  : AetronColors.borderSubtle.withValues(alpha: 0.4),
          width: isToday ? 1.8 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: tierColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isToday
                  ? AetronColors.cyan
                  : isActive
                      ? Colors.white
                      : AetronColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${date.day}',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isToday ? AetronColors.cyan : AetronColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? tierColor
                  : isToday
                      ? AetronColors.cyan.withValues(alpha: 0.2)
                      : Colors.transparent,
            ),
            child: isActive
                ? const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFF090D18),
                    size: 13,
                  )
                : isToday
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AetronColors.cyan,
                        ),
                      )
                    : Icon(
                        isFuture ? Icons.circle_outlined : Icons.remove_rounded,
                        color: AetronColors.textSecondary.withValues(alpha: 0.4),
                        size: 10,
                      ),
          ),
        ],
      ),
    );
  }
}

// --- STREAK MILESTONES ROADMAP ---
class _StreakMilestonesRoadmap extends StatelessWidget {
  const _StreakMilestonesRoadmap({
    required this.currentStreak,
    required this.longestStreak,
    required this.isVi,
  });

  final int currentStreak;
  final int longestStreak;
  final bool isVi;

  @override
  Widget build(BuildContext context) {
    final effectiveStreak = math.max(currentStreak, longestStreak);

    final milestones = [
      (
        target: 3,
        tier: 'BRONZE',
        tierColor: const Color(0xFFFF9F43),
        title: isVi ? 'Tia lửa khởi động' : '3-Day Spark',
        desc: isVi ? 'Duy trì 3 ngày tập liên tục' : 'Hold 3 consecutive days',
      ),
      (
        target: 7,
        tier: 'SILVER',
        tierColor: const Color(0xFFE0E6ED),
        title: isVi ? 'Ngọn lửa tuần hoàn' : 'Weekly Ignite',
        desc: isVi ? 'Duy trì trọn vẹn 7 ngày tuần' : 'Ignite a full 7-day streak',
      ),
      (
        target: 14,
        tier: 'GOLD',
        tierColor: const Color(0xFFFFBA20),
        title: isVi ? 'Ý chí thép 2 tuần' : 'Fortnight Blaze',
        desc: isVi ? 'Kiên định bền bỉ 14 ngày' : 'Unstoppable for 14 days',
      ),
      (
        target: 30,
        tier: 'TITAN',
        tierColor: const Color(0xFFFF4F57),
        title: isVi ? 'Chiến binh tháng Titan' : 'Monthly Titan',
        desc: isVi ? 'Chinh phục 30 ngày kiên trì' : '30-day champion streak',
      ),
      (
        target: 100,
        tier: 'QUANTUM',
        tierColor: const Color(0xFFA55EEA),
        title: isVi ? 'Huyền thoại 100 ngày' : 'Century Legend',
        desc: isVi ? 'Cột mốc thế kỷ vĩ đại' : 'Legendary 100 days milestone',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFFBA20), size: 18),
              const SizedBox(width: 8),
              Text(
                isVi ? 'LỘ TRÌNH CỘT MỐC CHUỖI TẬP' : 'STREAK MILESTONE ROADMAP',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Milestone List Cards
          for (final m in milestones) ...[
            _MilestoneRowItem(
              target: m.target,
              tier: m.tier,
              tierColor: m.tierColor,
              title: m.title,
              desc: m.desc,
              effectiveStreak: effectiveStreak,
              isVi: isVi,
            ),
            if (m != milestones.last)
              Divider(
                height: 18,
                thickness: 1,
                color: AetronColors.borderSubtle.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneRowItem extends StatelessWidget {
  const _MilestoneRowItem({
    required this.target,
    required this.tier,
    required this.tierColor,
    required this.title,
    required this.desc,
    required this.effectiveStreak,
    required this.isVi,
  });

  final int target;
  final String tier;
  final Color tierColor;
  final String title;
  final String desc;
  final int effectiveStreak;
  final bool isVi;

  @override
  Widget build(BuildContext context) {
    final isUnlocked = effectiveStreak >= target;
    final progress = (effectiveStreak / target).clamp(0.0, 1.0);

    return Row(
      children: [
        // Badge Orb
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked
                ? tierColor.withValues(alpha: 0.2)
                : const Color(0xFF131B2C),
            border: Border.all(
              color: isUnlocked
                  ? tierColor
                  : AetronColors.borderSubtle,
              width: 1.5,
            ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: tierColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: isUnlocked ? tierColor : AetronColors.textSecondary,
            size: 18,
          ),
        ),
        const SizedBox(width: 14),

        // Text & Progress
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isUnlocked ? Colors.white : AetronColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tier,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: tierColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: AetronColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFF131F33),
                        valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$effectiveStreak/$target ${isVi ? 'ngày' : 'd'}',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isUnlocked ? tierColor : AetronColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- STREAK SHIELD & PROTECTION INFO ---
class _StreakShieldCard extends StatelessWidget {
  const _StreakShieldCard({required this.isVi});

  final bool isVi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Color(0xFF00E5FF),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVi ? 'BẢO VỆ CHUỖI NGÀY THÔNG MINH' : 'SMART STREAK PROTECTION',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isVi
                      ? 'Hoàn thành ít nhất 1 buổi tập/ngày để giữ ngọn lửa luôn bùng cháy. Aetron sẽ nhắc bạn lúc 20:00 tối.'
                      : 'Complete at least 1 workout daily to keep your flame burning. Aetron sends alerts at 8:00 PM.',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
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

// --- HELPER METHODS (PRESERVED) ---
DateTime _startOfWeek(DateTime date) {
  final local = DateTimeHelper.localDateOnly(date);
  return local.subtract(Duration(days: local.weekday - 1));
}

int _weekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeekStart = firstThursday.subtract(
    Duration(days: firstThursday.weekday - 1),
  );
  return ((thursday.difference(firstWeekStart).inDays) / 7).floor() + 1;
}

String _formatMetric(double value, String unit) {
  switch (unit) {
    case 'km':
    case 'mi':
      return value.toStringAsFixed(1);
    case 'sessions':
    case 'kcal':
    default:
      return value.round().toString();
  }
}

double _monthlyTargetToWeeklyTarget(
  double monthlyTarget,
  DateTime startOfWeek,
) {
  final monthStart = DateTime(startOfWeek.year, startOfWeek.month, 1);
  final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
  final daysInMonth = nextMonth.difference(monthStart).inDays;
  return monthlyTarget / (daysInMonth / 7.0);
}

String _initialsFromEmail(String? email) {
  final source = (email ?? 'User').split('@').first.trim();
  if (source.isEmpty) return 'U';
  final parts = source
      .split(RegExp(r'[._\-\s]+'))
      .where((element) => element.isNotEmpty)
      .toList();
  if (parts.length == 1) {
    return parts.first
        .substring(0, math.min(2, parts.first.length))
        .toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _homeDisplayName(User? user) {
  final meta = user?.userMetadata;
  final displayName = (meta?['display_name'] ?? meta?['full_name'] ?? meta?['name']) as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  final username = meta?['username'] as String?;
  if (username != null && username.trim().isNotEmpty) return username.trim();
  return (user?.email ?? 'Athlete').split('@').first;
}


