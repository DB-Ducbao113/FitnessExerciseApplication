import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/core/services/notification_scheduler.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/edit_display_name_sheet.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _notificationStatus = PermissionStatus.denied;
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

  Future<void> _showUnitSelector(AppLanguage currentLang) async {
    final isVi = currentLang == AppLanguage.vi;
    final selected = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AetronColors.panelHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AetronColors.blue.withValues(alpha: 0.4), width: 1.2),
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
                isVi ? 'Chọn hệ đơn vị đo lường' : 'Select Measurement Unit',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _UnitOptionTile(
                icon: Icons.straighten_rounded,
                title: isVi ? 'Hệ mét (Metric)' : 'Metric System',
                subtitle: isVi
                    ? 'Kilômét (km), Mét (m), Vận tốc (km/h), Pace (min/km)'
                    : 'Kilometers (km), Meters (m), Speed (km/h), Pace (min/km)',
                isSelected: _useMetricUnits,
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 10),
              _UnitOptionTile(
                icon: Icons.speed_rounded,
                title: isVi ? 'Hệ Anh (Imperial)' : 'Imperial System',
                subtitle: isVi
                    ? 'Dặm (mi), Feet (ft), Vận tốc (mph), Pace (min/mi)'
                    : 'Miles (mi), Feet (ft), Speed (mph), Pace (min/mi)',
                isSelected: !_useMetricUnits,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != _useMetricUnits) {
      await _setUseMetricUnits(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selected
                  ? (isVi ? 'Đã chuyển sang Hệ mét (km, km/h)' : 'Switched to Metric units (km, km/h)')
                  : (isVi ? 'Đã chuyển sang Hệ dặm (mi, mph)' : 'Switched to Imperial units (mi, mph)'),
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
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _loadingPermissions = false;
        _notificationStatus = PermissionStatus.granted;
        _cameraStatus = PermissionStatus.granted;
        _locationStatus = PermissionStatus.granted;
        _photosStatus = PermissionState.authorized;
      });
      return;
    }

    final statuses = await Future.wait<PermissionStatus>([
      Permission.notification.status,
      Permission.camera.status,
      Permission.locationWhenInUse.status,
    ]);
    final photosStatus = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
    if (!mounted) return;
    final notifGranted = statuses[0].isGranted || statuses[0].isLimited;
    setState(() {
      _notificationStatus = statuses[0];
      _cameraStatus = statuses[1];
      _locationStatus = statuses[2];
      _photosStatus = photosStatus;
      _notificationsEnabled = notifGranted;
      _loadingPermissions = false;
    });
  }

  bool get _isNotificationGranted =>
      _notificationStatus.isGranted || _notificationStatus.isLimited;

  bool get _isCameraGranted =>
      _cameraStatus.isGranted || _cameraStatus.isLimited;

  bool get _isPhotosGranted =>
      _photosStatus.isAuth ||
      _photosStatus == PermissionState.authorized ||
      _photosStatus == PermissionState.limited;

  bool get _isLocationGranted =>
      _locationStatus.isGranted || _locationStatus.isLimited;

  Future<void> _showRevokePermissionDialog(
    BuildContext context,
    String permissionName,
    AppLanguage lang,
  ) async {
    final isVi = lang == AppLanguage.vi;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AetronColors.cyan.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AetronColors.cyan.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.settings_outlined, color: AetronColors.cyan, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVi ? 'Quản lý quyền $permissionName' : 'Manage $permissionName Access',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isVi
              ? 'Theo cơ chế bảo mật của iOS, để tắt hoặc thay đổi quyền $permissionName, bạn vui lòng chuyển nút gạt trong phần Cài đặt của iPhone.'
              : 'Per iOS security policy, to change or revoke $permissionName access, please update it in your iPhone Settings.',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            color: AetronColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isVi ? 'Đóng' : 'Cancel',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                color: AetronColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AetronColors.cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isVi ? 'Mở Cài Đặt' : 'Open Settings',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await openAppSettings();
    }
  }

  Future<void> _toggleNotificationPermission(bool value, AppLanguage lang) async {
    if (value) {
      final allowed = await NotificationService.instance.requestPermissions();
      await _refreshPermissions();
      if (!allowed && mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Thông báo' : 'Notifications',
          lang,
        );
      } else {
        await _setNotificationsEnabled(true);
      }
    } else {
      await _setNotificationsEnabled(false);
      if (mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Thông báo' : 'Notifications',
          lang,
        );
      }
    }
  }

  Future<void> _toggleCameraPermission(bool value, AppLanguage lang) async {
    if (value) {
      final status = await Permission.camera.request();
      await _refreshPermissions();
      if (!status.isGranted && !status.isLimited && mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Camera' : 'Camera',
          lang,
        );
      }
    } else {
      await _showRevokePermissionDialog(
        context,
        lang == AppLanguage.vi ? 'Camera' : 'Camera',
        lang,
      );
    }
  }

  Future<void> _togglePhotoPermission(bool value, AppLanguage lang) async {
    if (value) {
      final status = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.readWrite,
        ),
      );
      await _refreshPermissions();
      if (!status.isAuth && mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Thư viện ảnh' : 'Photo Library',
          lang,
        );
      }
    } else {
      await _showRevokePermissionDialog(
        context,
        lang == AppLanguage.vi ? 'Thư viện ảnh' : 'Photo Library',
        lang,
      );
    }
  }

  Future<void> _toggleLocationPermission(bool value, AppLanguage lang) async {
    if (value) {
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        await Permission.locationAlways.request();
      }
      await _refreshPermissions();
      if (!status.isGranted && !status.isLimited && mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Vị trí (GPS)' : 'Location (GPS)',
          lang,
        );
      }
    } else {
      await _showRevokePermissionDialog(
        context,
        lang == AppLanguage.vi ? 'Vị trí (GPS)' : 'Location (GPS)',
        lang,
      );
    }
  }

  Future<void> _clearCache() async {
    if (_isClearingCache) return;
    setState(() => _isClearingCache = true);
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully'),
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

  Future<void> _confirmDeleteAccount(BuildContext context, AppLanguage lang) async {
    final isVi = lang == AppLanguage.vi;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AetronColors.danger.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AetronColors.danger.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AetronColors.danger, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVi ? 'Xóa tài khoản vĩnh viễn' : 'Delete Account',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isVi
              ? 'Hành động này sẽ xóa vĩnh viễn toàn bộ lịch sử tập luyện, huy hiệu, mục tiêu và dữ liệu cá nhân của bạn trên hệ thống. Dữ liệu sau khi xóa sẽ không thể phục hồi.'
              : 'This action will permanently delete all your workout history, badges, goals, and personal data. This cannot be undone.',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            color: AetronColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isVi ? 'Hủy bỏ' : 'Cancel',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                color: AetronColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AetronColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isVi ? 'Xác nhận xóa' : 'Confirm Delete',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AetronColors.danger.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AetronColors.danger),
                    const SizedBox(height: 18),
                    Text(
                      isVi ? 'Đang xóa tài khoản...' : 'Deleting account...',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          ref.invalidate(workoutListProvider);
          ref.invalidate(userProfileProvider(user.id));
          ref.invalidate(currentAvatarDisplayProvider);
          ref.invalidate(userGoalProvider);

          await ref.read(userProfileRepositoryProvider).deleteAccount(user.id);

          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0F172A),
                content: Text(
                  isVi
                      ? 'Tài khoản và toàn bộ dữ liệu đã được xóa thành công.'
                      : 'Account and all data deleted successfully.',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red.shade900,
                content: Text(
                  isVi
                      ? 'Lỗi khi xóa tài khoản: $e'
                      : 'Error deleting account: $e',
                ),
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final user = Supabase.instance.client.auth.currentUser;

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
                    // SECTION 0: ACCOUNT & IDENTITY
                    _Settings3DGroup(
                      title: currentLang == AppLanguage.vi ? 'TÀI KHOẢN & DANH TÍNH' : 'ACCOUNT & IDENTITY',
                      children: [
                        _Settings3DTile(
                          icon: Icons.badge_outlined,
                          title: AppTranslations.get('display_name', currentLang),
                          subtitle: _settingsDisplayName(user),
                          accentColor: AetronColors.cyan,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AetronColors.cyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentLang == AppLanguage.vi ? 'Đổi tên' : 'Edit',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AetronColors.cyan,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_outlined, size: 12, color: AetronColors.cyan),
                              ],
                            ),
                          ),
                          onTap: () async {
                            final updated = await showEditDisplayNameSheet(
                              context,
                              currentName: _settingsDisplayName(user),
                            );
                            if (updated == true && mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

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
                          icon: Icons.straighten_rounded,
                          title: AppTranslations.get('units', currentLang),
                          subtitle: _useMetricUnits
                              ? (currentLang == AppLanguage.vi ? 'Hệ mét (km, m, km/h)' : 'Metric (km, m, km/h)')
                              : (currentLang == AppLanguage.vi ? 'Hệ Anh (mi, ft, mph)' : 'Imperial (mi, ft, mph)'),
                          accentColor: AetronColors.blue,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AetronColors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AetronColors.blue.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              _useMetricUnits ? 'KM / H' : 'MI / H',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AetronColors.blue,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          onTap: () => _showUnitSelector(currentLang),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // SECTION 2: PRIVACY & PERMISSIONS ACCESS
                    _Settings3DGroup(
                      title: AppTranslations.get('privacy_access', currentLang),
                      children: [
                        _Settings3DTile(
                          icon: Icons.notifications_active_rounded,
                          title: currentLang == AppLanguage.vi ? 'Thông báo' : 'Notifications',
                          subtitle: _loadingPermissions
                              ? AppTranslations.get('checking_access', currentLang)
                              : _isNotificationGranted
                                  ? (currentLang == AppLanguage.vi
                                      ? 'Đã cho phép • Nhắc nhở tập & chuỗi Streak'
                                      : 'Allowed • Workout & streak alerts')
                                  : (currentLang == AppLanguage.vi
                                      ? 'Chưa cho phép • Bật để nhận thông báo từ iPhone'
                                      : 'Denied • Tap to allow alerts'),
                          accentColor: AetronColors.mint,
                          trailing: Switch.adaptive(
                            value: _isNotificationGranted,
                            onChanged: (val) => _toggleNotificationPermission(val, currentLang),
                            activeTrackColor: AetronColors.mint.withValues(alpha: 0.5),
                            activeThumbColor: AetronColors.mint,
                          ),
                          onTap: () => _toggleNotificationPermission(!_isNotificationGranted, currentLang),
                        ),
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
                          trailing: Switch.adaptive(
                            value: _isCameraGranted,
                            onChanged: (val) => _toggleCameraPermission(val, currentLang),
                            activeTrackColor: AetronColors.cyan.withValues(alpha: 0.5),
                            activeThumbColor: AetronColors.cyan,
                          ),
                          onTap: () => _toggleCameraPermission(!_isCameraGranted, currentLang),
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
                          trailing: Switch.adaptive(
                            value: _isPhotosGranted,
                            onChanged: (val) => _togglePhotoPermission(val, currentLang),
                            activeTrackColor: AetronColors.mint.withValues(alpha: 0.5),
                            activeThumbColor: AetronColors.mint,
                          ),
                          onTap: () => _togglePhotoPermission(!_isPhotosGranted, currentLang),
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
                          trailing: Switch.adaptive(
                            value: _isLocationGranted,
                            onChanged: (val) => _toggleLocationPermission(val, currentLang),
                            activeTrackColor: AetronColors.gold.withValues(alpha: 0.5),
                            activeThumbColor: AetronColors.gold,
                          ),
                          onTap: () => _toggleLocationPermission(!_isLocationGranted, currentLang),
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
                    const SizedBox(height: 18),

                    // SECTION 5: ACCOUNT DELETION (Apple Guideline 5.1.1(v) Compliant)
                    _Settings3DGroup(
                      title: currentLang == AppLanguage.vi ? 'QUẢN LÝ TÀI KHOẢN' : 'ACCOUNT MANAGEMENT',
                      children: [
                        _Settings3DTile(
                          icon: Icons.person_remove_rounded,
                          title: currentLang == AppLanguage.vi ? 'Xóa tài khoản' : 'Delete Account',
                          subtitle: currentLang == AppLanguage.vi
                              ? 'Xóa vĩnh viễn tài khoản và toàn bộ dữ liệu'
                              : 'Permanently remove your account and all data',
                          accentColor: AetronColors.danger,
                          trailing: const Icon(Icons.chevron_right_rounded, color: AetronColors.danger),
                          onTap: () => _confirmDeleteAccount(context, currentLang),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AetronColors.cyan.withValues(alpha: 0.15)
                : AetronColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AetronColors.cyan
                  : AetronColors.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AetronColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AetronColors.cyan,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AetronColors.blue.withValues(alpha: 0.15)
                : AetronColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AetronColors.blue
                  : AetronColors.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: isSelected ? AetronColors.blue : AetronColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : AetronColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: AetronColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AetronColors.blue,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _settingsDisplayName(User? user) {
  final meta = user?.userMetadata;
  final displayName = (meta?['display_name'] ?? meta?['full_name'] ?? meta?['name']) as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  final email = user?.email;
  if (email != null && email.contains('@')) {
    return email.split('@').first;
  }
  return 'Athlete';
}
