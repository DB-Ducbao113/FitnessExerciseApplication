import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticAnalyticsHeader extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final bool isOffline;
  final bool isVi;

  const KineticAnalyticsHeader({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.isOffline,
    required this.isVi,
  });

  String _periodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.week:
        return isVi ? 'Tuần này' : 'This Week';
      case TimePeriod.month:
        return isVi ? 'Tháng này' : 'This Month';
      case TimePeriod.year:
        return isVi ? 'Năm nay' : 'This Year';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + Sync Status Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Main Title (Clear & Prominent)
            Expanded(
              child: Text(
                isVi ? 'Phân tích' : 'Analytics',
                style: KineticTypography.pageTitle.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // Right: Sync / Offline Status Badge Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.borderSubtle,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOffline ? colors.tertiary : colors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isOffline ? colors.tertiary : colors.primary)
                              .withValues(alpha: 0.6),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOffline
                        ? (isVi ? 'Ngoại tuyến' : 'Offline')
                        : (isVi ? 'Đã đồng bộ' : 'Synced'),
                    style: KineticTypography.unitLabel.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Expanded Period Filter Tabs (Tuần này / Tháng này / Năm nay dàn đều ngang)
        Row(
          children: [
            for (int i = 0; i < TimePeriod.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _buildPeriodTab(context, colors, TimePeriod.values[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodTab(
    BuildContext context,
    KineticColors colors,
    TimePeriod period,
  ) {
    final isSelected = selectedPeriod == period;
    final bg = isSelected ? colors.surface2 : colors.surface1;
    final borderColor = isSelected ? colors.primary : colors.borderSubtle;
    final textColor = isSelected ? colors.primary : colors.textMuted;
    final label = _periodLabel(period);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onPeriodChanged(period);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: KineticTypography.label.copyWith(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
