import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticHomeTopBar extends StatelessWidget {
  final ImageProvider? avatarImage;
  final String? initials;
  final String displayName;
  final String greeting;
  final int streakCount;
  final bool isVi;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onStreakTap;
  final VoidCallback? onNotificationTap;

  const KineticHomeTopBar({
    super.key,
    this.avatarImage,
    this.initials,
    required this.displayName,
    required this.greeting,
    required this.streakCount,
    this.isVi = true,
    this.onAvatarTap,
    this.onStreakTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Streamlined Greeting & Full User Name
          Expanded(
            child: InkWell(
              onTap: onAvatarTap,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting.endsWith(',') ? greeting : '$greeting,',
                    style: KineticTypography.unitLabel.copyWith(
                      color: colors.textMuted,
                      fontSize: 12,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: KineticTypography.headlineSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 3. Streak Indicator Pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onStreakTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surface1,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFFF8E52),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVi
                          ? '$streakCount ngày'
                          : '$streakCount ${streakCount == 1 ? "day" : "days"}',
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Notification Icon Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onNotificationTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surface1,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.6),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
