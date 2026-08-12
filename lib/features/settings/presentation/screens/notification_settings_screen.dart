import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/notification_scheduler.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/notification_settings_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/settings_section.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _masterEnabled = true;
  bool _workoutReminders = true;
  String _morningTime = '08:00';
  bool _goalProgress = true;
  bool _eveningCheckIn = true;
  String _eveningTime = '20:00';
  bool _achievements = true;
  bool _streakReminders = true;
  bool _inactivityReminders = true;
  bool _quietHours = true;
  String _quietStart = '22:00';
  String _quietEnd = '07:00';

  bool _isOsAllowed = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final allowed =
        await NotificationService.instance.areNotificationsAllowed();

    if (!mounted) return;
    setState(() {
      _masterEnabled = prefs.getBool(kNotificationsPrefKey) ?? true;
      _workoutReminders = prefs.getBool(kWorkoutRemindersPrefKey) ?? true;
      _morningTime = prefs.getString(kMorningTimePrefKey) ?? '08:00';
      _goalProgress = prefs.getBool(kGoalProgressPrefKey) ?? true;
      _eveningCheckIn = prefs.getBool(kEveningCheckInPrefKey) ?? true;
      _eveningTime = prefs.getString(kEveningTimePrefKey) ?? '20:00';
      _achievements = prefs.getBool(kAchievementPrefKey) ?? true;
      _streakReminders = prefs.getBool(kStreakRemindersPrefKey) ?? true;
      _inactivityReminders =
          prefs.getBool(kInactivityRemindersPrefKey) ?? true;
      _quietHours = prefs.getBool(kQuietHoursPrefKey) ?? true;
      _quietStart = prefs.getString(kQuietHoursStartPrefKey) ?? '22:00';
      _quietEnd = prefs.getString(kQuietHoursEndPrefKey) ?? '07:00';
      _isOsAllowed = allowed;
      _loading = false;
    });
  }

  Future<void> _updatePrefBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    _triggerScheduler();
  }

  Future<void> _updatePrefString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    _triggerScheduler();
  }

  void _triggerScheduler() {
    ref.invalidate(notificationSettingsProvider);
    ref.invalidate(notificationsPreferenceProvider);

    final lang = ref.read(appLanguageProvider);
    final workouts = ref.read(workoutListProvider).valueOrNull ?? [];
    final activeGoal = ref.read(userGoalProvider).valueOrNull;
    final streak = ref.read(streakProvider).currentStreak;
    final useMetric = ref.read(metricUnitsPreferenceProvider).value ?? true;

    NotificationScheduler.refreshSchedules(
      notificationsEnabled: _masterEnabled,
      workoutRemindersEnabled: _workoutReminders,
      morningReminderTime: _morningTime,
      goalProgressEnabled: _goalProgress,
      eveningCheckInEnabled: _eveningCheckIn,
      eveningCheckInTime: _eveningTime,
      achievementEnabled: _achievements,
      streakRemindersEnabled: _streakReminders,
      inactivityRemindersEnabled: _inactivityReminders,
      quietHoursEnabled: _quietHours,
      quietHoursStart: _quietStart,
      quietHoursEnd: _quietEnd,
      lang: lang,
      workouts: workouts,
      activeGoal: activeGoal,
      currentStreak: streak,
      useMetricUnits: useMetric,
    );
  }

  Future<void> _pickTime(String current, Function(String) onPicked) async {
    final parts = current.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AetronColors.cyan,
              surface: AetronColors.panelHigh,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onPicked(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AetronColors.background,
      body: AetronBackground(
        withGrid: false,
        child: SafeArea(
          child: Column(
            children: [
              AetronHeader(
                title: 'NOTIFICATIONS',
                eyebrow: 'ALERT & REMINDER SETTINGS',
                leading: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AetronColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: LoadingState(label: 'LOADING PREFERENCES'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AetronSpacing.page),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // OS Permission Card if disabled
                            if (!_isOsAllowed) ...[
                              AppCard(
                                padding: const EdgeInsets.all(AetronSpacing.md),
                                borderColor: AetronColors.warning,
                                backgroundColor: AetronColors.panel,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.notifications_off_rounded,
                                      color: AetronColors.warning,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AetronSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Notifications disabled in OS Settings',
                                            style: AetronTypography.headingSmall.copyWith(
                                              color: AetronColors.textPrimary,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Allow notifications in your phone settings to receive reminders.',
                                            style: AetronTypography.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => openAppSettings(),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AetronColors.cyan,
                                      ),
                                      child: const Text('OPEN'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AetronSpacing.lg),
                            ],

                             // Master Switch Card
                            AppCard(
                              padding: const EdgeInsets.all(AetronSpacing.md),
                              borderColor: _masterEnabled ? AetronColors.cyan : AetronColors.borderSubtle,
                              child: SwitchListTile(
                                value: _masterEnabled,
                                activeThumbColor: AetronColors.cyan,
                                title: Text(
                                  currentLang == AppLanguage.vi ? 'Cho phép Thông báo' : 'Allow Notifications',
                                  style: AetronTypography.headingMedium.copyWith(
                                    color: AetronColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  currentLang == AppLanguage.vi
                                      ? 'Bật hoặc tắt tất cả các thông báo nhắc nhở thể thao'
                                      : 'Enable or disable all fitness reminders & alerts',
                                  style: AetronTypography.bodySmall,
                                ),
                                onChanged: (val) {
                                  setState(() => _masterEnabled = val);
                                  _updatePrefBool(kNotificationsPrefKey, val);
                                },
                              ),
                            ),
                            const SizedBox(height: AetronSpacing.lg),

                            // LIVE NOTIFICATION PREVIEW CARD
                            SectionHeader(
                              title: currentLang == AppLanguage.vi ? 'XEM TRƯỚC THÔNG BÁO' : 'NOTIFICATION PREVIEW',
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: AetronSpacing.xs),
                            _NotificationPreviewCard(
                              enabled: _masterEnabled,
                              morningTime: _morningTime,
                            ),
                            const SizedBox(height: AetronSpacing.lg),

                            // GRANULAR CATEGORIES
                            SettingsSection(
                              title: currentLang == AppLanguage.vi ? 'DANH MỤC NHẮC NHỞ' : 'REMINDER CATEGORIES',
                              children: [
                                // Workout Reminders
                                SwitchListTile(
                                  value: _workoutReminders,
                                  activeThumbColor: AetronColors.cyan,
                                  title: Text(
                                    currentLang == AppLanguage.vi ? 'Nhắc nhở tập luyện' : 'Workout Reminders',
                                    style: AetronTypography.headingSmall.copyWith(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    currentLang == AppLanguage.vi
                                        ? 'Nhắc nhở buổi sáng lúc $_morningTime'
                                        : 'Morning reminder at $_morningTime',
                                    style: AetronTypography.bodySmall,
                                  ),
                                  onChanged: _masterEnabled
                                      ? (val) {
                                          setState(() => _workoutReminders = val);
                                          _updatePrefBool(kWorkoutRemindersPrefKey, val);
                                        }
                                      : null,
                                ),
                                if (_workoutReminders && _masterEnabled)
                                  ListTile(
                                    title: Text(
                                      currentLang == AppLanguage.vi ? 'Giờ nhắc nhở buổi sáng' : 'Morning Reminder Time',
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                    trailing: ActionChip(
                                      label: Text(_morningTime, style: const TextStyle(color: AetronColors.cyan, fontWeight: FontWeight.bold)),
                                      backgroundColor: AetronColors.panelHigh,
                                      onPressed: () => _pickTime(_morningTime, (val) {
                                        setState(() => _morningTime = val);
                                        _updatePrefString(kMorningTimePrefKey, val);
                                      }),
                                    ),
                                  ),
                                const Divider(height: 1),

                                // Goal Progress
                                SwitchListTile(
                                  value: _goalProgress,
                                  activeThumbColor: AetronColors.cyan,
                                  title: Text(
                                    currentLang == AppLanguage.vi ? 'Cập nhật tiến độ mục tiêu' : 'Goal Progress Updates',
                                    style: AetronTypography.headingSmall.copyWith(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    'Afternoon check-in on active targets',
                                    style: AetronTypography.bodySmall,
                                  ),
                                  onChanged: _masterEnabled
                                      ? (val) {
                                          setState(() => _goalProgress = val);
                                          _updatePrefBool(kGoalProgressPrefKey, val);
                                        }
                                      : null,
                                ),
                                const Divider(height: 1),

                                // Evening Check-in
                                SwitchListTile(
                                  value: _eveningCheckIn,
                                  activeThumbColor: AetronColors.cyan,
                                  title: Text(
                                    'Evening Check-in',
                                    style: AetronTypography.headingSmall.copyWith(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    'Summary at $_eveningTime',
                                    style: AetronTypography.bodySmall,
                                  ),
                                  onChanged: _masterEnabled
                                      ? (val) {
                                          setState(() => _eveningCheckIn = val);
                                          _updatePrefBool(kEveningCheckInPrefKey, val);
                                        }
                                      : null,
                                ),
                                const Divider(height: 1),

                                // Achievement
                                SwitchListTile(
                                  value: _achievements,
                                  activeThumbColor: AetronColors.cyan,
                                  title: Text(
                                    'Achievement & Goal Complete',
                                    style: AetronTypography.headingSmall.copyWith(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    'Instant alerts when you hit a target',
                                    style: AetronTypography.bodySmall,
                                  ),
                                  onChanged: _masterEnabled
                                      ? (val) {
                                          setState(() => _achievements = val);
                                          _updatePrefBool(kAchievementPrefKey, val);
                                        }
                                      : null,
                                ),
                                const Divider(height: 1),

                                // Streak Reminders
                                SwitchListTile(
                                  value: _streakReminders,
                                  activeThumbColor: AetronColors.cyan,
                                  title: Text(
                                    'Streak Protection Alerts',
                                    style: AetronTypography.headingSmall.copyWith(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    'Alerts when active streak is at risk',
                                    style: AetronTypography.bodySmall,
                                  ),
                                  onChanged: _masterEnabled
                                      ? (val) {
                                          setState(() => _streakReminders = val);
                                          _updatePrefBool(kStreakRemindersPrefKey, val);
                                        }
                                      : null,
                                ),
                                const Divider(height: 1),

                                // Inactivity Reminders
                                SwitchListTile(
                                  value: _inactivityReminders,
                                  activeThumbColor: AetronColors.cyan,
                                  title: Text(
                                    'Inactivity Reminders',
                                    style: AetronTypography.headingSmall.copyWith(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    'Alerts when no workout recorded for 48h (12h cooldown)',
                                    style: AetronTypography.bodySmall,
                                  ),
                                  onChanged: _masterEnabled
                                      ? (val) {
                                          setState(() => _inactivityReminders = val);
                                          _updatePrefBool(kInactivityRemindersPrefKey, val);
                                        }
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: AetronSpacing.lg),

                            // QUIET HOURS
                            SettingsSection(
                              title: 'QUIET HOURS',
                              children: [
                                SwitchListTile(
                                  value: _quietHours,
                                  activeThumbColor: AetronColors.cyan,
                                  title: Text(
                                    'Do Not Disturb Window',
                                    style: AetronTypography.headingSmall.copyWith(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '$_quietStart — $_quietEnd (Suppresses non-critical alerts)',
                                    style: AetronTypography.bodySmall,
                                  ),
                                  onChanged: _masterEnabled
                                      ? (val) {
                                          setState(() => _quietHours = val);
                                          _updatePrefBool(kQuietHoursPrefKey, val);
                                        }
                                      : null,
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
      ),
    );
  }
}

class _NotificationPreviewCard extends StatelessWidget {
  const _NotificationPreviewCard({
    required this.enabled,
    required this.morningTime,
  });

  final bool enabled;
  final String morningTime;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AetronSpacing.md),
      backgroundColor: AetronColors.panelHigh,
      borderColor: AetronColors.cyan.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AetronColors.cyan,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: AetronColors.space,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AETRON',
                style: AetronTypography.caption.copyWith(
                  color: AetronColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                morningTime,
                style: AetronTypography.caption.copyWith(
                  color: AetronColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            enabled ? 'Ready to move? 🏃' : 'Notifications Paused',
            style: AetronTypography.headingSmall.copyWith(
              color: enabled ? AetronColors.textPrimary : AetronColors.textSecondary,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            enabled
                ? "You haven't logged a workout today. Lace up and keep moving!"
                : 'Turn on notifications to receive workout reminders and goal achievements.',
            style: AetronTypography.bodySmall.copyWith(
              color: AetronColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
