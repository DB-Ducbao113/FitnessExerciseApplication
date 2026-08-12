import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kWorkoutRemindersPrefKey = 'settings.notifications.workout_reminders';
const kMorningTimePrefKey = 'settings.notifications.morning_time';
const kGoalProgressPrefKey = 'settings.notifications.goal_progress';
const kEveningCheckInPrefKey = 'settings.notifications.evening_checkin';
const kEveningTimePrefKey = 'settings.notifications.evening_time';
const kAchievementPrefKey = 'settings.notifications.achievement';
const kStreakRemindersPrefKey = 'settings.notifications.streak_reminders';
const kInactivityRemindersPrefKey = 'settings.notifications.inactivity_reminders';
const kQuietHoursPrefKey = 'settings.notifications.quiet_hours';
const kQuietHoursStartPrefKey = 'settings.notifications.quiet_hours_start';
const kQuietHoursEndPrefKey = 'settings.notifications.quiet_hours_end';

class NotificationSettingsData {
  const NotificationSettingsData({
    required this.workoutRemindersEnabled,
    required this.morningTime,
    required this.goalProgressEnabled,
    required this.eveningCheckInEnabled,
    required this.eveningTime,
    required this.achievementEnabled,
    required this.streakRemindersEnabled,
    required this.inactivityRemindersEnabled,
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
  });

  final bool workoutRemindersEnabled;
  final String morningTime;
  final bool goalProgressEnabled;
  final bool eveningCheckInEnabled;
  final String eveningTime;
  final bool achievementEnabled;
  final bool streakRemindersEnabled;
  final bool inactivityRemindersEnabled;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
}

final notificationSettingsProvider =
    FutureProvider<NotificationSettingsData>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return NotificationSettingsData(
    workoutRemindersEnabled: prefs.getBool(kWorkoutRemindersPrefKey) ?? true,
    morningTime: prefs.getString(kMorningTimePrefKey) ?? '08:00',
    goalProgressEnabled: prefs.getBool(kGoalProgressPrefKey) ?? true,
    eveningCheckInEnabled: prefs.getBool(kEveningCheckInPrefKey) ?? true,
    eveningTime: prefs.getString(kEveningTimePrefKey) ?? '20:00',
    achievementEnabled: prefs.getBool(kAchievementPrefKey) ?? true,
    streakRemindersEnabled: prefs.getBool(kStreakRemindersPrefKey) ?? true,
    inactivityRemindersEnabled: prefs.getBool(kInactivityRemindersPrefKey) ?? true,
    quietHoursEnabled: prefs.getBool(kQuietHoursPrefKey) ?? true,
    quietHoursStart: prefs.getString(kQuietHoursStartPrefKey) ?? '22:00',
    quietHoursEnd: prefs.getString(kQuietHoursEndPrefKey) ?? '07:00',
  );
});
