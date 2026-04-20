import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/locate_button.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/summary/workout_summary_screen.dart';
import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

const _kBgTop = Color(0xff0a0e1a);
const _kPanelBg = Color(0xee121b2c);
const _kPanelBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);

class RecordScreen extends ConsumerStatefulWidget {
  final String activityType;
  final bool requireGps;

  const RecordScreen({
    super.key,
    required this.activityType,
    this.requireGps = true,
  });

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  String? _navigatedSessionId;
  static const double _kSheetMinSize = 0.22;
  static const double _kSheetInitialSize = 0.28;
  static const double _kSheetMaxSize = 1.0;
  static const double _kLocateHideThreshold = 0.7;
  static const double _kExpandedSheetThreshold = 0.84;
  static const int _kStartupCountdownSeconds = 3;
  double _sheetExtent = _kSheetInitialSize;
  Timer? _startupCountdownTimer;
  int _startupCountdown = _kStartupCountdownSeconds;
  bool _isPreparingWorkout = true;
  bool _hasStartedWorkout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWorkout());
  }

  @override
  void dispose() {
    _startupCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startWorkout() async {
    _startupCountdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPreparingWorkout = true;
        _startupCountdown = _kStartupCountdownSeconds;
      });
    }

    final notifier = ref.read(workoutSessionProvider.notifier);
    try {
      if (widget.requireGps) {
        final locationService = ref.read(locationTrackingServiceProvider);
        await locationService.ensurePermissionsOrThrow();
        final lastKnown = await locationService.getLastKnownPosition();
        unawaited(
          locationService.getCurrentPositionWithTimeout(
            fallback: lastKnown,
            timeout: const Duration(seconds: _kStartupCountdownSeconds),
          ),
        );
      }
      // Motion permission is required for both indoor workouts and
      // GPS activities that may fall back to step tracking.
      await _ensureMotionPermissionOrThrow();
    } catch (e) {
      if (mounted) {
        _showStartError(e.toString().replaceAll('Exception: ', ''));
      }
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      try {
        final profile = await ref.read(userProfileProvider(userId).future);
        if (profile != null) {
          notifier.setUserProfile(
            weightKg: profile.weightKg,
            heightCm: profile.heightM * 100,
            gender: profile.gender,
          );
        }
      } catch (_) {
        // Fall back to default stride/weight when profile is temporarily unavailable.
      }
    }

    _startupCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_startupCountdown <= 1) {
        timer.cancel();
        setState(() {
          _startupCountdown = 0;
          _isPreparingWorkout = false;
        });
        if (!_hasStartedWorkout) {
          _hasStartedWorkout = true;
          notifier.startWorkout(widget.activityType);
        }
        return;
      }

      setState(() {
        _startupCountdown -= 1;
      });
    });
  }

  Future<void> _ensureMotionPermissionOrThrow() async {
    final permission = Theme.of(context).platform == TargetPlatform.iOS
        ? Permission.sensors
        : Permission.activityRecognition;
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return;

    final requested = await permission.request();
    if (requested.isGranted || requested.isLimited) return;
    if (requested.isPermanentlyDenied || requested.isRestricted) {
      throw Exception('activity_permission_denied_forever');
    }
    throw Exception('activity_permission_denied');
  }

  void _showStartError(String code) {
    String title;
    String message;
    String actionLabel;
    Future<void> Function() onAction;

    switch (code) {
      case 'location_disabled':
        title = 'GPS is Off';
        message =
            'Location services are disabled. Please enable GPS and try again.';
        actionLabel = 'Open Settings';
        onAction = () async {
          await Geolocator.openLocationSettings();
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      case 'permission_denied':
        title = 'Location Permission Needed';
        message =
            'Location permission is required to track your workout. Open Settings and allow location access.';
        actionLabel = 'Open Settings';
        onAction = () async {
          await Geolocator.openAppSettings();
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      case 'permission_denied_forever':
        title = 'Permission Blocked';
        message =
            'Location is permanently blocked. Open App Settings > Permissions > Location.';
        actionLabel = 'Open Settings';
        onAction = () async {
          await Geolocator.openAppSettings();
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      case 'activity_permission_denied':
        title = 'Motion Permission Needed';
        message =
            'Motion access is needed so indoor fallback can count your steps when GPS is weak.';
        actionLabel = 'Open Settings';
        onAction = () async {
          await openAppSettings();
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      case 'activity_permission_denied_forever':
        title = 'Motion Permission Blocked';
        message =
            'Motion access is blocked. Open Settings and allow Motion & Fitness so indoor tracking can update in real time.';
        actionLabel = 'Open Settings';
        onAction = () async {
          await openAppSettings();
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      default:
        title = 'Could Not Start';
        message = code;
        actionLabel = 'Back';
        onAction = () async {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        };
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff0f1726),
        title: Text(title),
        content: Text(message, style: const TextStyle(color: _kMutedText)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel', style: TextStyle(color: _kMutedText)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await onAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNeonCyan,
              foregroundColor: _kBgTop,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _onLocatePressed() {
    final didRequest = ref
        .read(workoutSessionProvider.notifier)
        .requestRecenter();
    if (didRequest) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Waiting for GPS fix...')));
  }

  Future<void> _confirmStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff0f1726),
        title: const Text('Finish Workout?'),
        content: const Text(
          'Are you sure you want to end this session?',
          style: TextStyle(color: _kMutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kMutedText)),
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
      await ref.read(workoutSessionProvider.notifier).stopWorkout();
    }
  }

  void _openSummary(WorkoutSessionState finalState) {
    final sessionId = finalState.sessionId;
    if (!mounted || sessionId == null || sessionId.isEmpty) return;
    if (_navigatedSessionId == sessionId) return;
    _navigatedSessionId = sessionId;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          sessionId: sessionId,
          activityType: finalState.activityType,
          trackingMode: finalState.trackingMode,
          durationSeconds: finalState.durationSeconds,
          distanceMeters: finalState.distanceMeters,
          avgSpeedKmh: finalState.avgSpeedKmh,
          calories: finalState.caloriesBurned,
          gpsAnalysis: finalState.gpsAnalysis,
          routePoints: finalState.routePoints,
          routeSegments: finalState.routeSegments,
          lapSplits: finalState.lapSplits,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutSessionProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    ref.listen<WorkoutSessionState>(workoutSessionProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _showStartError(next.errorMessage!);
      }
      final didFinishSession =
          next.status == RecordingState.finished &&
          (next.sessionId ?? '').isNotEmpty &&
          prev?.status != RecordingState.finished;
      if (didFinishSession) {
        _openSummary(next);
      }
    });

    final shouldShowGpsRoute =
        state.routePoints.length >= 2 || state.trackingMode != kIndoorMode;
    final isExpandedSheet = _sheetExtent >= _kExpandedSheetThreshold;

    return Scaffold(
      backgroundColor: _kBgTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: TrackingMapWidget(
              routePoints: state.smoothedRoutePoints.isNotEmpty
                  ? state.smoothedRoutePoints
                  : state.routePoints,
              routeSegments: state.smoothedRouteSegments.isNotEmpty
                  ? state.smoothedRouteSegments
                  : state.routeSegments,
              activityType: widget.activityType,
              initialPosition: state.initialPosition,
              currentLocation:
                  state.smoothedCurrentLatLng ?? state.currentLatLng,
              gpsGapMarker: state.gpsGapMarker,
              gpsGapSegments: state.gpsGapSegments,
              isGpsSignalWeak: state.isGpsSignalWeak,
              followUser: state.followUser,
              recenterRequestId: state.recenterRequestId,
              showRoute: shouldShowGpsRoute,
              onUserGesturePan: () {
                ref.read(workoutSessionProvider.notifier).onUserDraggedMap();
              },
            ),
          ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kPanelBg,
                        border: Border.all(color: _kPanelBorder),
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
                            color: _kNeonCyan,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.activityType.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _modeBadgeText(state.trackingMode),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _kMutedText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
          if (_sheetExtent < _kLocateHideThreshold)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 220,
              child: LocateButton(
                isFollowEnabled: state.followUser,
                onPressed: _onLocatePressed,
              ),
            ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              final extent = notification.extent;
              if ((extent - _sheetExtent).abs() > 0.01 && mounted) {
                setState(() => _sheetExtent = extent);
              }
              return false;
            },
            child: DraggableScrollableSheet(
              minChildSize: _kSheetMinSize,
              initialChildSize: _kSheetInitialSize,
              maxChildSize: _kSheetMaxSize,
              snap: true,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: _kPanelBg,
                    border: const Border(top: BorderSide(color: _kPanelBorder)),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(isExpandedSheet ? 0 : 28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      isExpandedSheet
                          ? MediaQuery.of(context).padding.top + 12
                          : 12,
                      20,
                      20,
                    ),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionLabel('Session'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.activityType.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _modeBadgeText(state.trackingMode),
                                  style: const TextStyle(
                                    color: _kMutedText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _kPanelBorder),
                            ),
                            child: Text(
                              _statusText(state),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('Core Stats'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureStatCard(
                              label: 'TIME',
                              value: WorkoutFormatters.formatElapsedClock(
                                state.durationSeconds,
                              ),
                              accent: _kNeonCyan,
                              isHero: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureStatCard(
                              label: 'DISTANCE',
                              value: WorkoutFormatters.formatDistance(
                                state.distanceMeters / 1000,
                                useMetric: useMetricUnits,
                                decimals: 2,
                              ),
                              accent: const Color(0xff7df9a8),
                              isHero: true,
                              align: CrossAxisAlignment.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SectionLabel('Performance'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureStatCard(
                              label: 'AVG PACE',
                              value: WorkoutFormatters.formatPaceFromSpeedKmh(
                                state.avgSpeedKmh,
                                useMetric: useMetricUnits,
                              ),
                              accent: const Color(0xfff8c15c),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureStatCard(
                              label: 'CALORIES',
                              value: '${state.caloriesBurned} kcal',
                              accent: const Color(0xffff8ca1),
                              align: CrossAxisAlignment.end,
                            ),
                          ),
                        ],
                      ),
                      if (state.lapSplits.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _SectionLabel('Latest Split'),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kPanelBorder),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'LATEST SPLIT',
                                style: TextStyle(
                                  color: _kMutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatSplit(
                                  state.lapSplits.last,
                                  useMetricUnits: useMetricUnits,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _SectionLabel('Controls'),
                      const SizedBox(height: 10),
                      _buildControls(state.status),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 8,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isPreparingWorkout)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.42),
                  child: Center(
                    child: Container(
                      width: 210,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 26,
                      ),
                      decoration: BoxDecoration(
                        color: _kPanelBg,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _kPanelBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _startupCountdown > 0 ? '$_startupCountdown' : 'GO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Getting your current GPS position',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Recording will start in a moment',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _kMutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(RecordingState status) {
    if (status == RecordingState.initializing) {
      return const SizedBox(
        height: 64,
        child: Center(
          child: Text(
            'Initializing...',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (status == RecordingState.stopping) {
      return const SizedBox(
        height: 64,
        child: Center(
          child: Text(
            'Saving workout...',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final pauseOrResume = status == RecordingState.paused
        ? ElevatedButton.icon(
            onPressed: () =>
                ref.read(workoutSessionProvider.notifier).resumeWorkout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNeonCyan,
              foregroundColor: _kBgTop,
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (status == RecordingState.paused)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Auto finish in ${WorkoutFormatters.formatElapsedClock(ref.watch(workoutSessionProvider).pausedAutoStopRemainingSeconds)}',
              style: const TextStyle(
                color: _kMutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Row(
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
        ),
      ],
    );
  }

  String _formatSplit(WorkoutLapSplit split, {required bool useMetricUnits}) {
    return '${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase()} ${split.index} · ${WorkoutFormatters.formatElapsedClock(split.durationSeconds)} · ${WorkoutFormatters.formatSplitPace(split.paceMinPerKm, useMetric: useMetricUnits)}';
  }

  String _modeBadgeText(String mode) {
    switch (mode) {
      case kOutdoorMode:
        return 'GPS Tracking';
      case kIndoorMode:
        return 'Step Tracking';
      default:
        return 'Tracking';
    }
  }

  String _statusText(WorkoutSessionState state) {
    if (state.status == RecordingState.paused) return 'Paused';
    if (state.status == RecordingState.stopping) return 'Saving';
    if (state.status == RecordingState.finished) return 'Finished';
    if (state.isAutoPaused) return 'Auto Pause';
    if (state.trackingMode == kIndoorMode) return 'Indoor';
    if (state.trackingMode == kOutdoorMode) return 'Outdoor';
    return 'Tracking';
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

class _FeatureStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final bool isHero;
  final CrossAxisAlignment align;

  const _FeatureStatCard({
    required this.label,
    required this.value,
    required this.accent,
    this.isHero = false,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: align == CrossAxisAlignment.end
                ? TextAlign.right
                : TextAlign.left,
            style: TextStyle(
              color: Colors.white,
              fontSize: isHero ? 24 : 18,
              fontWeight: FontWeight.w900,
              letterSpacing: isHero ? -1.0 : -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _kMutedText,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    );
  }
}
