import 'dart:async';
import 'dart:io';
import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
const _resetCallbackUrl = 'io.supabase.flutter://callback';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
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
      body: AetronBackground(
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(
              child: AetronLoadingPanel(
                label: 'LOADING PROFILE',
                message: 'Reading your athlete signal.',
              ),
            ),
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
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 28),
              children: [
                const _ProfilePageHeader(),
                const SizedBox(height: 16),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: _cyan, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            AppTranslations.get('system_actions', currentLang),
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
                _ActionTile(
                  icon: Icons.settings_outlined,
                  color: _cyan,
                  label: AppTranslations.get('settings', currentLang),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.shield_outlined,
                  color: _blue,
                  label: AppTranslations.get('security', currentLang),
                  onTap: () =>
                      _showSecuritySheet(context, _accountUsername(user), currentLang),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.emoji_events_outlined,
                  color: _amber,
                  label: AppTranslations.get('achievements', currentLang),
                  onTap: () => _openAchievements(
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
                  label: AppTranslations.get('logout', currentLang),
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
    final currentLang = ref.read(appLanguageProvider);
    final profileAvatarUrl = ref
        .read(currentUserProfileProvider)
        .valueOrNull
        ?.avatarUrl;
    final avatarUrl = ref
        .read(avatarUploadProvider)
        .resolveAvatarUrl(profileAvatarUrl);
    final hasAvatar =
        avatarUrl != null && avatarUrl.isNotEmpty ||
        ref.read(avatarUploadProvider).localAvatarPathOverride != null;

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
                label: AppTranslations.get('choose_from_gallery', currentLang),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(avatarUploadProvider.notifier)
                      .pickAndUpload(ImageSource.gallery);
                },
              ),
              _SheetTile(
                icon: Icons.camera_alt_outlined,
                label: AppTranslations.get('take_a_photo', currentLang),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(avatarUploadProvider.notifier)
                      .pickAndUpload(ImageSource.camera);
                },
              ),
              if (hasAvatar)
                _SheetTile(
                  icon: Icons.delete_outline_rounded,
                  label: AppTranslations.get('remove_current_photo', currentLang),
                  color: _red,
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(avatarUploadProvider.notifier).removeAvatar();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecuritySheet(
    BuildContext context,
    String accountUsername,
    AppLanguage currentLang,
  ) {
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
              Text(
                AppTranslations.get('security', currentLang),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '@$accountUsername',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _SecurityOption(
                icon: Icons.account_circle_outlined,
                title: 'Google Gmail recovery',
                subtitle:
                    'Link a Google account to sign back in if you lose access.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showGoogleGmailRecoverySheet(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoogleGmailRecoverySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _GoogleGmailRecoverySheet(),
    );
  }

  void _openAchievements(
    BuildContext context, {
    required int totalWorkouts,
    required int currentStreak,
    required int longestStreak,
    required double totalDistanceKm,
  }) {
    final achievements = <_AchievementData>[
      _AchievementData(
        title: 'First Signal',
        description: 'Complete your first recorded workout.',
        icon: Icons.bolt_rounded,
        current: totalWorkouts.toDouble(),
        target: 1,
        progressLabel: 'workout',
        reward: 'Starter Signal badge',
      ),
      _AchievementData(
        title: 'Three Day Flow',
        description: 'Build a 3-day training streak.',
        icon: Icons.local_fire_department_rounded,
        current: longestStreak.toDouble(),
        target: 3,
        progressLabel: 'days',
        reward: 'Flow State badge',
      ),
      _AchievementData(
        title: 'Distance Builder',
        description: 'Accumulate 25 km across your sessions.',
        icon: Icons.route_rounded,
        current: totalDistanceKm,
        target: 25,
        progressLabel: 'km',
        reward: 'Distance Builder badge',
      ),
      _AchievementData(
        title: 'Committed Athlete',
        description: 'Log 10 workouts on Aetron.',
        icon: Icons.emoji_events_rounded,
        current: totalWorkouts.toDouble(),
        target: 10,
        progressLabel: 'workouts',
        reward: 'Committed Athlete badge',
      ),
      _AchievementData(
        title: 'Elite Rhythm',
        description: 'Keep a 7-day training streak alive.',
        icon: Icons.workspace_premium_rounded,
        current: longestStreak.toDouble(),
        target: 7,
        progressLabel: 'days',
        reward: 'Elite Rhythm badge',
      ),
      _AchievementData(
        title: 'Century Mark',
        description: 'Travel 100 km through recorded activity.',
        icon: Icons.explore_rounded,
        current: totalDistanceKm,
        target: 100,
        progressLabel: 'km',
        reward: 'Century Explorer badge',
      ),
    ];
    final unlockedCount = achievements.where((item) => item.unlocked).length;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AchievementsPage(
          achievements: achievements,
          unlockedCount: unlockedCount,
          totalWorkouts: totalWorkouts,
          currentStreak: currentStreak,
          totalDistanceKm: totalDistanceKm,
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

class _ProfilePageHeader extends ConsumerWidget {
  const _ProfilePageHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    return AetronHeader(
      title: AppTranslations.get('profile', currentLang),
      compact: true,
    );
  }
}

class _AccountCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final imageUrl = avatarState.resolveAvatarUrl(profile?.avatarUrl);
    final localImagePath = avatarState.localAvatarPathOverride;
    final ImageProvider? imageProvider = localImagePath != null
        ? FileImage(File(localImagePath))
        : imageUrl != null && imageUrl.isNotEmpty
        ? NetworkImage(imageUrl)
        : null;
    final memberSince = _formatDate(
      profile?.createdAt ?? _parseDate(user?.createdAt),
      currentLang,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 118,
                height: 118,
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
                    key: ValueKey(
                      localImagePath ?? imageUrl ?? 'default-avatar',
                    ),
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF102031),
                      image: imageProvider != null
                          ? DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageProvider == null
                        ? ClipOval(
                            child: Image.asset(
                              'assets/screen.png',
                              fit: BoxFit.cover,
                            ),
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
                      width: 34,
                      height: 34,
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
            _athleteDisplayName(user),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
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
                  '${AppTranslations.get('member_since', currentLang)} $memberSince',
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

class _InfoSection extends ConsumerWidget {
  const _InfoSection({
    required this.profile,
    required this.useMetricUnits,
    required this.onEdit,
  });
  final UserProfile profile;
  final bool useMetricUnits;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final bmiMeta = _bmi(profile.bmi);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: _cyan, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppTranslations.get('biometric_data', currentLang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _cyan.withValues(alpha: 0.6)),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: _cyan,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.08,
            children: [
              _InfoTile(
                icon: Icons.monitor_weight_outlined,
                color: _green,
                value: useMetricUnits
                    ? '${profile.weightKg.toStringAsFixed(1)} kg'
                    : '${_kgToLb(profile.weightKg).toStringAsFixed(1)} lb',
                label: AppTranslations.get('weight', currentLang).toUpperCase(),
              ),
              _InfoTile(
                icon: Icons.straighten_rounded,
                color: _cyan,
                value: useMetricUnits
                    ? '${profile.heightM.toStringAsFixed(2)} m'
                    : _formatHeightImperial(profile.heightM),
                label: AppTranslations.get('height', currentLang).toUpperCase(),
              ),
              _InfoTile(
                icon: Icons.cake_outlined,
                color: _green,
                value: '${profile.age} ${AppTranslations.get('years_old', currentLang)}',
                label: AppTranslations.get('age', currentLang).toUpperCase(),
              ),
              _InfoTile(
                icon: profile.gender.toLowerCase() == 'male'
                    ? Icons.male_rounded
                    : Icons.female_rounded,
                color: _blue,
                value: profile.gender.toLowerCase() == 'male'
                    ? AppTranslations.get('male', currentLang)
                    : AppTranslations.get('female', currentLang),
                label: AppTranslations.get('gender', currentLang).toUpperCase(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: _panelAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bmiMeta.$2.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bmiMeta.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
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
                    fontSize: 14,
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
      margin: const EdgeInsets.symmetric(horizontal: 10),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                  size: 22,
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(8),
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
              fontSize: 15,
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
    this.color = _cyan,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _panel,
        child: Icon(Icons.image_outlined, color: color),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      iconColor: color,
      textColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      trailing: Icon(icon, color: color),
    );
  }
}

class _GoogleGmailRecoverySheet extends StatefulWidget {
  const _GoogleGmailRecoverySheet();

  @override
  State<_GoogleGmailRecoverySheet> createState() =>
      _GoogleGmailRecoverySheetState();
}

class _GoogleGmailRecoverySheetState extends State<_GoogleGmailRecoverySheet> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isLinking = false;
  String? _errorMessage;
  String? _statusMessage;

  User? get _user => Supabase.instance.client.auth.currentUser;

  UserIdentity? get _googleIdentity {
    for (final identity in _user?.identities ?? const <UserIdentity>[]) {
      if (identity.provider == 'google') return identity;
    }
    return null;
  }

  bool get _isGoogleLinked => _googleIdentity != null;

  String? get _googleEmail {
    final identityEmail = _googleIdentity?.identityData?['email'] as String?;
    return identityEmail ?? _user?.email;
  }

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _linkGoogleGmail() async {
    if (_isLinking || _isGoogleLinked) return;

    setState(() {
      _isLinking = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final opened = await Supabase.instance.client.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : _resetCallbackUrl,
        scopes: 'email profile',
        queryParams: const {'prompt': 'select_account'},
      );
      if (!mounted) return;
      setState(() {
        _isLinking = false;
        _statusMessage = opened
            ? 'Complete Google sign-in in your browser, then return to Aetron.'
            : null;
        _errorMessage = opened ? null : 'Could not open Google sign-in.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLinking = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLinking = false;
        _errorMessage = 'Could not link your Google Gmail.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final linked = _isGoogleLinked;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1726),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset('assets/GoogleLogo.jpg', width: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Google Gmail recovery',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: linked
                    ? _green.withValues(alpha: 0.08)
                    : _panel.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: linked ? _green : _border),
              ),
              child: Row(
                children: [
                  Icon(
                    linked
                        ? Icons.verified_user_rounded
                        : Icons.account_circle_outlined,
                    color: linked ? _green : _cyan,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      linked
                          ? 'Linked: ${_googleEmail ?? 'Google account'}'
                          : 'No Google Gmail linked',
                      style: TextStyle(
                        color: linked ? _green : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              linked
                  ? 'You can recover access by choosing Continue with Google on the Aetron sign-in screen.'
                  : 'Choose the Gmail account you want to use for account recovery.',
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _RecoveryMessageBox.error(_errorMessage!),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 14),
              _RecoveryMessageBox.success(_statusMessage!),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: linked || _isLinking ? null : _linkGoogleGmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: _bgBottom,
                  disabledBackgroundColor: _panelAlt,
                  disabledForegroundColor: _muted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLinking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _bgBottom,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Text(
                        linked ? 'GOOGLE GMAIL LINKED' : 'LINK GOOGLE GMAIL',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedGmailRecoverySheet extends StatefulWidget {
  const _LinkedGmailRecoverySheet();

  @override
  State<_LinkedGmailRecoverySheet> createState() =>
      _LinkedGmailRecoverySheetState();
}

class _LinkedGmailRecoverySheetState extends State<_LinkedGmailRecoverySheet> {
  final _gmailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _isRemoving = false;
  String? _linkedEmail;
  String? _verifiedAt;
  String? _errorMessage;
  String? _successMessage;

  bool get _isVerified => _verifiedAt != null;

  @override
  void initState() {
    super.initState();
    _loadLinkedGmail();
  }

  @override
  void dispose() {
    _gmailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedGmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('user_recovery_emails')
          .select('recovery_email, verified_at')
          .maybeSingle();
      if (!mounted) return;
      final email = response?['recovery_email'] as String?;
      setState(() {
        _linkedEmail = email;
        _verifiedAt = response?['verified_at'] as String?;
        _gmailController.text = email ?? '';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load linked Gmail status.';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendCode() async {
    final gmail = _gmailController.text.trim().toLowerCase();
    if (!_isGmail(gmail)) {
      setState(() {
        _errorMessage = 'Please enter a valid @gmail.com address.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client.functions.invoke(
        'recovery-email-start',
        body: {'recovery_email': gmail},
      );
      if (!mounted) return;
      setState(() {
        _linkedEmail = gmail;
        _verifiedAt = null;
        _successMessage = 'Verification code sent to $gmail.';
        _isSendingCode = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _functionErrorMessage(
          error,
          fallback: 'Could not send verification code.',
        );
        _isSendingCode = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final gmail = _gmailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();
    if (!_isGmail(gmail) || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'Enter the Gmail address and 6-digit code.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client.functions.invoke(
        'recovery-email-verify',
        body: {'recovery_email': gmail, 'code': code},
      );
      if (!mounted) return;
      setState(() {
        _linkedEmail = gmail;
        _verifiedAt = DateTime.now().toIso8601String();
        _successMessage = 'Recovery Gmail verified.';
        _codeController.clear();
        _isVerifyingCode = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _functionErrorMessage(
          error,
          fallback: 'Could not verify recovery Gmail.',
        );
        _isVerifyingCode = false;
      });
    }
  }

  Future<void> _removeLinkedGmail() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isRemoving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client
          .from('user_recovery_emails')
          .delete()
          .eq('user_id', userId);
      if (!mounted) return;
      setState(() {
        _linkedEmail = null;
        _verifiedAt = null;
        _gmailController.clear();
        _codeController.clear();
        _successMessage = 'Linked Gmail removed.';
        _isRemoving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not remove linked Gmail.';
        _isRemoving = false;
      });
    }
  }

  bool _isGmail(String value) {
    return RegExp(r'^[^@\s]+@gmail\.com$').hasMatch(value);
  }

  String _functionErrorMessage(Object error, {required String fallback}) {
    final message = error.toString();
    final match = RegExp(r'error:\s*([^}]+)').firstMatch(message);
    return match?.group(1)?.trim() ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1726),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: _isLoading
              ? const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator(color: _cyan)),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Linked Gmail recovery',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _linkedEmail == null
                            ? 'Add a Gmail address that can receive reset links.'
                            : _isVerified
                            ? 'Verified: $_linkedEmail'
                            : 'Pending verification: $_linkedEmail',
                        style: TextStyle(
                          color: _isVerified ? _green : _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _RecoveryTextField(
                        controller: _gmailController,
                        hintText: 'your.recovery@gmail.com',
                        prefixIcon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isSendingCode ? null : _sendCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _panel,
                          foregroundColor: _cyan,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: _border),
                          ),
                        ),
                        child: _isSendingCode
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: _cyan,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Text(
                                _linkedEmail == null
                                    ? 'SEND VERIFICATION CODE'
                                    : 'SEND NEW CODE',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      _RecoveryTextField(
                        controller: _codeController,
                        hintText: '6-digit code',
                        prefixIcon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isVerifyingCode ? null : _verifyCode,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isVerifyingCode
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: _green,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Text(
                                'VERIFY GMAIL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                      if (_linkedEmail != null) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _isRemoving ? null : _removeLinkedGmail,
                          icon: _isRemoving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: _red,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.link_off_rounded),
                          label: const Text('Remove linked Gmail'),
                          style: TextButton.styleFrom(foregroundColor: _red),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _RecoveryMessageBox.error(_errorMessage!),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: 12),
                        _RecoveryMessageBox.success(_successMessage!),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _RecoveryTextField extends StatelessWidget {
  const _RecoveryTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _muted),
        filled: true,
        fillColor: _panelAlt,
        prefixIcon: Icon(prefixIcon, color: _muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _cyan),
        ),
      ),
    );
  }
}

class _RecoveryMessageBox extends StatelessWidget {
  const _RecoveryMessageBox({
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  factory _RecoveryMessageBox.error(String message) {
    return _RecoveryMessageBox(
      message: message,
      backgroundColor: const Color(0xFF401A24),
      borderColor: _red.withValues(alpha: 0.45),
      textColor: const Color(0xFFFFB3C3),
    );
  }

  factory _RecoveryMessageBox.success(String message) {
    return _RecoveryMessageBox(
      message: message,
      backgroundColor: const Color(0xFF103125),
      borderColor: _green.withValues(alpha: 0.45),
      textColor: const Color(0xFFA9F5D8),
    );
  }

  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(message, style: TextStyle(color: textColor, fontSize: 14)),
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

class _AchievementData {
  const _AchievementData({
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
    required this.progressLabel,
    required this.reward,
  });

  final String title;
  final String description;
  final IconData icon;
  final double current;
  final double target;
  final String progressLabel;
  final String reward;

  bool get unlocked => current >= target;
  double get progress => (current / target).clamp(0, 1);

  String get progressText {
    final currentLabel = progressLabel == 'km'
        ? current.toStringAsFixed(current >= 10 ? 0 : 1)
        : current.toStringAsFixed(0);
    final targetLabel = target.toStringAsFixed(0);
    return '$currentLabel / $targetLabel $progressLabel';
  }

  String get remainingText {
    if (unlocked) return 'Milestone secured';
    final remaining = target - current;
    final number = progressLabel == 'km'
        ? remaining.toStringAsFixed(remaining >= 10 ? 0 : 1)
        : remaining.toStringAsFixed(0);
    return '$number $progressLabel to go';
  }
}

class _AchievementsPage extends StatelessWidget {
  const _AchievementsPage({
    required this.achievements,
    required this.unlockedCount,
    required this.totalWorkouts,
    required this.currentStreak,
    required this.totalDistanceKm,
  });

  final List<_AchievementData> achievements;
  final int unlockedCount;
  final int totalWorkouts;
  final int currentStreak;
  final double totalDistanceKm;

  @override
  Widget build(BuildContext context) {
    final nextAchievement = achievements
        .where((achievement) => !achievement.unlocked)
        .fold<_AchievementData?>(null, (nearest, achievement) {
          if (nearest == null || achievement.progress > nearest.progress) {
            return achievement;
          }
          return nearest;
        });
    return Scaffold(
      backgroundColor: _bgBottom,
      body: AetronBackground(
        child: SafeArea(
          child: Column(
            children: [
              _AchievementsHeader(
                unlockedCount: unlockedCount,
                total: achievements.length,
              ),
              const Divider(height: 1, color: _border),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
                  itemCount: achievements.length + 3,
                  separatorBuilder: (_, index) =>
                      SizedBox(height: index == 0 ? 18 : 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AchievementTelemetry(
                        totalWorkouts: totalWorkouts,
                        currentStreak: currentStreak,
                        totalDistanceKm: totalDistanceKm,
                      );
                    }
                    if (index == 1) {
                      return _NextMilestoneCard(achievement: nextAchievement);
                    }
                    if (index == 2) {
                      return const Text(
                        'MILESTONE VAULT',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.25,
                        ),
                      );
                    }
                    return _AchievementCard(
                      achievement: achievements[index - 3],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementsHeader extends StatelessWidget {
  const _AchievementsHeader({required this.unlockedCount, required this.total});

  final int unlockedCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to profile',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: _cyan,
          ),
          const Expanded(
            child: Text(
              'ACHIEVEMENTS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.15,
              ),
            ),
          ),
          _UnlockCount(unlocked: unlockedCount, total: total),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _NextMilestoneCard extends StatelessWidget {
  const _NextMilestoneCard({required this.achievement});

  final _AchievementData? achievement;

  @override
  Widget build(BuildContext context) {
    if (achievement == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _amber.withValues(alpha: 0.1),
          border: Border.all(color: _amber.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: _amber),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'ALL CURRENT MILESTONES SECURED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cyan.withValues(alpha: 0.08),
        border: Border.all(color: _cyan.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _cyan.withValues(alpha: 0.08),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _cyan.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(achievement!.icon, color: _cyan, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEXT MILESTONE',
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement!.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${achievement!.remainingText} - ${achievement!.reward}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(achievement!.progress * 100).round()}%',
            style: const TextStyle(
              color: _cyan,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockCount extends StatelessWidget {
  const _UnlockCount({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _cyan.withValues(alpha: 0.1),
        border: Border.all(color: _cyan.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$unlocked / $total',
        style: const TextStyle(
          color: _cyan,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AchievementTelemetry extends StatelessWidget {
  const _AchievementTelemetry({
    required this.totalWorkouts,
    required this.currentStreak,
    required this.totalDistanceKm,
  });

  final int totalWorkouts;
  final int currentStreak;
  final double totalDistanceKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _TelemetryValue(label: 'SESSIONS', value: '$totalWorkouts'),
          const _TelemetryDivider(),
          _TelemetryValue(
            label: 'STREAK',
            value: '${currentStreak}D',
            accent: _cyan,
          ),
          const _TelemetryDivider(),
          _TelemetryValue(
            label: 'DISTANCE',
            value:
                '${totalDistanceKm.toStringAsFixed(totalDistanceKm >= 10 ? 0 : 1)} KM',
            accent: _green,
          ),
        ],
      ),
    );
  }
}

class _TelemetryValue extends StatelessWidget {
  const _TelemetryValue({
    required this.label,
    required this.value,
    this.accent = Colors.white,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryDivider extends StatelessWidget {
  const _TelemetryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: _border);
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final _AchievementData achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final accent = unlocked ? _amber : _cyan;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAchievementDetail(context, achievement),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 106,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: unlocked ? _panelAlt : _panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: unlocked ? _amber.withValues(alpha: 0.48) : _border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  unlocked ? achievement.icon : Icons.lock_outline_rounded,
                  size: 20,
                  color: accent,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              achievement.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            unlocked ? 'UNLOCKED' : 'TRACKING',
                            style: TextStyle(
                              color: accent,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .65,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: achievement.progress,
                          minHeight: 5,
                          color: accent,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        achievement.progressText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unlocked ? _amber : _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
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

void _showAchievementDetail(
  BuildContext context,
  _AchievementData achievement,
) {
  final unlocked = achievement.unlocked;
  final accent = unlocked ? _amber : _cyan;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: _bgBottom,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _mutedSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(achievement.icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        unlocked
                            ? 'MILESTONE SECURED'
                            : 'MILESTONE IN PROGRESS',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .85,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              achievement.description,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _AchievementDetailLine(
              label: 'PROGRESS',
              value: achievement.progressText,
            ),
            const SizedBox(height: 10),
            _AchievementDetailLine(
              label: unlocked ? 'REWARD EARNED' : 'REWARD',
              value: achievement.reward,
              accent: accent,
            ),
            const SizedBox(height: 10),
            _AchievementDetailLine(
              label: 'STATUS',
              value: achievement.remainingText,
              accent: unlocked ? _green : _cyan,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: unlocked ? _panelAlt : _cyan,
                  foregroundColor: unlocked ? Colors.white : _bgBottom,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(unlocked ? 'SECURED' : 'KEEP TRAINING'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AchievementDetailLine extends StatelessWidget {
  const _AchievementDetailLine({
    required this.label,
    required this.value,
    this.accent = Colors.white,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardBox() => BoxDecoration(
  color: _panel,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: _border),
);

String _displayName(String? email) {
  if (email == null || email.isEmpty) return 'Athlete';
  final raw = email.split('@').first.trim();
  return raw.isEmpty ? 'Athlete' : raw[0].toUpperCase() + raw.substring(1);
}

String _accountUsername(User? user) {
  final username = user?.userMetadata?['username'] as String?;
  return username ?? _displayName(user?.email);
}

String _athleteDisplayName(User? user) {
  final displayName = user?.userMetadata?['display_name'] as String?;
  return displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : _accountUsername(user);
}

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

String _formatDate(DateTime? date, [AppLanguage? lang]) {
  if (date == null) return lang == AppLanguage.vi ? 'Chưa xác định' : 'Unknown';
  if (lang == AppLanguage.vi) {
    return 'Thg ${date.month} ${date.year}';
  }
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
  return '${months[date.month - 1]} ${date.year}';
}

double _kgToLb(double kg) => kg * 2.2046226218;

String _formatHeightImperial(double meters) {
  final totalInches = meters * 39.37007874;
  final feet = totalInches ~/ 12;
  final inches = (totalInches - (feet * 12)).round();
  return '$feet ft $inches in';
}
