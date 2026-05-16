import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/core/storage/database_helper.dart';

part 'app_providers.g.dart';

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
