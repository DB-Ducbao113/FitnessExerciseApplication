import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSummaryHeader extends StatelessWidget {
  final String activityType;
  final String trackingMode;
  final AppLanguage currentLang;
  final VoidCallback onBackToHome;
  final VoidCallback onShare;

  const KineticSummaryHeader({
    super.key,
    required this.activityType,
    required this.trackingMode,
    required this.currentLang,
    required this.onBackToHome,
    required this.onShare,
  });

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'running':
      default:
        return Icons.directions_run_rounded;
    }
  }

  String _getActivityName(String type, AppLanguage lang) {
    switch (type.toLowerCase()) {
      case 'cycling':
        return lang == AppLanguage.vi ? 'Đạp xe' : 'Cycling';
      case 'walking':
        return lang == AppLanguage.vi ? 'Đi bộ' : 'Walking';
      case 'running':
      default:
        return lang == AppLanguage.vi ? 'Chạy bộ' : 'Running';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final activityIcon = _getActivityIcon(activityType);
    final activityName = _getActivityName(activityType, currentLang);
    final isOutdoor = trackingMode.toLowerCase() != 'indoor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Action Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              button: true,
              label: currentLang == AppLanguage.vi ? 'Quay về trang chủ' : 'Return to home',
              child: InkWell(
                onTap: onBackToHome,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.surface1,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: colors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'AETRON TELEMETRY',
                    style: KineticTypography.pageEyebrow.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppTranslations.get('workout_summary', currentLang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KineticTypography.pageTitleCompact.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: currentLang == AppLanguage.vi ? 'Chia sẻ buổi tập' : 'Share workout',
              child: InkWell(
                onTap: onShare,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.surface1,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Icon(
                    Icons.ios_share_rounded,
                    color: colors.primary,
                    size: 19,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Activity & Mode Badges Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(activityIcon, size: 15, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    activityName,
                    style: KineticTypography.label.copyWith(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOutdoor ? colors.primary : colors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOutdoor
                        ? (currentLang == AppLanguage.vi ? 'GPS Ngoài trời' : 'Outdoor GPS')
                        : (currentLang == AppLanguage.vi ? 'Cảm biến Trong nhà' : 'Indoor Pedometer'),
                    style: KineticTypography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              currentLang == AppLanguage.vi ? 'Đã lưu' : 'Saved',
              style: KineticTypography.unitLabel.copyWith(
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
