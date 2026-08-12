import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_permission_sheet.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
    final isGpsReady = !_requiresGps || (_gpsEnabled && _locationPermissionGranted);

    return Scaffold(
      backgroundColor: AetronColors.background,
      body: AetronBackground(
        child: SafeArea(
          child: Column(
            children: [
              AetronHeader(
                title: widget.activityName.toUpperCase(),
                eyebrow: currentLang == AppLanguage.vi ? 'THIẾT LẬP BUỔI TẬP' : 'WORKOUT SETUP',
                leading: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: AetronColors.textPrimary),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AetronSpacing.page),
                  child: Column(
                    children: [
                      // Sleek Session Configuration & Readiness Card (Non-duplicate)
                      AppCard(
                        padding: const EdgeInsets.all(AetronSpacing.lg),
                        hasGlow: true,
                        borderColor: AetronColors.cyan,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Activity Header & Badge
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AetronColors.cyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AetronRadius.medium),
                                    border: Border.all(
                                      color: AetronColors.cyan.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Icon(
                                    _activityIcon(widget.activityType),
                                    color: AetronColors.cyan,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: AetronSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.activityName.toUpperCase(),
                                        style: AetronTypography.headingLarge.copyWith(
                                          color: AetronColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currentLang == AppLanguage.vi
                                            ? 'Kiểm tra sẵn sàng trước buổi tập'
                                            : 'Pre-workout readiness & setup',
                                        style: AetronTypography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                AppBadge(
                                  label: _requiresGps
                                      ? (currentLang == AppLanguage.vi ? 'GPS NGOÀI TRỜI' : 'GPS OUTDOOR')
                                      : (currentLang == AppLanguage.vi ? 'TRONG NHÀ' : 'INDOOR'),
                                  color: _requiresGps ? AetronColors.cyan : AetronColors.mint,
                                ),
                              ],
                            ),
                            const Divider(color: AetronColors.borderSubtle, height: AetronSpacing.xl),

                            // Session Target Info
                            Row(
                              children: [
                                const Icon(
                                  Icons.flag_rounded,
                                  color: AetronColors.gold,
                                  size: 20,
                                ),
                                const SizedBox(width: AetronSpacing.xs),
                                Text(
                                  currentLang == AppLanguage.vi ? 'CHẾ ĐỘ TẬP' : 'SESSION MODE',
                                  style: AetronTypography.caption.copyWith(
                                    color: AetronColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  currentLang == AppLanguage.vi ? 'Tự do' : 'Open Session',
                                  style: AetronTypography.headingSmall.copyWith(
                                    color: AetronColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AetronSpacing.md),

                      // GPS Status Card
                      if (_requiresGps)
                        AppCard(
                          padding: const EdgeInsets.all(AetronSpacing.md),
                          borderColor: isGpsReady
                              ? AetronColors.mint.withValues(alpha: 0.4)
                              : AetronColors.warning.withValues(alpha: 0.4),
                          backgroundColor: AetronColors.panel.withValues(alpha: 0.9),
                          child: Row(
                            children: [
                              Icon(
                                isGpsReady ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                                color: isGpsReady ? AetronColors.mint : AetronColors.warning,
                                size: 24,
                              ),
                              const SizedBox(width: AetronSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isGpsReady
                                          ? (currentLang == AppLanguage.vi ? 'GPS SẴN SÀNG' : 'GPS READY')
                                          : (currentLang == AppLanguage.vi ? 'YÊU CẦU GPS' : 'GPS REQUIRED'),
                                      style: AetronTypography.headingSmall.copyWith(
                                        color: isGpsReady ? AetronColors.mint : AetronColors.warning,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isGpsReady
                                          ? (currentLang == AppLanguage.vi
                                              ? 'Đã kết nối vệ tinh GPS'
                                              : 'Satellite lock established')
                                          : (currentLang == AppLanguage.vi
                                              ? 'Nhấn để cấp quyền truy cập vị trí'
                                              : 'Tap to grant location permissions'),
                                      style: AetronTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (!isGpsReady)
                                AppButton(
                                  label: currentLang == AppLanguage.vi ? 'SỬA' : 'FIX',
                                  fullWidth: false,
                                  height: 36,
                                  variant: AppButtonVariant.outlined,
                                  onPressed: _openGpsSettings,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AetronSpacing.md),

                      // Primary START WORKOUT Action
                      AppButton(
                        label: isGpsReady
                            ? AppTranslations.get('start_workout', currentLang)
                            : (currentLang == AppLanguage.vi ? 'BẬT GPS & BẮT ĐẦU' : 'ENABLE GPS & START'),
                        icon: Icons.play_arrow_rounded,
                        height: 60,
                        onPressed: _handlePrimaryAction,
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

IconData _activityIcon(String activityType) {
  switch (activityType.toLowerCase()) {
    case 'running':
      return Icons.directions_run_rounded;
    case 'cycling':
      return Icons.directions_bike_rounded;
    case 'walking':
      return Icons.directions_walk_rounded;
    default:
      return Icons.fitness_center_rounded;
  }
}
