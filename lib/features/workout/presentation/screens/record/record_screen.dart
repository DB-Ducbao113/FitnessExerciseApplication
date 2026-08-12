import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/summary/workout_summary_screen.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/locate_button.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_permission_sheet.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
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
  bool _isLockingStartupGps = false;
  bool _hasStartedWorkout = false;
  Future<Position?>? _startupGpsLockFuture;

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
    _startupGpsLockFuture = null;
    if (mounted) {
      setState(() {
        _isPreparingWorkout = true;
        _isLockingStartupGps = false;
        _hasStartedWorkout = false;
        _startupCountdown = _kStartupCountdownSeconds;
      });
    }

    final notifier = ref.read(workoutSessionProvider.notifier);
    try {
      if (widget.requireGps) {
        final locationService = ref.read(locationTrackingServiceProvider);
        await locationService.ensurePermissionsOrThrow();
        _startupGpsLockFuture = locationService.acquireStartupLock(
          activityType: widget.activityType,
          maxWait: null,
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
            heightCm: profile.heightCm,
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
        unawaited(_startAfterCountdown(notifier));
        return;
      }

      setState(() {
        _startupCountdown -= 1;
      });
    });
  }

  Future<void> _startAfterCountdown(WorkoutSessionNotifier notifier) async {
    if (!mounted || _hasStartedWorkout) return;
    setState(() {
      _startupCountdown = 0;
      _isLockingStartupGps = widget.requireGps;
    });

    final startupGpsLock = await (_startupGpsLockFuture ?? Future.value());
    if (!mounted || _hasStartedWorkout) return;

    if (widget.requireGps && startupGpsLock == null) {
      setState(() {
        _isLockingStartupGps = false;
      });
      _showStartError('gps_startup_lock_failed');
      return;
    }

    setState(() {
      _isPreparingWorkout = false;
      _isLockingStartupGps = false;
    });
    _hasStartedWorkout = true;
    notifier.startWorkout(widget.activityType, startupGpsLock: startupGpsLock);
  }

  Future<void> _ensureMotionPermissionOrThrow() async {
    final permission = Theme.of(context).platform == TargetPlatform.iOS
        ? Permission.sensors
        : Permission.activityRecognition;
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return;

    if (!mounted ||
        !await showAetronPermissionSheet(
          context,
          kind: AetronPermissionKind.motion,
        )) {
      throw Exception('activity_permission_denied');
    }

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
      case 'gps_startup_lock_failed':
        title = 'GPS Signal Needed';
        message =
            'Move to a more open area so the app can lock your current GPS position before recording.';
        actionLabel = 'Try Again';
        onAction = () async {
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

  void _handlePauseResume(RecordingState status) {
    final notifier = ref.read(workoutSessionProvider.notifier);
    if (status == RecordingState.paused) {
      notifier.resumeWorkout();
      return;
    }
    if (status == RecordingState.active) {
      notifier.pauseWorkout();
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
          movingTimeSeconds: finalState.movingTimeSeconds,
          distanceMeters: finalState.distanceMeters,
          avgSpeedKmh: finalState.avgSpeedKmh,
          calories: finalState.caloriesBurned,
          steps: finalState.stepCount,
          gpsAnalysis: finalState.gpsAnalysis,
          routePoints: finalState.filteredRoutePoints.isNotEmpty
              ? finalState.filteredRoutePoints
              : (finalState.smoothedRoutePoints.isNotEmpty
                    ? finalState.smoothedRoutePoints
                    : finalState.routePoints),
          routeSegments: finalState.smoothedRouteSegments.isNotEmpty
              ? finalState.smoothedRouteSegments
              : finalState.routeSegments,
          lapSplits: finalState.lapSplits,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final state = ref.watch(workoutSessionProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final distanceKm = state.distanceMeters / 1000.0;
    final avgPace = WorkoutFormatters.formatPaceFromSpeedKmh(
      state.avgSpeedKmh,
      useMetric: useMetricUnits,
    );
    final movingPace = WorkoutFormatters.formatPaceFromDistanceAndDuration(
      distanceKm: distanceKm,
      durationSec: state.movingTimeSeconds,
      useMetric: useMetricUnits,
    );

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
                                AppTranslations.get(widget.activityType, currentLang).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _modeBadgeText(state.trackingMode, currentLang),
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
                if (!isExpandedSheet) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 22,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        MediaQuery.of(context).padding.bottom + 12,
                      ),
                      children: [
                        _CompactRecordingHud(
                          state: state,
                          activityIcon: _activityIcon(widget.activityType),
                          useMetricUnits: useMetricUnits,
                          avgPace: avgPace,
                          onPauseResume: () => _handlePauseResume(state.status),
                          onStop: _confirmStop,
                        ),
                      ],
                    ),
                  );
                }

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
                      _SectionLabel(AppTranslations.get('overview', currentLang)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppTranslations.get(widget.activityType, currentLang).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _modeBadgeText(state.trackingMode, currentLang),
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
                              _statusText(state, currentLang),
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
                      _SectionLabel(AppTranslations.get('core_stats', currentLang)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureStatCard(
                              label: AppTranslations.get('duration', currentLang).toUpperCase(),
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
                              label: AppTranslations.get('distance', currentLang).toUpperCase(),
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
                      _SectionLabel(AppTranslations.get('performance', currentLang)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureStatCard(
                              label: AppTranslations.get('best_pace', currentLang).toUpperCase(),
                              value: avgPace,
                              accent: const Color(0xfff8c15c),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureStatCard(
                              label: AppTranslations.get('moving_pace', currentLang).toUpperCase(),
                              value: movingPace,
                              accent: const Color(0xff7df9a8),
                              align: CrossAxisAlignment.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureStatCard(
                              label: AppTranslations.get('moving_time', currentLang).toUpperCase(),
                              value: WorkoutFormatters.formatElapsedClock(
                                state.movingTimeSeconds,
                              ),
                              accent: _kNeonCyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureStatCard(
                              label: AppTranslations.get('calories', currentLang).toUpperCase(),
                              value: '${state.caloriesBurned} kcal',
                              accent: const Color(0xffff8ca1),
                              align: CrossAxisAlignment.end,
                            ),
                          ),
                        ],
                      ),
                      if (state.lapSplits.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _SectionLabel(AppTranslations.get('latest_split', currentLang)),
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
                            _startupCountdown > 0
                                ? '$_startupCountdown'
                                : _isLockingStartupGps
                                ? ''
                                : 'GO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                            ),
                          ),
                          if (_isLockingStartupGps) ...[
                            const SizedBox(height: 2),
                            const SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: _kNeonCyan,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            _isLockingStartupGps
                                ? 'Locking your GPS position'
                                : 'Getting your current GPS position',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLockingStartupGps
                                ? 'Recording starts once the location is accurate'
                                : 'Recording will start in a moment',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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

  String _modeBadgeText(String mode, AppLanguage lang) {
    switch (mode) {
      case kOutdoorMode:
        return lang == AppLanguage.vi ? 'Theo dõi GPS' : 'GPS Tracking';
      case kIndoorMode:
        return lang == AppLanguage.vi ? 'Đếm bước chân' : 'Step Tracking';
      default:
        return lang == AppLanguage.vi ? 'Đang theo dõi' : 'Tracking';
    }
  }

  String _statusText(WorkoutSessionState state, AppLanguage lang) {
    if (state.status == RecordingState.paused) return AppTranslations.get('paused', lang);
    if (state.status == RecordingState.stopping) return AppTranslations.get('saving', lang);
    if (state.status == RecordingState.finished) return AppTranslations.get('finish', lang);
    if (state.isAutoPaused) return AppTranslations.get('auto_pause', lang);
    if (state.trackingMode == kIndoorMode) return lang == AppLanguage.vi ? 'Trong nhà' : 'Indoor';
    if (state.trackingMode == kOutdoorMode) return lang == AppLanguage.vi ? 'Ngoài trời' : 'Outdoor';
    return lang == AppLanguage.vi ? 'Đang theo dõi' : 'Tracking';
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AetronColors.space.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AetronColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: align == CrossAxisAlignment.end
                ? TextAlign.right
                : TextAlign.left,
            style: TextStyle(
              color: Colors.white,
              fontSize: isHero ? 28 : 20,
              fontWeight: FontWeight.w900,
              letterSpacing: isHero ? -1.2 : -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRecordingHud extends ConsumerWidget {
  const _CompactRecordingHud({
    required this.state,
    required this.activityIcon,
    required this.useMetricUnits,
    required this.avgPace,
    required this.onPauseResume,
    required this.onStop,
  });

  final WorkoutSessionState state;
  final IconData activityIcon;
  final bool useMetricUnits;
  final String avgPace;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final canToggle =
        state.status == RecordingState.active ||
        state.status == RecordingState.paused;
    final isPaused = state.status == RecordingState.paused;
    final isSaving = state.status == RecordingState.stopping;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AetronColors.space.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.14),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RecordingStatusDot(label: _statusLabel(state, currentLang)),
              const Spacer(),
              Icon(
                Icons.bolt_rounded,
                color: AetronColors.cyan,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                'AETRON LIVE',
                style: AetronTypography.caption.copyWith(
                  color: AetronColors.cyanSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppTranslations.get('session_time', currentLang).toUpperCase(),
            style: AetronTypography.caption.copyWith(
              color: AetronColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    WorkoutFormatters.formatElapsedClock(state.durationSeconds),
                    maxLines: 1,
                    style: const TextStyle(
                      color: AetronColors.cyanSoft,
                      fontSize: 44,
                      height: 0.98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      shadows: [
                        Shadow(
                          color: AetronColors.cyan,
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                ),
                child: Icon(
                  activityIcon,
                  color: AetronColors.cyanSoft,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactMetric(
                  icon: Icons.route_rounded,
                  label: AppTranslations.get('dist', currentLang),
                  value: WorkoutFormatters.formatDistance(
                    state.distanceMeters / 1000,
                    useMetric: useMetricUnits,
                    decimals: 1,
                  ),
                ),
              ),
              Expanded(
                child: _CompactMetric(
                  icon: Icons.speed_rounded,
                  label: AppTranslations.get('pace', currentLang).toUpperCase(),
                  value: avgPace,
                ),
              ),
              Expanded(
                child: _CompactMetric(
                  icon: Icons.local_fire_department_rounded,
                  label: AppTranslations.get('calories', currentLang).substring(0, 3).toUpperCase(),
                  value: '${state.caloriesBurned} kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: canToggle && !isSaving ? onPauseResume : null,
                    icon: Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 16,
                    ),
                    label: Text(isPaused
                        ? AppTranslations.get('resume', currentLang).toUpperCase()
                        : AppTranslations.get('pause', currentLang).toUpperCase()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AetronColors.cyan.withValues(
                        alpha: 0.14,
                      ),
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.05,
                      ),
                      foregroundColor: AetronColors.cyan,
                      disabledForegroundColor: AetronColors.muted,
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: AetronColors.cyan.withValues(alpha: 0.38),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 40,
                child: ElevatedButton(
                  onPressed: isSaving ? null : onStop,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xff2d2028),
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.05,
                    ),
                    foregroundColor: const Color(0xffffa0a8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: const Color(0xffffa0a8).withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AetronColors.muted,
                          ),
                        )
                      : const Icon(Icons.stop_rounded, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: null,
              minHeight: 3,
              backgroundColor: AetronColors.panelBright.withValues(alpha: 0.46),
              valueColor: AlwaysStoppedAnimation<Color>(
                isPaused ? AetronColors.gold : AetronColors.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(WorkoutSessionState state, AppLanguage lang) {
    if (state.status == RecordingState.paused) return AppTranslations.get('paused', lang).toUpperCase();
    if (state.status == RecordingState.stopping) return AppTranslations.get('saving', lang).toUpperCase();
    if (state.isAutoPaused) return AppTranslations.get('auto_pause', lang).toUpperCase();
    return AppTranslations.get('recording', lang).toUpperCase();
  }
}

class _RecordingStatusDot extends StatelessWidget {
  const _RecordingStatusDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = label == 'PAUSED' ? AetronColors.gold : AetronColors.cyan;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AetronText.label.copyWith(
            color: AetronColors.cyanSoft,
            fontSize: 9,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AetronColors.muted, size: 11),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AetronText.label.copyWith(
                    fontSize: 8,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AetronColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
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
