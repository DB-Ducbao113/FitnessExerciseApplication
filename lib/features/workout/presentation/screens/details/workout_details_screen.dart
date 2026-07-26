import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_state_panel.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

const _kBgTop = Color(0xff070b18);
const _kBgBottom = Color(0xff0a1020);
const _kPanel = Color(0xff101728);
const _kPanelDeep = Color(0xff0e1424);
const _kBorder = Color(0x553a4a63);
const _kMuted = Color(0xff7d8da6);
const _kText = Color(0xffd9e6f2);
const _kCyan = Color(0xff00e5ff);
const _kGreen = Color(0xff6be39b);
const _kRed = Color(0xffff7a8a);

bool _hasSteps(String activityType) {
  final t = activityType.toLowerCase();
  return t == 'running' || t == 'walking';
}

class WorkoutDetailsScreen extends ConsumerWidget {
  const WorkoutDetailsScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(workoutProvider(workoutId));
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: _kBgTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: workoutAsync.when(
          data: (workout) {
            if (workout == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AetronStatePanel(
                    title: 'Workout unavailable',
                    message: 'This saved workout is no longer available.',
                    tone: AetronStateTone.error,
                    onRetry: () => ref.invalidate(workoutProvider(workoutId)),
                  ),
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                14,
                MediaQuery.of(context).padding.top,
                14,
                24,
              ),
              children: [
                _DetailsHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                  onDelete: () =>
                      _showDeleteConfirmation(context, ref, workoutId),
                ),
                const SizedBox(height: 10),
                _DetailsContent(
                  workoutId: workoutId,
                  workout: workout,
                  useMetricUnits: useMetricUnits,
                ),
              ],
            );
          },
          loading: () => const Center(
            child: AetronLoadingPanel(
              label: 'LOADING DETAILS',
              message: 'Rebuilding your route recap.',
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AetronStatePanel(
                title: 'Details unavailable',
                message: 'This workout could not be loaded right now.',
                tone: AetronStateTone.error,
                onRetry: () => ref.invalidate(workoutProvider(workoutId)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsHeader extends ConsumerWidget {
  const _DetailsHeader({required this.onBack, required this.onDelete});

  final VoidCallback onBack;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded),
              color: _kText,
              iconSize: 32,
            ),
          ),
          Text(
            AppTranslations.get('workout_details', currentLang).toUpperCase(),
            style: const TextStyle(
              color: _kText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.4,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: _kMuted,
              iconSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsContent extends ConsumerWidget {
  const _DetailsContent({
    required this.workoutId,
    required this.workout,
    required this.useMetricUnits,
  });

  final String workoutId;
  final WorkoutSession workout;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final routeAsync = ref.watch(workoutRoutePresentationProvider(workoutId));
    final displayDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : workout.distanceKm;
    final avgPace = WorkoutFormatters.formatPaceFromDistanceAndDuration(
      distanceKm: displayDistanceKm,
      durationSec: workout.durationSec,
      useMetric: useMetricUnits,
    );
    final movingPace =
        WorkoutFormatters.formatMovingPaceFromDistanceAndDuration(
          distanceKm: displayDistanceKm,
          durationSec: workout.movingTimeSec,
          restDurationSec: 0,
          useMetric: useMetricUnits,
        );
    final showSteps = _hasSteps(workout.activityType) && workout.steps > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RouteRecapCard(
          child: routeAsync.when(
            data: (route) => route.routePoints.length >= 2
                ? _RouteMapHero(
                    routePoints: route.routePoints,
                    activityType: workout.activityType,
                  )
                : _RouteUnavailable(
                    activityType: workout.activityType,
                    durationSec: workout.durationSec,
                    distanceKm: displayDistanceKm,
                    useMetricUnits: useMetricUnits,
                  ),
            loading: () => const Center(
              child: AetronLoadingPanel(label: 'ROUTE SCAN', size: 126),
            ),
            error: (_, _) => _RouteUnavailable(
              activityType: workout.activityType,
              durationSec: workout.durationSec,
              distanceKm: displayDistanceKm,
              useMetricUnits: useMetricUnits,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ActivityTitleRow(
          activityType: workout.activityType,
          dateLabel: _formatDate(workout.startedAt, currentLang),
        ),
        const SizedBox(height: 18),
        _DistanceReadout(
          distanceKm: displayDistanceKm,
          useMetricUnits: useMetricUnits,
        ),
        const SizedBox(height: 22),
        _StatsPanel(
          children: [
            _HudMetric(
              label: AppTranslations.get('duration', currentLang),
              value: WorkoutFormatters.formatDurationFromSeconds(
                workout.durationSec,
              ),
            ),
            _HudMetric(label: AppTranslations.get('best_pace', currentLang), value: avgPace, alignRight: true),
            _HudMetric(label: AppTranslations.get('moving_pace', currentLang), value: movingPace),
            _HudMetric(
              label: AppTranslations.get('moving_time', currentLang),
              value: WorkoutFormatters.formatElapsedClock(
                workout.movingTimeSec,
              ),
              alignRight: true,
            ),
            _HudMetric(
              label: AppTranslations.get('calories', currentLang),
              value: '${workout.caloriesKcal.round()} kcal',
            ),
            _HudMetric(
              label: showSteps
                  ? (currentLang == AppLanguage.vi ? 'Số bước' : 'Steps')
                  : AppTranslations.get('rest_time', currentLang),
              value: showSteps
                  ? _formatSteps(workout.steps)
                  : WorkoutFormatters.formatElapsedClock(
                      workout.gpsAnalysis.restDurationSec,
                    ),
              alignRight: true,
            ),
            _HudMetric(
              label: currentLang == AppLanguage.vi ? 'Bắt đầu' : 'Started',
              value: DateFormat('HH:mm:ss').format(workout.startedAt.toLocal()),
            ),
            _HudMetric(
              label: currentLang == AppLanguage.vi ? 'Hoàn thành' : 'Finished',
              value: DateFormat('HH:mm:ss').format(workout.endedAt.toLocal()),
              alignRight: true,
            ),
            _HudMetric(
              label: currentLang == AppLanguage.vi ? 'Đã lưu' : 'Saved',
              value: _formatDate(workout.createdAt, currentLang, includeTime: true),
              wide: true,
            ),
          ],
        ),
        if (workout.lapSplits.isNotEmpty) ...[
          const SizedBox(height: 14),
          _StatsPanel(
            children: [
              for (final split in workout.lapSplits)
                _HudMetric(
                  label:
                      '${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase()} ${split.index}',
                  value:
                      '${WorkoutFormatters.formatDurationFromSeconds(split.durationSeconds)}  ${WorkoutFormatters.formatSplitPace(split.paceMinPerKm, useMetric: useMetricUnits)}',
                  wide: true,
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        const Center(child: _SignalBadge()),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'A E T R O N   T E L E M E T R Y   H U D   V.2.0.4',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteRecapCard extends StatelessWidget {
  const _RouteRecapCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 252,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _kBorder),
      ),
      child: child,
    );
  }
}

class _ActivityTitleRow extends ConsumerWidget {
  const _ActivityTitleRow({
    required this.activityType,
    required this.dateLabel,
  });

  final String activityType;
  final String dateLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xff063a4d),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_activityIcon(activityType), color: _kCyan, size: 30),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get(activityType, currentLang).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistanceReadout extends ConsumerWidget {
  const _DistanceReadout({
    required this.distanceKm,
    required this.useMetricUnits,
  });

  final double distanceKm;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final value = useMetricUnits
        ? distanceKm
        : WorkoutFormatters.kmToMi(distanceKm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                color: Color(0xff8fdcff),
                fontSize: 41,
                height: 0.9,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.6,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits),
                style: const TextStyle(
                  color: _kText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          currentLang == AppLanguage.vi
              ? 'KHOẢNG CÁCH GHI NHẬN'
              : 'RECORDED DISTANCE',
          style: const TextStyle(
            color: _kMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: _kPanelDeep,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Wrap(runSpacing: 20, children: children),
    );
  }
}

class _HudMetric extends StatelessWidget {
  const _HudMetric({
    required this.label,
    required this.value,
    this.alignRight = false,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool alignRight;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide
          ? double.infinity
          : (MediaQuery.of(context).size.width - 64) / 2,
      child: Column(
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: _kText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBadge extends ConsumerWidget {
  const _SignalBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _kCyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kCyan.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, color: _kCyan, size: 15),
          const SizedBox(width: 8),
          Text(
            AppTranslations.get('high_precision_signal', currentLang),
            style: const TextStyle(
              color: _kCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMapHero extends StatelessWidget {
  const _RouteMapHero({required this.routePoints, required this.activityType});

  final List<LatLng> routePoints;
  final String activityType;

  @override
  Widget build(BuildContext context) {
    return WorkoutRoutePreviewMap(
      routePoints: routePoints,
      activityType: activityType,
      icon: _activityIcon(activityType),
      accentColor: _kCyan,
      glowColor: _kCyan.withValues(alpha: 0.22),
      highlightColor: Colors.white.withValues(alpha: 0.74),
      startColor: _kGreen,
      endColor: _kRed,
      badgeText: 'ROUTE RECAP',
      footerText: '${routePoints.length} points recorded',
    );
  }
}

class _RouteUnavailable extends ConsumerWidget {
  const _RouteUnavailable({
    required this.activityType,
    required this.durationSec,
    required this.distanceKm,
    required this.useMetricUnits,
  });

  final String activityType;
  final int durationSec;
  final double distanceKm;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff13263a), Color(0xff0b1725)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_activityIcon(activityType), color: _kCyan, size: 42),
              const SizedBox(height: 14),
              Text(
                currentLang == AppLanguage.vi
                    ? 'KHÔNG CÓ LỘ TRÌNH GPS'
                    : 'GPS ROUTE UNAVAILABLE',
                style: const TextStyle(
                  color: _kText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${WorkoutFormatters.formatDistance(distanceKm, useMetric: useMetricUnits, decimals: 2)} / ${WorkoutFormatters.formatElapsedClock(durationSec)}',
                style: const TextStyle(
                  color: _kMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt, AppLanguage lang, {bool includeTime = false}) {
  final local = dt.toLocal();
  if (lang == AppLanguage.vi) {
    const daysVi = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
    final dayOfWeek = daysVi[local.weekday % 7];
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    if (includeTime) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }
    return '$dayOfWeek, $day/$month/$year';
  }
  if (includeTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(local);
  }
  return DateFormat('EEEE, MMM dd, yyyy').format(local);
}

String _formatSteps(int steps) {
  if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
  return '$steps';
}

IconData _activityIcon(String activityType) {
  switch (activityType.toLowerCase()) {
    case 'running':
      return Icons.directions_run_rounded;
    case 'cycling':
      return Icons.directions_bike_rounded;
    case 'walking':
      return Icons.directions_walk_rounded;
    default:
      return Icons.bolt_rounded;
  }
}

Future<void> _showDeleteConfirmation(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
) async {
  final confirmed = await showAetronConfirmDialog(
    context,
    title: 'Delete workout',
    message:
        'This removes the workout, route, and saved telemetry from your account. This cannot be undone.',
    confirmLabel: 'Delete',
    icon: Icons.delete_forever_rounded,
    destructive: true,
  );
  if (!confirmed) return;

  try {
    await ref.read(workoutListProvider.notifier).deleteWorkout(workoutId);
    if (context.mounted) Navigator.of(context).pop();
  } catch (_) {
    if (!context.mounted) return;
    showAetronNotice(
      context,
      message: 'Could not delete this workout. Please try again.',
      tone: AetronNoticeTone.error,
    );
  }
}
