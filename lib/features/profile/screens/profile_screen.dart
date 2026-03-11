import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/providers/workout_providers.dart';
import 'package:fitness_exercise_application/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/auth/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/profile/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/profile/screens/goal_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final avatarState = ref.watch(avatarUploadProvider);
    final userGoalAsync = ref.watch(userGoalProvider);

    return Scaffold(
      backgroundColor: const Color(0xfff4f6fa),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xff18b0e8),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            children: [
              // ── Account Header Card ──────────────────────────────────
              _AccountCard(
                user: user,
                avatarUrl: profile?.avatarUrl,
                isUploading: avatarState.isUploading,
                errorMessage: avatarState.errorMessage,
                onCameraTap: () => _showAvatarSourceSheet(context, ref),
              ),
              const SizedBox(height: 16),

              // ── Personal Information Card ────────────────────────────
              if (profile != null)
                _PersonalInfoCard(
                  profile: profile,
                  onEdit: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileSetupScreen(existingProfile: profile),
                        ),
                      )
                      .then(
                        (_) => ref
                            .read(currentUserProfileProvider.notifier)
                            .invalidateAndRefresh(),
                      ),
                ),

              if (profile == null)
                _EmptyProfileCard(
                  onSetup: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileSetupScreen(),
                        ),
                      )
                      .then(
                        (_) => ref
                            .read(currentUserProfileProvider.notifier)
                            .invalidateAndRefresh(),
                      ),
                ),

              const SizedBox(height: 16),

              // ── Goal Summary Card ────────────────────────────────────
              userGoalAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading goal: $e')),
                data: (goal) => _GoalSummaryCard(
                  goal: goal,
                  onEdit: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(builder: (_) => const GoalScreen()),
                      )
                      .then(
                        (_) => ref.read(userGoalProvider.notifier).refresh(),
                      ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Action Card ─────────────────────────────────────────
              _ActionCard(onLogout: () => _logout(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvatarSourceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xff18b0e8),
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(avatarUploadProvider.notifier)
                    .pickAndUpload(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xff18b0e8),
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(avatarUploadProvider.notifier)
                    .pickAndUpload(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
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

// ── Account Header Card ─────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final dynamic user;
  final String? avatarUrl;
  final bool isUploading;
  final String? errorMessage;
  final VoidCallback onCameraTap;

  const _AccountCard({
    required this.user,
    required this.avatarUrl,
    required this.isUploading,
    required this.errorMessage,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    final memberSince = _parseMemberSince(user?.createdAt);
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            // Avatar with camera icon overlay
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 52, // Keep the size larger for profile screen
                    backgroundColor: const Color(0xffe8f7fd),
                    backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null || avatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 52,
                            color: Color(0xff18b0e8),
                          )
                        : null,
                  ),
                ),
                // Upload spinner overlay
                if (isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.4),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                // Camera button
                if (!isUploading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: onCameraTap,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff18b0e8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user?.email ?? 'Unknown',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 13,
                  color: Color(0xff18b0e8),
                ),
                const SizedBox(width: 5),
                Text(
                  'Member since $memberSince',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _parseMemberSince(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown';
    }
  }
}

// ── Personal Information Card ────────────────────────────────────────
class _PersonalInfoCard extends StatelessWidget {
  final dynamic profile;
  final VoidCallback onEdit;

  const _PersonalInfoCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final bmi = profile.bmi as double;
    final (bmiLabel, bmiColor) = _bmiInfo(bmi);

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xff18b0e8)),
                  onPressed: onEdit,
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight',
                    value: '${profile.weightKg.toStringAsFixed(1)} kg',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.height,
                    label: 'Height',
                    value: '${profile.heightM.toStringAsFixed(2)} m',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.cake_outlined,
                    label: 'Age',
                    value: '${profile.age} years',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: profile.gender.toLowerCase() == 'male'
                        ? Icons.male
                        : Icons.female,
                    label: 'Gender',
                    value: _capitalize(profile.gender as String),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // BMI banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bmiColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bmiColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: bmiColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'BMI',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        bmi.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: bmiColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: bmiColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          bmiLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _bmiInfo(double bmi) {
    if (bmi < 18.5) return ('Underweight', Colors.blue);
    if (bmi < 25) return ('Normal', Colors.green);
    if (bmi < 30) return ('Overweight', Colors.orange);
    return ('Obese', Colors.red);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Empty Profile card ───────────────────────────────────────────────
class _EmptyProfileCard extends StatelessWidget {
  final VoidCallback onSetup;
  const _EmptyProfileCard({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.person_add_alt_1_outlined,
              size: 40,
              color: Color(0xff18b0e8),
            ),
            const SizedBox(height: 12),
            const Text(
              'Profile not set up yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your height, weight and gender to get BMI calculations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSetup,
              icon: const Icon(Icons.edit),
              label: const Text('Set up Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff18b0e8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action Card (Logout only) ───────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final VoidCallback onLogout;

  const _ActionCard({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.logout,
            label: 'Logout',
            onTap: onLogout,
            iconColor: Colors.red,
            textColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  final Color iconColor;
  final Color textColor;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
    this.iconColor = const Color(0xff18b0e8),
    this.textColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: disabled ? Colors.grey : iconColor),
      title: Text(
        label,
        style: TextStyle(color: disabled ? Colors.grey : textColor),
      ),
      trailing: disabled
          ? null
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: disabled ? null : onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

// ── Info Tile ────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff0f8ff),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xff18b0e8), size: 20),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ── Goal Summary Card ─────────────────────────────────────────────────
/// Shows on Profile page below Personal Information.
/// If no goal is set, displays a prompt to create one.
class _GoalSummaryCard extends StatelessWidget {
  final dynamic goal; // UserGoal?
  final VoidCallback onEdit;

  const _GoalSummaryCard({required this.goal, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (goal == null) {
      return Card(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xffe8f7fd),
            child: Icon(Icons.flag_outlined, color: Color(0xff18b0e8)),
          ),
          title: const Text(
            'No goal set',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Tap to set your fitness goal'),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onEdit,
        ),
      );
    }

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flag,
                        color: Color(0xff18b0e8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Goal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.edit, color: Colors.grey, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                goal.label as String,
                style: const TextStyle(fontSize: 14, color: Color(0xff18b0e8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
