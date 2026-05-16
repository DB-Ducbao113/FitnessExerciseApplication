import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/repositories/workout_repository_impl.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';

part 'workout_providers_infra.g.dart';

@riverpod
WorkoutRemoteDataSource workoutRemoteDataSource(
  WorkoutRemoteDataSourceRef ref,
) {
  final supabase = ref.watch(supabaseClientProvider);
  return WorkoutRemoteDataSource(supabase);
}

@riverpod
WorkoutRepository workoutRepository(WorkoutRepositoryRef ref) {
  final remoteDataSource = ref.watch(workoutRemoteDataSourceProvider);
  final supabase = ref.watch(supabaseClientProvider);

  return WorkoutRepositoryImpl(remoteDataSource, supabase);
}
