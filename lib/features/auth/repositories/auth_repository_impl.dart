import 'package:fitness_exercise_application/models/app_user.dart';
import 'package:fitness_exercise_application/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  AuthRepositoryImpl(this._supabase);

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      // Fallback if users table isn't populated yet
      return AppUser(
        id: user.id,
        email: user.email ?? '',
        profileCompleted: false,
        createdAt: DateTime.parse(user.createdAt),
      );
    }

    return AppUser(
      id: response['id'] as String,
      email: response['email'] as String,
      profileCompleted: response['profile_completed'] as bool,
      createdAt: DateTime.parse(response['created_at'] as String),
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
