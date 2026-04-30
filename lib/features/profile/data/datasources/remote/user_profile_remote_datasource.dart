import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/profile/data/models/user_profile_model.dart';
import 'package:fitness_exercise_application/core/constants/db_tables.dart';

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

    final rawHeightCm = response['height_cm'];
    final rawHeightM = response['height_m'];
    final heightCm = rawHeightCm != null
        ? (rawHeightCm as num).toDouble()
        : ((rawHeightM as num?)?.toDouble() ?? 0) * 100.0;
    final dateOfBirth = _parseDate(response['date_of_birth']);
    final legacyAge = (response['age'] as num?)?.toInt() ?? 0;

    return UserProfileModel(
      id: response['id'] as String,
      userId: response['user_id'] as String,
      weightKg: (response['weight_kg'] as num).toDouble(),
      heightCm: heightCm,
      dateOfBirth: dateOfBirth,
      legacyAge: legacyAge,
      gender: (response['gender'] as String?) ?? '',
      createdAt: DateTime.parse(response['created_at'] as String),
      updatedAt: DateTime.parse(response['updated_at'] as String),
      avatarUrl: response['avatar_url'] as String?,
    );
  }

  Future<void> createProfile(UserProfileModel profile) async {
    await _supabase.from(DbTables.userProfiles).upsert({
      'id': profile.id,
      'user_id': profile.userId,
      'weight_kg': profile.weightKg,
      'height_cm': profile.heightCm,
      'height_m': profile.heightCm / 100.0,
      'date_of_birth': _serializeDate(profile.dateOfBirth),
      'age': profile.dateOfBirth != null ? null : profile.legacyAge,
      'gender': profile.gender,
      'avatar_url': profile.avatarUrl,
      'created_at': profile.createdAt.toIso8601String(),
      'updated_at': profile.updatedAt.toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    await _supabase
        .from(DbTables.userProfiles)
        .update({
          'weight_kg': profile.weightKg,
          'height_cm': profile.heightCm,
          'height_m': profile.heightCm / 100.0,
          'date_of_birth': _serializeDate(profile.dateOfBirth),
          'age': profile.dateOfBirth != null ? null : profile.legacyAge,
          'gender': profile.gender,
          'avatar_url': profile.avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', profile.userId);
  }

  /// Upload [imageFile] to Supabase Storage under avatars/{userId}.jpg
  /// Returns the public URL of the uploaded image.
  Future<String> uploadAvatar(String userId, File imageFile) async {
    final storagePath = '$userId/avatar.jpg';
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
    final version = DateTime.now().millisecondsSinceEpoch;
    return '$publicUrl?v=$version';
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

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _serializeDate(DateTime? value) {
  if (value == null) return null;
  return value.toIso8601String().split('T').first;
}
