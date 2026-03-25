import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';

const _kBgTop = Color(0xff0a0e1a);
const _kBgBottom = Color(0xff0d1b2a);
const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final avatarState = ref.watch(avatarUploadProvider);
    final userGoalAsync = ref.watch(userGoalProvider);

    return Scaffold(
      backgroundColor: _kBgTop,
      appBar: AppBar(
        title: const Text('Profile'),
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
        child: profileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _kNeonCyan)),
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          data: (profile) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROFILE',
                        style: TextStyle(
                          color: _kMutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your account and goals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                        .then((_) {
                          if (userId != null) {
                            ref.invalidate(userProfileProvider(userId));
                          }
                        }),
                  ),

                if (profile == null)
                  _EmptyProfileCard(
                    onSetup: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileSetupScreen(),
                          ),
                        )
                        .then((_) {
                          if (userId != null) {
                            ref.invalidate(userProfileProvider(userId));
                          }
                        }),
                  ),

                const SizedBox(height: 16),

                // ── Goal Summary Card ────────────────────────────────────
                userGoalAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error loading goal: $e')),
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
      ),
    );
  }

  void _showAvatarSourceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xff0f1726),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xff102739),
                  child: Icon(Icons.photo_library, color: _kNeonCyan),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(avatarUploadProvider.notifier)
                      .pickAndUpload(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xff102739),
                  child: Icon(Icons.camera_alt, color: _kNeonCyan),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(color: Colors.white),
                ),
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
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff0f1726),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _kMutedText)),
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
      color: _kCardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
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
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kNeonCyan.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 52, // Keep the size larger for profile screen
                    backgroundColor: const Color(0xff101a29),
                    backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null || avatarUrl!.isEmpty
                        ? const Icon(Icons.person, size: 52, color: _kNeonCyan)
                        : null,
                  ),
                ),
                // Upload spinner overlay
                if (isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
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
                          color: const Color(0xff102739),
                          shape: BoxShape.circle,
                          border: Border.all(color: _kCardBorder, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: _kNeonCyan,
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
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 13, color: _kNeonCyan),
                const SizedBox(width: 5),
                Text(
                  'Member since $memberSince',
                  style: const TextStyle(color: _kMutedText, fontSize: 13),
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
      color: _kCardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: _kNeonCyan),
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
                color: bmiColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bmiColor.withValues(alpha: 0.3)),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
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
      color: _kCardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.person_add_alt_1_outlined,
              size: 40,
              color: _kNeonCyan,
            ),
            const SizedBox(height: 12),
            const Text(
              'Profile not set up yet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your height, weight and gender to get BMI calculations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kMutedText),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSetup,
              icon: const Icon(Icons.edit),
              label: const Text('Set up Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNeonCyan,
                foregroundColor: _kBgTop,
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
      color: _kCardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
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
  final Color iconColor;
  final Color textColor;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = _kNeonCyan,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: textColor)),
      trailing: const Icon(Icons.chevron_right, color: _kMutedText),
      onTap: onTap,
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
        color: const Color(0xff101a29),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kNeonCyan, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: _kMutedText)),
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
        color: _kCardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xff102739),
            child: Icon(Icons.flag_outlined, color: _kNeonCyan),
          ),
          title: const Text(
            'No goal set',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          subtitle: const Text(
            'Tap to set your fitness goal',
            style: TextStyle(color: _kMutedText),
          ),
          trailing: const Icon(Icons.chevron_right, color: _kMutedText),
          onTap: onEdit,
        ),
      );
    }

    return Card(
      color: _kCardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
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
                      const Icon(Icons.flag, color: _kNeonCyan, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Goal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.edit, color: _kMutedText, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                goal.label as String,
                style: const TextStyle(fontSize: 14, color: _kNeonCyan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
