import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_delete_dialog.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_header.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_route_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_splits_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_telemetry_list_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_top_bar.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_skeleton.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkoutDetailsScreen extends ConsumerWidget {
  final String workoutId;

  const WorkoutDetailsScreen({super.key, required this.workoutId});

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    final lang = ref.read(appLanguageProvider);
    final colors = context.kinetic;

    showDialog<void>(
      context: context,
      builder: (_) => KineticDetailsDeleteDialog(
        currentLang: lang,
        onConfirm: () async {
          try {
            await ref.read(workoutListProvider.notifier).deleteWorkout(workoutId);
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    lang == AppLanguage.vi ? 'Đã xóa buổi tập' : 'Workout deleted',
                    style: KineticTypography.label.copyWith(color: colors.background),
                  ),
                  backgroundColor: colors.primary,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error: $e',
                    style: KineticTypography.label.copyWith(color: Colors.white),
                  ),
                  backgroundColor: colors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final workoutAsync = ref.watch(workoutProvider(workoutId));
    final routeAsync = ref.watch(workoutRoutePresentationProvider(workoutId));
    final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            KineticDetailsTopBar(
              currentLang: currentLang,
              onBack: () => Navigator.of(context).pop(),
              onDelete: () => _showDeleteDialog(context, ref),
            ),

            // Content
            Expanded(
              child: workoutAsync.when(
                loading: () => const WorkoutDetailsSkeletonView(),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: $error',
                      style: TextStyle(color: colors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (workout) {
                  if (workout == null) {
                    return Center(
                      child: Text(
                        currentLang == AppLanguage.vi
                            ? 'Không tìm thấy buổi tập'
                            : 'Workout not found',
                        style: TextStyle(color: colors.textPrimary),
                      ),
                    );
                  }

                  final routePoints = routeAsync.valueOrNull?.routePoints ?? const [];

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      // 1. Activity Header (Chỉ hiển thị Đi bộ / Chạy bộ / Đạp xe, không có thứ ở dưới)
                      KineticDetailsHeader(
                        workout: workout,
                        currentLang: currentLang,
                      ),
                      const SizedBox(height: 14),

                      // 2. Route Map Card (Màn hình route)
                      KineticDetailsRouteCard(
                        routePoints: routePoints,
                        activityType: workout.activityType,
                        currentLang: currentLang,
                      ),
                      const SizedBox(height: 14),

                      // 3. Toàn bộ thông số gộp chung thành một list thông tin duy nhất ở dưới màn hình route (bỏ môi trường)
                      KineticDetailsTelemetryListCard(
                        workout: workout,
                        useMetricUnits: useMetricUnits,
                        currentLang: currentLang,
                      ),

                      // 4. Lap Splits Card (Km-by-Km laps if present)
                      if (workout.lapSplits.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        KineticDetailsSplitsCard(
                          lapSplits: workout.lapSplits,
                          useMetricUnits: useMetricUnits,
                          currentLang: currentLang,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
