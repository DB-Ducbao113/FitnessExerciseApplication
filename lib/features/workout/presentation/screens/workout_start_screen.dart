import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_permission_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

const _kBgTop = Color(0xff0a0e1a);
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
      final approved = await showAetronPermissionSheet(
        context,
        kind: AetronPermissionKind.location,
        actionLabel: 'OPEN SETTINGS',
      );
      if (!approved) return;
      await Geolocator.openLocationSettings();
      await _refreshGpsStatus();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (!mounted) return;
    if (permission == LocationPermission.denied) {
      final approved = await showAetronPermissionSheet(
        context,
        kind: AetronPermissionKind.location,
        actionLabel: 'GRANT GPS ACCESS',
      );
      if (!approved) return;
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }

    await _refreshGpsStatus();
  }

  void _startWorkout() {
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
    final currentLang = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: _kBgTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: widget.activityType,
              child: Image.asset(widget.activityImagePath, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    _kBgTop.withValues(alpha: 0.62),
                    _kBgTop.withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ),
          Offstage(
            offstage: true,
            child: Column(
              children: [
                AetronHeader(
                  title: AppTranslations.get('start_workout', currentLang),
                  eyebrow: widget.activityName,
                  compact: true,
                  leading: Tooltip(
                    message: 'Back',
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AetronColors.cyanSoft,
                      style: IconButton.styleFrom(
                        backgroundColor: AetronColors.cyan.withValues(
                          alpha: 0.10,
                        ),
                        fixedSize: const Size(44, 44),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ActivitySignalIntro(
                          activityName: widget.activityName,
                          icon: _activityIcon(widget.activityType),
                        ),
                        const SizedBox(height: 18),
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
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kNeonBlue, _kNeonCyan],
                          ),
                          borderRadius: BorderRadius.circular(18),
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
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: Icon(
                            _requiresGps &&
                                    (!_gpsEnabled ||
                                        !_locationPermissionGranted)
                                ? Icons.gps_fixed_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                          ),
                          label: Text(
                            _primaryButtonLabel(currentLang),
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
                ),
              ],
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Back',
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AetronColors.cyanSoft,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.42,
                            ),
                            fixedSize: const Size(46, 46),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AetronColors.cyan.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'AETRON / LIVE GPS',
                              style: TextStyle(
                                color: AetronColors.cyanSoft,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppTranslations.get(widget.activityType, currentLang).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 96,
                  left: 22,
                  right: 22,
                  child: _StartControlDeck(
                    activityName: AppTranslations.get(widget.activityType, currentLang),
                    isEnabled: _gpsEnabled,
                    hasLocationPermission: _locationPermissionGranted,
                    isPermissionBlocked: _locationPermissionBlocked,
                    isChecking: _checkingGps,
                    isRequired: _requiresGps,
                    onSettingsTap: _openGpsSettings,
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 72,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.explore_outlined,
                        color: AetronColors.cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppTranslations.get('outdoor_session', currentLang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'GPS settings',
                        child: IconButton(
                          onPressed: _openGpsSettings,
                          icon: const Icon(Icons.settings_rounded),
                          color: AetronColors.cyan,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.36,
                            ),
                            fixedSize: const Size(36, 36),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: _StartWorkoutButton(
                    label: _primaryButtonLabel(currentLang),
                    ready:
                        !_requiresGps ||
                        (_gpsEnabled && _locationPermissionGranted),
                    onPressed: _handlePrimaryAction,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _primaryButtonLabel(AppLanguage lang) {
    if (!_requiresGps) return AppTranslations.get('start_workout', lang).toUpperCase();
    if (_checkingGps) return AppTranslations.get('checking', lang).toUpperCase();
    if (!_gpsEnabled) return AppTranslations.get('allow_gps', lang).toUpperCase();
    if (!_locationPermissionGranted) return AppTranslations.get('allow_gps', lang).toUpperCase();
    return AppTranslations.get('start_workout', lang).toUpperCase();
  }
}

class _GpsSetupPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final accent = isChecking
        ? _kMutedText
        : (!isEnabled || !hasLocationPermission
              ? const Color(0xffff6b6b)
              : const Color(0xff2be38c));
    final label = isChecking
        ? AppTranslations.get('checking', currentLang).toUpperCase()
        : isRequired
        ? (!isEnabled
              ? AppTranslations.get('gps_off', currentLang).toUpperCase()
              : hasLocationPermission
              ? AppTranslations.get('gps_on', currentLang).toUpperCase()
              : AppTranslations.get('location_blocked', currentLang).toUpperCase())
        : (isEnabled ? AppTranslations.get('gps_ready', currentLang).toUpperCase() : 'GPS OPTIONAL');
    final title = isChecking
        ? AppTranslations.get('checking_access', currentLang)
        : isRequired
        ? (!isEnabled
              ? AppTranslations.get('location_services_off', currentLang)
              : hasLocationPermission
              ? AppTranslations.get('outdoor_tracking_ready', currentLang)
              : isPermissionBlocked
              ? AppTranslations.get('location_access_blocked', currentLang)
              : AppTranslations.get('location_permission_needed', currentLang))
        : 'This activity can start anytime';
    final actionLabel = !isRequired
        ? 'OPEN LOCATION SETTINGS'
        : (!isEnabled
              ? AppTranslations.get('allow_gps', currentLang).toUpperCase()
              : hasLocationPermission
              ? 'OPEN GPS SETTINGS'
              : AppTranslations.get('allow_gps', currentLang).toUpperCase());

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
                          isRequired
                              ? AppTranslations.get('outdoor_mode', currentLang)
                              : AppTranslations.get('flexible_start', currentLang),
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
              const SizedBox(width: 8),
              Tooltip(
                message: actionLabel,
                child: IconButton(
                  onPressed: onActionTap,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    foregroundColor: Colors.white,
                    fixedSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.settings_rounded, size: 19),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartControlDeck extends ConsumerWidget {
  const _StartControlDeck({
    required this.activityName,
    required this.isEnabled,
    required this.hasLocationPermission,
    required this.isPermissionBlocked,
    required this.isChecking,
    required this.isRequired,
    required this.onSettingsTap,
  });

  final String activityName;
  final bool isEnabled;
  final bool hasLocationPermission;
  final bool isPermissionBlocked;
  final bool isChecking;
  final bool isRequired;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final isReady = !isRequired || (isEnabled && hasLocationPermission);
    final status = isChecking
        ? AppTranslations.get('checking', currentLang).toUpperCase()
        : isReady
        ? AppTranslations.get('gps_ready', currentLang).toUpperCase()
        : !isEnabled
        ? AppTranslations.get('gps_off', currentLang).toUpperCase()
        : isPermissionBlocked
        ? AppTranslations.get('location_blocked', currentLang).toUpperCase()
        : AppTranslations.get('allow_gps', currentLang).toUpperCase();
    final description = isReady
        ? (currentLang == AppLanguage.vi
            ? 'Theo dõi vị trí độ chính xác cao đã sẵn sàng cho lộ trình.'
            : 'High precision tracking is active and ready for your route.')
        : isChecking
        ? (currentLang == AppLanguage.vi
            ? 'Đang kiểm tra tín hiệu vị trí trên thiết bị.'
            : 'Checking your device location signal.')
        : (currentLang == AppLanguage.vi
            ? 'Bật quyền vị trí để ghi lại bản đồ đường đi ngoài trời.'
            : 'Enable location access to record your outdoor route.');
    final accent = isReady
        ? AetronColors.cyan
        : isChecking
        ? AetronColors.muted
        : const Color(0xFFFFB85C);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xEA0A1422),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
              border: Border.all(color: accent.withValues(alpha: 0.34)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              isReady ? Icons.gps_fixed_rounded : Icons.location_searching,
              color: accent,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(AppTranslations.get('gps_status', currentLang), style: AetronText.label.copyWith(color: accent)),
          const SizedBox(height: 7),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kMutedText,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: Icons.explore_outlined,
                label: AppTranslations.get('outdoor_mode', currentLang).toUpperCase(),
                color: accent,
              ),
              _StatusPill(
                icon: Icons.route_rounded,
                label: isReady
                    ? AppTranslations.get('route_locked', currentLang)
                    : AppTranslations.get('route_pending', currentLang),
                color: accent,
              ),
              InkWell(
                onTap: onSettingsTap,
                borderRadius: BorderRadius.circular(999),
                child: _StatusPill(
                  icon: Icons.tune_rounded,
                  label: AppTranslations.get('gps_settings', currentLang),
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartWorkoutButton extends StatelessWidget {
  const _StartWorkoutButton({
    required this.label,
    required this.ready,
    required this.onPressed,
  });

  final String label;
  final bool ready;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kNeonBlue, _kNeonCyan]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: _kNeonCyan.withValues(alpha: 0.30),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: _kBgTop,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: Icon(
            ready ? Icons.play_arrow_rounded : Icons.gps_fixed_rounded,
            size: 25,
          ),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
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

class _ActivitySignalIntro extends StatelessWidget {
  const _ActivitySignalIntro({required this.activityName, required this.icon});

  final String activityName;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _kNeonCyan.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _kNeonCyan.withValues(alpha: 0.38)),
          ),
          child: Icon(icon, color: _kNeonCyan, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GPS TRACKING', style: AetronText.label),
              const SizedBox(height: 4),
              Text(
                activityName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
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
