import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/data/datasources/local/database_helper.dart';
import 'package:fitness_exercise_application/data/datasources/local/workout_local_datasource.dart';
import 'package:fitness_exercise_application/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/data/repositories/workout_repository_impl.dart';
import 'package:fitness_exercise_application/domain/repositories/workout_repository.dart';

part 'providers.g.dart';

/// Database Helper Provider
@riverpod
DatabaseHelper databaseHelper(DatabaseHelperRef ref) {
  return DatabaseHelper.instance;
}

/// Supabase Client Provider
@riverpod
SupabaseClient supabaseClient(SupabaseClientRef ref) {
  return Supabase.instance.client;
}

/// Current User ID Provider
@riverpod
String? currentUserId(CurrentUserIdRef ref) {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  return user?.id;
}

/// Workout Local DataSource Provider
@riverpod
WorkoutLocalDataSource workoutLocalDataSource(WorkoutLocalDataSourceRef ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return WorkoutLocalDataSource(dbHelper);
}

/// Workout Remote DataSource Provider
@riverpod
WorkoutRemoteDataSource workoutRemoteDataSource(
  WorkoutRemoteDataSourceRef ref,
) {
  final supabase = ref.watch(supabaseClientProvider);
  return WorkoutRemoteDataSource(supabase);
}

/// Workout Repository Provider
@riverpod
WorkoutRepository workoutRepository(WorkoutRepositoryRef ref) {
  final remoteDataSource = ref.watch(workoutRemoteDataSourceProvider);
  final supabase = ref.watch(supabaseClientProvider);

  return WorkoutRepositoryImpl(remoteDataSource, supabase);
}
