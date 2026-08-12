import 'dart:io';
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
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
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
        top: false,
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
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: AetronSpacing.xxl),
                          child: LoadingState(label: 'LOADING TELEMETRY'),
                        ),
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
class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final avatar = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? avatarImage = avatar.localPath != null
        ? FileImage(File(avatar.localPath!))
        : avatar.remoteUrl != null && avatar.remoteUrl!.isNotEmpty
            ? NetworkImage(avatar.remoteUrl!)
            : null;
    final streak = ref.watch(streakProvider);
    final initials = _initialsFromEmail(user?.email);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AetronSpacing.page,
        AetronSpacing.lg + 8,
        AetronSpacing.page,
        AetronSpacing.xs,
      ),
      child: Row(
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

          // User Greeting & Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTranslations.get('welcome_back', currentLang).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _homeDisplayName(user),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    );
  }
}

// --- POPULATED HOME VIEW ---
class _HomePopulatedView extends StatelessWidget {
  const _HomePopulatedView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Workout Banner ("READY TO MOVE?")
        _StartWorkout3DHeroCard(),
        SizedBox(height: AetronSpacing.lg),

        // 2. Spotlight 3D Workout Carousel (Image 1 Spotlight Section)
        _SpotlightWorkoutSection(),
        SizedBox(height: AetronSpacing.lg),

        // 3. Weekly Goal Progress & Radial Activity Ring
        _WeeklyGoalSection(),
        SizedBox(height: AetronSpacing.lg),

        // 4. Recent Workout Log
        _RecentWorkoutSection(),
      ],
    );
  }
}

// --- SPOTLIGHT WORKOUT SECTION (RUNNING SERIES FOR RUNNERS) ---
class _SpotlightWorkoutSection extends ConsumerStatefulWidget {
  const _SpotlightWorkoutSection();

  @override
  ConsumerState<_SpotlightWorkoutSection> createState() => _SpotlightWorkoutSectionState();
}

class _SpotlightWorkoutSectionState extends ConsumerState<_SpotlightWorkoutSection> {
  final Set<String> _favorites = {};

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);

    final spotlightItems = [
      {
        'id': '1',
        'title': AppTranslations.get('couch_to_5k', currentLang),
        'category': currentLang == AppLanguage.vi ? 'NGƯỜI MỚI • 4 TUẦN' : 'BEGINNER • 4 WEEKS',
        'stat': '5.0 km • Run/Walk Interval',
        'icon': Icons.directions_run_rounded,
        'type': 'running',
      },
      {
        'id': '2',
        'title': AppTranslations.get('easy_base_run', currentLang),
        'category': currentLang == AppLanguage.vi ? 'PHỤC HỒI • DỊU NHẸ' : 'RECOVERY • EASY BASE',
        'stat': '3.0 km • Zone 2 HR',
        'icon': Icons.favorite_rounded,
        'type': 'running',
      },
      {
        'id': '3',
        'title': AppTranslations.get('pace_builder_10k', currentLang),
        'category': currentLang == AppLanguage.vi ? 'TRUNG CẤP • 6 TUẦN' : 'INTERMEDIATE • 6 WEEKS',
        'stat': '10.0 km • Tempo Pace',
        'icon': Icons.speed_rounded,
        'type': 'running',
      },
      {
        'id': '4',
        'title': AppTranslations.get('speed_intervals', currentLang),
        'category': currentLang == AppLanguage.vi ? 'TỐC ĐỘ • NÂNG CAO' : 'ADVANCED • SPEED',
        'stat': '400m Reps • Fartlek',
        'icon': Icons.bolt_rounded,
        'type': 'running',
      },
    ];

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
          height: 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: spotlightItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = spotlightItems[index];
              final isFav = _favorites.contains(item['id']);

              return Container(
                width: 210,
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
                    // Top 3D Visual Box
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AetronColors.cyan.withValues(alpha: 0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Icon(
                            item['icon'] as IconData,
                            size: 48,
                            color: AetronColors.cyan,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category Tag
                    Text(
                      item['category'] as String,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Title
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AetronColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Stat & Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['stat'] as String,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: AetronColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            // Favorite Heart Orb
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isFav) {
                                    _favorites.remove(item['id']);
                                  } else {
                                    _favorites.add(item['id'] as String);
                                  }
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AetronColors.space,
                                  border: Border.all(
                                    color: isFav
                                        ? AetronColors.danger
                                        : AetronColors.borderSubtle,
                                  ),
                                ),
                                child: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: isFav
                                      ? AetronColors.danger
                                      : AetronColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Quick Add / Start Button
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RecordScreen(
                                      activityType: item['type'] as String,
                                      requireGps: true,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AetronColors.cyan,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AetronColors.cyan.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: AetronColors.space,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}



// --- 3. WEEKLY GOAL SECTION WITH GLOWING ACTIVITY RING ---
class _WeeklyGoalSection extends ConsumerWidget {
  const _WeeklyGoalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final hero = ref.watch(_weeklyHeroProvider);
    final progress = (hero.target > 0 ? (hero.current / hero.target) : 0.0).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

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
          borderColor: AetronColors.cyan.withValues(alpha: 0.35),
          hasGlow: true,
          glowColor: AetronColors.cyan,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoalScreen()),
          ),
          child: Row(
            children: [
              // Custom Radial Activity Progress Ring
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(84, 84),
                      painter: _ActivityRingPainter(
                        progress: progress,
                        trackColor: AetronColors.space,
                        ringColor: AetronColors.cyan,
                        glowColor: AetronColors.mint,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: AetronTypography.headingMedium.copyWith(
                            color: AetronColors.cyanSoft,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          currentLang == AppLanguage.vi ? 'MỤC TIÊU' : 'GOAL',
                          style: AetronTypography.label.copyWith(
                            color: AetronColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                            color: AetronColors.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AetronRadius.pill),
                            border: Border.all(
                              color: AetronColors.cyan.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            currentLang == AppLanguage.vi
                                ? 'TUẦN ${hero.weekNumber}'
                                : 'WEEK ${hero.weekNumber}',
                            style: AetronTypography.caption.copyWith(
                              color: AetronColors.cyan,
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
                          : (currentLang == AppLanguage.vi
                              ? 'Cố lên! Bạn sắp hoàn thành mục tiêu.'
                              : 'Keep pushing! Almost at target.'),
                      style: AetronTypography.bodySmall.copyWith(
                        color: percent >= 100 ? AetronColors.mint : AetronColors.textSecondary,
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
    final radius = (size.width - 12) / 2;
    const strokeWidth = 8.0;

    // Track Paint
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Glowing Arc Paint
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..strokeCap = StrokeCap.round;

    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: [ringColor, glowColor, ringColor],
        stops: const [0.0, 0.7, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      glowPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ActivityRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.ringColor != ringColor;
  }
}


// --- 3D START WORKOUT HERO CARD ---
class _StartWorkout3DHeroCard extends ConsumerWidget {
  const _StartWorkout3DHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return AppCard(
      padding: const EdgeInsets.all(AetronSpacing.lg),
      backgroundColor: AetronColors.panelHigh,
      borderColor: AetronColors.cyan.withValues(alpha: 0.4),
      hasGlow: true,
      glowColor: AetronColors.cyan,
      child: Row(
        children: [
          // Left: Title, Subtitle, and START WORKOUT Button
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTranslations.get('ready_to_move', currentLang),
                  style: AetronTypography.headingLarge.copyWith(
                    color: AetronColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTranslations.get('ready_to_move_sub', currentLang),
                  style: AetronTypography.bodySmall.copyWith(
                    color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AetronSpacing.md),
                    AppButton(
                      label: AppTranslations.get('start_workout', currentLang),
                      icon: Icons.arrow_forward_rounded,
                      height: 44,
                      fontSize: 12,
                      fullWidth: true,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecordScreen(
                            activityType: 'running',
                            requireGps: true,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),

          const SizedBox(width: AetronSpacing.sm),

          // Right: 3D Runner Character Avatar Visual with Glowing Backdrop
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Radial Glowing Cyan Background Circle
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AetronColors.cyan.withValues(alpha: 0.35),
                          AetronColors.cyan.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),
                  // 3D Character Avatar Image (Cute 3D Shiba Inu Mascot)
                  Image.asset(
                    'assets/shiba_3d.png',
                    fit: BoxFit.contain,
                    height: 135,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.directions_run_rounded,
                        size: 64,
                        color: AetronColors.cyan,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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
class _StreakDetailsSheet extends ConsumerWidget {
  const _StreakDetailsSheet({required this.streak});

  final StreakData streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final workouts = ref.watch(workoutListProvider).valueOrNull ?? const <WorkoutSession>[];
    final days = streak.currentStreak;
    final targetDays = _nextStreakTarget(days);
    final progress = (days / targetDays).clamp(0.0, 1.0);
    final daysLeft = math.max(0, targetDays - days);

    final statusLabel = days == 0
        ? AppTranslations.get('start_your_streak', currentLang)
        : days >= 7
            ? AppTranslations.get('milestone_unlocked', currentLang)
            : AppTranslations.get('streak_active', currentLang);

    final today = DateTimeHelper.localDateOnly(DateTime.now());
    final activeDates = workouts
        .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
        .toSet();

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: AetronColors.panelHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border(
              top: BorderSide(
                color: AetronColors.cyan.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppTranslations.get('aetron_streak', currentLang),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AetronColors.cyan,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
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
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    children: [
                      // 3D Hero Flame & Radial Arc Box
                      SizedBox(
                        height: 210,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 3D Radial Outer Glow Circle
                            Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AetronColors.cyan.withValues(alpha: 0.25),
                                    AetronColors.cyan.withValues(alpha: 0.05),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.65, 1.0],
                                ),
                              ),
                            ),

                            // Custom Radial Painter
                            CustomPaint(
                              size: const Size.square(185),
                              painter: _Streak3DRingsPainter(progress: progress),
                            ),

                            // Central Content
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 32,
                                  color: days > 0 ? AetronColors.cyan : AetronColors.muted,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$days',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    color: AetronColors.textPrimary,
                                    fontSize: 58,
                                    height: 1.0,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppTranslations.get('days_streak', currentLang),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    color: AetronColors.cyanSoft,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AetronColors.cyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      color: AetronColors.cyan,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3D Target Progress Card
                      _Streak3DTargetCard(
                        progress: progress,
                        daysLeft: daysLeft,
                        targetDays: targetDays,
                      ),
                      const SizedBox(height: 16),

                      // 3D Weekly Activity Matrix
                      _Streak3DWeekStrip(today: today, activeDates: activeDates),
                      const SizedBox(height: 24),

                      // 3D CTA Button
                      Aetron3DPrimaryButton(
                        label: AppTranslations.get('continue_workout', currentLang),
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

class _Streak3DRingsPainter extends CustomPainter {
  const _Streak3DRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;

    final outerTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AetronColors.cyan.withValues(alpha: 0.2);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AetronColors.cyan;

    canvas.drawCircle(center, radius, outerTrack);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * math.pi * 2,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _Streak3DRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Streak3DTargetCard extends ConsumerWidget {
  const _Streak3DTargetCard({
    required this.progress,
    required this.daysLeft,
    required this.targetDays,
  });

  final double progress;
  final int daysLeft;
  final int targetDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                currentLang == AppLanguage.vi ? 'TIẾN ĐỘ CHUỖI TẬP' : 'STREAK PROGRESSION',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '$daysLeft ${AppTranslations.get('days_left', currentLang)}',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(progress: progress, color: AetronColors.cyan),
        ],
      ),
    );
  }
}

class _Streak3DWeekStrip extends ConsumerWidget {
  const _Streak3DWeekStrip({required this.today, required this.activeDates});

  final DateTime today;
  final Set<DateTime> activeDates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.get('this_week', currentLang),
            style: const TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.cyanSoft,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: _Streak3DDayMarker(
                    label: labels[index],
                    date: startOfWeek.add(Duration(days: index)),
                    today: today,
                    isActive: activeDates.contains(
                      startOfWeek.add(Duration(days: index)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Streak3DDayMarker extends StatelessWidget {
  const _Streak3DDayMarker({
    required this.label,
    required this.date,
    required this.today,
    required this.isActive,
  });

  final String label;
  final DateTime date;
  final DateTime today;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isToday ? AetronColors.cyan : AetronColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AetronColors.cyan : AetronColors.space,
            border: Border.all(
              color: isToday
                  ? AetronColors.cyan
                  : isActive
                      ? AetronColors.cyan
                      : AetronColors.borderSubtle,
              width: isToday ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AetronColors.cyan.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: isActive
              ? const Icon(
                  Icons.check_rounded,
                  color: AetronColors.space,
                  size: 18,
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
                  : null,
        ),
      ],
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
  final displayName = user?.userMetadata?['display_name'] as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  final username = user?.userMetadata?['username'] as String?;
  if (username != null && username.trim().isNotEmpty) return username.trim();
  return (user?.email ?? 'Athlete').split('@').first;
}


