import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_state_panel.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedPeriodProvider = StateProvider<TimePeriod>(
  (ref) => TimePeriod.week,
);

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final period = ref.watch(selectedPeriodProvider);
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;
    final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: workoutsAsync.when(
          data: (workouts) {
            if (workouts.isEmpty) {
              return _EmptyAnalyticsPanel(period: period);
            }
            final filtered = _filterWorkouts(workouts, period);
            final comparison = _calculateComparison(workouts, period);
            final records = _PersonalRecords.fromWorkouts(workouts);
            final chart = _distanceChartData(filtered, period, currentLang);
            final breakdown = _activityBreakdown(filtered);

            return RefreshIndicator(
              color: AetronColors.cyan,
              backgroundColor: AetronColors.panelHigh,
              onRefresh: () async {
                await ref.read(workoutListProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: ANALYTICS
                      Text(
                        AppTranslations.get('analytics_title', currentLang),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.textPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTranslations.get('your_performance', currentLang),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: AetronColors.cyanSoft,
                        ),
                      ),
                      if (isOffline) ...[
                        const SizedBox(height: 12),
                        const AetronOfflineBanner(),
                      ],
                      const SizedBox(height: 16),

                      // 3D Period Switcher (Week / Month / Year)
                      _PeriodSwitcher(
                        selectedPeriod: period,
                        onChanged: (value) {
                          ref.read(selectedPeriodProvider.notifier).state = value;
                        },
                      ),
                      const SizedBox(height: 16),

                      if (filtered.isEmpty) ...[
                        _EmptyAnalyticsPanel(period: period),
                      ] else ...[
                        // 1. Performance Summary Card
                        _Performance3DSummaryCard(
                          period: period,
                          comparison: comparison,
                          useMetricUnits: useMetricUnits,
                        ),
                        const SizedBox(height: 16),

                        // 2. 4 Key Metrics 3D Grid (Distance, Duration, Calories, Workouts)
                        _KeyMetrics3DGrid(
                          workouts: filtered,
                          useMetricUnits: useMetricUnits,
                        ),
                        const SizedBox(height: 20),

                        // 3. Distance Trend Section
                        _SectionHeader3D(
                          title: AppTranslations.get('distance_trend', currentLang),
                        ),
                        const SizedBox(height: 10),
                        _DistanceTrend3DCard(
                          chartData: chart,
                          period: period,
                          comparison: comparison,
                          useMetricUnits: useMetricUnits,
                        ),
                        const SizedBox(height: 20),

                        // 4. Goal Progress Section
                        _SectionHeader3D(
                          title: AppTranslations.get('goal_progress', currentLang),
                        ),
                        const SizedBox(height: 10),
                        _GoalProgress3DCard(
                          progress: ref.watch(goalProgressProvider),
                        ),
                        const SizedBox(height: 20),

                        // 5. Activity Mix Section
                        _SectionHeader3D(
                          title: AppTranslations.get('activity_mix', currentLang),
                        ),
                        const SizedBox(height: 10),
                        _ActivityMix3DCard(
                          breakdown: breakdown,
                          total: filtered.length,
                        ),
                        const SizedBox(height: 20),

                        // 6. Personal Bests Section
                        _SectionHeader3D(
                          title: AppTranslations.get('personal_bests', currentLang),
                        ),
                        const SizedBox(height: 10),
                        _PersonalBests3DCard(
                          records: records,
                          useMetricUnits: useMetricUnits,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: AetronLoadingPanel(
              label: 'LOADING ANALYTICS',
              message: 'Compiling your workout performance.',
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AetronStatePanel(
                title: 'Analytics unavailable',
                message: 'Your saved workout data could not be analyzed right now.',
                tone: AetronStateTone.error,
                onRetry: () => ref.read(workoutListProvider.notifier).refresh(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 3D Section Header ──────────────────────────────────────────────────────
class _SectionHeader3D extends StatelessWidget {
  final String title;

  const _SectionHeader3D({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: AetronColors.cyan,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AetronColors.cyanSoft,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Period Switcher ────────────────────────────────────────────────────────
class _PeriodSwitcher extends ConsumerWidget {
  const _PeriodSwitcher({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final values = TimePeriod.values;
    final selectedIdx = values.indexOf(selectedPeriod);

    return AetronSegmentedControl(
      selectedIndex: selectedIdx,
      tabs: values.map((p) => _periodLabel(p, currentLang)).toList(),
      onTabChanged: (index) => onChanged(values[index]),
    );
  }
}

// ─── 3D Performance Summary Card ────────────────────────────────────────────────
class _Performance3DSummaryCard extends ConsumerWidget {
  const _Performance3DSummaryCard({
    required this.period,
    required this.comparison,
    required this.useMetricUnits,
  });

  final TimePeriod period;
  final _PeriodComparison comparison;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final distanceVal = useMetricUnits
        ? comparison.currentDistanceKm
        : WorkoutFormatters.kmToMi(comparison.currentDistanceKm);
    final unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
    final periodTitle = switch (period) {
      TimePeriod.week => currentLang == AppLanguage.vi ? '7 NGÀY QUA' : 'LAST 7 DAYS',
      TimePeriod.month => currentLang == AppLanguage.vi ? '30 NGÀY QUA' : 'LAST 30 DAYS',
      TimePeriod.year => currentLang == AppLanguage.vi ? 'NĂM NÀY' : 'THIS YEAR',
    };

    final changePercent = comparison.percentageChange;
    final isPositive = changePercent != null && changePercent >= 0;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                periodTitle,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (changePercent != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPositive ? AetronColors.mint : AetronColors.error)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isPositive ? AetronColors.mint : AetronColors.error)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 14,
                        color: isPositive ? AetronColors.mint : AetronColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}${changePercent.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isPositive ? AetronColors.mint : AetronColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                distanceVal > 0 ? distanceVal.toStringAsFixed(1) : '—',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.textPrimary,
                  height: 1,
                  shadows: [
                    Shadow(color: AetronColors.cyan, blurRadius: 16),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                distanceVal > 0
                    ? unit.toUpperCase()
                    : (currentLang == AppLanguage.vi
                        ? 'CHƯA CÓ DỮ LIỆU QUÃNG ĐƯỜNG'
                        : 'NO DISTANCE DATA'),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: distanceVal > 0 ? AetronColors.cyan : AetronColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            currentLang == AppLanguage.vi
                ? 'Tổng quãng đường đã tập trong giai đoạn này'
                : 'Total distance tracked in this period',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: AetronColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4 Key Metrics 3D Grid ──────────────────────────────────────────────────
class _KeyMetrics3DGrid extends ConsumerWidget {
  const _KeyMetrics3DGrid({
    required this.workouts,
    required this.useMetricUnits,
  });

  final List<WorkoutSession> workouts;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    final totalDistKm = workouts.fold(
      0.0,
      (sum, item) => sum + _effectiveDistanceKm(item),
    );
    final totalDurationSec = workouts.fold(
      0,
      (sum, item) => sum + item.durationSec,
    );
    final totalCalories = workouts.fold(
      0,
      (sum, item) => sum + item.caloriesKcal.round(),
    );
    final totalWorkouts = workouts.length;

    final distVal = totalDistKm > 0
        ? (useMetricUnits
            ? totalDistKm.toStringAsFixed(1)
            : WorkoutFormatters.kmToMi(totalDistKm).toStringAsFixed(1))
        : '—';
    final distUnit = totalDistKm > 0
        ? WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits)
        : (currentLang == AppLanguage.vi ? 'Chưa có dữ liệu' : 'No data');

    final durVal = totalDurationSec > 0
        ? WorkoutFormatters.formatDurationFromSeconds(totalDurationSec)
        : '—';

    final calVal = totalCalories > 0 ? '$totalCalories' : '—';
    final workVal = '$totalWorkouts';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard3D(
                label: AppTranslations.get('distance', currentLang),
                value: distVal,
                unit: distUnit.toUpperCase(),
                icon: Icons.route_rounded,
                accentColor: AetronColors.cyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard3D(
                label: AppTranslations.get('duration', currentLang),
                value: durVal,
                unit: currentLang == AppLanguage.vi ? 'THỜI GIAN' : 'TIME',
                icon: Icons.timer_rounded,
                accentColor: AetronColors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10, height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard3D(
                label: AppTranslations.get('calories', currentLang),
                value: calVal,
                unit: currentLang == AppLanguage.vi ? 'CALO' : 'KCAL',
                icon: Icons.local_fire_department_rounded,
                accentColor: AetronColors.gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard3D(
                label: currentLang == AppLanguage.vi ? 'Buổi tập' : 'Workouts',
                value: workVal,
                unit: currentLang == AppLanguage.vi ? 'BUỔI' : 'SESSIONS',
                icon: Icons.fitness_center_rounded,
                accentColor: AetronColors.mint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard3D extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color accentColor;

  const _StatCard3D({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AetronColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AetronColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unit,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3D Distance Trend Card ─────────────────────────────────────────────────
class _DistanceTrend3DCard extends ConsumerWidget {
  const _DistanceTrend3DCard({
    required this.chartData,
    required this.period,
    required this.comparison,
    required this.useMetricUnits,
  });

  final Map<String, double> chartData;
  final TimePeriod period;
  final _PeriodComparison comparison;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final values = chartData.values
        .map((v) => useMetricUnits ? v : WorkoutFormatters.kmToMi(v))
        .toList();
    final labels = chartData.keys.toList();
    final hasData = values.any((v) => v > 0);

    if (!hasData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AetronColors.panelHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AetronColors.borderSubtle),
        ),
        child: SizedBox(
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.show_chart_rounded,
                color: AetronColors.muted,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                currentLang == AppLanguage.vi
                    ? 'Hoàn thành thêm buổi tập để xem biểu đồ xu hướng.'
                    : 'Complete more workouts to see your distance trend.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: AetronColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final maxY = (values.reduce((a, b) => a > b ? a : b) * 1.25).clamp(1.0, 9999.0);
    final maxIdx = values.indexOf(values.reduce((a, b) => a >= b ? a : b));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AetronColors.cyan.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
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
                AppTranslations.get('distance_trend', currentLang),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${values.fold(0.0, (s, v) => s + v).toStringAsFixed(1)} ${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits)}',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AetronColors.space,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(1)} ${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits)}',
                        const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: AetronColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AetronColors.borderSubtle,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        final isPeak = idx == maxIdx;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[idx],
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              color: isPeak ? AetronColors.cyan : AetronColors.textSecondary,
                              fontWeight: isPeak ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          width: 22,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: i == maxIdx
                              ? const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [AetronColors.cyanSoft, AetronColors.cyan],
                                )
                              : LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AetronColors.muted.withValues(alpha: 0.2),
                                    AetronColors.muted.withValues(alpha: 0.5),
                                  ],
                                ),
                        ),
                      ],
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

// ─── 3D Goal Progress Card ──────────────────────────────────────────────────
class _GoalProgress3DCard extends ConsumerWidget {
  const _GoalProgress3DCard({required this.progress});

  final GoalProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    if (progress == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AetronColors.panelHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AetronColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.get('goal_progress', currentLang),
              style: TextStyle(
                fontFamily: 'Outfit',
                color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              currentLang == AppLanguage.vi ? 'Đặt mục tiêu tập luyện đầu tiên' : 'Set your fitness goal',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AetronColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentLang == AppLanguage.vi
                  ? 'Tạo mục tiêu để theo dõi tiến độ tuần/tháng của bạn.'
                  : 'Create a goal to start tracking your progress.',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: AetronColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Aetron3DPrimaryButton(
              label: currentLang == AppLanguage.vi ? 'ĐẶT MỤC TIÊU →' : 'SET A GOAL →',
              icon: Icons.flag_rounded,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalScreen()),
                );
              },
            ),
          ],
        ),
      );
    }

    final goal = progress!;
    final remaining = (goal.target - goal.current).clamp(0, 99999);
    final remainingLabel = remaining == 0
        ? (currentLang == AppLanguage.vi ? 'Đã hoàn thành mục tiêu!' : 'Goal achieved! Great job!')
        : '${goal.unit == 'km' || goal.unit == 'mi' ? remaining.toStringAsFixed(1) : remaining.toInt()} ${goal.unit} ${currentLang == AppLanguage.vi ? 'còn lại' : 'remaining'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: goal.isAchieved ? AetronColors.mint : AetronColors.cyan.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (goal.isAchieved ? AetronColors.mint : AetronColors.cyan).withValues(alpha: 0.15),
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
                AppTranslations.get('goal_progress', currentLang),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.cyanSoft.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${goal.percent}%',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: goal.isAchieved ? AetronColors.mint : AetronColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${goal.currentLabel} / ${goal.targetLabel} ${goal.unit}',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AetronColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            remainingLabel,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: goal.isAchieved ? AetronColors.mint : AetronColors.textSecondary,
              fontWeight: goal.isAchieved ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          AppProgressBar(
            progress: (goal.percent / 100.0).clamp(0.0, 1.0),
            color: goal.isAchieved ? AetronColors.mint : AetronColors.cyan,
            showPercentage: false,
          ),
        ],
      ),
    );
  }
}

// ─── 3D Activity Mix Card ────────────────────────────────────────────────────
class _ActivityMix3DCard extends ConsumerWidget {
  const _ActivityMix3DCard({
    required this.breakdown,
    required this.total,
  });

  final Map<String, int> breakdown;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: breakdown.entries.map((entry) {
              final type = entry.key;
              final count = entry.value;
              final pct = ((count / total) * 100).round();
              final label = WorkoutFormatters.formatActivityType(type, ref.watch(appLanguageProvider));
              final color = _activityColor(type);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(_activityIcon(type), color: color, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AetronColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$count ($pct%)',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AppProgressBar(
                      progress: (count / total).clamp(0.0, 1.0),
                      color: color,
                      showPercentage: false,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _activityColor(String type) {
    return switch (type.toLowerCase()) {
      'running' => AetronColors.cyan,
      'cycling' => AetronColors.mint,
      'walking' => AetronColors.blue,
      _ => AetronColors.gold,
    };
  }

  IconData _activityIcon(String type) {
    return switch (type.toLowerCase()) {
      'running' => Icons.directions_run_rounded,
      'cycling' => Icons.directions_bike_rounded,
      'walking' => Icons.directions_walk_rounded,
      _ => Icons.fitness_center_rounded,
    };
  }
}

// ─── 3D Personal Bests Card ─────────────────────────────────────────────────
class _PersonalBests3DCard extends ConsumerWidget {
  const _PersonalBests3DCard({
    required this.records,
    required this.useMetricUnits,
  });

  final _PersonalRecords records;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    final longestDistStr = records.longestDistanceKm > 0
        ? WorkoutFormatters.formatDistance(records.longestDistanceKm, useMetric: useMetricUnits, decimals: 1)
        : '—';
    final longestDurStr = records.longestDurationSec > 0
        ? WorkoutFormatters.formatDurationFromSeconds(records.longestDurationSec)
        : '—';
    final maxCalStr = records.maxCalories > 0 ? '${records.maxCalories} kcal' : '—';
    final topPaceStr = records.bestPaceKmh > 0
        ? WorkoutFormatters.formatPaceFromSpeedKmh(records.bestPaceKmh, useMetric: useMetricUnits)
        : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AetronColors.gold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AetronColors.gold.withValues(alpha: 0.12),
            blurRadius: 14,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _RecordItem3D(
                  title: currentLang == AppLanguage.vi ? 'Đường chạy dài nhất' : 'Longest Distance',
                  value: longestDistStr,
                  icon: Icons.emoji_events_rounded,
                  color: AetronColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecordItem3D(
                  title: currentLang == AppLanguage.vi ? 'Thời gian lâu nhất' : 'Longest Duration',
                  value: longestDurStr,
                  icon: Icons.timer_rounded,
                  color: AetronColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RecordItem3D(
                  title: currentLang == AppLanguage.vi ? 'Calo đốt nhiều nhất' : 'Max Calories',
                  value: maxCalStr,
                  icon: Icons.local_fire_department_rounded,
                  color: AetronColors.mint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecordItem3D(
                  title: currentLang == AppLanguage.vi ? 'Pace tốt nhất' : 'Best Pace',
                  value: topPaceStr,
                  icon: Icons.speed_rounded,
                  color: AetronColors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordItem3D extends StatelessWidget {
  const _RecordItem3D({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AetronColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Analytics Panel ──────────────────────────────────────────────────
class _EmptyAnalyticsPanel extends ConsumerWidget {
  const _EmptyAnalyticsPanel({required this.period});

  final TimePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final label = _periodLabel(period, currentLang);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.analytics_outlined,
            size: 44,
            color: AetronColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            currentLang == AppLanguage.vi
                ? 'Không có dữ liệu cho ($label)'
                : 'No workouts in this period ($label)',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AetronColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentLang == AppLanguage.vi
                ? 'Hãy hoàn thành thêm bài tập để xem thống kê.'
                : 'Complete workouts during this time frame to unlock performance charts.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: AetronColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Aetron3DPrimaryButton(
            label: AppTranslations.get('start_workout', currentLang).toUpperCase(),
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ActivityScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Helper Functions & Models ──────────────────────────────────────────────
String _periodLabel(TimePeriod p, AppLanguage lang) {
  switch (p) {
    case TimePeriod.week:
      return AppTranslations.get('week', lang);
    case TimePeriod.month:
      return AppTranslations.get('month', lang);
    case TimePeriod.year:
      return AppTranslations.get('year', lang);
  }
}

double _effectiveDistanceKm(WorkoutSession w) {
  return w.gpsAnalysis.validDistanceKm > 0
      ? w.gpsAnalysis.validDistanceKm
      : w.distanceKm;
}

List<WorkoutSession> _filterWorkouts(
  List<WorkoutSession> workouts,
  TimePeriod period,
) {
  if (workouts.isEmpty) return [];
  final now = DateTime.now();

  List<WorkoutSession> getForRef(DateTime refDate) {
    final refDay = DateTimeHelper.localDateOnly(refDate);
    switch (period) {
      case TimePeriod.week:
        final start = refDay.subtract(const Duration(days: 6));
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && !d.isAfter(refDay);
        }).toList();

      case TimePeriod.month:
        final start = refDay.subtract(const Duration(days: 29));
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && !d.isAfter(refDay);
        }).toList();

      case TimePeriod.year:
        final start = DateTime(refDay.year, 1, 1);
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && d.year == refDay.year;
        }).toList();
    }
  }

  final currentFiltered = getForRef(now);
  if (currentFiltered.isNotEmpty) return currentFiltered;

  final latestDate = workouts.first.startedAt;
  return getForRef(latestDate);
}

class _PeriodComparison {
  final double currentDistanceKm;
  final double? percentageChange;

  const _PeriodComparison({
    required this.currentDistanceKm,
    this.percentageChange,
  });
}

_PeriodComparison _calculateComparison(
  List<WorkoutSession> workouts,
  TimePeriod period,
) {
  final current = _filterWorkouts(workouts, period);
  final currentDist = current.fold(
    0.0,
    (sum, item) => sum + _effectiveDistanceKm(item),
  );

  if (workouts.isEmpty) {
    return const _PeriodComparison(currentDistanceKm: 0.0);
  }

  final now = DateTime.now();
  final refDay = DateTimeHelper.localDateOnly(now);

  List<WorkoutSession> previous = [];
  switch (period) {
    case TimePeriod.week:
      final prevEnd = refDay.subtract(const Duration(days: 7));
      final prevStart = prevEnd.subtract(const Duration(days: 6));
      previous = workouts.where((w) {
        final d = DateTimeHelper.localDateOnly(w.startedAt);
        return !d.isBefore(prevStart) && !d.isAfter(prevEnd);
      }).toList();
      break;

    case TimePeriod.month:
      final prevEnd = refDay.subtract(const Duration(days: 30));
      final prevStart = prevEnd.subtract(const Duration(days: 29));
      previous = workouts.where((w) {
        final d = DateTimeHelper.localDateOnly(w.startedAt);
        return !d.isBefore(prevStart) && !d.isAfter(prevEnd);
      }).toList();
      break;

    case TimePeriod.year:
      final prevYear = refDay.year - 1;
      previous = workouts.where((w) {
        return DateTimeHelper.localDateOnly(w.startedAt).year == prevYear;
      }).toList();
      break;
  }

  final prevDist = previous.fold(
    0.0,
    (sum, item) => sum + _effectiveDistanceKm(item),
  );

  if (prevDist == 0.0) {
    return _PeriodComparison(
      currentDistanceKm: currentDist,
      percentageChange: currentDist > 0 ? 100.0 : null,
    );
  }

  final pct = ((currentDist - prevDist) / prevDist) * 100.0;
  return _PeriodComparison(
    currentDistanceKm: currentDist,
    percentageChange: pct,
  );
}

class _PersonalRecords {
  final double longestDistanceKm;
  final int longestDurationSec;
  final int maxCalories;
  final double bestPaceKmh;

  const _PersonalRecords({
    required this.longestDistanceKm,
    required this.longestDurationSec,
    required this.maxCalories,
    required this.bestPaceKmh,
  });

  factory _PersonalRecords.fromWorkouts(List<WorkoutSession> workouts) {
    if (workouts.isEmpty) {
      return const _PersonalRecords(
        longestDistanceKm: 0,
        longestDurationSec: 0,
        maxCalories: 0,
        bestPaceKmh: 0,
      );
    }

    double maxDist = 0;
    int maxDur = 0;
    int maxCal = 0;
    double maxSpeed = 0;

    for (final w in workouts) {
      final d = _effectiveDistanceKm(w);
      if (d > maxDist) maxDist = d;
      if (w.durationSec > maxDur) maxDur = w.durationSec;
      final cal = w.caloriesKcal.round();
      if (cal > maxCal) maxCal = cal;
      if (w.avgSpeedKmh > maxSpeed) maxSpeed = w.avgSpeedKmh;
    }

    return _PersonalRecords(
      longestDistanceKm: maxDist,
      longestDurationSec: maxDur,
      maxCalories: maxCal,
      bestPaceKmh: maxSpeed,
    );
  }
}

Map<String, double> _distanceChartData(
  List<WorkoutSession> workouts,
  TimePeriod period,
  AppLanguage lang,
) {
  final map = <String, double>{};

  if (period == TimePeriod.week) {
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = switch (date.weekday) {
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        _ => 'Sun',
      };
      map[key] = 0.0;

      for (final w in workouts) {
        final wd = w.startedAt.toLocal();
        if (wd.year == date.year && wd.month == date.month && wd.day == date.day) {
          map[key] = (map[key] ?? 0.0) + _effectiveDistanceKm(w);
        }
      }
    }
  } else if (period == TimePeriod.month) {
    for (var wIdx = 1; wIdx <= 4; wIdx++) {
      map['W$wIdx'] = 0.0;
    }
    final now = DateTime.now();
    for (final w in workouts) {
      final wd = w.startedAt.toLocal();
      final diffDays = now.difference(wd).inDays;
      if (diffDays >= 0 && diffDays < 28) {
        final wNum = 4 - (diffDays ~/ 7);
        final key = 'W${wNum.clamp(1, 4)}';
        map[key] = (map[key] ?? 0.0) + _effectiveDistanceKm(w);
      }
    }
  } else {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (final m in months) {
      map[m] = 0.0;
    }
    for (final w in workouts) {
      final wd = w.startedAt.toLocal();
      final mKey = months[wd.month - 1];
      map[mKey] = (map[mKey] ?? 0.0) + _effectiveDistanceKm(w);
    }
  }

  return map;
}

Map<String, int> _activityBreakdown(List<WorkoutSession> workouts) {
  final map = <String, int>{};
  for (final w in workouts) {
    final type = w.activityType.toLowerCase();
    map[type] = (map[type] ?? 0) + 1;
  }
  return map;
}
