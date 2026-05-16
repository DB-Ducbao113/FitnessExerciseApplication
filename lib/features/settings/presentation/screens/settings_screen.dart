import 'dart:io';

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

    return Scaffold(
      backgroundColor: _bgBottom,
      appBar: AppBar(
        title: const Text('Settings'),
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
                name: user?.email?.split('@').first ?? 'User',
                email: user?.email ?? 'No email',
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, color: _cyan, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'SETTINGS',
                          style: TextStyle(
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
                title: 'APP PREFERENCES',
                children: [
                  SettingsTile(
                    icon: Icons.notifications,
                    title: 'Notifications',
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
                    title: 'Units',
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
                title: 'PRIVACY ACCESS',
                children: [
                  SettingsTile(
                    icon: Icons.camera_alt,
                    title: 'Camera Access',
                    subtitle: _loadingPermissions
                        ? 'Checking access...'
                        : _permissionDescription(
                            _cameraStatus,
                            allowed: 'Ready for taking profile photos',
                            denied:
                                'Tap to request camera access or open Settings',
                          ),
                    trailing: _permissionBadge(_cameraStatus),
                    onTap: _handleCameraPermissionTap,
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.photo_library,
                    title: 'Photo Library Access',
                    subtitle: _loadingPermissions
                        ? 'Checking access...'
                        : _photoPermissionDescription(
                            _photosStatus,
                            full:
                                'Full access is ready for choosing profile photos',
                            denied:
                                'Tap to request photo access or open Settings',
                            limited:
                                'Limited access. Switch to Full Access in Settings',
                          ),
                    trailing: _photoPermissionBadge(_photosStatus),
                    onTap: _handlePhotoPermissionTap,
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.location_on,
                    title: 'Location Access',
                    subtitle: _loadingPermissions
                        ? 'Checking access...'
                        : _permissionDescription(
                            _locationStatus,
                            allowed: 'Ready for outdoor workout tracking',
                            denied:
                                'Tap to request GPS access or open Settings',
                          ),
                    trailing: _permissionBadge(_locationStatus),
                    onTap: _handleLocationPermissionTap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SettingsSection(
                title: 'DATA',
                children: [
                  SettingsTile(
                    icon: Icons.delete_sweep,
                    title: 'Clear Cache',
                    subtitle: _isClearingCache
                        ? 'Clearing temporary files...'
                        : '',
                    trailing: _isClearingCache
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _showClearCacheDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SettingsSection(
                title: 'ABOUT',
                children: [
                  SettingsTile(
                    icon: Icons.info,
                    title: 'Version',
                    subtitle: _appVersion,
                    trailing: const SizedBox.shrink(),
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.description,
                    title: 'Terms of Service',
                    subtitle: '',
                    onTap: () => _showDocumentSheet(
                      title: 'Terms of Service',
                      content: _termsOfServiceText,
                    ),
                  ),
                  const Divider(height: 1, color: Color(0x12FFFFFF)),
                  SettingsTile(
                    icon: Icons.privacy_tip,
                    title: 'Privacy Policy',
                    subtitle: '',
                    onTap: () => _showDocumentSheet(
                      title: 'Privacy Policy',
                      content: _privacyPolicyText,
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
                    label: const Text('Logout'),
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

  Widget _permissionBadge(PermissionStatus status) {
    final label = switch (status) {
      PermissionStatus.granted => 'Allowed',
      PermissionStatus.limited => 'Limited',
      PermissionStatus.provisional => 'Allowed',
      PermissionStatus.restricted => 'Restricted',
      PermissionStatus.permanentlyDenied => 'Blocked',
      PermissionStatus.denied => 'Denied',
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

  Widget _photoPermissionBadge(PermissionState status) {
    final label = switch (status) {
      PermissionState.authorized => 'Full Access',
      PermissionState.limited => 'Limited',
      PermissionState.restricted => 'Restricted',
      PermissionState.denied => 'Blocked',
      PermissionState.notDetermined => 'Denied',
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
    String? limited,
  }) {
    return switch (status) {
      PermissionStatus.granted => allowed,
      PermissionStatus.provisional => allowed,
      PermissionStatus.limited => limited ?? allowed,
      PermissionStatus.restricted => 'Restricted by system settings',
      PermissionStatus.permanentlyDenied => denied,
      PermissionStatus.denied => denied,
    };
  }

  String _photoPermissionDescription(
    PermissionState status, {
    required String full,
    required String denied,
    String? limited,
  }) {
    return switch (status) {
      PermissionState.authorized => full,
      PermissionState.limited => limited ?? full,
      PermissionState.restricted => 'Restricted by system settings',
      PermissionState.denied => denied,
      PermissionState.notDetermined => denied,
    };
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'Are you sure you want to clear temporary files and image cache? Your workouts will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _clearCache();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDocumentSheet({required String title, required String content}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.5,
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

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
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

const String _termsOfServiceText =
    'By using Aetron, you agree to use the app for lawful personal fitness tracking purposes only. You are responsible for the accuracy of the information you enter, and for using workout guidance safely and appropriately for your health condition. The app may provide estimates such as pace, calories, and route summaries, but these are informational only and should not be treated as medical advice. We may update features, availability, and app behavior over time.';

const String _privacyPolicyText =
    'Aetron stores your workout records, profile information, and route data so you can review progress and sync history across devices. Camera and photo access are used only when you choose a profile image. Location access is used for outdoor workout tracking. Motion access is used for step-based activity tracking and fallback scenarios. Exported files remain on your device unless you choose to share them. We do not present your private data publicly unless a feature explicitly asks you to do so.';
