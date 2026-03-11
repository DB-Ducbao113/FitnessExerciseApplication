import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/models/user_profile_model.dart';
import 'package:fitness_exercise_application/config/constants/db_tables.dart';

class UserProfileRemoteDataSource {
  final SupabaseClient _supabase;

  UserProfileRemoteDataSource(this._supabase);

  Future<UserProfileModel?> getProfile(String userId) async {
    final response = await _supabase
        .from(DbTables.userProfiles)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;

    return UserProfileModel(
      id: response['id'] as String,
      userId: response['user_id'] as String,
      weightKg: (response['weight_kg'] as num).toDouble(),
      heightM: (response['height_m'] as num).toDouble(),
      age: (response['age'] as num).toInt(),
      gender: response['gender'] as String,
      createdAt: DateTime.parse(response['created_at'] as String),
      updatedAt: DateTime.parse(response['updated_at'] as String),
      avatarUrl: response['avatar_url'] as String?,
    );
  }

  Future<void> createProfile(UserProfileModel profile) async {
    await _supabase.from(DbTables.userProfiles).insert({
      'id': profile.id,
      'user_id': profile.userId,
      'weight_kg': profile.weightKg,
      'height_m': profile.heightM,
      'age': profile.age,
      'gender': profile.gender,
      'avatar_url': profile.avatarUrl,
      'created_at': profile.createdAt.toIso8601String(),
      'updated_at': profile.updatedAt.toIso8601String(),
    });
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    await _supabase
        .from(DbTables.userProfiles)
        .update({
          'weight_kg': profile.weightKg,
          'height_m': profile.heightM,
          'age': profile.age,
          'gender': profile.gender,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', profile.userId);
  }

  /// Upload [imageFile] to Supabase Storage under avatars/{userId}.jpg
  /// Returns the public URL of the uploaded image.
  Future<String> uploadAvatar(String userId, File imageFile) async {
    final storagePath = 'avatars/$userId.jpg';
    await _supabase.storage
        .from('avatars')
        .upload(
          storagePath,
          imageFile,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true, // overwrite on re-upload
          ),
        );
    final publicUrl = _supabase.storage
        .from('avatars')
        .getPublicUrl(storagePath);
    return publicUrl;
  }

  /// Persist [avatarUrl] to user_profiles.avatar_url in the database.
  Future<void> updateAvatarUrl(String userId, String avatarUrl) async {
    await _supabase
        .from(DbTables.userProfiles)
        .update({
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId);
  }
}
