import 'dart:async';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
    imagePath: 'assets/running_3d.png',
    icon: Icons.directions_run_rounded,
    accentColor: AetronColors.cyan,
    requireGps: true,
  ),
  ActivityOption(
    type: 'cycling',
    nameKey: 'cycling',
    descKey: 'cycling_desc',
    imagePath: 'assets/cycling_3d.png',
    icon: Icons.directions_bike_rounded,
    accentColor: AetronColors.blue,
    requireGps: true,
  ),
  ActivityOption(
    type: 'walking',
    nameKey: 'walking',
    descKey: 'walking_desc',
    imagePath: 'assets/walking_3d.png',
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

            // Activity Modes 3D Cards List
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

/// 3D ACTIVITY CARD IN SELECTION HUB
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 165,
        decoration: BoxDecoration(
          color: AetronColors.panelHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: activity.accentColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: activity.accentColor.withValues(alpha: 0.10),
              blurRadius: 14,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Radial Glow Backdrop
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        activity.accentColor.withValues(alpha: 0.22),
                        activity.accentColor.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // 3D Character Image (Right aligned)
              Positioned(
                right: -10,
                top: -10,
                bottom: -10,
                width: 170,
                child: Image.asset(
                  activity.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      activity.icon,
                      size: 72,
                      color: activity.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),

              // Card Text & Information (Left side)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: activity.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: activity.accentColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
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
                        width: 170,
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

  bool get _hasLocationPermission =>
      _permission == LocationPermission.always ||
      _permission == LocationPermission.whileInUse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationStatus();
    }
  }

  Future<void> _refreshLocationStatus() async {
    setState(() => _checkingLocation = true);

    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    LatLng? nextLocation = _currentLocation;

    if (gpsEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)) {
      nextLocation = await _getBestKnownLocation();
    }

    if (!mounted) return;
    setState(() {
      _gpsEnabled = gpsEnabled;
      _permission = permission;
      _currentLocation = nextLocation;
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

  Future<void> _handleLocationAction() async {
    if (!_gpsEnabled) {
      await Geolocator.openLocationSettings();
      await _refreshLocationStatus();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }

    await _refreshLocationStatus();
  }

  void _startWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          activityType: widget.activity.type,
          requireGps: widget.activity.requireGps,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final activityName = AppTranslations.get(widget.activity.nameKey, currentLang);
    final isGpsReady = _gpsEnabled && _hasLocationPermission && _currentLocation != null;

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AetronColors.cyanSoft,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentLang == AppLanguage.vi ? 'CHUẨN BỊ BUỔI TẬP' : 'PRE-WORKOUT LAUNCH',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: widget.activity.accentColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activityName.toUpperCase(),
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
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  children: [
                    // 1. CLEAN 3D MODE INFOBAR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AetronColors.panelHigh,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: widget.activity.accentColor.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.activity.accentColor.withValues(alpha: 0.15),
                              border: Border.all(color: widget.activity.accentColor.withValues(alpha: 0.4)),
                            ),
                            child: Icon(widget.activity.icon, color: widget.activity.accentColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activityName.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AetronColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppTranslations.get(widget.activity.descKey, currentLang),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    color: AetronColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. GPS DIAGNOSTIC STATUS CARD
                    GestureDetector(
                      onTap: _handleLocationAction,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AetronColors.panelHigh,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: (isGpsReady ? AetronColors.mint : AetronColors.gold).withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isGpsReady ? AetronColors.mint : AetronColors.gold).withValues(alpha: 0.1),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isGpsReady ? AetronColors.mint : AetronColors.gold).withValues(alpha: 0.15),
                                border: Border.all(
                                  color: (isGpsReady ? AetronColors.mint : AetronColors.gold).withValues(alpha: 0.4),
                                ),
                              ),
                              child: _checkingLocation
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AetronColors.cyan,
                                      ),
                                    )
                                  : Icon(
                                      isGpsReady ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                                      color: isGpsReady ? AetronColors.mint : AetronColors.gold,
                                      size: 20,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isGpsReady
                                        ? AppTranslations.get('gps_ready_status', currentLang)
                                        : AppTranslations.get('gps_disabled_status', currentLang),
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: isGpsReady ? AetronColors.mint : AetronColors.gold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isGpsReady
                                        ? (currentLang == AppLanguage.vi ? 'Sẵn sàng ghi nhận lộ trình GPS' : 'Ready for real-time GPS telemetry')
                                        : AppTranslations.get('enable_gps_action', currentLang),
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 10,
                                      color: AetronColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isGpsReady)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AetronColors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.4)),
                                ),
                                child: const Text(
                                  'FIX GPS',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AetronColors.cyan,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. LIVE MAP CONTEXT PREVIEW
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AetronColors.panelHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.activity.accentColor.withValues(alpha: 0.3),
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              SizedBox.expand(
                                child: TrackingMapWidget(
                                  routePoints: const [],
                                  activityType: widget.activity.type,
                                  initialPosition: _currentLocation,
                                  currentLocation: _currentLocation,
                                  followUser: true,
                                  recenterRequestId: _recenterRequestId,
                                  showRoute: false,
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AetronColors.space.withValues(alpha: 0.90),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: widget.activity.accentColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.map_rounded,
                                        color: widget.activity.accentColor,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        AppTranslations.get('location_context', currentLang),
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 9,
                                          color: AetronColors.cyanSoft,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
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
                    ),
                    const SizedBox(height: 16),

                    // 4. PRIMARY 3D START WORKOUT BUTTON
                    Aetron3DPrimaryButton(
                      label: '${AppTranslations.get('start_workout', currentLang).toUpperCase()} ($activityName)',
                      icon: Icons.play_arrow_rounded,
                      onPressed: _startWorkout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
