import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const _kBgTop = Color(0xff0a0e1a);
const _kBgBottom = Color(0xff0d1b2a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);
const _kNeonBlue = Color(0xff00bfff);

class WorkoutDetailsScreen extends ConsumerWidget {
  final String workoutId;

  const WorkoutDetailsScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(workoutProvider(workoutId));

    return Scaffold(
      backgroundColor: _kBgTop,
      appBar: AppBar(
        title: const Text('Details'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _showDeleteConfirmation(context, ref, workoutId),
          ),
        ],
      ),
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
              return const Center(
                child: Text(
                  'Workout not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _HeroCard(
                  activityType: workout.activityType,
                  dateLabel: DateFormat(
                    'EEEE, MMM dd, yyyy',
                  ).format(workout.startedAt.toLocal()),
                ),
                const SizedBox(height: 16),
                _StatsGrid(workout: workout),
                const SizedBox(height: 16),
                if (workout.lapSplits.isNotEmpty) ...[
                  _LapSplitsCard(workout: workout),
                  const SizedBox(height: 16),
                ],
                _TimelineCard(workout: workout),
                const SizedBox(height: 16),
                _SessionMetaCard(workout: workout),
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _kNeonCyan)),
          error: (error, _) => Center(
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String activityType;
  final String dateLabel;

  const _HeroCard({required this.activityType, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [_kNeonBlue, _kNeonCyan]),
              boxShadow: [
                BoxShadow(
                  color: _kNeonCyan.withValues(alpha: 0.20),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Icon(_activityIcon(activityType), color: _kBgTop, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  WorkoutFormatters.formatActivityType(
                    activityType,
                  ).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: _kMutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _StatsGrid extends StatelessWidget {
  final dynamic workout;

  const _StatsGrid({required this.workout});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DetailItem(
        icon: Icons.straighten_rounded,
        label: 'Distance',
        value: '${workout.distanceKm.toStringAsFixed(2)} km',
      ),
      _DetailItem(
        icon: Icons.timer_outlined,
        label: 'Duration',
        value: WorkoutFormatters.formatDurationFromSeconds(workout.durationSec),
      ),
      _DetailItem(
        icon: Icons.speed_rounded,
        label: 'Avg Speed',
        value: '${workout.avgSpeedKmh.toStringAsFixed(1)} km/h',
      ),
      _DetailItem(
        icon: Icons.local_fire_department_rounded,
        label: 'Calories',
        value: '${workout.caloriesKcal.round()} kcal',
      ),
      _DetailItem(
        icon: Icons.directions_walk_rounded,
        label: 'Steps',
        value: '${workout.steps}',
      ),
      _DetailItem(
        icon: Icons.explore_rounded,
        label: 'Mode',
        value: '${workout.mode}'.toUpperCase(),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (_, index) => _DetailCard(item: items[index]),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final _DetailItem item;

  const _DetailCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xff101a29),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: _kNeonCyan, size: 20),
          ),
          const Spacer(),
          Text(
            item.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final dynamic workout;

  const _TimelineCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _TimelineItem(
            icon: Icons.play_circle_outline_rounded,
            label: 'Started',
            time: DateFormat('HH:mm:ss').format(workout.startedAt.toLocal()),
          ),
          if (workout.endedAt != null) ...[
            const SizedBox(height: 12),
            _TimelineItem(
              icon: Icons.stop_circle_outlined,
              label: 'Ended',
              time: DateFormat('HH:mm:ss').format(workout.endedAt.toLocal()),
            ),
          ],
        ],
      ),
    );
  }
}

class _LapSplitsCard extends StatelessWidget {
  final dynamic workout;

  const _LapSplitsCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lap Splits',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          for (final split in workout.lapSplits) ...[
            _LapSplitRow(split: split),
            if (split != workout.lapSplits.last)
              Divider(height: 18, color: Colors.white.withValues(alpha: 0.06)),
          ],
        ],
      ),
    );
  }
}

class _LapSplitRow extends StatelessWidget {
  final WorkoutLapSplit split;

  const _LapSplitRow({required this.split});

  @override
  Widget build(BuildContext context) {
    final paceMinutes = split.paceMinPerKm.floor();
    var paceSeconds = ((split.paceMinPerKm - paceMinutes) * 60).round();
    var minutes = paceMinutes;
    if (paceSeconds == 60) {
      minutes += 1;
      paceSeconds = 0;
    }

    return Row(
      children: [
        Text(
          'KM ${split.index}',
          style: const TextStyle(
            color: _kNeonCyan,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          WorkoutFormatters.formatDurationFromSeconds(split.durationSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$minutes:${paceSeconds.toString().padLeft(2, '0')}/km',
          style: const TextStyle(
            color: _kMutedText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;

  const _TimelineItem({
    required this.icon,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xff101a29),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _kNeonCyan, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            color: _kMutedText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SessionMetaCard extends StatelessWidget {
  final dynamic workout;

  const _SessionMetaCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session info',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _MetaRow(label: 'Workout ID', value: workout.id),
          const SizedBox(height: 10),
          _MetaRow(
            label: 'Created',
            value: DateFormat(
              'MMM dd, yyyy HH:mm',
            ).format(workout.createdAt.toLocal()),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kMutedText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: _kNeonCyan.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

IconData _activityIcon(String activityType) {
  switch (activityType.toLowerCase()) {
    case 'running':
      return Icons.directions_run_rounded;
    case 'cycling':
      return Icons.directions_bike_rounded;
    case 'walking':
      return Icons.directions_walk_rounded;
    case 'swimming':
      return Icons.pool_rounded;
    case 'weights':
      return Icons.fitness_center_rounded;
    case 'yoga':
      return Icons.self_improvement_rounded;
    default:
      return Icons.bolt_rounded;
  }
}

void _showDeleteConfirmation(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xff0f1726),
      title: const Text('Delete Workout'),
      content: const Text(
        'Are you sure you want to delete this workout? This action cannot be undone.',
        style: TextStyle(color: _kMutedText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel', style: TextStyle(color: _kMutedText)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            try {
              await ref
                  .read(workoutListProvider.notifier)
                  .deleteWorkout(workoutId);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Workout deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
