import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/notification_message_builder.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/core/services/notification_state_store.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationScheduler {
  const NotificationScheduler._();

  static const idWorkoutReminder = 101;
  static const idGoalProgress = 102;
  static const idEveningCheckIn = 103;
  static const idInactivityReminder = 104;
  static const idAchievement = 105;

  /// Main state-aware scheduler evaluator called on app launch, resume, or state change.
  static Future<void> refreshSchedules({
    required bool notificationsEnabled,
    required bool workoutRemindersEnabled,
    required String morningReminderTime, // '08:00'
    required bool goalProgressEnabled,
    required bool eveningCheckInEnabled,
    required String eveningCheckInTime, // '20:00'
    required bool achievementEnabled,
    required bool streakRemindersEnabled,
    required bool inactivityRemindersEnabled,
    required bool quietHoursEnabled,
    required String quietHoursStart, // '22:00'
    required String quietHoursEnd, // '07:00'
    required AppLanguage lang,
    required List<WorkoutSession> workouts,
    required UserGoal? activeGoal,
    required int currentStreak,
    required bool useMetricUnits,
  }) async {
    final service = NotificationService.instance;
    final store = NotificationStateStore.instance;
    await store.init();

    if (!notificationsEnabled) {
      await service.cancelAll();
      debugPrint('[NotificationScheduler] Notifications disabled. Cancelled all.');
      return;
    }

    final now = DateTime.now();
    final todayWorkouts = workouts.where((w) {
      return w.startedAt.year == now.year &&
          w.startedAt.month == now.month &&
          w.startedAt.day == now.day;
    }).toList();
    final completedWorkoutToday = todayWorkouts.isNotEmpty;

    // --- 1. MORNING WORKOUT REMINDER ---
    if (workoutRemindersEnabled && !completedWorkoutToday && !store.isWorkoutReminderSentToday()) {
      final morningParts = morningReminderTime.split(':');
      final hour = int.tryParse(morningParts[0]) ?? 8;
      final minute = int.tryParse(morningParts[1]) ?? 0;
      final targetDate = _computeNextDate(hour, minute, quietHoursEnabled, quietHoursStart, quietHoursEnd);
      final content = NotificationMessageBuilder.buildWorkoutReminder(lang);

      await service.scheduleZoned(
        id: idWorkoutReminder,
        title: content.title,
        body: content.body,
        scheduledDate: targetDate,
        payload: content.payload,
      );
    } else {
      await service.cancel(idWorkoutReminder);
    }

    // --- 2. GOAL PROGRESS NOTIFICATION (Evaluated at scheduled afternoon time) ---
    if (goalProgressEnabled && activeGoal != null && !store.isGoalProgressSentToday()) {
      final (totalValue, targetValue) = _calculateGoalProgress(activeGoal, workouts);
      final remaining = (targetValue - totalValue).clamp(0.0, 99999.0);
      final isGoalHit = totalValue >= targetValue && targetValue > 0;

      if (!isGoalHit && remaining > 0) {
        final targetDate = _computeNextDate(14, 0, quietHoursEnabled, quietHoursStart, quietHoursEnd);
        final unitLabel = _goalUnitLabel(activeGoal.goalType, useMetricUnits);
        final content = NotificationMessageBuilder.buildGoalProgress(
          lang: lang,
          remainingValue: remaining,
          unit: unitLabel,
        );

        await service.scheduleZoned(
          id: idGoalProgress,
          title: content.title,
          body: content.body,
          scheduledDate: targetDate,
          payload: content.payload,
          isAchievement: true,
        );
      } else {
        await service.cancel(idGoalProgress);
      }
    } else {
      await service.cancel(idGoalProgress);
    }

    // --- 3. EVENING CHECK-IN & STREAK REMINDER ---
    if (eveningCheckInEnabled && !store.isEveningNotificationSentToday()) {
      final eveningParts = eveningCheckInTime.split(':');
      final hour = int.tryParse(eveningParts[0]) ?? 20;
      final minute = int.tryParse(eveningParts[1]) ?? 0;
      final targetDate = _computeNextDate(hour, minute, quietHoursEnabled, quietHoursStart, quietHoursEnd);

      if (streakRemindersEnabled && currentStreak > 0 && !completedWorkoutToday) {
        final content = NotificationMessageBuilder.buildStreakReminder(
          lang: lang,
          currentStreak: currentStreak,
        );
        await service.scheduleZoned(
          id: idEveningCheckIn,
          title: content.title,
          body: content.body,
          scheduledDate: targetDate,
          payload: content.payload,
        );
      } else if (activeGoal != null) {
        final (totalVal, targetVal) = _calculateGoalProgress(activeGoal, workouts);
        final pct = targetVal <= 0 ? 0 : ((totalVal / targetVal) * 100).clamp(0, 100).round();
        if (pct < 100) {
          final content = NotificationMessageBuilder.buildEveningCheckIn(
            lang: lang,
            progressPercentage: pct,
          );
          await service.scheduleZoned(
            id: idEveningCheckIn,
            title: content.title,
            body: content.body,
            scheduledDate: targetDate,
            payload: content.payload,
          );
        }
      }
    } else {
      await service.cancel(idEveningCheckIn);
    }

    // --- 4. INACTIVITY REMINDER (12H Cooldown + 48H Inactivity Threshold) ---
    if (inactivityRemindersEnabled && !store.isInactivityCooldownActive(cooldownHours: 12)) {
      final lastWorkoutDate = workouts.isEmpty ? null : workouts.first.startedAt;
      final hoursInactive = lastWorkoutDate == null
          ? 72
          : now.difference(lastWorkoutDate).inHours;

      if (hoursInactive >= 48) {
        final targetDate = _computeNextDate(10, 0, quietHoursEnabled, quietHoursStart, quietHoursEnd);
        final content = NotificationMessageBuilder.buildInactivityReminder(lang);

        await service.scheduleZoned(
          id: idInactivityReminder,
          title: content.title,
          body: content.body,
          scheduledDate: targetDate,
          payload: content.payload,
        );
      }
    } else {
      await service.cancel(idInactivityReminder);
    }

    // --- 5. INSTANT ACHIEVEMENT CHECK ---
    if (achievementEnabled && activeGoal != null && !store.isAchievementSentToday()) {
      final (totalVal, targetVal) = _calculateGoalProgress(activeGoal, workouts);
      if (totalVal >= targetVal && targetVal > 0) {
        final content = NotificationMessageBuilder.buildAchievement(lang);
        await service.showInstant(
          id: idAchievement,
          title: content.title,
          body: content.body,
          payload: content.payload,
        );
        await store.markAchievementSentToday();
      }
    }
  }

  static (double, double) _calculateGoalProgress(
    UserGoal goal,
    List<WorkoutSession> workouts,
  ) {
    final now = DateTime.now();
    final filtered = workouts.where((w) {
      if (goal.period == GoalPeriod.weekly) {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final dayOnly = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return w.startedAt.isAfter(dayOnly);
      } else {
        return w.startedAt.year == now.year && w.startedAt.month == now.month;
      }
    }).toList();

    switch (goal.goalType) {
      case GoalType.distance:
        final sumKm = filtered.fold(0.0, (acc, item) => acc + item.distanceKm);
        return (sumKm, goal.targetValue);
      case GoalType.workouts:
        return (filtered.length.toDouble(), goal.targetValue);
      case GoalType.calories:
        final sumCal = filtered.fold(0.0, (acc, item) => acc + item.caloriesKcal);
        return (sumCal, goal.targetValue);
    }
  }

  static String _goalUnitLabel(GoalType type, bool useMetric) {
    switch (type) {
      case GoalType.distance:
        return useMetric ? 'km' : 'mi';
      case GoalType.workouts:
        return 'workouts';
      case GoalType.calories:
        return 'kcal';
    }
  }

  static tz.TZDateTime _computeNextDate(
    int hour,
    int minute,
    bool quietHoursEnabled,
    String quietStart,
    String quietEnd,
  ) {
    final localNow = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      localNow.year,
      localNow.month,
      localNow.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(localNow)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    if (quietHoursEnabled) {
      final startHour = int.tryParse(quietStart.split(':')[0]) ?? 22;
      final endHour = int.tryParse(quietEnd.split(':')[0]) ?? 7;

      if (scheduled.hour >= startHour || scheduled.hour < endHour) {
        // Adjust scheduled time to 08:00 AM outside quiet hours
        scheduled = tz.TZDateTime(
          tz.local,
          scheduled.year,
          scheduled.month,
          scheduled.day,
          8,
          0,
        );
        if (scheduled.isBefore(localNow)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
      }
    }

    return scheduled;
  }
}
