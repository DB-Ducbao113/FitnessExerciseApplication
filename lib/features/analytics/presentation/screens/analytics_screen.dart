import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_state_panel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedPeriodProvider = StateProvider<TimePeriod>(
  (ref) => TimePeriod.week,
);

const _kCard = Color(0xFF242C3A);
const _kCardSoft = Color(0xFF1A212D);
const _kTrack = Color(0xFF343B48);
const _kMutedText = Color(0xFFB7C0CC);
const _kMutedSoft = Color(0xFF7D8DA6);
const _kNeonCyan = Color(0xFF21D9F8);
const _kAmber = Color(0xFFFFB85C);
const _kRed = Color(0xFFE02431);
const _kSlate = Color(0xFF6F7F8F);

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final period = ref.watch(selectedPeriodProvider);
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: AetronBackground(
        withGrid: false,
        child: workoutsAsync.when(
          data: (workouts) {
            if (workouts.isEmpty) {
              return _AnalyticsEmptyExperience(period: period);
            }
            final filtered = _filterWorkouts(workouts, period);
            final insights = _AnalyticsInsights.fromWorkouts(filtered, period);
            final records = _PersonalRecords.fromWorkouts(workouts);
            final chart = _distanceChartData(filtered, period);
            final breakdown = _activityBreakdown(filtered);
            final average = chart.isEmpty
                ? 0.0
                : chart.values.fold<double>(0, (sum, v) => sum + v) /
                      chart.length;

            return RefreshIndicator(
              color: _kNeonCyan,
              backgroundColor: _kCardSoft,
              onRefresh: () async {
                await ref.read(workoutListProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
                children: [
                  const _AnalyticsTopBar(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppTranslations.get('analytics', currentLang).toUpperCase(), style: AetronText.label),
                        if (isOffline) ...[
                          const SizedBox(height: 12),
                          const AetronOfflineBanner(),
                        ],
                        const SizedBox(height: 14),
                        _PeriodSwitcher(
                          selectedPeriod: period,
                          onChanged: (value) {
                            ref.read(selectedPeriodProvider.notifier).state =
                                value;
                          },
                        ),
                        const SizedBox(height: 18),
                        if (filtered.isEmpty)
                          _EmptyAnalyticsPanel(period: period)
                        else ...[
                          _SectionTitle(title: AppTranslations.get('overview', currentLang)),
                          const SizedBox(height: 10),
                          _OverviewGrid(
                            insights: insights,
                            useMetricUnits: useMetricUnits,
                          ),
                          const SizedBox(height: 22),
                          _SectionTitle(title: AppTranslations.get('distance_trend', currentLang)),
                          const SizedBox(height: 10),
                          _WeekTrendCard(
                            chartData: chart,
                            period: period,
                            average: average,
                            useMetricUnits: useMetricUnits,
                          ),
                          const SizedBox(height: 22),
                          _GoalProgressSection(
                            progress: ref.watch(goalProgressProvider),
                          ),
                          const SizedBox(height: 22),
                          _SectionTitle(title: AppTranslations.get('achievement_records', currentLang)),
                          const SizedBox(height: 10),
                          _RecordsList(
                            records: records,
                            useMetricUnits: useMetricUnits,
                          ),
                          const SizedBox(height: 22),
                          _SectionTitle(title: AppTranslations.get('activity_mix', currentLang)),
                          const SizedBox(height: 10),
                          _ActivityDistributionCard(
                            breakdown: breakdown,
                            total: filtered.length,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: AetronLoadingPanel(
              label: 'LOADING ANALYTICS',
              message: 'Compiling your workout signal.',
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AetronStatePanel(
                title: 'Analytics unavailable',
                message:
                    'Your saved workout data could not be analyzed right now.',
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

class _AnalyticsEmptyExperience extends ConsumerWidget {
  const _AnalyticsEmptyExperience({required this.period});

  final TimePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return RefreshIndicator(
      color: _kNeonCyan,
      backgroundColor: _kCardSoft,
      onRefresh: () => ref.read(workoutListProvider.notifier).refresh(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: .86,
            child: CustomPaint(painter: _EmptyAnalyticsPainter()),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AetronColors.voidBlack.withValues(alpha: .36),
                  Colors.transparent,
                  AetronColors.voidBlack.withValues(alpha: .95),
                ],
              ),
            ),
          ),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    const _AnalyticsTopBar(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      child: _PeriodSwitcher(
                        selectedPeriod: period,
                        onChanged: (value) {
                          ref.read(selectedPeriodProvider.notifier).state =
                              value;
                        },
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.query_stats_rounded,
                      color: _kNeonCyan,
                      size: 34,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppTranslations.get('analysis_standby', currentLang),
                      style: AetronText.section,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppTranslations.get('no_telemetry_yet', currentLang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        AppTranslations.get('no_telemetry_sub', currentLang),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AetronColors.cyanSoft,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: AetronPrimaryButton(
                          label: AppTranslations.get('start_workout', currentLang),
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ActivityScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsTopBar extends ConsumerWidget {
  const _AnalyticsTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return AetronHeader(
      title: AppTranslations.get('analytics', currentLang),
      compact: true,
      titleSize: 22,
    );
  }
}

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
    return AetronSegmented<TimePeriod>(
      values: TimePeriod.values,
      selected: selectedPeriod,
      labelBuilder: (p) => _periodLabel(p, currentLang),
      onChanged: onChanged,
    );
  }
}

class _EmptyAnalyticsPanel extends ConsumerWidget {
  const _EmptyAnalyticsPanel({required this.period});

  final TimePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final periodLabel = _periodLabel(period, currentLang).toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1928),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kNeonCyan.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: _kNeonCyan.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kNeonCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: _kNeonCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppTranslations.get('analysis_standby', currentLang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                '$periodLabel / EMPTY',
                style: const TextStyle(
                  color: _kNeonCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.65,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(painter: _EmptyAnalyticsPainter()),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppTranslations.get('no_telemetry_yet', currentLang),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            AppTranslations.get('no_telemetry_sub', currentLang),
            style: TextStyle(
              color: _kMutedText.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _EmptyTelemetryMetric(label: AppTranslations.get('distance', currentLang).toUpperCase())),
              const SizedBox(width: 10),
              Expanded(child: _EmptyTelemetryMetric(label: AppTranslations.get('pace', currentLang).toUpperCase())),
              const SizedBox(width: 10),
              Expanded(child: _EmptyTelemetryMetric(label: AppTranslations.get('personal_records', currentLang).toUpperCase())),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTelemetryMetric extends StatelessWidget {
  const _EmptyTelemetryMetric({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '--',
            style: TextStyle(
              color: _kNeonCyan,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kMutedSoft,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAnalyticsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF081524), Color(0xFF102B3A)],
        ).createShader(rect),
    );

    final grid = Paint()
      ..color = _kNeonCyan.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final center = Offset(size.width * 0.5, size.height * 0.52);
    final radius = size.shortestSide * 0.29;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _kNeonCyan.withValues(alpha: 0.22);
    for (final factor in [0.42, 0.7, 1.0]) {
      canvas.drawCircle(center, radius * factor, ring);
    }
    canvas.drawLine(
      Offset(center.dx - radius * 1.35, center.dy),
      Offset(center.dx + radius * 1.35, center.dy),
      ring,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 1.35),
      Offset(center.dx, center.dy + radius * 1.35),
      ring,
    );

    final wave = Path()..moveTo(0, size.height * 0.73);
    for (var x = 0.0; x <= size.width; x += 8) {
      final y =
          size.height * 0.73 +
          (x == size.width * 0.48 ? -20.0 : (x % 32 == 0 ? -5.0 : 0.0));
      wave.lineTo(x, y);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = _kNeonCyan.withValues(alpha: 0.7),
    );
    canvas.drawCircle(center, 7, Paint()..color = _kNeonCyan);
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kNeonCyan.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OverviewGrid extends ConsumerWidget {
  const _OverviewGrid({required this.insights, required this.useMetricUnits});

  final _AnalyticsInsights insights;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final cards = [
      _OverviewItem(
        icon: Icons.route_rounded,
        label: AppTranslations.get('avg_distance', currentLang),
        value:
            (useMetricUnits
                    ? insights.averageDistanceKm
                    : WorkoutFormatters.kmToMi(insights.averageDistanceKm))
                .toStringAsFixed(1),
        suffix:
            ' ${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits)}',
        color: _kAmber,
      ),
      _OverviewItem(
        icon: Icons.speed_rounded,
        label: AppTranslations.get('best_pace', currentLang),
        value: insights.bestPaceSecPerKm == null
            ? '--'
            : WorkoutFormatters.formatPaceFromSecondsPerKm(
                insights.bestPaceSecPerKm!,
                useMetric: useMetricUnits,
              ),
        suffix: '',
        color: _kNeonCyan,
      ),
      _OverviewItem(
        icon: Icons.event_available_rounded,
        label: '${insights.activeDays}/${insights.expectedDays} ${AppTranslations.get('days', currentLang)}',
        value: '${insights.consistencyPercent}',
        suffix: '%',
        color: _kRed,
      ),
      _OverviewItem(
        icon: Icons.fitness_center_rounded,
        label: 'WORKOUTS',
        value: '${insights.totalWorkouts}',
        suffix: '',
        color: _kNeonCyan,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.32,
      ),
      itemBuilder: (_, index) => _StatOverviewCard(item: cards[index]),
    );
  }
}

class _StatOverviewCard extends StatelessWidget {
  const _StatOverviewCard({required this.item});

  final _OverviewItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, color: item.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: _kMutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE8EDF5),
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 0.95,
                  ),
                ),
              ),
              if (item.suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    item.suffix.trim(),
                    style: const TextStyle(
                      color: _kMutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

class _GoalProgressSection extends ConsumerWidget {
  const _GoalProgressSection({required this.progress});

  final GoalProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    if (progress == null) {
      return _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: currentLang == AppLanguage.vi ? 'MỤC TIÊU TIẾN ĐỘ' : 'GOAL PROGRESS'),
            const SizedBox(height: 8),
            Text(
              currentLang == AppLanguage.vi
                  ? 'Hãy đặt mục tiêu để xem tiến độ tại đây.'
                  : 'Set a goal to see your progress here.',
              style: const TextStyle(
                color: _kMutedSoft,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final goal = progress!;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: currentLang == AppLanguage.vi ? 'MỤC TIÊU TIẾN ĐỘ' : 'GOAL PROGRESS'),
          const SizedBox(height: 4),
          Text(
            (goal.unit == 'km' || goal.unit == 'mi')
                ? (currentLang == AppLanguage.vi ? 'KHOẢNG CÁCH HÀNG THÁNG' : 'MONTHLY DISTANCE')
                : (currentLang == AppLanguage.vi ? 'MỤC TIÊU HIỆN TẠI' : 'CURRENT GOAL'),
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${goal.percent}%',
              style: const TextStyle(
                color: _kNeonCyan,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal.ratio,
              minHeight: 10,
              backgroundColor: _kTrack,
              valueColor: const AlwaysStoppedAnimation<Color>(_kNeonCyan),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${goal.currentLabel} ${goal.unit}'.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${goal.targetLabel} ${goal.unit} TARGET'.toUpperCase(),
                style: const TextStyle(
                  color: _kMutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekTrendCard extends ConsumerWidget {
  const _WeekTrendCard({
    required this.chartData,
    required this.period,
    required this.average,
    required this.useMetricUnits,
  });

  final Map<String, double> chartData;
  final TimePeriod period;
  final double average;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final labels = chartData.keys.toList();
    final values = chartData.values
        .map(
          (value) => useMetricUnits ? value : WorkoutFormatters.kmToMi(value),
        )
        .toList();
    final displayAverage = useMetricUnits
        ? average
        : WorkoutFormatters.kmToMi(average);
    final unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
    final maxY = values.isEmpty
        ? 1.0
        : (values.reduce((a, b) => a > b ? a : b) * 1.2)
              .clamp(1.0, 9999.0)
              .toDouble();
    final selectedIndex = values.isEmpty
        ? -1
        : values.indexOf(values.reduce((a, b) => a >= b ? a : b));

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_periodLabel(period, currentLang).toUpperCase()} ${AppTranslations.get('distance', currentLang).toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF133444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avg: ${displayAverage.toStringAsFixed(1)} $unit',
                  style: const TextStyle(
                    color: _kNeonCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 184,
            child: values.every((value) => value == 0)
                ? const Center(
                    child: Text(
                      'No activity in this period',
                      style: TextStyle(color: _kMutedSoft),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(enabled: false),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              final selected = index == selectedIndex;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  labels[index],
                                  style: TextStyle(
                                    color: selected ? _kNeonCyan : _kMutedText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
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
                                width: 36,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                                gradient: i == selectedIndex
                                    ? LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          _kNeonCyan.withValues(alpha: 0.55),
                                          _kNeonCyan,
                                        ],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          const Color(
                                            0xFF173140,
                                          ).withValues(alpha: 0.55),
                                          const Color(
                                            0xFF1F7D90,
                                          ).withValues(alpha: 0.85),
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

class _RecordsList extends ConsumerWidget {
  const _RecordsList({required this.records, required this.useMetricUnits});

  final _PersonalRecords records;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final items = [
      _RecordItem(
        label: currentLang == AppLanguage.vi ? 'KHOẢNG CÁCH DÀI NHẤT' : 'LONGEST DISTANCE',
        title: currentLang == AppLanguage.vi ? 'Lộ trình đường dài' : 'Marathon Run',
        value: WorkoutFormatters.formatDistance(
          records.longestDistance,
          useMetric: useMetricUnits,
          decimals: 1,
        ),
        date: currentLang == AppLanguage.vi ? 'Kỷ lục tốt nhất' : 'Best record',
        icon: Icons.emoji_events_rounded,
        color: _kAmber,
      ),
      _RecordItem(
        label: currentLang == AppLanguage.vi ? 'THỜI GIAN LÂU NHẤT' : 'LONGEST DURATION',
        title: currentLang == AppLanguage.vi ? 'Buổi tập bền bỉ' : 'Endurance Session',
        value: WorkoutFormatters.formatDurationFromSeconds(
          records.longestDurationSec,
        ),
        date: currentLang == AppLanguage.vi ? 'Kỷ lục tốt nhất' : 'Best record',
        icon: Icons.timer_rounded,
        color: _kNeonCyan,
      ),
      _RecordItem(
        label: currentLang == AppLanguage.vi ? 'CALO CAO NHẤT' : 'MOST CALORIES',
        title: currentLang == AppLanguage.vi ? 'Buổi tập tiêu hao cao' : 'High Burn Session',
        value: '${records.highestCalories} kcal',
        date: records.topActivity == 'No data'
            ? (currentLang == AppLanguage.vi ? 'Chưa có dữ liệu' : 'No data')
            : AppTranslations.get(records.topActivity, currentLang),
        icon: Icons.local_fire_department_rounded,
        color: _kRed,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _RecordCard(item: items[i]),
          if (i != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.item});

  final _RecordItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: _kMutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.value,
                style: TextStyle(
                  color: item.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.date,
                style: const TextStyle(
                  color: _kMutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityDistributionCard extends ConsumerWidget {
  const _ActivityDistributionCard({
    required this.breakdown,
    required this.total,
  });

  final Map<String, int> breakdown;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (breakdown.isEmpty)
            Text(
              currentLang == AppLanguage.vi
                  ? 'Chưa có dữ liệu hoạt động trong khoảng thời gian này.'
                  : 'No activity data in this period.',
              style: const TextStyle(color: _kMutedSoft),
            )
          else
            ...breakdown.entries.map((entry) {
              final ratio = total == 0 ? 0.0 : entry.value / total;
              final percent = (ratio * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          AppTranslations.get(entry.key, currentLang),
                          style: TextStyle(
                            color: _activityColor(entry.key),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: _kTrack,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _activityColor(entry.key),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE8EDF5),
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _OverviewItem {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final Color color;

  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });
}

class _RecordItem {
  final String label;
  final String title;
  final String value;
  final String date;
  final IconData icon;
  final Color color;

  const _RecordItem({
    required this.label,
    required this.title,
    required this.value,
    required this.date,
    required this.icon,
    required this.color,
  });
}

class _AnalyticsInsights {
  final int totalWorkouts;
  final double averageDistanceKm;
  final double? bestPaceSecPerKm;
  final int activeDays;
  final int expectedDays;
  final int consistencyPercent;

  const _AnalyticsInsights({
    required this.totalWorkouts,
    required this.averageDistanceKm,
    required this.bestPaceSecPerKm,
    required this.activeDays,
    required this.expectedDays,
    required this.consistencyPercent,
  });

  factory _AnalyticsInsights.fromWorkouts(
    List<WorkoutSession> workouts,
    TimePeriod period,
  ) {
    final totalDistance = workouts.fold(
      0.0,
      (sum, item) => sum + _effectiveDistanceKm(item),
    );
    final pacedWorkouts = workouts.where((workout) {
      return _effectiveDistanceKm(workout) > 0 && workout.durationSec > 0;
    }).toList();
    final bestPace = pacedWorkouts.isEmpty
        ? null
        : pacedWorkouts
              .map((workout) {
                return workout.durationSec / _effectiveDistanceKm(workout);
              })
              .reduce((a, b) => a < b ? a : b);
    final activeDates = workouts
        .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
        .toSet();
    final expectedDays = _elapsedDaysInPeriod(period);
    final consistency = expectedDays <= 0
        ? 0
        : ((activeDates.length / expectedDays) * 100).clamp(0, 100).round();

    return _AnalyticsInsights(
      totalWorkouts: workouts.length,
      averageDistanceKm: workouts.isEmpty ? 0 : totalDistance / workouts.length,
      bestPaceSecPerKm: bestPace,
      activeDays: activeDates.length,
      expectedDays: expectedDays,
      consistencyPercent: consistency,
    );
  }
}

class _PersonalRecords {
  final double longestDistance;
  final int longestDurationSec;
  final int highestCalories;
  final String topActivity;

  const _PersonalRecords({
    required this.longestDistance,
    required this.longestDurationSec,
    required this.highestCalories,
    required this.topActivity,
  });

  factory _PersonalRecords.fromWorkouts(List<WorkoutSession> workouts) {
    if (workouts.isEmpty) {
      return const _PersonalRecords(
        longestDistance: 0,
        longestDurationSec: 0,
        highestCalories: 0,
        topActivity: 'No data',
      );
    }

    final counts = <String, int>{};
    for (final workout in workouts) {
      counts.update(
        workout.activityType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return _PersonalRecords(
      longestDistance: workouts
          .map((item) => item.distanceKm)
          .reduce((a, b) => a > b ? a : b),
      longestDurationSec: workouts
          .map((item) => item.durationSec)
          .reduce((a, b) => a > b ? a : b),
      highestCalories: workouts
          .map((item) => item.caloriesKcal.round())
          .reduce((a, b) => a > b ? a : b),
      topActivity: top,
    );
  }
}

List<WorkoutSession> _filterWorkouts(
  List<WorkoutSession> workouts,
  TimePeriod period,
) {
  final now = DateTime.now();
  switch (period) {
    case TimePeriod.week:
      final start = DateTimeHelper.localDateOnly(
        now,
      ).subtract(Duration(days: DateTimeHelper.localDateOnly(now).weekday - 1));
      return workouts.where((workout) {
        return !DateTimeHelper.localDateOnly(workout.startedAt).isBefore(start);
      }).toList();
    case TimePeriod.month:
      final start = DateTime(now.year, now.month, 1);
      return workouts.where((workout) {
        return !DateTimeHelper.localDateOnly(workout.startedAt).isBefore(start);
      }).toList();
    case TimePeriod.year:
      final start = DateTime(now.year, 1, 1);
      return workouts.where((workout) {
        return !DateTimeHelper.localDateOnly(workout.startedAt).isBefore(start);
      }).toList();
  }
}

Map<String, double> _distanceChartData(
  List<WorkoutSession> workouts,
  TimePeriod period,
) {
  final data = <String, double>{};
  final now = DateTimeHelper.localDateOnly(DateTime.now());

  switch (period) {
    case TimePeriod.week:
      for (var i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: now.weekday - 1 - i));
        data[_weekdayLabel(day)] = 0;
      }
      for (final workout in workouts) {
        final key = _weekdayLabel(
          DateTimeHelper.localDateOnly(workout.startedAt),
        );
        if (data.containsKey(key)) {
          data[key] = data[key]! + _effectiveDistanceKm(workout);
        }
      }
      break;
    case TimePeriod.month:
      for (var week = 1; week <= 5; week++) {
        data['W$week'] = 0;
      }
      for (final workout in workouts) {
        final date = DateTimeHelper.localDateOnly(workout.startedAt);
        final index = ((date.day - 1) ~/ 7) + 1;
        final key = 'W${index.clamp(1, 5)}';
        data[key] = (data[key] ?? 0) + _effectiveDistanceKm(workout);
      }
      break;
    case TimePeriod.year:
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      for (var i = 0; i < 12; i++) {
        data[months[i]] = 0;
      }
      for (final workout in workouts) {
        final date = DateTimeHelper.localDateOnly(workout.startedAt);
        final key = months[date.month - 1];
        data[key] = (data[key] ?? 0) + _effectiveDistanceKm(workout);
      }
      break;
  }

  return data;
}

double _effectiveDistanceKm(WorkoutSession workout) {
  final validDistance = workout.gpsAnalysis.validDistanceKm;
  return validDistance > 0 ? validDistance : workout.distanceKm;
}

int _elapsedDaysInPeriod(TimePeriod period) {
  final now = DateTimeHelper.localDateOnly(DateTime.now());
  switch (period) {
    case TimePeriod.week:
      return now.weekday;
    case TimePeriod.month:
      return now.day;
    case TimePeriod.year:
      return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  }
}

Map<String, int> _activityBreakdown(List<WorkoutSession> workouts) {
  final map = <String, int>{};
  for (final workout in workouts) {
    final key = WorkoutFormatters.formatActivityType(workout.activityType);
    map.update(key, (value) => value + 1, ifAbsent: () => 1);
  }
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final entry in entries) entry.key: entry.value};
}

String _periodLabel(TimePeriod period, AppLanguage lang) {
  switch (period) {
    case TimePeriod.week:
      return AppTranslations.get('week', lang);
    case TimePeriod.month:
      return AppTranslations.get('month', lang);
    case TimePeriod.year:
      return AppTranslations.get('year', lang);
  }
}

String _weekdayLabel(DateTime day) {
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return labels[day.weekday - 1];
}

Color _activityColor(String activity) {
  switch (activity.toLowerCase()) {
    case 'running':
      return _kNeonCyan;
    case 'cycling':
      return _kAmber;
    case 'walking':
      return Colors.white;
    default:
      return _kSlate;
  }
}
