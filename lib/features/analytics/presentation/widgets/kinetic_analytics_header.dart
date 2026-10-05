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
        // Subtitle + Sync Status Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isVi ? 'NHỊP ĐIỆU VẬN ĐỘNG' : 'CADENCE & PERFORMANCE',
              style: KineticTypography.pageEyebrow.copyWith(
                color: colors.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.borderSubtle.withValues(alpha: 0.8),
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
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOffline
                        ? (isVi ? 'Ngoại tuyến' : 'Offline')
                        : (isVi ? 'Đã đồng bộ' : 'Synced'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Headline
        Text(
          isVi ? 'Phân tích & Hiệu suất' : 'Performance Analytics',
          style: KineticTypography.pageTitle.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        // Period Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: TimePeriod.values.map((period) {
              final isSelected = selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: KineticChip(
                  label: _periodLabel(period),
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPeriodChanged(period);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
