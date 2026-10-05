import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticActivityCockpit extends StatelessWidget {
  final String activityName;
  final bool isOutdoor;
  final bool gpsEnabled;
  final bool checkingLocation;
  final bool hasLocationPermission;
  final double? gpsAccuracyM;
  final WorkoutTarget selectedTarget;
  final bool isVi;
  final VoidCallback onRefreshGps;
  final VoidCallback onTargetCustomizeTap;
  final ValueChanged<WorkoutTarget> onTargetChanged;
  final VoidCallback onStartTap;
  final VoidCallback? onMapPreviewTap;

  const KineticActivityCockpit({
    super.key,
    required this.activityName,
    required this.isOutdoor,
    required this.gpsEnabled,
    required this.checkingLocation,
    required this.hasLocationPermission,
    this.gpsAccuracyM,
    required this.selectedTarget,
    required this.isVi,
    required this.onRefreshGps,
    required this.onTargetCustomizeTap,
    required this.onTargetChanged,
    required this.onStartTap,
    this.onMapPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isGpsReady = gpsEnabled && hasLocationPermission;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.borderSubtle.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Telemetry Sensor Status Row
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.borderSubtle.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.borderSubtle.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          isOutdoor
                              ? Icons.satellite_alt_rounded
                              : Icons.sensors_rounded,
                          size: 16,
                          color: isOutdoor
                              ? (isGpsReady ? colors.primary : colors.tertiary)
                              : colors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isOutdoor
                                      ? (isGpsReady
                                          ? (isVi
                                              ? 'GPS sẵn sàng'
                                              : 'GPS Ready')
                                          : (isVi
                                              ? 'Chờ tín hiệu GPS'
                                              : 'Waiting for GPS'))
                                      : (isVi
                                          ? 'Cảm biến trong nhà'
                                          : 'Indoor Sensors Ready'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (isOutdoor && isGpsReady && gpsAccuracyM != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '< ${gpsAccuracyM!.toStringAsFixed(1)}m',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: colors.primary,
                                        fontFeatures: KineticTypography.tabularFigures,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Refresh / Map peek actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onMapPreviewTap != null && isOutdoor) ...[
                      IconButton(
                        tooltip: isVi ? 'Xem bản đồ' : 'Map Preview',
                        icon: Icon(
                          Icons.map_outlined,
                          size: 19,
                          color: colors.textSecondary,
                        ),
                        onPressed: onMapPreviewTap,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: isVi ? 'Làm mới tín hiệu' : 'Refresh signal',
                      icon: checkingLocation
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              size: 19,
                              color: colors.textSecondary,
                            ),
                      onPressed: checkingLocation ? null : onRefreshGps,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Workout Target Goal Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'MỤC TIÊU BUỔI TẬP' : 'SESSION TARGET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              GestureDetector(
                onTap: onTargetCustomizeTap,
                child: Text(
                  selectedTarget.type == WorkoutTargetType.none
                      ? (isVi ? 'Tùy chỉnh' : 'Custom')
                      : selectedTarget.getDisplayTitle(
                          isVi ? AppLanguage.vi : AppLanguage.en,
                        ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Horizontal Quick Target Chips
          _buildQuickChips(context),
          const SizedBox(height: 14),

          // 4. Primary CTA Start Button
          KineticButton(
            label: isVi
                ? 'BẮT ĐẦU ${activityName.toUpperCase()}'
                : 'START ${activityName.toUpperCase()}',
            icon: Icons.play_arrow_rounded,
            height: 52,
            onPressed: onStartTap,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips(BuildContext context) {
    // Different presets depending on whether activity is outdoor/distance or time-based
    final List<(String, WorkoutTarget)> presets;

    if (isOutdoor) {
      presets = [
        (
          isVi ? 'Tự do' : 'Free',
          WorkoutTarget.free,
        ),
        (
          '3.0 km',
          const WorkoutTarget(type: WorkoutTargetType.distance, value: 3.0),
        ),
        (
          '5.0 km',
          const WorkoutTarget(type: WorkoutTargetType.distance, value: 5.0),
        ),
        (
          '10.0 km',
          const WorkoutTarget(type: WorkoutTargetType.distance, value: 10.0),
        ),
      ];
    } else {
      presets = [
        (
          isVi ? 'Tự do' : 'Free',
          WorkoutTarget.free,
        ),
        (
          isVi ? '20 phút' : '20 min',
          const WorkoutTarget(type: WorkoutTargetType.duration, value: 20.0),
        ),
        (
          isVi ? '30 phút' : '30 min',
          const WorkoutTarget(type: WorkoutTargetType.duration, value: 30.0),
        ),
        (
          isVi ? '45 phút' : '45 min',
          const WorkoutTarget(type: WorkoutTargetType.duration, value: 45.0),
        ),
      ];
    }

    return Row(
      children: [
        for (int i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _QuickChip(
              title: presets[i].$1,
              isSelected: selectedTarget.type == presets[i].$2.type &&
                  (presets[i].$2.type == WorkoutTargetType.none ||
                      selectedTarget.value == presets[i].$2.value),
              onTap: () {
                HapticFeedback.selectionClick();
                onTargetChanged(presets[i].$2);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickChip({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.16)
                : colors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.primary : colors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? colors.primary : colors.textPrimary,
              fontFeatures: KineticTypography.tabularFigures,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
