import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/models/personal_records.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PersonalRecordsTrophyWall extends StatelessWidget {
  final DetailedPersonalRecords records;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const PersonalRecordsTrophyWall({
    super.key,
    required this.records,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final all = records.allRecords;
    final unlockedCount = records.unlockedCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AetronColors.gold.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AetronColors.gold.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AetronColors.gold.withValues(alpha: 0.18),
                      border: Border.all(color: AetronColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: AetronColors.gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentLang == AppLanguage.vi ? 'ĐỀN THỜ KỶ LỤC' : 'PR HALL OF FAME',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AetronColors.gold.withValues(alpha: 0.9),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        currentLang == AppLanguage.vi ? 'Kỷ Lục Cá Nhân (PRs)' : 'Personal Bests',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Unlocked Counter Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AetronColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AetronColors.gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$unlockedCount / ${all.length} ${currentLang == AppLanguage.vi ? 'KỶ LỤC' : 'RECORDS'}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AetronColors.gold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2-Column Bento Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final record = all[index];
              return _TrophyCardItem(
                record: record,
                useMetricUnits: useMetricUnits,
                currentLang: currentLang,
                onTap: () => _showRecordDetailSheet(context, record),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRecordDetailSheet(BuildContext context, SingleRecordItem record) {
    HapticFeedback.lightImpact();
    final isUnlocked = record.isUnlocked;
    final isVi = currentLang == AppLanguage.vi;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AetronColors.space.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isUnlocked ? AetronColors.gold : AetronColors.borderSubtle,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 28,
              ),
              if (isUnlocked)
                BoxShadow(
                  color: AetronColors.gold.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AetronColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Emblem
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? AetronColors.gold.withValues(alpha: 0.2)
                      : AetronColors.panelHigh,
                  border: Border.all(
                    color: isUnlocked ? AetronColors.gold : AetronColors.borderSubtle,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isUnlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                  size: 32,
                  color: isUnlocked ? AetronColors.gold : AetronColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              Text(
                isVi ? record.titleVi : record.titleEn,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AetronColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                isUnlocked
                    ? (isVi ? 'KỶ LỤC CÁ NHÂN ĐÃ XÁC LẬP' : 'PERSONAL BEST ESTABLISHED')
                    : (isVi ? 'CHƯA MỞ KHÓA' : 'NOT YET UNLOCKED'),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isUnlocked ? AetronColors.gold : AetronColors.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              // Detail box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AetronColors.panelHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AetronColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    if (isUnlocked) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isVi ? 'THÀNH TÍCH ĐỈNH CAO' : 'PEAK RECORD',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: AetronColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _formatRecordValue(record, useMetricUnits),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AetronColors.gold,
                            ),
                          ),
                        ],
                      ),
                      if (record.achievedAt != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi ? 'NGÀY XÁC LẬP' : 'DATE ACHIEVED',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                color: AetronColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${record.achievedAt!.toLocal().day.toString().padLeft(2, '0')}/${record.achievedAt!.toLocal().month.toString().padLeft(2, '0')}/${record.achievedAt!.toLocal().year}',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AetronColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      Text(
                        isVi ? record.unlockHintVi : record.unlockHintEn,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AetronColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AppButton(
                label: isVi ? 'ĐÓNG' : 'CLOSE',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatRecordValue(SingleRecordItem record, bool useMetricUnits) {
    if (record.durationSec != null) {
      return WorkoutFormatters.formatDurationFromSeconds(record.durationSec!);
    }
    if (record.id == 'pr_longest_dist' && record.numericValue != null) {
      return WorkoutFormatters.formatDistance(record.numericValue!, useMetric: useMetricUnits, decimals: 1);
    }
    if (record.id == 'pr_fastest_pace' && record.numericValue != null) {
      return WorkoutFormatters.formatPaceFromSpeedKmh(record.numericValue!, useMetric: useMetricUnits);
    }
    if (record.id == 'pr_max_cal' && record.numericValue != null) {
      return '${record.numericValue!.round()} kcal';
    }
    return '—';
  }
}

class _TrophyCardItem extends StatelessWidget {
  final SingleRecordItem record;
  final bool useMetricUnits;
  final AppLanguage currentLang;
  final VoidCallback onTap;

  const _TrophyCardItem({
    required this.record,
    required this.useMetricUnits,
    required this.currentLang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = record.isUnlocked;
    final isVi = currentLang == AppLanguage.vi;
    final title = isVi ? record.titleVi : record.titleEn;

    final accentColor = switch (record.category) {
      'speed' => AetronColors.cyan,
      'distance' => AetronColors.gold,
      'energy' => AetronColors.mint,
      _ => const Color(0xFFA55EEA),
    };

    final icon = switch (record.id) {
      'pr_1k' => Icons.electric_bolt_rounded,
      'pr_5k' => Icons.directions_run_rounded,
      'pr_10k' => Icons.military_tech_rounded,
      'pr_21k' => Icons.emoji_events_rounded,
      'pr_longest_dist' => Icons.explore_rounded,
      'pr_fastest_pace' => Icons.speed_rounded,
      'pr_max_cal' => Icons.local_fire_department_rounded,
      _ => Icons.timer_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked ? const Color(0xFF0F1524) : AetronColors.space.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnlocked ? accentColor.withValues(alpha: 0.45) : AetronColors.borderSubtle,
              width: 1.2,
            ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon & Category Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    isUnlocked ? icon : Icons.lock_outline_rounded,
                    size: 18,
                    color: isUnlocked ? accentColor : AetronColors.muted,
                  ),
                  if (isUnlocked && record.achievedAt != null)
                    Text(
                      '${record.achievedAt!.toLocal().day.toString().padLeft(2, '0')}/${record.achievedAt!.toLocal().month.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AetronColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),

              // Middle: Title
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isUnlocked ? AetronColors.textPrimary : AetronColors.textSecondary,
                ),
              ),

              // Bottom: Value or Locked hint
              Text(
                isUnlocked
                    ? PersonalRecordsTrophyWall._formatRecordValue(record, useMetricUnits)
                    : (isVi ? 'Chưa mở khóa' : 'Locked'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: isUnlocked ? 15 : 10,
                  fontWeight: FontWeight.w900,
                  color: isUnlocked ? accentColor : AetronColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
