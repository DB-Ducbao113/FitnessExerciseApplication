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

/// Emits whenever Supabase switches auth state.
///
/// Providers that depend on the active account should watch this before
/// reading `auth.currentUser`; the Supabase client object itself is stable, so
/// watching only [supabaseClientProvider] does not rebuild on login/logout.
@riverpod
Stream<AuthState> authStateChanges(AuthStateChangesRef ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
}

/// Current User ID Provider
@riverpod
String? currentUserId(CurrentUserIdRef ref) {
  ref.watch(authStateChangesProvider);
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  return user?.id;
}
