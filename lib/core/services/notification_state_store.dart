import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistence store for notification delivery state and metadata.
/// Uses SharedPreferences to prevent duplicate notifications across app restarts.
class NotificationStateStore {
  NotificationStateStore._();

  static final instance = NotificationStateStore._();

  static const _kLastWorkoutReminderDate =
      'notif_store.last_workout_reminder_date';
  static const _kLastGoalProgressDate =
      'notif_store.last_goal_progress_date';
  static const _kLastEveningNotificationDate =
      'notif_store.last_evening_date';
  static const _kLastInactivityTimestamp =
      'notif_store.last_inactivity_timestamp';
  static const _kLastAchievementDate =
      'notif_store.last_achievement_date';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // --- WORKOUT REMINDER DATE ---
  Future<void> markWorkoutReminderSentToday() async {
    await init();
    await _prefs.setString(_kLastWorkoutReminderDate, _todayString());
  }

  bool isWorkoutReminderSentToday() {
    if (!_initialized) return false;
    return _prefs.getString(_kLastWorkoutReminderDate) == _todayString();
  }

  // --- GOAL PROGRESS NOTIFICATION DATE ---
  Future<void> markGoalProgressSentToday() async {
    await init();
    await _prefs.setString(_kLastGoalProgressDate, _todayString());
  }

  bool isGoalProgressSentToday() {
    if (!_initialized) return false;
    return _prefs.getString(_kLastGoalProgressDate) == _todayString();
  }

  // --- EVENING CHECK-IN DATE ---
  Future<void> markEveningNotificationSentToday() async {
    await init();
    await _prefs.setString(_kLastEveningNotificationDate, _todayString());
  }

  bool isEveningNotificationSentToday() {
    if (!_initialized) return false;
    return _prefs.getString(_kLastEveningNotificationDate) == _todayString();
  }

  // --- INACTIVITY NOTIFICATION TIMESTAMP & COOLDOWN (12 HOURS) ---
  Future<void> markInactivityNotificationSent() async {
    await init();
    await _prefs.setInt(
      _kLastInactivityTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool isInactivityCooldownActive({int cooldownHours = 12}) {
    if (!_initialized) return false;
    final lastTs = _prefs.getInt(_kLastInactivityTimestamp);
    if (lastTs == null) return false;
    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTs);
    final diff = DateTime.now().difference(lastTime);
    return diff.inHours < cooldownHours;
  }

  // --- ACHIEVEMENT NOTIFICATION DATE ---
  Future<void> markAchievementSentToday() async {
    await init();
    await _prefs.setString(_kLastAchievementDate, _todayString());
  }

  bool isAchievementSentToday() {
    if (!_initialized) return false;
    return _prefs.getString(_kLastAchievementDate) == _todayString();
  }
}
