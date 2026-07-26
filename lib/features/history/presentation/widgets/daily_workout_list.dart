import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/utils/activity_consistency_feedback.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kCardBg = Color(0xFF102033);
const _kCardBorder = Color(0x2200E5FF);
const _kMutedText = Color(0xFF8A96A9);
const _kMutedSoft = Color(0xFF627286);
const _kNeonCyan = Color(0xFF19E2FF);
const _kAmber = Color(0xFFFFB85C);
const _kValidGreen = Color(0xFF6BE39B);
const _kDangerRed = Color(0xFFFF7A8A);

class DailyWorkoutList extends ConsumerWidget {
  final List<WorkoutSession> workouts;
  final String range;

  const DailyWorkoutList({
    super.key,
    required this.workouts,
    required this.range,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    if (workouts.isEmpty) {
      return _EmptyHistoryCard(range: range);
    }

    return Column(
      children: workouts.map((workout) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _WorkoutHistoryCard(
            workout: workout,
            useMetricUnits: useMetricUnits,
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.range});

  final String range;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: _kNeonCyan.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.55,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(
                painter: _EmptyHistoryMapPainter(),
                child: Stack(
                  children: [
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _EmptyStatusBadge(range: range),
                    ),
                    const Positioned(
                      right: 14,
                      bottom: 14,
                      child: _EmptySignalPill(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _kNeonCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kNeonCyan.withValues(alpha: 0.34)),
                ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  color: _kNeonCyan,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NO ACTIVITY RECORDED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      range == 'All'
                          ? 'Start your first session to activate history telemetry.'
                          : 'No sessions found for this $range window.',
                      style: const TextStyle(
                        color: _kMutedText,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: _EmptyMetricChip(
                  icon: Icons.route_rounded,
                  value: '0.0',
                  label: 'DISTANCE',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _EmptyMetricChip(
                  icon: Icons.timer_outlined,
                  value: '00:00',
                  label: 'TIME',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _EmptyMetricChip(
                  icon: Icons.local_fire_department_rounded,
                  value: '0',
                  label: 'KCAL',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _kNeonCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kNeonCyan.withValues(alpha: 0.18)),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: _kNeonCyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Open Activity and record a workout to fill this timeline.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
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

class _EmptyStatusBadge extends StatelessWidget {
  const _EmptyStatusBadge({required this.range});

  final String range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE60A1320),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            color: _kNeonCyan,
            size: 15,
          ),
          const SizedBox(width: 7),
          Text(
            '${range.toUpperCase()} / EMPTY',
            style: const TextStyle(
              color: Colors.white,
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

class _EmptySignalPill extends StatelessWidget {
  const _EmptySignalPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE60A1320),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kNeonCyan.withValues(alpha: 0.24)),
      ),
      child: const Text(
        'AWAITING FIRST SIGNAL',
        style: TextStyle(
          color: _kNeonCyan,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _EmptyMetricChip extends StatelessWidget {
  const _EmptyMetricChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      // A fixed height gives the internal Spacer a bounded main axis.
      // Without it, the empty history transition can leave this Column
      // unconstrained and Flutter cannot lay it out for hit testing.
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kNeonCyan, size: 16),
          const Spacer(),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF081421), Color(0xFF102840)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final gridPaint = Paint()
      ..color = _kNeonCyan.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 26.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final ringCenter = Offset(size.width * 0.58, size.height * 0.48);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _kNeonCyan.withValues(alpha: 0.16);
    for (final scale in [0.55, 0.82, 1.08]) {
      canvas.drawCircle(
        ringCenter,
        size.shortestSide * 0.24 * scale,
        ringPaint,
      );
    }

    final route = Path()
      ..moveTo(size.width * 0.12, size.height * 0.68)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.30,
        size.width * 0.46,
        size.height * 0.82,
        size.width * 0.62,
        size.height * 0.44,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.16,
        size.width * 0.88,
        size.height * 0.36,
        size.width * 0.84,
        size.height * 0.66,
      );
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = _kNeonCyan.withValues(alpha: 0.22);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _kNeonCyan.withValues(alpha: 0.66);
    canvas.drawPath(route, glow);
    canvas.drawPath(route, line);

    final dotPaint = Paint()..color = _kNeonCyan;
    for (final dot in [
      Offset(size.width * 0.12, size.height * 0.68),
      Offset(size.width * 0.62, size.height * 0.44),
      Offset(size.width * 0.84, size.height * 0.66),
    ]) {
      canvas.drawCircle(dot, 4, dotPaint);
      canvas.drawCircle(
        dot,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _kNeonCyan.withValues(alpha: 0.38),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WorkoutHistoryCard extends ConsumerWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;

  const _WorkoutHistoryCard({
    required this.workout,
    required this.useMetricUnits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final color = _activityColor(workout.activityType);
    final start = workout.startedAt.toLocal();
    final day = start.day.toString().padLeft(2, '0');
    final month = _monthShort(start.month, currentLang).toUpperCase();
    final pace = _paceLabel(workout, useMetricUnits: useMetricUnits);
    final consistency = assessWorkoutSession(workout);
    final shouldWarn = consistency.validityFlag != WorkoutValidityFlag.verified;
    final primaryDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : workout.distanceKm;
    final excludedKm =
        workout.gpsAnalysis.suspiciousDistanceKm +
        workout.gpsAnalysis.invalidDistanceKm;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkoutDetailsScreen(workoutId: workout.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _kCardBorder),
          boxShadow: [
            BoxShadow(
              color: _kNeonCyan.withValues(alpha: 0.06),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    month,
                    style: const TextStyle(
                      color: _kMutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppTranslations.get(workout.activityType, currentLang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _HistoryValidityBadge(flag: consistency.validityFlag, currentLang: currentLang),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel(workout.startedAt),
                        style: const TextStyle(
                          color: _kMutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (shouldWarn) ...[
                    const SizedBox(height: 8),
                    Text(
                      activityConsistencyWarningText(consistency),
                      style: const TextStyle(
                        color: _kAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Raw ${WorkoutFormatters.formatDistance(workout.gpsAnalysis.totalDistanceKm, useMetric: useMetricUnits, decimals: 2)} • Excluded ${WorkoutFormatters.formatDistance(excludedKm, useMetric: useMetricUnits, decimals: 2)}',
                      style: const TextStyle(
                        color: _kMutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MetricMini(
                        color: _kNeonCyan,
                        icon: Icons.place_outlined,
                        value:
                            (useMetricUnits
                                    ? primaryDistanceKm
                                    : WorkoutFormatters.kmToMi(
                                        primaryDistanceKm,
                                      ))
                                .toStringAsFixed(1),
                        label: WorkoutFormatters.distanceUnitLabel(
                          useMetric: useMetricUnits,
                        ),
                      ),
                      _MetricMini(
                        color: color,
                        icon: Icons.timer_outlined,
                        value: _durationShort(workout.durationSec),
                        label: currentLang == AppLanguage.vi ? 'thời gian' : 'time',
                      ),
                      _MetricMini(
                        color: Colors.white,
                        icon: Icons.speed_rounded,
                        value: pace,
                        label: currentLang == AppLanguage.vi ? 'tốc độ TB' : 'avg pace',
                      ),
                      _MetricMini(
                        color: _kAmber,
                        icon: Icons.local_fire_department_rounded,
                        value: '${workout.caloriesKcal.round()}',
                        label: 'kcal',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _kMutedSoft),
          ],
        ),
      ),
    );
  }
}

class _MetricMini extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String value;
  final String label;

  const _MetricMini({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: _kMutedText,
                  fontSize: 8,
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

class _HistoryValidityBadge extends StatelessWidget {
  const _HistoryValidityBadge({required this.flag, required this.currentLang});

  final WorkoutValidityFlag flag;
  final AppLanguage currentLang;

  @override
  Widget build(BuildContext context) {
    final color = switch (flag) {
      WorkoutValidityFlag.verified => _kValidGreen,
      WorkoutValidityFlag.partial => _kAmber,
      WorkoutValidityFlag.unverified => _kDangerRed,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        workoutValidityLabel(flag, currentLang),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _timeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _monthShort(int month, [AppLanguage? lang]) {
  if (lang == AppLanguage.vi) {
    return 'Thg $month';
  }
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
  return months[month - 1];
}

String _durationShort(int seconds) {
  return WorkoutFormatters.formatElapsedClock(seconds);
}

String _paceLabel(WorkoutSession workout, {required bool useMetricUnits}) {
  final distanceKm = workout.gpsAnalysis.validDistanceKm > 0
      ? workout.gpsAnalysis.validDistanceKm
      : workout.distanceKm;
  if (distanceKm <= 0 || workout.durationSec <= 0) return '--';
  final paceMinPerKm = workout.durationSec / 60 / distanceKm;
  return WorkoutFormatters.formatSplitPace(
    paceMinPerKm,
    useMetric: useMetricUnits,
  );
}

Color _activityColor(String activity) {
  switch (activity.toLowerCase()) {
    case 'running':
      return const Color(0xFF19E2FF);
    case 'cycling':
      return const Color(0xFFFFB85C);
    case 'walking':
      return const Color(0xFF39F2B8);
    default:
      return _kNeonCyan;
  }
}
