import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

const _kBgTop = Color(0xff0a0e1a);
const _kBgBottom = Color(0xff0d1b2a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);
const _kNeonBlue = Color(0xff00bfff);

bool _requiresGpsTracking(String activityType) {
  switch (activityType.toLowerCase()) {
    case 'running':
    case 'walking':
    case 'cycling':
      return true;
    default:
      return false;
  }
}

class WorkoutStartScreen extends ConsumerStatefulWidget {
  final String activityType;
  final String activityName;
  final String activityImagePath;

  const WorkoutStartScreen({
    super.key,
    required this.activityType,
    required this.activityName,
    required this.activityImagePath,
  });

  @override
  ConsumerState<WorkoutStartScreen> createState() => _WorkoutStartScreenState();
}

class _WorkoutStartScreenState extends ConsumerState<WorkoutStartScreen>
    with WidgetsBindingObserver {
  bool _gpsEnabled = false;
  bool _locationPermissionGranted = false;
  bool _locationPermissionBlocked = false;
  bool _checkingGps = true;

  bool get _requiresGps => _requiresGpsTracking(widget.activityType);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshGpsStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshGpsStatus();
    }
  }

  Future<void> _refreshGpsStatus() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      _gpsEnabled = enabled;
      _locationPermissionGranted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      _locationPermissionBlocked =
          permission == LocationPermission.deniedForever;
      _checkingGps = false;
    });
  }

  Future<void> _openGpsSettings() async {
    if (!_gpsEnabled) {
      await Geolocator.openLocationSettings();
      await _refreshGpsStatus();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }

    await _refreshGpsStatus();
  }

  void _startWorkout() {
    if (_requiresGps && (!_gpsEnabled || !_locationPermissionGranted)) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          activityType: widget.activityType,
          requireGps: _requiresGps,
        ),
      ),
    );
  }

  void _handlePrimaryAction() {
    if (_requiresGps && (!_gpsEnabled || !_locationPermissionGranted)) {
      _openGpsSettings();
      return;
    }
    _startWorkout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activityName.toUpperCase(),
                        style: const TextStyle(
                          color: _kMutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HeroImage(
                        tag: widget.activityType,
                        imagePath: widget.activityImagePath,
                        icon: _activityIcon(widget.activityType),
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        child: _GpsSetupPanel(
                          isEnabled: _gpsEnabled,
                          hasLocationPermission: _locationPermissionGranted,
                          isPermissionBlocked: _locationPermissionBlocked,
                          isChecking: _checkingGps,
                          isRequired: _requiresGps,
                          onActionTap: _openGpsSettings,
                        ),
                      ),
                      if (_requiresGps &&
                          (_gpsEnabled && _locationPermissionGranted)) ...[
                        const SizedBox(height: 10),
                        _GlassCard(
                          child: Row(
                            children: [
                              _MiniSignalChip(
                                icon: Icons.route_rounded,
                                label: 'Live route',
                              ),
                              const SizedBox(width: 10),
                              _MiniSignalChip(
                                icon: Icons.location_searching_rounded,
                                label: 'GPS locked',
                              ),
                              const SizedBox(width: 10),
                              _MiniSignalChip(
                                icon: Icons.auto_awesome_rounded,
                                label: 'Ready',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kNeonBlue, _kNeonCyan],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _kNeonCyan.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _handlePrimaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: _kBgTop,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      icon: Icon(
                        _requiresGps &&
                                (!_gpsEnabled || !_locationPermissionGranted)
                            ? Icons.gps_fixed_rounded
                            : Icons.play_arrow_rounded,
                        size: 28,
                      ),
                      label: Text(
                        _primaryButtonLabel(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _primaryButtonLabel() {
    if (!_requiresGps) return 'START WORKOUT';
    if (_checkingGps) return 'CHECKING GPS';
    if (!_gpsEnabled) return 'TURN ON GPS';
    if (!_locationPermissionGranted) return 'ALLOW LOCATION';
    return 'START WORKOUT';
  }
}

class _GpsSetupPanel extends StatelessWidget {
  final bool isEnabled;
  final bool hasLocationPermission;
  final bool isPermissionBlocked;
  final bool isChecking;
  final bool isRequired;
  final VoidCallback onActionTap;

  const _GpsSetupPanel({
    required this.isEnabled,
    required this.hasLocationPermission,
    required this.isPermissionBlocked,
    required this.isChecking,
    required this.isRequired,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isChecking
        ? _kMutedText
        : (!isEnabled || !hasLocationPermission
              ? const Color(0xffff6b6b)
              : const Color(0xff2be38c));
    final label = isChecking
        ? 'Checking GPS'
        : isRequired
        ? (!isEnabled
              ? 'GPS OFF'
              : hasLocationPermission
              ? 'GPS ON'
              : 'LOCATION BLOCKED')
        : (isEnabled ? 'GPS READY' : 'GPS OPTIONAL');
    final title = isChecking
        ? 'Checking your location status'
        : isRequired
        ? (!isEnabled
              ? 'Location services are off'
              : hasLocationPermission
              ? 'Outdoor tracking is ready'
              : isPermissionBlocked
              ? 'Location access is blocked'
              : 'Location permission is needed')
        : 'This activity can start anytime';
    final actionLabel = !isRequired
        ? 'OPEN LOCATION SETTINGS'
        : (!isEnabled
              ? 'TURN ON GPS'
              : hasLocationPermission
              ? 'OPEN GPS SETTINGS'
              : 'ALLOW LOCATION');

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
      decoration: BoxDecoration(
        color: const Color(0xff101a29),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.10), const Color(0xff101a29)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRequired ? Icons.gps_fixed_rounded : Icons.explore_outlined,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.32),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isRequired ? 'Outdoor mode' : 'Flexible start',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: onActionTap,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
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

class _MiniSignalChip extends StatelessWidget {
  const _MiniSignalChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xff101a29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kNeonCyan, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String tag;
  final String imagePath;
  final IconData icon;

  const _HeroImage({
    required this.tag,
    required this.imagePath,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _kCardBorder),
          boxShadow: [
            BoxShadow(
              color: _kNeonCyan.withValues(alpha: 0.10),
              blurRadius: 26,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(imagePath, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: child,
    );
  }
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
