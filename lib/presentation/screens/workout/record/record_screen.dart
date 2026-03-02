import 'package:fitness_exercise_application/presentation/screens/workout/record/record_providers.dart';
import 'package:fitness_exercise_application/presentation/screens/workout/record/widgets/tracking_map_widget.dart';
import 'package:fitness_exercise_application/presentation/screens/workout/summary/workout_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecordScreen extends ConsumerStatefulWidget {
  final String activityType;

  const RecordScreen({super.key, required this.activityType});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with WidgetsBindingObserver {
  bool _isAutoFollow = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // startWorkout is now synchronous: fires immediately, no await needed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWorkout());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final status = ref.read(workoutSessionProvider).status;
    final notifier = ref.read(workoutSessionProvider.notifier);
    if (lifecycle == AppLifecycleState.paused &&
        status == RecordingState.active) {
      notifier.pauseWorkout();
    } else if (lifecycle == AppLifecycleState.resumed &&
        status == RecordingState.paused) {
      notifier.resumeWorkout();
    }
  }

  // ─── Workout lifecycle ────────────────────────────────────────────────────

  void _startWorkout() {
    // Fire-and-return: sensors start in background, UI responds immediately.
    ref.read(workoutSessionProvider.notifier).startWorkout(widget.activityType);
  }

  void _showStartError(String code) {
    String title, message, actionLabel;
    VoidCallback onAction;

    switch (code) {
      case 'location_disabled':
        title = 'GPS is Off';
        message =
            'Location services are disabled. Please enable GPS and try again.';
        actionLabel = 'Try Again';
        onAction = () {
          Navigator.of(context).pop();
          _startWorkout();
        };
      case 'permission_denied':
        title = 'Permission Denied';
        message = 'Location permission is required to track your workout.';
        actionLabel = 'Try Again';
        onAction = () {
          Navigator.of(context).pop();
          _startWorkout();
        };
      case 'permission_denied_forever':
        title = 'Permission Blocked';
        message =
            'Location is permanently blocked. Open App Settings → Permissions → Location.';
        actionLabel = 'Close';
        onAction = () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        };
      default:
        title = 'Could Not Start';
        message = code;
        actionLabel = 'Back';
        onAction = () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        };
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAction();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text('Are you sure you want to end this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final finalState = ref.read(workoutSessionProvider);
      await ref.read(workoutSessionProvider.notifier).stopWorkout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WorkoutSummaryScreen(
              workoutId: finalState.workoutId ?? 0,
              activityType: finalState.activityType,
              trackingMode: finalState.trackingMode,
              durationSeconds: finalState.durationSeconds,
              distanceMeters: finalState.distanceMeters,
              avgPace: 0,
              calories: finalState.caloriesBurned,
            ),
          ),
        );
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutSessionProvider);

    // React to GPS errors surfaced through state (non-blocking)
    ref.listen<WorkoutSessionState>(workoutSessionProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _showStartError(next.errorMessage!);
      }
    });

    final isDetecting = state.trackingMode == kAutoTrackingMode;
    final isOutdoor = state.trackingMode == kOutdoorMode;
    final currentLocation = state.routePoints.isNotEmpty
        ? state.routePoints.last
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── 1. MAP — always rendered, even during detecting/indoor ─────────
          Positioned.fill(
            bottom: MediaQuery.of(context).size.height * 0.45,
            child: TrackingMapWidget(
              routePoints: state.routePoints,
              currentLocation: currentLocation,
              isAutoFollow: _isAutoFollow,
              showRoute: isOutdoor, // polyline only in outdoor
              onPan: () => setState(() => _isAutoFollow = false),
            ),
          ),

          // ── 2. Detecting overlay (transparent, on top of map) ─────────────
          if (isDetecting)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.04,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Detecting environment…',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── 3. Indoor mode overlay (bottom-left chip on map) ──────────────
          if (!isDetecting && !isOutdoor)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.455,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Indoor — Step tracking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 4. Top bar ────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Activity + mode badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _activityIcon(widget.activityType),
                            size: 20,
                            color: const Color(0xff18b0e8),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.activityType.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _modeBadgeText(state.trackingMode),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Re-center button
                    if (isOutdoor && !_isAutoFollow)
                      FloatingActionButton.small(
                        backgroundColor: Colors.white,
                        onPressed: () => setState(() => _isAutoFollow = true),
                        child: const Icon(
                          Icons.my_location,
                          color: Color(0xff18b0e8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── 5. Metrics + Controls panel ───────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: MediaQuery.of(context).size.height * 0.55,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timer + Distance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _BigStat(
                          label: 'TIME',
                          value: _formatDuration(state.durationSeconds),
                        ),
                        _BigStat(
                          label: 'DISTANCE',
                          value:
                              '${(state.distanceMeters / 1000).toStringAsFixed(2)} km',
                          align: TextAlign.right,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Secondary metrics
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MetricStat(
                          label: 'SPEED',
                          value: '${state.speedKmh.toStringAsFixed(1)} km/h',
                        ),
                        _MetricStat(
                          label: 'STEPS',
                          value: '${state.stepCount}',
                        ),
                        _MetricStat(
                          label: 'CALORIES',
                          value: '${state.caloriesBurned} kcal',
                        ),
                      ],
                    ),

                    const Spacer(),
                    _buildControls(state.status),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Controls ─────────────────────────────────────────────────────────────

  Widget _buildControls(RecordingState status) {
    if (status == RecordingState.initializing) {
      return const SizedBox(
        height: 64,
        child: Center(
          child: Text(
            'Initializing…',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final pauseOrResume = status == RecordingState.paused
        ? ElevatedButton.icon(
            onPressed: () =>
                ref.read(workoutSessionProvider.notifier).resumeWorkout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff18b0e8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            icon: const Icon(Icons.play_arrow, size: 26),
            label: const Text(
              'RESUME',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          )
        : ElevatedButton.icon(
            onPressed: () =>
                ref.read(workoutSessionProvider.notifier).pauseWorkout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            icon: const Icon(Icons.pause, size: 26),
            label: const Text(
              'PAUSE',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          );

    return Row(
      children: [
        Expanded(child: SizedBox(height: 60, child: pauseOrResume)),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _confirmStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              icon: const Icon(Icons.stop, size: 26),
              label: const Text(
                'STOP',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _modeBadgeText(String mode) {
    switch (mode) {
      case kOutdoorMode:
        return '🛰️ GPS Tracking';
      case kIndoorMode:
        return '🏃 Step Tracking';
      default:
        return '🔍 Detecting…';
    }
  }

  IconData _activityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.fitness_center;
    }
  }
}

// ─── Stat widgets ─────────────────────────────────────────────────────────────

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final TextAlign align;
  const _BigStat({
    required this.label,
    required this.value,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: align,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          textAlign: align,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
          ),
        ),
      ],
    );
  }
}

class _MetricStat extends StatelessWidget {
  final String label;
  final String value;
  const _MetricStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
