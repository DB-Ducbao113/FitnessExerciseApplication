import 'dart:async';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/achievements_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/edit_display_name_sheet.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_3d_decorations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logout_dialog.dart';
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
            loading: () => const ProfileSkeletonView(),
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
                  icon: Icons.badge_outlined,
                  color: _green,
                  label: AppTranslations.get('edit_display_name', currentLang),
                  onTap: () => showEditDisplayNameSheet(
                    context,
                    currentName: _athleteDisplayName(user),
                  ),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.shield_outlined,
                  color: _blue,
                  label: AppTranslations.get('security', currentLang),
                  onTap: () =>
                      _showSecuritySheet(context, _accountUsername(user), currentLang, ref),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.emoji_events_outlined,
                  color: _amber,
                  label: AppTranslations.get('achievements', currentLang),
                  onTap: () => _openAchievements(
                    context,
                    currentLang: currentLang,
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
    WidgetRef ref,
  ) {
    final user = Supabase.instance.client.auth.currentUser;
    final userMetadata = user?.userMetadata ?? {};
    final isGoogleUser = user?.appMetadata['provider'] == 'google';
    final isPasswordUpgraded = isGoogleUser || (userMetadata['password_upgraded_v1'] == true);

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
              Align(
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
              Text(
                AppTranslations.get('security', currentLang),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@$accountUsername',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // DYNAMIC 3D SECURITY STATUS CARD
              if (!isPasswordUpgraded) ...[
                // Gold Warning Card for accounts requiring upgrade
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AetronColors.panelHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AetronColors.gold.withValues(alpha: 0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AetronColors.gold.withValues(alpha: 0.12),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AetronColors.gold.withValues(alpha: 0.15),
                              border: Border.all(color: AetronColors.gold.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.security_update_good_rounded, color: AetronColors.gold, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppTranslations.get('security_upgrade_title', currentLang),
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AetronColors.gold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppTranslations.get('security_upgrade_desc', currentLang),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: AetronColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Aetron3DPrimaryButton(
                        label: AppTranslations.get('update_password_action', currentLang),
                        icon: Icons.lock_reset_rounded,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showUpdatePasswordSheet(context, currentLang);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Mint Green Optimal Security Card when password is up to date
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AetronColors.panelHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AetronColors.mint.withValues(alpha: 0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AetronColors.mint.withValues(alpha: 0.12),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AetronColors.mint.withValues(alpha: 0.15),
                          border: Border.all(color: AetronColors.mint.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: AetronColors.mint, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentLang == AppLanguage.vi
                                  ? 'BẢO MẬT ĐÃ ĐẠT CHUẨN TỐI ƯU'
                                  : 'STRONG SECURITY ACTIVE',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AetronColors.mint,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentLang == AppLanguage.vi
                                  ? 'Tài khoản đã được bảo vệ với mật khẩu đủ tiêu chuẩn mạnh (chữ hoa, thường, số, ký tự đặc biệt).'
                                  : 'Your account is protected with strong password security standards.',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                color: AetronColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _SecurityOption(
                icon: Icons.shield_rounded,
                title: currentLang == AppLanguage.vi
                    ? 'Đổi mật khẩu mới'
                    : 'Change password',
                subtitle: currentLang == AppLanguage.vi
                    ? 'Cập nhật lại mật khẩu đăng nhập tài khoản.'
                    : 'Update your account login password.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showUpdatePasswordSheet(context, currentLang);
                },
              ),
              const SizedBox(height: 10),
              _SecurityOption(
                icon: Icons.account_circle_outlined,
                title: currentLang == AppLanguage.vi
                    ? 'Khôi phục qua Google Gmail'
                    : 'Google Gmail recovery',
                subtitle: currentLang == AppLanguage.vi
                    ? 'Liên kết tài khoản Google để khôi phục khi quên mật khẩu.'
                    : 'Link a Google account to sign back in if you lose access.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showGoogleGmailRecoverySheet(context);
                },
              ),
              const SizedBox(height: 10),
              _SecurityOption(
                icon: Icons.person_remove_rounded,
                title: currentLang == AppLanguage.vi
                    ? 'Xóa tài khoản vĩnh viễn'
                    : 'Delete account permanently',
                subtitle: currentLang == AppLanguage.vi
                    ? 'Xóa vĩnh viễn dữ liệu tài khoản và toàn bộ lịch sử tập luyện.'
                    : 'Permanently remove your account and all workout records.',
                iconColor: _red,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeleteAccount(context, currentLang, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AppLanguage lang,
    WidgetRef ref,
  ) async {
    final isVi = lang == AppLanguage.vi;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: _red.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.warning_amber_rounded, color: _red, size: 22),
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
            color: _muted,
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
                color: _muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
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
                  border: Border.all(color: _red.withValues(alpha: 0.4), width: 1.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _red),
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

  void _showUpdatePasswordSheet(BuildContext context, AppLanguage currentLang) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpdatePasswordSheet(currentLang: currentLang),
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
    required AppLanguage currentLang,
    required int totalWorkouts,
    required int currentStreak,
    required int longestStreak,
    required double totalDistanceKm,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AchievementsScreen(),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AetronLogoutDialog.show(context);
    if (confirmed == true && context.mounted) {
      ref.invalidate(workoutListProvider);
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
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
    final avatarDisplay = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? imageProvider = avatarDisplay.imageProvider;
    final memberSince = _formatDate(
      profile?.createdAt ?? _parseDate(user?.createdAt),
      currentLang,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88,
                height: 88,
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
                      avatarDisplay.localPath ?? avatarDisplay.remoteUrl ?? 'default-avatar',
                    ),
                    width: 68,
                    height: 68,
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
          InkWell(
            onTap: () => showEditDisplayNameSheet(
              context,
              currentName: _athleteDisplayName(user),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _athleteDisplayName(user),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _cyan.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: _cyan,
                    ),
                  ),
                ],
              ),
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
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AetronColors.panelHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: AetronColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AetronColors.textSecondary,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              color: color,
              fontSize: 10,
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
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
      ),
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
    ) async {
      try {
        await Supabase.instance.client.auth.getUser();
      } catch (_) {}
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
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

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
  final meta = user?.userMetadata;
  final displayName = (meta?['display_name'] ?? meta?['full_name'] ?? meta?['name']) as String?;
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

class _UpdatePasswordSheet extends StatefulWidget {
  final AppLanguage currentLang;

  const _UpdatePasswordSheet({required this.currentLang});

  @override
  State<_UpdatePasswordSheet> createState() => _UpdatePasswordSheetState();
}

class _UpdatePasswordSheetState extends State<_UpdatePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
          data: {'password_upgraded_v1': true},
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.get('password_updated_success', widget.currentLang),
          ),
          backgroundColor: AetronColors.mint,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = widget.currentLang == AppLanguage.vi
            ? 'Không thể cập nhật mật khẩu. Vui lòng thử lại.'
            : 'Could not update password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.currentLang;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AetronColors.panelHigh,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AetronColors.cyan, width: 1.2)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
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
                Text(
                  AppTranslations.get('security_upgrade_title', lang),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTranslations.get('security_upgrade_desc', lang),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),

                // New Password Field
                Text(
                  AppTranslations.get('new_password', lang).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.cyanSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  validator: (val) => validatePasswordStrict(val, lang),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                      fontFamily: 'Outfit',
                      color: AetronColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: AetronColors.space,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AetronColors.cyanSoft, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AetronColors.cyanSoft,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AetronColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AetronColors.cyan, width: 1.5),
                    ),
                  ),
                ),
                PasswordSecurityMeter(
                  password: _passwordController.text,
                  lang: lang,
                ),
                const SizedBox(height: 12),

                // Confirm New Password
                Text(
                  AppTranslations.get('confirm_password', lang).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.cyanSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AetronColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return AppTranslations.get('password_mismatch', lang);
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                      fontFamily: 'Outfit',
                      color: AetronColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: AetronColors.space,
                    prefixIcon: const Icon(Icons.lock_clock_outlined, color: AetronColors.cyanSoft, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AetronColors.cyanSoft,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AetronColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AetronColors.cyan, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AetronColors.danger, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],

                Aetron3DPrimaryButton(
                  label: AppTranslations.get('update_password_action', lang),
                  icon: Icons.shield_rounded,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _updatePassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
