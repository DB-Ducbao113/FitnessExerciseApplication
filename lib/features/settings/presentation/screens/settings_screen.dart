import 'dart:io';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/core/services/notification_scheduler.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionState _photosStatus = PermissionState.notDetermined;
  bool _loadingPermissions = true;
  bool _notificationsEnabled = true;
  bool _useMetricUnits = true;
  String _appVersion = 'Loading...';
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
    _loadPreferences();
    _loadVersion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled =
          prefs.getBool(kNotificationsPrefKey) ?? _notificationsEnabled;
      _useMetricUnits = prefs.getBool(kMetricUnitsPrefKey) ?? _useMetricUnits;
    });
  }

  Future<void> _showLanguageSelector(AppLanguage currentLang) async {
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AetronColors.panelHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('select_language', currentLang),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _LanguageOptionTile(
                flag: '🇻🇳',
                name: 'Tiếng Việt',
                isSelected: currentLang == AppLanguage.vi,
                onTap: () => Navigator.of(context).pop(AppLanguage.vi),
              ),
              const SizedBox(height: 10),
              _LanguageOptionTile(
                flag: '🇬🇧',
                name: 'English',
                isSelected: currentLang == AppLanguage.en,
                onTap: () => Navigator.of(context).pop(AppLanguage.en),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != currentLang) {
      await ref.read(appLanguageProvider.notifier).setLanguage(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selected == AppLanguage.vi
                  ? 'Đã đổi ngôn ngữ sang Tiếng Việt'
                  : 'App language set to English',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    if (value) {
      final allowed = await NotificationService.instance.requestPermissions();
      if (!allowed && mounted) {
        openAppSettings();
      }
    }
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotificationsPrefKey, value);
    ref.invalidate(notificationsPreferenceProvider);

    final lang = ref.read(appLanguageProvider);
    final workouts = ref.read(workoutListProvider).valueOrNull ?? [];
    final activeGoal = ref.read(userGoalProvider).valueOrNull;
    final streak = ref.read(streakProvider).currentStreak;
    final useMetric = _useMetricUnits;

    NotificationScheduler.refreshSchedules(
      notificationsEnabled: value,
      workoutRemindersEnabled: value,
      morningReminderTime: '08:00',
      goalProgressEnabled: value,
      eveningCheckInEnabled: value,
      eveningCheckInTime: '20:00',
      achievementEnabled: value,
      streakRemindersEnabled: value,
      inactivityRemindersEnabled: value,
      quietHoursEnabled: true,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
      lang: lang,
      workouts: workouts,
      activeGoal: activeGoal,
      currentStreak: streak,
      useMetricUnits: useMetric,
    );
  }

  Future<void> _setUseMetricUnits(bool value) async {
    setState(() => _useMetricUnits = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kMetricUnitsPrefKey, value);
    ref.invalidate(metricUnitsPreferenceProvider);
  }

  Future<void> _refreshPermissions() async {
    final statuses = await Future.wait<PermissionStatus>([
      Permission.camera.status,
      Permission.locationWhenInUse.status,
    ]);
    final photosStatus = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
    if (!mounted) return;
    setState(() {
      _cameraStatus = statuses[0];
      _locationStatus = statuses[1];
      _photosStatus = photosStatus;
      _loadingPermissions = false;
    });
  }

  Future<void> _openPermissionSettings() async {
    await openAppSettings();
  }

  Future<void> _handleCameraPermissionTap() async {
    final status = await Permission.camera.request();
    await _refreshPermissions();
    if (!mounted) return;

    if (status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera access is ready')));
      return;
    }

    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      await _openPermissionSettings();
    }
  }

  Future<void> _handlePhotoPermissionTap() async {
    final status = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
    await _refreshPermissions();
    if (!mounted) return;

    if (status.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo library access is ready')),
      );
      return;
    }

    await _openPermissionSettings();
  }

  Future<void> _handleLocationPermissionTap() async {
    final status = await Permission.locationWhenInUse.request();
    await _refreshPermissions();
    if (!mounted) return;

    if (status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location access is ready')));
      return;
    }

    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      await _openPermissionSettings();
    }
  }

  Future<void> _clearCache() async {
    if (_isClearingCache) return;
    setState(() => _isClearingCache = true);
    try {
      int deletedEntries = 0;
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        deletedEntries += await _clearDirectoryContents(tempDir);
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${docsDir.path}/exports');
      if (await exportDir.exists()) {
        deletedEntries += await _clearDirectoryContents(exportDir);
      }

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedEntries > 0 ? 'Cache cleared successfully' : 'No temporary files to clear',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not clear cache')));
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  Future<int> _clearDirectoryContents(Directory dir) async {
    var deleted = 0;
    await for (final entity in dir.list()) {
      await entity.delete(recursive: true);
      deleted += 1;
    }
    return deleted;
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            // 3D Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: AetronColors.cyanSoft,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.get('settings', currentLang).toUpperCase(),
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
                        AppTranslations.get('settings', currentLang),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: AetronColors.cyan,
                backgroundColor: AetronColors.panelHigh,
                onRefresh: _refreshPermissions,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    // SECTION 1: APP PREFERENCES
                    _Settings3DGroup(
                      title: AppTranslations.get('app_preferences', currentLang),
                      children: [
                        _Settings3DTile(
                          icon: Icons.language_rounded,
                          title: AppTranslations.get('app_language', currentLang),
                          subtitle: currentLang == AppLanguage.vi ? '🇻🇳 Tiếng Việt' : '🇬🇧 English',
                          accentColor: AetronColors.cyan,
                          trailing: const Icon(Icons.chevron_right_rounded, color: AetronColors.textSecondary),
                          onTap: () => _showLanguageSelector(currentLang),
                        ),
                        _Settings3DTile(
                          icon: Icons.notifications_active_rounded,
                          title: AppTranslations.get('daily_reminder', currentLang),
                          subtitle: AppTranslations.get('daily_notifications', currentLang),
                          accentColor: AetronColors.mint,
                          trailing: Switch(
                            value: _notificationsEnabled,
                            onChanged: _setNotificationsEnabled,
                            activeThumbColor: AetronColors.cyan,
                          ),
                          onTap: () => _setNotificationsEnabled(!_notificationsEnabled),
                        ),
                        _Settings3DTile(
                          icon: Icons.straighten_rounded,
                          title: AppTranslations.get('units', currentLang),
                          subtitle: AppTranslations.get('units_subtitle', currentLang),
                          accentColor: AetronColors.blue,
                          trailing: Switch(
                            value: _useMetricUnits,
                            onChanged: _setUseMetricUnits,
                            activeThumbColor: AetronColors.cyan,
                          ),
                          onTap: () => _setUseMetricUnits(!_useMetricUnits),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // SECTION 2: PRIVACY & PERMISSIONS ACCESS
                    _Settings3DGroup(
                      title: AppTranslations.get('privacy_access', currentLang),
                      children: [
                        _Settings3DTile(
                          icon: Icons.camera_alt_rounded,
                          title: AppTranslations.get('camera_access', currentLang),
                          subtitle: _loadingPermissions
                              ? AppTranslations.get('checking_access', currentLang)
                              : _permissionDescription(
                                  _cameraStatus,
                                  allowed: AppTranslations.get('camera_ready', currentLang),
                                  denied: AppTranslations.get('camera_denied', currentLang),
                                  lang: currentLang,
                                ),
                          accentColor: AetronColors.cyan,
                          trailing: _permission3DBadge(_cameraStatus, currentLang),
                          onTap: _handleCameraPermissionTap,
                        ),
                        _Settings3DTile(
                          icon: Icons.photo_library_rounded,
                          title: AppTranslations.get('photo_access', currentLang),
                          subtitle: _loadingPermissions
                              ? AppTranslations.get('checking_access', currentLang)
                              : _photoPermissionDescription(
                                  _photosStatus,
                                  full: AppTranslations.get('photos_ready', currentLang),
                                  denied: AppTranslations.get('photos_denied', currentLang),
                                  limited: AppTranslations.get('photos_limited', currentLang),
                                  lang: currentLang,
                                ),
                          accentColor: AetronColors.mint,
                          trailing: _photoPermission3DBadge(_photosStatus, currentLang),
                          onTap: _handlePhotoPermissionTap,
                        ),
                        _Settings3DTile(
                          icon: Icons.location_on_rounded,
                          title: AppTranslations.get('location_access', currentLang),
                          subtitle: _loadingPermissions
                              ? AppTranslations.get('checking_access', currentLang)
                              : _permissionDescription(
                                  _locationStatus,
                                  allowed: AppTranslations.get('location_ready', currentLang),
                                  denied: AppTranslations.get('location_denied', currentLang),
                                  lang: currentLang,
                                ),
                          accentColor: AetronColors.gold,
                          trailing: _permission3DBadge(_locationStatus, currentLang),
                          onTap: _handleLocationPermissionTap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // SECTION 3: DATA & STORAGE
                    _Settings3DGroup(
                      title: AppTranslations.get('data', currentLang),
                      children: [
                        _Settings3DTile(
                          icon: Icons.delete_sweep_rounded,
                          title: AppTranslations.get('clear_cache', currentLang),
                          subtitle: _isClearingCache
                              ? AppTranslations.get('clearing_cache', currentLang)
                              : (currentLang == AppLanguage.vi ? 'Xóa tệp tạm và bộ nhớ đệm hình ảnh' : 'Clear temporary files and cached images'),
                          accentColor: AetronColors.warning,
                          trailing: _isClearingCache
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AetronColors.cyan,
                                  ),
                                )
                              : const Icon(Icons.chevron_right_rounded, color: AetronColors.textSecondary),
                          onTap: _clearCache,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // SECTION 4: LEGAL & SUPPORT
                    _Settings3DGroup(
                      title: AppTranslations.get('legal_and_support', currentLang),
                      children: [
                        _Settings3DTile(
                          icon: Icons.privacy_tip_outlined,
                          title: AppTranslations.get('privacy_policy', currentLang),
                          subtitle: AppTranslations.get('privacy_sub', currentLang),
                          accentColor: AetronColors.cyan,
                          trailing: const Icon(Icons.chevron_right_rounded, color: AetronColors.textSecondary),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                            );
                          },
                        ),
                        _Settings3DTile(
                          icon: Icons.description_outlined,
                          title: AppTranslations.get('terms_of_service', currentLang),
                          subtitle: AppTranslations.get('terms_sub', currentLang),
                          accentColor: AetronColors.blue,
                          trailing: const Icon(Icons.chevron_right_rounded, color: AetronColors.textSecondary),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                            );
                          },
                        ),
                        _Settings3DTile(
                          icon: Icons.info_outline_rounded,
                          title: currentLang == AppLanguage.vi ? 'Phiên bản ứng dụng' : 'App Version',
                          subtitle: _appVersion,
                          accentColor: AetronColors.mint,
                          onTap: () {},
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AetronColors.mint.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AetronColors.mint.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'AETRON',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AetronColors.mint,
                                letterSpacing: 1.0,
                              ),
                            ),
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
    );
  }

  Widget _permission3DBadge(PermissionStatus status, AppLanguage lang) {
    if (status.isGranted) {
      return _statusBadge(AppTranslations.get('allowed', lang), AetronColors.mint);
    }
    if (status.isLimited) {
      return _statusBadge(AppTranslations.get('limited', lang), AetronColors.warning);
    }
    if (status.isRestricted) {
      return _statusBadge(AppTranslations.get('restricted', lang), AetronColors.warning);
    }
    return _statusBadge(AppTranslations.get('denied', lang), AetronColors.danger);
  }

  Widget _photoPermission3DBadge(PermissionState status, AppLanguage lang) {
    if (status == PermissionState.authorized) {
      return _statusBadge(AppTranslations.get('full_access', lang), AetronColors.mint);
    }
    if (status == PermissionState.limited) {
      return _statusBadge(AppTranslations.get('limited', lang), AetronColors.warning);
    }
    return _statusBadge(AppTranslations.get('denied', lang), AetronColors.danger);
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  String _permissionDescription(
    PermissionStatus status, {
    required String allowed,
    required String denied,
    required AppLanguage lang,
  }) {
    if (status.isGranted) return allowed;
    if (status.isLimited) return AppTranslations.get('photos_limited', lang);
    if (status.isRestricted) return AppTranslations.get('location_blocked', lang);
    return denied;
  }

  String _photoPermissionDescription(
    PermissionState status, {
    required String full,
    required String denied,
    required String limited,
    required AppLanguage lang,
  }) {
    if (status == PermissionState.authorized) return full;
    if (status == PermissionState.limited) return limited;
    return denied;
  }
}

class _Settings3DGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Settings3DGroup({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AetronColors.cyanSoft,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AetronColors.panelHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AetronColors.cyan.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AetronColors.borderSubtle,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Settings3DTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _Settings3DTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accentColor.withValues(alpha: 0.15),
          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: accentColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AetronColors.textPrimary,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                color: AetronColors.textSecondary,
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AetronColors.panelHigh : AetronColors.space,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AetronColors.cyan : AetronColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AetronColors.cyan : AetronColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AetronColors.cyan, size: 20),
          ],
        ),
      ),
    );
  }
}
