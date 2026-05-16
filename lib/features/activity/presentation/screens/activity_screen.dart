import 'dart:async';

import 'package:fitness_exercise_application/features/workout/presentation/screens/workout_start_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const _kBgTop = Color(0xff0a0e1a);
const _kPanelBg = Color(0xee0f1726);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);
const _kNeonBlue = Color(0xff00bfff);
const _kWarning = Color(0xffffb85c);

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with WidgetsBindingObserver {
  static const _activities = [
    _ActivityOption(
      type: 'running',
      name: 'Running',
      imagePath: 'assets/running.jpg',
      icon: Icons.directions_run,
    ),
    _ActivityOption(
      type: 'cycling',
      name: 'Cycling',
      imagePath: 'assets/cycling.jpg',
      icon: Icons.directions_bike,
    ),
    _ActivityOption(
      type: 'walking',
      name: 'Walking',
      imagePath: 'assets/walking.jpg',
      icon: Icons.directions_walk,
    ),
  ];

  int _selectedIndex = 0;
  bool _gpsEnabled = false;
  bool _checkingLocation = true;
  LocationPermission _permission = LocationPermission.denied;
  LatLng? _currentLocation;
  int _recenterRequestId = 0;

  _ActivityOption get _selectedActivity => _activities[_selectedIndex];

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
      final current =
          await Geolocator.getCurrentPosition(
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
        builder: (_) => WorkoutStartScreen(
          activityType: _selectedActivity.type,
          activityName: _selectedActivity.name,
          activityImagePath: _selectedActivity.imagePath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: TrackingMapWidget(
              routePoints: const [],
              activityType: _selectedActivity.type,
              initialPosition: _currentLocation,
              currentLocation: _currentLocation,
              followUser: true,
              recenterRequestId: _recenterRequestId,
              showRoute: false,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ACTIVITY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _LocationBadge(
                      isChecking: _checkingLocation,
                      gpsEnabled: _gpsEnabled,
                      hasPermission: _hasLocationPermission,
                      hasLocation: _currentLocation != null,
                      onTap: _handleLocationAction,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _ActivityBottomPanel(
                activities: _activities,
                selectedIndex: _selectedIndex,
                selectedActivity: _selectedActivity,
                checkingLocation: _checkingLocation,
                gpsEnabled: _gpsEnabled,
                hasPermission: _hasLocationPermission,
                hasLocation: _currentLocation != null,
                onSelect: (index) => setState(() => _selectedIndex = index),
                onLocationAction: _handleLocationAction,
                onStart: _startWorkout,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityBottomPanel extends StatelessWidget {
  final List<_ActivityOption> activities;
  final int selectedIndex;
  final _ActivityOption selectedActivity;
  final bool checkingLocation;
  final bool gpsEnabled;
  final bool hasPermission;
  final bool hasLocation;
  final ValueChanged<int> onSelect;
  final VoidCallback onLocationAction;
  final VoidCallback onStart;

  const _ActivityBottomPanel({
    required this.activities,
    required this.selectedIndex,
    required this.selectedActivity,
    required this.checkingLocation,
    required this.gpsEnabled,
    required this.hasPermission,
    required this.hasLocation,
    required this.onSelect,
    required this.onLocationAction,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _kNeonCyan.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'READY TO MOVE',
                      style: TextStyle(
                        color: _kMutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      selectedActivity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _GpsStatusChip(
                checkingLocation: checkingLocation,
                gpsEnabled: gpsEnabled,
                hasPermission: hasPermission,
                hasLocation: hasLocation,
                onTap: onLocationAction,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < activities.length; i++) ...[
                Expanded(
                  child: _ActivityChoice(
                    activity: activities[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
                if (i != activities.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kNeonBlue, _kNeonCyan],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _kNeonCyan.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: const Text('START WORKOUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: _kBgTop,
                  shadowColor: Colors.transparent,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityChoice extends StatelessWidget {
  final _ActivityOption activity;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityChoice({
    required this.activity,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _kNeonCyan.withValues(alpha: 0.14)
              : _kCardBg.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _kNeonCyan : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              activity.icon,
              color: selected ? _kNeonCyan : Colors.white,
              size: 24,
            ),
            const SizedBox(height: 7),
            Text(
              activity.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : _kMutedText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  final bool isChecking;
  final bool gpsEnabled;
  final bool hasPermission;
  final bool hasLocation;
  final VoidCallback onTap;

  const _LocationBadge({
    required this.isChecking,
    required this.gpsEnabled,
    required this.hasPermission,
    required this.hasLocation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ready = gpsEnabled && hasPermission && hasLocation;
    final color = isChecking ? _kMutedText : (ready ? _kNeonCyan : _kWarning);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xe60f1726),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.34)),
          ),
          child: Icon(
            ready ? Icons.my_location_rounded : Icons.location_searching,
            color: color,
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _GpsStatusChip extends StatelessWidget {
  final bool checkingLocation;
  final bool gpsEnabled;
  final bool hasPermission;
  final bool hasLocation;
  final VoidCallback onTap;

  const _GpsStatusChip({
    required this.checkingLocation,
    required this.gpsEnabled,
    required this.hasPermission,
    required this.hasLocation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = _statusContent();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, Color) _statusContent() {
    if (checkingLocation) {
      return (Icons.location_searching_rounded, 'CHECKING', _kMutedText);
    }
    if (!gpsEnabled) {
      return (Icons.gps_off_rounded, 'GPS OFF', _kWarning);
    }
    if (!hasPermission) {
      return (Icons.lock_outline_rounded, 'ALLOW GPS', _kWarning);
    }
    if (!hasLocation) {
      return (Icons.location_searching_rounded, 'LOCATING', _kWarning);
    }
    return (Icons.my_location_rounded, 'LIVE MAP', _kNeonCyan);
  }
}

class _ActivityOption {
  final String type;
  final String name;
  final String imagePath;
  final IconData icon;

  const _ActivityOption({
    required this.type,
    required this.name,
    required this.imagePath,
    required this.icon,
  });
}
