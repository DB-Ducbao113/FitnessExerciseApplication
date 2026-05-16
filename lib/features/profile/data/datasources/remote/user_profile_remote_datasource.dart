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

  /// Upload [imageFile] to a fresh Supabase Storage object.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadAvatar(String userId, File imageFile) async {
    final version = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$userId/avatar-$version.jpg';
    final bucket = _supabase.storage.from('avatars');
    const fileOptions = FileOptions(contentType: 'image/jpeg');

    await bucket.upload(storagePath, imageFile, fileOptions: fileOptions);
    return bucket.getPublicUrl(storagePath);
  }

  /// Persist [avatarUrl] to user_profiles.avatar_url in the database.
  Future<void> updateAvatarUrl(String userId, String? avatarUrl) async {
    await _supabase
        .from(DbTables.userProfiles)
        .update({
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  /// Remove the current stored avatar object when storage allows it.
  Future<void> deleteAvatarObject(String userId, {String? avatarUrl}) async {
    final storagePath =
        _avatarStoragePathFromUrl(avatarUrl) ?? '$userId/avatar.jpg';
    try {
      await _supabase.storage.from('avatars').remove([storagePath]);
    } catch (_) {
      // The profile should still fall back to the default avatar even if the
      // stored object was already missing or storage deletion is blocked.
    }
  }

  /// Clear avatar URL from profile and remove the current stored avatar.
  Future<void> clearAvatar(String userId) async {
    await updateAvatarUrl(userId, null);
    await deleteAvatarObject(userId);
  }
}

String? _avatarStoragePathFromUrl(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return null;
  final uri = Uri.tryParse(avatarUrl);
  if (uri == null) return null;

  final index = uri.pathSegments.indexOf('avatars');
  if (index < 0 || index + 1 >= uri.pathSegments.length) return null;
  return uri.pathSegments.skip(index + 1).map(Uri.decodeComponent).join('/');
}

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _serializeDate(DateTime? value) {
  if (value == null) return null;
  return value.toIso8601String().split('T').first;
}
