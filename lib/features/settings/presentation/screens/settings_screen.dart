import 'dart:io';

import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/core/legal/legal_documents.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';

import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/profile_header.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/settings_section.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/settings_tile.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bgTop = Color(0xFF0A1320);
const _bgBottom = Color(0xFF08111B);
const _muted = Color(0xFF8A96A9);
const _cyan = Color(0xFF19E2FF);
const _red = Color(0xFFE33C49);

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
      backgroundColor: const Color(0xFF112033),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  AppTranslations.get('select_language', currentLang),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Text('🇻🇳', style: TextStyle(fontSize: 24)),
                title: const Text('Tiếng Việt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: currentLang == AppLanguage.vi ? const Icon(Icons.check_circle_rounded, color: _cyan) : null,
                onTap: () => Navigator.of(context).pop(AppLanguage.vi),
              ),
              const Divider(color: Color(0x12FFFFFF)),
              ListTile(
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                title: const Text('English', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: currentLang == AppLanguage.en ? const Icon(Icons.check_circle_rounded, color: _cyan) : null,
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
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotificationsPrefKey, value);
    ref.invalidate(notificationsPreferenceProvider);
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
            deletedEntries > 0 ? 'Cache cleared' : 'No cache to clear',
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
    final user = Supabase.instance.client.auth.currentUser;
    final currentLang = ref.watch(appLanguageProvider);
    final userMetaName = user?.userMetadata?['display_name'] as String? ??
        user?.userMetadata?['username'] as String?;
    final displayName = (userMetaName != null && userMetaName.trim().isNotEmpty)
        ? userMetaName.trim()
        : user?.email?.split('@').first ?? 'Athlete';

    return Scaffold(
      backgroundColor: _bgBottom,
      appBar: AppBar(
        title: Text(AppTranslations.get('settings', currentLang)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshPermissions,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
            children: [
              const SizedBox(height: 8),
              ProfileHeader(
                name: displayName,
                handle: '',
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: _cyan, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          AppTranslations.get('settings', currentLang).toUpperCase(),
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SettingsSection(
                title: AppTranslations.get('app_preferences', currentLang),
                children: [
                  SettingsTile(
                    icon: Icons.language_rounded,
                    title: AppTranslations.get('app_language', currentLang),
                    subtitle: currentLang == AppLanguage.vi ? '🇻🇳 Tiếng Việt' : '🇬🇧 English',
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                    onTap: () => _showLanguageSelector(currentLang),
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.notifications,
                    title: AppTranslations.get('daily_reminder', currentLang),
                    subtitle: '',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: _setNotificationsEnabled,
                      activeThumbColor: _cyan,
                    ),
                    onTap: () =>
                        _setNotificationsEnabled(!_notificationsEnabled),
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.straighten,
                    title: AppTranslations.get('units', currentLang),
                    subtitle: '',
                    trailing: Switch(
                      value: _useMetricUnits,
                      onChanged: _setUseMetricUnits,
                      activeThumbColor: _cyan,
                    ),
                    onTap: () => _setUseMetricUnits(!_useMetricUnits),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SettingsSection(
                title: AppTranslations.get('privacy_access', currentLang),
                children: [
                  SettingsTile(
                    icon: Icons.camera_alt,
                    title: AppTranslations.get('camera_access', currentLang),
                    subtitle: _loadingPermissions
                        ? AppTranslations.get('checking_access', currentLang)
                        : _permissionDescription(
                            _cameraStatus,
                            allowed: AppTranslations.get('camera_ready', currentLang),
                            denied: AppTranslations.get('camera_denied', currentLang),
                            lang: currentLang,
                          ),
                    trailing: _permissionBadge(_cameraStatus, currentLang),
                    onTap: _handleCameraPermissionTap,
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.photo_library,
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
                    trailing: _photoPermissionBadge(_photosStatus, currentLang),
                    onTap: _handlePhotoPermissionTap,
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.location_on,
                    title: AppTranslations.get('location_access', currentLang),
                    subtitle: _loadingPermissions
                        ? AppTranslations.get('checking_access', currentLang)
                        : _permissionDescription(
                            _locationStatus,
                            allowed: AppTranslations.get('location_ready', currentLang),
                            denied: AppTranslations.get('location_denied', currentLang),
                            lang: currentLang,
                          ),
                    trailing: _permissionBadge(_locationStatus, currentLang),
                    onTap: _handleLocationPermissionTap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SettingsSection(
                title: AppTranslations.get('data', currentLang),
                children: [
                  SettingsTile(
                    icon: Icons.delete_sweep,
                    title: AppTranslations.get('clear_cache', currentLang),
                    subtitle: _isClearingCache
                        ? AppTranslations.get('clearing_cache', currentLang)
                        : '',
                    trailing: _isClearingCache
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: () => _showClearCacheDialog(currentLang),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SettingsSection(
                title: AppTranslations.get('about_legal', currentLang),
                children: [
                  SettingsTile(
                    icon: Icons.info,
                    title: AppTranslations.get('version', currentLang),
                    subtitle: _appVersion,
                    trailing: const SizedBox.shrink(),
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.description,
                    title: AppTranslations.get('terms_of_service', currentLang),
                    subtitle: '',
                    onTap: () => _showDocumentSheet(
                      title: AppTranslations.get('terms_of_service', currentLang),
                      sections: LegalDocuments.getTermsOfService(currentLang),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.privacy_tip,
                    title: AppTranslations.get('privacy_policy', currentLang),
                    subtitle: '',
                    onTap: () => _showDocumentSheet(
                      title: AppTranslations.get('privacy_policy', currentLang),
                      sections: LegalDocuments.getPrivacyPolicy(currentLang),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context, ref),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(AppTranslations.get('logout', currentLang)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionBadge(PermissionStatus status, AppLanguage lang) {
    final label = switch (status) {
      PermissionStatus.granted => AppTranslations.get('allowed', lang),
      PermissionStatus.limited => AppTranslations.get('limited', lang),
      PermissionStatus.provisional => AppTranslations.get('allowed', lang),
      PermissionStatus.restricted => AppTranslations.get('restricted', lang),
      PermissionStatus.permanentlyDenied => AppTranslations.get('blocked', lang),
      PermissionStatus.denied => AppTranslations.get('denied', lang),
    };

    final color = switch (status) {
      PermissionStatus.granted => Colors.green,
      PermissionStatus.limited => Colors.orange,
      PermissionStatus.provisional => Colors.green,
      PermissionStatus.restricted => Colors.grey,
      PermissionStatus.permanentlyDenied => Colors.red,
      PermissionStatus.denied => Colors.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _photoPermissionBadge(PermissionState status, AppLanguage lang) {
    final label = switch (status) {
      PermissionState.authorized => AppTranslations.get('full_access', lang),
      PermissionState.limited => AppTranslations.get('limited', lang),
      PermissionState.restricted => AppTranslations.get('restricted', lang),
      PermissionState.denied => AppTranslations.get('blocked', lang),
      PermissionState.notDetermined => AppTranslations.get('denied', lang),
    };

    final color = switch (status) {
      PermissionState.authorized => Colors.green,
      PermissionState.limited => Colors.orange,
      PermissionState.restricted => Colors.grey,
      PermissionState.denied => Colors.red,
      PermissionState.notDetermined => Colors.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _permissionDescription(
    PermissionStatus status, {
    required String allowed,
    required String denied,
    required AppLanguage lang,
    String? limited,
  }) {
    return switch (status) {
      PermissionStatus.granted => allowed,
      PermissionStatus.provisional => allowed,
      PermissionStatus.limited => limited ?? allowed,
      PermissionStatus.restricted => AppTranslations.get('restricted', lang),
      PermissionStatus.permanentlyDenied => denied,
      PermissionStatus.denied => denied,
    };
  }

  String _photoPermissionDescription(
    PermissionState status, {
    required String full,
    required String denied,
    required AppLanguage lang,
    String? limited,
  }) {
    return switch (status) {
      PermissionState.authorized => full,
      PermissionState.limited => limited ?? full,
      PermissionState.restricted => AppTranslations.get('restricted', lang),
      PermissionState.denied => denied,
      PermissionState.notDetermined => denied,
    };
  }

  void _showClearCacheDialog(AppLanguage lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('clear_cache', lang)),
        content: Text(AppTranslations.get('clear_cache_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppTranslations.get('cancel', lang)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _clearCache();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppTranslations.get('clear', lang)),
          ),
        ],
      ),
    );
  }

  void _showDocumentSheet({
    required String title,
    required List<LegalDocumentSection> sections,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: _cyan, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Aetron Legal & Compliance Telemetry',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0x1AFFFFFF), height: 1),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: sections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = sections[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF132238),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x1F19E2FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _cyan,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.content,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFD0D7E3),
                                height: 1.55,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(appLanguageProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('logout', lang)),
        content: Text(AppTranslations.get('logout_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTranslations.get('cancel', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppTranslations.get('logout', lang)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.invalidate(workoutListProvider);
      await Supabase.instance.client.auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
