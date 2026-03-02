import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/data/models/user_profile_model.dart';

class UserProfileRemoteDataSource {
  final SupabaseClient _supabase;

  UserProfileRemoteDataSource(this._supabase);

  Future<UserProfileModel?> getProfile(String userId) async {
    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;

    return UserProfileModel.fromJson(response);
  }

  Future<void> createProfile(UserProfileModel profile) async {
    await _supabase.from('user_profiles').insert({
      'id': profile.id,
      'user_id': profile.userId,
      'weight_kg': profile.weightKg,
      'height_m': profile.heightM,
      'age': profile.age,
      'gender': profile.gender,
      'created_at': profile.createdAt.toIso8601String(),
      'updated_at': profile.updatedAt.toIso8601String(),
    });
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    await _supabase
        .from('user_profiles')
        .update({
          'weight_kg': profile.weightKg,
          'height_m': profile.heightM,
          'age': profile.age,
          'gender': profile.gender,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', profile.userId);
  }
}
