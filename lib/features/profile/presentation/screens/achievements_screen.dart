import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/features/profile/domain/services/achievement_evaluator.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/achievement_badge_item.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/achievement_detail_sheet.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  BadgeCategory _selectedCategory = BadgeCategory.all;

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final streak = ref.watch(streakProvider);

    final workouts = workoutsAsync.valueOrNull ?? <WorkoutSession>[];
    final totalDistanceKm = workouts.fold<double>(
      0.0,
      (sum, w) => sum + (w.gpsAnalysis.validDistanceKm > 0 ? w.gpsAnalysis.validDistanceKm : w.distanceKm),
    );

    final allBadges = AchievementEvaluator.evaluateAchievements(
      workouts: workouts,
      currentStreak: streak.currentStreak,
      longestStreak: streak.longestStreak,
      totalDistanceKm: totalDistanceKm,
    );

    final unlockedCount = allBadges.where((b) => b.isUnlocked).length;
    final totalCount = allBadges.length;
    final overallProgress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    // Filter badges based on selected category
    final filteredBadges = _selectedCategory == BadgeCategory.all
        ? allBadges
        : allBadges.where((b) => b.category == _selectedCategory).toList();

    // Next nearest milestone
    final nextMilestone = allBadges
        .where((b) => !b.isUnlocked)
        .fold<AchievementBadge?>(null, (nearest, b) {
      if (nearest == null || b.progress > nearest.progress) {
        return b;
      }
      return nearest;
    });

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, currentLang, unlockedCount, totalCount),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // 1. Overall Progress & Telemetry Banner
                  _buildOverallProgressCard(
                    currentLang,
                    unlockedCount,
                    totalCount,
                    overallProgress,
                    workouts.length,
                    streak.longestStreak,
                    totalDistanceKm,
                  ),
                  const SizedBox(height: 16),

                  // 2. Next Milestone Spotlight (if available)
                  if (nextMilestone != null) ...[
                    _buildNextMilestoneSpotlight(context, nextMilestone, currentLang),
                    const SizedBox(height: 16),
                  ],

                  // 3. Category Filter Tabs
                  _buildCategoryFilters(currentLang),
                  const SizedBox(height: 16),

                  // 4. Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategory == BadgeCategory.all
                            ? (currentLang == AppLanguage.vi ? 'TẤT CẢ HUY HIỆU' : 'ALL BADGES')
                            : _selectedCategory.label(currentLang).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.cyanSoft,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '${filteredBadges.where((b) => b.isUnlocked).length} / ${filteredBadges.length}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AetronColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. Badges Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredBadges.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.08,
                    ),
                    itemBuilder: (context, index) {
                      final badge = filteredBadges[index];
                      return AchievementBadgeItem(
                        badge: badge,
                        currentLang: currentLang,
                        onTap: () => AchievementDetailSheet.show(
                          context,
                          badge: badge,
                          currentLang: currentLang,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AppLanguage currentLang,
    int unlockedCount,
    int totalCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Back Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AetronColors.panelHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AetronColors.borderSubtle),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AetronColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentLang == AppLanguage.vi ? 'DANH HIỆU & THÀNH TỰU' : 'AETRON ACHIEVEMENTS',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  currentLang == AppLanguage.vi ? 'Kho Huy Hiệu' : 'Badge Vault',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Unlocked Counter Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AetronColors.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, size: 14, color: AetronColors.cyan),
                const SizedBox(width: 4),
                Text(
                  '$unlockedCount / $totalCount',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.cyan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgressCard(
    AppLanguage currentLang,
    int unlockedCount,
    int totalCount,
    double overallProgress,
    int totalWorkouts,
    int longestStreak,
    double totalDistanceKm,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentLang == AppLanguage.vi ? 'TIẾN TRÌNH DANH HIỆU' : 'ACHIEVEMENT PROGRESS',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.cyan,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${(overallProgress * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
              backgroundColor: AetronColors.space,
              valueColor: const AlwaysStoppedAnimation<Color>(AetronColors.cyan),
            ),
          ),
          const SizedBox(height: 16),

          // 3 Telemetry Metrics Mini Cards
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.fitness_center_rounded,
                  label: currentLang == AppLanguage.vi ? 'Buổi tập' : 'Sessions',
                  value: '$totalWorkouts',
                  color: AetronColors.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.local_fire_department_rounded,
                  label: currentLang == AppLanguage.vi ? 'Chuỗi max' : 'Best Streak',
                  value: '$longestStreak ${currentLang == AppLanguage.vi ? 'ngày' : 'd'}',
                  color: AetronColors.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.route_rounded,
                  label: currentLang == AppLanguage.vi ? 'Quãng đường' : 'Distance',
                  value: '${totalDistanceKm.toStringAsFixed(1)} km',
                  color: AetronColors.mint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AetronColors.space.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AetronColors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 9,
              color: AetronColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextMilestoneSpotlight(
    BuildContext context,
    AchievementBadge badge,
    AppLanguage currentLang,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => AchievementDetailSheet.show(
          context,
          badge: badge,
          currentLang: currentLang,
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AetronColors.panelHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: badge.tier.primaryColor.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: badge.tier.glowColor,
                blurRadius: 16,
                spreadRadius: -3,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Emblem
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge.tier.primaryColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: badge.tier.primaryColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(badge.icon, size: 22, color: badge.tier.primaryColor),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLang == AppLanguage.vi ? 'CỘT MỐC TIẾP THEO' : 'NEXT MILESTONE',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: badge.tier.primaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge.title(currentLang),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AetronColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${badge.formattedProgress(currentLang)} • ${badge.remainingText(currentLang)}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: AetronColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Progress %
              Text(
                '${badge.progressPercent}%',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: badge.tier.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(AppLanguage currentLang) {
    const categories = BadgeCategory.values;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == _selectedCategory;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AetronColors.cyan.withValues(alpha: 0.20)
                      : AetronColors.panelHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AetronColors.cyan
                        : AetronColors.borderSubtle,
                    width: isSelected ? 1.2 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AetronColors.cyan.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 14,
                      color: isSelected ? AetronColors.cyan : AetronColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label(currentLang),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AetronColors.cyan : AetronColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
