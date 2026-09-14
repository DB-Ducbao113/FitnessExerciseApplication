import 'dart:async';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_target_selector_sheet.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityOption {
  final String type;
  final String nameKey;
  final String descKey;
  final String imagePath;
  final IconData icon;
  final Color accentColor;
  final bool requireGps;

  const ActivityOption({
    required this.type,
    required this.nameKey,
    required this.descKey,
    required this.imagePath,
    required this.icon,
    required this.accentColor,
    required this.requireGps,
  });
}

const _kActivities = [
  ActivityOption(
    type: 'running',
    nameKey: 'running',
    descKey: 'running_desc',
    imagePath: 'assets/running_real.jpg',
    icon: Icons.directions_run_rounded,
    accentColor: AetronColors.cyan,
    requireGps: true,
  ),
  ActivityOption(
    type: 'cycling',
    nameKey: 'cycling',
    descKey: 'cycling_desc',
    imagePath: 'assets/cycling_real.jpg',
    icon: Icons.directions_bike_rounded,
    accentColor: AetronColors.blue,
    requireGps: true,
  ),
  ActivityOption(
    type: 'walking',
    nameKey: 'walking',
    descKey: 'walking_desc',
    imagePath: 'assets/walking_real.jpg',
    icon: Icons.directions_walk_rounded,
    accentColor: AetronColors.mint,
    requireGps: false,
  ),
];

/// 1. MAIN ACTIVITY SCREEN: MODE SELECTION HUB
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.get('select_activity_mode', currentLang),
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
                          AppTranslations.get('nav_activity', currentLang),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AetronColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Activity Modes Realistic Scenic Cards List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _kActivities.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final activity = _kActivities[index];
                  return _ActivityMode3DCard(
                    activity: activity,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ActivityDetailScreen(activity: activity),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// REALISTIC SCENIC ACTIVITY CARD IN SELECTION HUB
class _ActivityMode3DCard extends ConsumerWidget {
  final ActivityOption activity;
  final VoidCallback onTap;

  const _ActivityMode3DCard({
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final activityName = AppTranslations.get(activity.nameKey, currentLang);
    final activityDesc = AppTranslations.get(activity.descKey, currentLang);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 175,
          decoration: BoxDecoration(
            color: const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: activity.accentColor.withValues(alpha: 0.40),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: activity.accentColor.withValues(alpha: 0.15),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Realistic Scenic Athlete Photography
                Image.asset(
                  activity.imagePath,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      activity.icon,
                      size: 72,
                      color: activity.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),

                // 2. High-Contrast Obsidian Gradient Overlay
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF070B14),
                        const Color(0xFF070B14).withValues(alpha: 0.95),
                        const Color(0xFF070B14).withValues(alpha: 0.60),
                        const Color(0xFF070B14).withValues(alpha: 0.10),
                      ],
                      stops: const [0.0, 0.42, 0.68, 1.0],
                    ),
                  ),
                ),

                // 3. Accent Glow Overlay
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        activity.accentColor.withValues(alpha: 0.18),
                        Colors.transparent,
                        activity.accentColor.withValues(alpha: 0.08),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),

                // 4. Card Text & Information (Left side)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070B14).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: activity.accentColor.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: activity.accentColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              activity.icon,
                              size: 12,
                              color: activity.accentColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              activity.requireGps
                                  ? AppTranslations.get('gps_required', currentLang)
                                  : AppTranslations.get('gps_optional', currentLang),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: activity.accentColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        activityName.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 180,
                        child: Text(
                          activityDesc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: AetronColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            AppTranslations.get('start_mode', currentLang),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: activity.accentColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: activity.accentColor,
                          ),
                        ],
                      ),
                    ],
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

/// 2. DEDICATED PRE-WORKOUT & GPS PREPARATION SCREEN
class ActivityDetailScreen extends ConsumerStatefulWidget {
  final ActivityOption activity;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
  });

  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen>
    with WidgetsBindingObserver {
  bool _gpsEnabled = false;
  bool _checkingLocation = true;
  LocationPermission _permission = LocationPermission.denied;
  LatLng? _currentLocation;
  int _recenterRequestId = 0;
  WorkoutTarget _selectedTarget = WorkoutTarget.free;
  StreamSubscription<Position>? _positionSubscription;

  bool get _hasLocationPermission =>
      _permission == LocationPermission.always ||
      _permission == LocationPermission.whileInUse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationStatus(requestIfNeeded: true);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationStatus(requestIfNeeded: false);
    }
  }

  void _startPositionStream() {
    _positionSubscription?.cancel();
    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        ),
      ).listen(
        (position) {
          if (!mounted) return;
          final latLng = LatLng(position.latitude, position.longitude);
          final wasNull = _currentLocation == null;
          setState(() {
            _currentLocation = latLng;
            _gpsEnabled = true;
            _permission = LocationPermission.whileInUse;
            _checkingLocation = false;
            if (wasNull) {
              _recenterRequestId += 1;
            }
          });
        },
        onError: (err) {
          debugPrint('[ActivityDetailScreen] GPS stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('[ActivityDetailScreen] Error starting position stream: $e');
    }
  }

  Future<void> _refreshLocationStatus({bool requestIfNeeded = false}) async {
    setState(() => _checkingLocation = true);

    final gpsEnabled = kIsWeb ? true : await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestIfNeeded) {
      try {
        permission = await Geolocator.requestPermission();
      } catch (_) {}
    }

    LatLng? nextLocation = _currentLocation;

    if (gpsEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)) {
      _startPositionStream();
      nextLocation = await _getBestKnownLocation();
    }

    if (!mounted) return;
    setState(() {
      _gpsEnabled = gpsEnabled;
      _permission = permission;
      if (nextLocation != null) {
        _currentLocation = nextLocation;
      }
      _checkingLocation = false;
      if (nextLocation != null) {
        _recenterRequestId += 1;
      }
    });
  }

  Future<LatLng?> _getBestKnownLocation() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 4),
        ),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (lastKnown != null) return lastKnown;
          throw TimeoutException('location_timeout');
        },
      );
      return LatLng(current.latitude, current.longitude);
    } catch (_) {
      try {
        final fallback = await Geolocator.getLastKnownPosition();
        if (fallback == null) return null;
        return LatLng(fallback.latitude, fallback.longitude);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _handleLocateTap() async {
    HapticFeedback.lightImpact();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!kIsWeb && permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
      if (mounted) {
        final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Vui lòng cấp quyền truy cập vị trí để định vị GPS'
                  : 'Please enable location permission to locate GPS',
            ),
          ),
        );
      }
      return;
    }

    _startPositionStream();

    if (_currentLocation != null) {
      setState(() => _recenterRequestId += 1);
    } else {
      setState(() => _checkingLocation = true);
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 6),
        ),
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _gpsEnabled = true;
          _permission = permission;
          _checkingLocation = false;
          _recenterRequestId += 1;
        });
      }
    } catch (e) {
      debugPrint('[ActivityDetailScreen] locate error: $e');
      if (mounted) {
        setState(() => _checkingLocation = false);
        if (_currentLocation == null) {
          final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isVi
                    ? 'Đang tìm kiếm tín hiệu GPS...'
                    : 'Acquiring GPS signal...',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLocationAction() async {
    if (!_gpsEnabled && !kIsWeb) {
      await Geolocator.openLocationSettings();
      await _refreshLocationStatus();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever && !kIsWeb) {
      await Geolocator.openAppSettings();
    }

    await _refreshLocationStatus();
  }

  Future<void> _openTargetSelector(AppLanguage currentLang) async {
    final target = await WorkoutTargetSelectorSheet.show(
      context,
      initialTarget: _selectedTarget,
      currentLang: currentLang,
      accentColor: widget.activity.accentColor,
    );
    if (target != null && mounted) {
      setState(() => _selectedTarget = target);
    }
  }

  void _startWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          activityType: widget.activity.type,
          requireGps: widget.activity.requireGps,
          workoutTarget: _selectedTarget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final activityName = AppTranslations.get(widget.activity.nameKey, currentLang);
    final isGpsReady = _gpsEnabled && _hasLocationPermission && _currentLocation != null;
    final accent = widget.activity.accentColor;

    final avatar = ref.watch(currentAvatarDisplayProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final ImageProvider? avatarImage = avatar.imageProvider;
    final initials = user?.email?.isNotEmpty == true
        ? user!.email!.substring(0, 1).toUpperCase()
        : 'A';

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: Stack(
        children: [
          // 1. FULL-SCREEN IMMERSIVE MAP
          Positioned.fill(
            child: TrackingMapWidget(
              routePoints: const [],
              activityType: widget.activity.type,
              initialPosition: _currentLocation,
              currentLocation: _currentLocation,
              followUser: true,
              recenterRequestId: _recenterRequestId,
              showRoute: false,
              avatarImage: avatarImage,
              initials: initials,
              currentLang: currentLang,
              topControlOffset: 120.0,
            ),
          ),

          // Top Horizon Gradient for visual contrast
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Vignette Gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 240,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.40),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. TOP FLOATING NAVIGATION & GPS TELEMETRY BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Back Glass Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0D1424).withValues(alpha: 0.85),
                            border: Border.all(
                              color: AetronColors.borderSubtle,
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AetronColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Activity Title Capsule
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1424).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.activity.icon, color: accent, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                activityName.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AetronColors.textPrimary,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // GPS Satellite Diagnostic Pill
                    GestureDetector(
                      onTap: _handleLocationAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1424).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: (isGpsReady ? AetronColors.mint : AetronColors.gold)
                                .withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isGpsReady ? AetronColors.mint : AetronColors.gold)
                                  .withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_checkingLocation) ...[
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AetronColors.cyan,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVi ? 'KẾT NỐI...' : 'LOCATING...',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AetronColors.cyan,
                                ),
                              ),
                            ] else ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isGpsReady ? AetronColors.mint : AetronColors.gold,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isGpsReady ? AetronColors.mint : AetronColors.gold,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isGpsReady
                                    ? 'GPS READY'
                                    : (isVi ? 'BẬT GPS' : 'FIX GPS'),
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isGpsReady ? AetronColors.mint : AetronColors.gold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. FLOATING RECENTER GPS BUTTON (Middle Right)
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 215,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleLocateTap,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D1424).withValues(alpha: 0.90),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.my_location_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // 4. FLOATING CYBER LAUNCH COCKPIT DOCK (Bottom)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1424).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: accent.withValues(alpha: 0.4),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Target Goal Title & Customizer Trigger
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.track_changes_rounded, color: accent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            isVi ? 'MỤC TIÊU BUỔI TẬP' : 'SESSION TARGET',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _openTargetSelector(currentLang),
                        child: Text(
                          _selectedTarget.getDisplayTitle(currentLang),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AetronColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Horizontal Quick Target Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildQuickChip(
                          label: isVi ? 'Tự do' : 'Free',
                          isSelected: _selectedTarget.type == WorkoutTargetType.none,
                          accent: accent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTarget = WorkoutTarget.free);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: '3 km',
                          isSelected: _selectedTarget.type == WorkoutTargetType.distance &&
                              _selectedTarget.value == 3.0,
                          accent: accent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTarget = const WorkoutTarget(
                                  type: WorkoutTargetType.distance,
                                  value: 3.0,
                                ));
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: '5 km',
                          isSelected: _selectedTarget.type == WorkoutTargetType.distance &&
                              _selectedTarget.value == 5.0,
                          accent: accent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTarget = const WorkoutTarget(
                                  type: WorkoutTargetType.distance,
                                  value: 5.0,
                                ));
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: '10 km',
                          isSelected: _selectedTarget.type == WorkoutTargetType.distance &&
                              _selectedTarget.value == 10.0,
                          accent: accent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTarget = const WorkoutTarget(
                                  type: WorkoutTargetType.distance,
                                  value: 10.0,
                                ));
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: isVi ? '30 phút' : '30 min',
                          isSelected: _selectedTarget.type == WorkoutTargetType.duration &&
                              _selectedTarget.value == 30.0,
                          accent: accent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTarget = const WorkoutTarget(
                                  type: WorkoutTargetType.duration,
                                  value: 30.0,
                                ));
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: '300 kcal',
                          isSelected: _selectedTarget.type == WorkoutTargetType.calories &&
                              _selectedTarget.value == 300.0,
                          accent: accent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTarget = const WorkoutTarget(
                                  type: WorkoutTargetType.calories,
                                  value: 300.0,
                                ));
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                          label: isVi ? '+ Khác' : '+ More',
                          isSelected: false,
                          accent: accent,
                          onTap: () => _openTargetSelector(currentLang),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Row 3: PRIMARY 3D START WORKOUT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _startWorkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        elevation: 10,
                        shadowColor: accent.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            isVi ? 'BẮT ĐẦU BUỔI TẬP' : 'START WORKOUT',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.22) : const Color(0xFF070B14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent : AetronColors.borderSubtle,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? accent : AetronColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
