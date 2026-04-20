import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bgTop = Color(0xFF0A1320);
const _bgBottom = Color(0xFF08111B);
const _panel = Color(0xFF112033);
const _panelAlt = Color(0xFF162031);
const _border = Color(0x2200E5FF);
const _muted = Color(0xFF8A96A9);
const _mutedSoft = Color(0xFF617286);
const _cyan = Color(0xFF19E2FF);
const _blue = Color(0xFF0D5DFF);
const _green = Color(0xFF30F0A4);
const _amber = Color(0xFFFFB85C);
const _red = Color(0xFFE33C49);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final avatar = ref.watch(avatarUploadProvider);
    final streak = ref.watch(streakProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: _bgBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: profileAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: _cyan)),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Your profile could not be loaded.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            data: (profile) => ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
              children: [
                _Header(
                  name: _displayName(user?.email),
                  streak: streak.currentStreak,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            color: _cyan,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'PROFILE',
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
                const SizedBox(height: 12),
                _AccountCard(
                  user: user,
                  profile: profile,
                  avatarState: avatar,
                  onCameraTap: () => _showAvatarSourceSheet(context, ref),
                ),
                const SizedBox(height: 18),
                if (profile != null)
                  _InfoSection(
                    profile: profile,
                    useMetricUnits: useMetricUnits,
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
                  )
                else
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
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, color: _cyan, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'ACTIONS',
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
                _ActionTile(
                  icon: Icons.settings_outlined,
                  color: _cyan,
                  label: 'Settings',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.shield_outlined,
                  color: _blue,
                  label: 'Security',
                  onTap: () => _showSecuritySheet(context, user?.email),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.emoji_events_outlined,
                  color: _amber,
                  label: 'Achievements',
                  onTap: () => _showAchievementsSheet(
                    context,
                    totalWorkouts: workoutsAsync.valueOrNull?.length ?? 0,
                    currentStreak: streak.currentStreak,
                    longestStreak: streak.longestStreak,
                    totalDistanceKm:
                        workoutsAsync.valueOrNull?.fold<double>(
                          0,
                          (sum, workout) => sum + workout.distanceKm,
                        ) ??
                        0,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.logout_rounded,
                  color: _red,
                  label: 'Log Out',
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAvatarSourceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1726),
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
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              _SheetTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(avatarUploadProvider.notifier)
                      .pickAndUpload(ImageSource.gallery);
                },
              ),
              _SheetTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
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

  void _showSecuritySheet(BuildContext context, String? email) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1726),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Security',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email ?? 'No email available',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _SecurityOption(
                icon: Icons.mark_email_read_outlined,
                title: 'Send password reset email',
                subtitle:
                    'We will send a secure reset link to your account email.',
                onTap: email == null
                    ? null
                    : () async {
                        Navigator.of(ctx).pop();
                        try {
                          await Supabase.instance.client.auth
                              .resetPasswordForEmail(email);
                          if (context.mounted) {
                            _snack(context, 'Password reset email sent');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            _snack(context, 'Could not send reset email');
                          }
                        }
                      },
              ),
              const SizedBox(height: 10),
              _SecurityOption(
                icon: Icons.settings_outlined,
                title: 'Open app settings',
                subtitle:
                    'Manage camera, photos, location, and app permissions.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementsSheet(
    BuildContext context, {
    required int totalWorkouts,
    required int currentStreak,
    required int longestStreak,
    required double totalDistanceKm,
  }) {
    final achievements = <({String title, String subtitle, bool unlocked})>[
      (
        title: 'First Workout',
        subtitle: 'Complete your first recorded session',
        unlocked: totalWorkouts >= 1,
      ),
      (
        title: 'Consistency',
        subtitle: 'Reach a 3-day workout streak',
        unlocked: longestStreak >= 3,
      ),
      (
        title: 'Distance Builder',
        subtitle: 'Accumulate 25 distance units across all workouts',
        unlocked: totalDistanceKm >= 25,
      ),
      (
        title: 'Committed Athlete',
        subtitle: 'Log 10 workouts',
        unlocked: totalWorkouts >= 10,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1726),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Achievements',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalWorkouts workouts logged, current streak $currentStreak days',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ...achievements.map(
                (achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AchievementRow(
                    title: achievement.title,
                    subtitle: achievement.subtitle,
                    unlocked: achievement.unlocked,
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1726),
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: const Text('Log out'),
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

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.streak});
  final String name;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final greeting = _profileGreeting();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF13263B),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border(
          bottom: BorderSide(color: _cyan.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_cyan, _blue],
                  ).createShader(bounds),
                  child: const Text(
                    'PROFILE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(text: '$greeting, '),
                      TextSpan(
                        text: name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2A18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _amber.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFFD364),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$streak',
                  style: const TextStyle(
                    color: Color(0xFFFFD364),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.profile,
    required this.avatarState,
    required this.onCameraTap,
  });

  final User? user;
  final UserProfile? profile;
  final AvatarState avatarState;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile?.avatarUrl;
    final memberSince = _formatDate(
      profile?.createdAt ?? _parseDate(user?.createdAt),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      decoration: _cardBox(),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _cyan.withValues(alpha: 0.18),
                      _blue.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(
                    color: _cyan.withValues(alpha: 0.45),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF102031),
                      image: imageUrl != null && imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageUrl == null || imageUrl.isEmpty
                        ? const Icon(
                            Icons.person_outline_rounded,
                            color: _cyan,
                            size: 54,
                          )
                        : null,
                  ),
                ),
              ),
              if (avatarState.isUploading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.42),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              if (!avatarState.isUploading)
                Positioned(
                  right: -2,
                  bottom: 10,
                  child: GestureDetector(
                    onTap: onCameraTap,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [_cyan, _blue]),
                        boxShadow: [
                          BoxShadow(
                            color: _cyan.withValues(alpha: 0.28),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        color: _bgBottom,
                        size: 19,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user?.email ?? 'Unknown account',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: _cyan),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Member since $memberSince',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (avatarState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              avatarState.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFF8992), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.profile,
    required this.useMetricUnits,
    required this.onEdit,
  });
  final UserProfile profile;
  final bool useMetricUnits;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bmiMeta = _bmi(profile.bmi);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Personal Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF103048),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cyan.withValues(alpha: 0.6)),
                  ),
                  child: const Icon(Icons.edit_outlined, color: _cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.08,
            children: [
              _InfoTile(
                icon: Icons.monitor_weight_outlined,
                color: _green,
                value: useMetricUnits
                    ? '${profile.weightKg.toStringAsFixed(1)} kg'
                    : '${_kgToLb(profile.weightKg).toStringAsFixed(1)} lb',
                label: 'WEIGHT',
              ),
              _InfoTile(
                icon: Icons.straighten_rounded,
                color: _cyan,
                value: useMetricUnits
                    ? '${profile.heightM.toStringAsFixed(2)} m'
                    : _formatHeightImperial(profile.heightM),
                label: 'HEIGHT',
              ),
              _InfoTile(
                icon: Icons.cake_outlined,
                color: _green,
                value: '${profile.age} years',
                label: 'AGE',
              ),
              _InfoTile(
                icon: profile.gender.toLowerCase() == 'male'
                    ? Icons.male_rounded
                    : Icons.female_rounded,
                color: _blue,
                value: _cap(profile.gender),
                label: 'GENDER',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: _panelAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bmiMeta.$2.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bmiMeta.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.analytics_outlined, color: bmiMeta.$2),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BMI',
                        style: TextStyle(
                          color: _mutedSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Body mass index',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  profile.bmi.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bmiMeta.$2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    bmiMeta.$1.toUpperCase(),
                    style: const TextStyle(
                      color: _bgBottom,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProfileCard extends StatelessWidget {
  const _EmptyProfileCard({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Set up your body metrics to improve distance-based calories, pace, and health insights.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: _bgBottom,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Set Up Profile',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: _cardBox(),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.34)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: _mutedSoft,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: _panel,
        child: Icon(Icons.image_outlined, color: _cyan),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      iconColor: _cyan,
      textColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      trailing: Icon(icon, color: _cyan),
    );
  }
}

class _SecurityOption extends StatelessWidget {
  const _SecurityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _panelAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _cyan, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.title,
    required this.subtitle,
    required this.unlocked,
  });

  final String title;
  final String subtitle;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? _amber : _mutedSoft;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              unlocked
                  ? Icons.emoji_events_rounded
                  : Icons.lock_outline_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Text(
            unlocked ? 'Unlocked' : 'Locked',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardBox() => BoxDecoration(
  color: _panel,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: _border),
);

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF102234),
      content: Text(message, style: const TextStyle(color: Colors.white)),
    ),
  );
}

String _displayName(String? email) {
  if (email == null || email.isEmpty) return 'Athlete';
  final raw = email.split('@').first.trim();
  return raw.isEmpty ? 'Athlete' : raw[0].toUpperCase() + raw.substring(1);
}

String _cap(String value) => value.isEmpty
    ? value
    : value[0].toUpperCase() + value.substring(1).toLowerCase();

(String, Color) _bmi(double bmi) {
  if (bmi < 18.5) return ('Underweight', _blue);
  if (bmi < 25) return ('Normal', _green);
  if (bmi < 30) return ('Overweight', _amber);
  return ('Obese', _red);
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

double _kgToLb(double kg) => kg * 2.2046226218;

String _profileGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String _formatHeightImperial(double meters) {
  final totalInches = meters * 39.37007874;
  final feet = totalInches ~/ 12;
  final inches = (totalInches - (feet * 12)).round();
  return '$feet ft $inches in';
}
