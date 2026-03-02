import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/presentation/screens/auth/login_screen.dart';
import 'package:fitness_exercise_application/presentation/screens/settings/widgets/profile_header.dart';
import 'package:fitness_exercise_application/presentation/screens/settings/widgets/settings_section.dart';
import 'package:fitness_exercise_application/presentation/screens/settings/widgets/settings_tile.dart';

// State providers for settings
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final useMetricUnitsProvider = StateProvider<bool>((ref) => true);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final useMetricUnits = ref.watch(useMetricUnitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xff18b0e8),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Profile Header
          ProfileHeader(
            name: user?.email?.split('@').first ?? 'User',
            email: user?.email ?? 'No email',
            avatarPath: 'assets/profile.jpg',
          ),

          const SizedBox(height: 16),

          // App Preferences Section
          SettingsSection(
            title: 'APP PREFERENCES',
            children: [
              SettingsTile(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Workout reminders and updates',
                trailing: Switch(
                  value: notificationsEnabled,
                  onChanged: (value) {
                    ref.read(notificationsEnabledProvider.notifier).state =
                        value;
                  },
                  activeColor: const Color(0xff18b0e8),
                ),
                onTap: () {
                  ref.read(notificationsEnabledProvider.notifier).state =
                      !notificationsEnabled;
                },
              ),
              const Divider(height: 1),
              SettingsTile(
                icon: Icons.straighten,
                title: 'Units',
                subtitle: useMetricUnits
                    ? 'Metric (km, kg)'
                    : 'Imperial (mi, lb)',
                trailing: Switch(
                  value: useMetricUnits,
                  onChanged: (value) {
                    ref.read(useMetricUnitsProvider.notifier).state = value;
                  },
                  activeColor: const Color(0xff18b0e8),
                ),
                onTap: () {
                  ref.read(useMetricUnitsProvider.notifier).state =
                      !useMetricUnits;
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Data & Privacy Section
          SettingsSection(
            title: 'DATA & PRIVACY',
            children: [
              SettingsTile(
                icon: Icons.download,
                title: 'Export Data',
                subtitle: 'Download your workout data',
                onTap: () => _showExportDialog(context),
              ),
              const Divider(height: 1),
              SettingsTile(
                icon: Icons.delete_sweep,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: () => _showClearCacheDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // About Section
          SettingsSection(
            title: 'ABOUT',
            children: [
              SettingsTile(
                icon: Icons.info,
                title: 'Version',
                subtitle: '1.0.0',
                trailing: const SizedBox.shrink(),
              ),
              const Divider(height: 1),
              SettingsTile(
                icon: Icons.description,
                title: 'Terms of Service',
                onTap: () {
                  // TODO: Open terms of service
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Terms of Service')),
                  );
                },
              ),
              const Divider(height: 1),
              SettingsTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () {
                  // TODO: Open privacy policy
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Privacy Policy')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'Your workout data will be exported as a JSON file. This feature will be available soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'Are you sure you want to clear the cache? This will not delete your workouts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
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
