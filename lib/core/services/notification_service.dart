import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Global Navigator Key for Deep-Link Navigation from Notification Taps.
final GlobalKey<NavigatorState> aetronNavigatorKey =
    GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  static const _channelIdReminders = 'aetron_reminders';
  static const _channelIdAchievements = 'aetron_achievements';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _available = true;

  bool get isAvailable => _available;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (error) {
      debugPrint('[NotificationService] Timezone unavailable: $error');
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
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _initialized = true;
    } catch (error) {
      debugPrint('[NotificationService] Initialization error: $error');
      _available = false;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    debugPrint('[NotificationService] Notification tapped with payload: $payload');
    final navigator = aetronNavigatorKey.currentState;
    if (navigator == null) return;

    switch (payload) {
      case 'open_activity':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ActivityScreen()),
        );
        break;
      case 'open_goal':
        navigator.push(
          MaterialPageRoute(builder: (_) => const GoalScreen()),
        );
        break;
      case 'open_analytics':
        navigator.push(
          MaterialPageRoute(builder: (_) => const StatsScreen()),
        );
        break;
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await initialize();
    if (!_available) return false;

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidAllowed = await android?.requestNotificationsPermission();

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosAllowed = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return (androidAllowed ?? true) && (iosAllowed ?? true);
  }

  Future<bool> areNotificationsAllowed() async {
    if (kIsWeb) return false;
    await initialize();
    if (!_available) return false;

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return true;
  }

  Future<void> scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
    bool isAchievement = false,
  }) async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;

    final channelId =
        isAchievement ? _channelIdAchievements : _channelIdReminders;
    final channelName =
        isAchievement ? 'Achievements & Goals' : 'Workout Reminders';

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      debugPrint('[NotificationService] Scheduled notif #$id for $scheduledDate');
    } catch (e) {
      debugPrint('[NotificationService] Schedule error for #$id: $e');
    }
  }

  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdAchievements,
          'Achievements & Goals',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;
    await _notifications.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;
    await _notifications.cancelAll();
  }
}
