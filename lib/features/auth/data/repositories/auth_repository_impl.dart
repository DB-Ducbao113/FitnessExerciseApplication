import 'package:fitness_exercise_application/features/auth/domain/entities/app_user.dart';
import 'package:fitness_exercise_application/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  AuthRepositoryImpl(this._supabase);

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return AppUser(
      id: user.id,
      email: user.email ?? '',
      profileCompleted: await _hasProfile(user.id),
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  Future<bool> _hasProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
