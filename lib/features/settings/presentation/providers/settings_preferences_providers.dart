import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kNotificationsPrefKey = 'settings.notifications.enabled';
const kTrainingReminderMinutesPrefKey =
    'settings.notifications.reminder_minutes';
const kMetricUnitsPrefKey = 'settings.units.metric';

final metricUnitsPreferenceProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kMetricUnitsPrefKey) ?? true;
});

final notificationsPreferenceProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kNotificationsPrefKey) ?? false;
});
