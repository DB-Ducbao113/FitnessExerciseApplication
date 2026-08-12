import 'dart:math';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';

class NotificationPayload {
  static const openActivity = 'open_activity';
  static const openGoal = 'open_goal';
  static const openAnalytics = 'open_analytics';
}

class NotificationContent {
  const NotificationContent({
    required this.title,
    required this.body,
    required this.payload,
  });

  final String title;
  final String body;
  final String payload;
}

/// Dynamic notification message variants builder incorporating real metric values.
class NotificationMessageBuilder {
  const NotificationMessageBuilder._();

  static final _random = Random();

  // --- WORKOUT REMINDERS ---
  static NotificationContent buildWorkoutReminder(AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      final titles = [
        'Sẵn sàng vận động chưa? 🏃',
        'Đã đến lúc tập luyện! 🔥',
        'Bài tập tiếp theo đang chờ bạn 💪',
      ];
      final bodies = [
        'Bạn chưa ghi nhận buổi tập nào hôm nay. Cùng giữ vững phong độ nhé!',
        'Hãy dành 15 phút tập luyện để tiếp thêm năng lượng cho ngày mới.',
        'Đừng ngần ngại! Khởi động bài tập ngay hôm nay nào.',
      ];
      final idx = _random.nextInt(titles.length);
      return NotificationContent(
        title: titles[idx],
        body: bodies[idx],
        payload: NotificationPayload.openActivity,
      );
    } else {
      final titles = [
        'Ready to move? 🏃',
        'Time to get active! 🔥',
        'Your next workout is waiting 💪',
      ];
      final bodies = [
        "You haven't logged a workout today. Lace up and keep moving!",
        'A quick 15-minute session will boost your energy for the day.',
        'Keep momentum going — log your workout session today.',
      ];
      final idx = _random.nextInt(titles.length);
      return NotificationContent(
        title: titles[idx],
        body: bodies[idx],
        payload: NotificationPayload.openActivity,
      );
    }
  }

  // --- GOAL PROGRESS NOTIFICATIONS ---
  static NotificationContent buildGoalProgress({
    required AppLanguage lang,
    required double remainingValue,
    required String unit,
  }) {
    final formattedVal = remainingValue.toStringAsFixed(1);
    if (lang == AppLanguage.vi) {
      return NotificationContent(
        title: 'Bạn đã rất gần mục tiêu rồi! 🔥',
        body: 'Chỉ còn $formattedVal $unit nữa thôi là hoàn thành mục tiêu hôm nay.',
        payload: NotificationPayload.openGoal,
      );
    } else {
      return NotificationContent(
        title: "You're almost there! 🔥",
        body: 'Just $formattedVal $unit left to reach today\'s target.',
        payload: NotificationPayload.openGoal,
      );
    }
  }

  // --- EVENING CHECK-IN ---
  static NotificationContent buildEveningCheckIn({
    required AppLanguage lang,
    required int progressPercentage,
  }) {
    if (lang == AppLanguage.vi) {
      return NotificationContent(
        title: 'Kết thúc ngày thật mạnh mẽ! 💪',
        body: 'Bạn đã đạt $progressPercentage% mục tiêu hôm nay. Hãy kiểm tra tiến độ của mình nhé!',
        payload: NotificationPayload.openAnalytics,
      );
    } else {
      return NotificationContent(
        title: 'Finish your day strong 💪',
        body: "You're $progressPercentage% toward today's target. Check out your summary!",
        payload: NotificationPayload.openAnalytics,
      );
    }
  }

  // --- INACTIVITY REMINDER ---
  static NotificationContent buildInactivityReminder(AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      return NotificationContent(
        title: 'Đã đến lúc vận động rồi 🚶',
        body: 'Một chuyến đi bộ ngắn sẽ giúp bạn duy trì thể lực và tinh thần thoải mái.',
        payload: NotificationPayload.openActivity,
      );
    } else {
      return NotificationContent(
        title: 'Time to move? 🚶',
        body: 'A short walk can help you stay on track and refresh your mind today.',
        payload: NotificationPayload.openActivity,
      );
    }
  }

  // --- ACHIEVEMENT NOTIFICATION ---
  static NotificationContent buildAchievement(AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      return NotificationContent(
        title: 'Mục tiêu hoàn thành! 🎉',
        body: 'Chúc mừng! Bạn đã chinh phục thành công chỉ số tiêu chuẩn hôm nay.',
        payload: NotificationPayload.openAnalytics,
      );
    } else {
      return NotificationContent(
        title: 'Goal complete! 🎉',
        body: 'Awesome work! You reached your daily target session.',
        payload: NotificationPayload.openAnalytics,
      );
    }
  }

  // --- STREAK REMINDER ---
  static NotificationContent buildStreakReminder({
    required AppLanguage lang,
    required int currentStreak,
  }) {
    if (lang == AppLanguage.vi) {
      return NotificationContent(
        title: 'Giữ vững chuỗi $currentStreak ngày tập! 🔥',
        body: 'Hoàn thành 1 bài tập hôm nay để duy trì chuỗi thành tích ấn tượng của bạn.',
        payload: NotificationPayload.openActivity,
      );
    } else {
      return NotificationContent(
        title: "Don't break your $currentStreak-day streak 🔥",
        body: 'Complete a workout today to keep your streak alive and strong!',
        payload: NotificationPayload.openActivity,
      );
    }
  }
}
