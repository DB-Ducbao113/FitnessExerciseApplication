import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TrainingReminderService {
  TrainingReminderService._();

  static final instance = TrainingReminderService._();
  static const notificationId = 7301;
  static const _channelId = 'training_reminders';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _available = true;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (error) {
      // This platform channel may be unavailable until a full native rebuild.
      // Keep startup resilient and avoid scheduling at an incorrect timezone.
      debugPrint('[TrainingReminder] Timezone unavailable: $error');
      _available = false;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _notifications.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      _initialized = true;
    } catch (error) {
      debugPrint('[TrainingReminder] Notifications unavailable: $error');
      _available = false;
    }
  }

  /// Requests permission only. The server decides whether and when a
  /// personalized reminder should be delivered for each athlete.
  Future<bool> enableNotifications() async {
    if (kIsWeb) return false;
    await initialize();
    if (!_available) return false;
    return _requestPermission();
  }
  Future<bool> enableDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return false;
    await initialize();
    if (!_available) return false;
    if (!await _requestPermission()) return false;
    await scheduleDailyReminder(hour: hour, minute: minute);
    return true;
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;
    await _notifications.zonedSchedule(
      id: notificationId,
      title: 'Have you recorded your run today?',
      body: 'You have not recorded a run today. Lace up and keep your streak moving.',
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Training reminders',
          channelDescription: 'Daily reminders to start a workout in Aetron.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'open_activity',
    );
  }

  Future<void> disableDailyReminder() async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;
    await _notifications.cancel(id: notificationId);
  }

  /// Reads the actual operating-system setting instead of trusting a saved
  /// in-app preference. iPhone notification access can change in Settings.
  Future<bool> areNotificationsAllowed() async {
    if (kIsWeb) return false;
    await initialize();
    if (!_available) return false;

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios == null) return true;

    final permissions = await ios.checkPermissions();
    return permissions?.isEnabled ?? false;
  }

  Future<bool> _requestPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidAllowed = await android?.requestNotificationsPermission();
    if (androidAllowed == false) return false;

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosAllowed = await ios?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );
    return iosAllowed ?? true;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
