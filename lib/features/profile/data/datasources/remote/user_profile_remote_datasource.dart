import 'dart:io';
import 'package:flutter/foundation.dart';
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
    final storedAvatar = response['avatar_url'] as String?;
    final avatarPath = avatarStoragePathFromValue(storedAvatar);
    String? signedAvatarUrl;
    if (avatarPath != null) {
      try {
        signedAvatarUrl = await _supabase.storage
            .from('avatars')
            .createSignedUrl(avatarPath, 7 * 24 * 60 * 60);
      } catch (_) {
        signedAvatarUrl = null;
      }
    }

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
      avatarUrl: signedAvatarUrl,
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
      'age': _resolveAge(profile),
      'gender': profile.gender,
      'avatar_url': avatarStoragePathFromValue(profile.avatarUrl),
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
          'age': _resolveAge(profile),
          'gender': profile.gender,
          'avatar_url': avatarStoragePathFromValue(profile.avatarUrl),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', profile.userId);
  }

  /// Upload [imageBytes] or [imageFile] to a fresh Supabase Storage object.
  /// Returns a short-lived signed URL for the uploaded private image.
  Future<String> uploadAvatarBytes(String userId, Uint8List imageBytes) async {
    if (!isValidAvatarJpeg(imageBytes)) {
      throw const FormatException(
        'Avatar must be a valid JPEG no larger than 5 MiB.',
      );
    }
    final version = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$userId/avatar-$version.jpg';
    final bucket = _supabase.storage.from('avatars');
    const fileOptions = FileOptions(contentType: 'image/jpeg', upsert: true);

    await bucket.uploadBinary(
      storagePath,
      imageBytes,
      fileOptions: fileOptions,
    );
    return bucket.createSignedUrl(storagePath, 7 * 24 * 60 * 60);
  }

  Future<String> uploadAvatar(String userId, File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return uploadAvatarBytes(userId, bytes);
  }

  /// Persist [avatarUrl] to user_profiles.avatar_url in the database.
  Future<void> updateAvatarUrl(String userId, String? avatarUrl) async {
    await _supabase
        .from(DbTables.userProfiles)
        .update({
          'avatar_url': avatarStoragePathFromValue(avatarUrl),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  /// Remove the current stored avatar object when storage allows it.
  Future<void> deleteAvatarObject(String userId, {String? avatarUrl}) async {
    try {
      final bucket = _supabase.storage.from('avatars');
      final storagePath = avatarStoragePathFromValue(avatarUrl);
      if (storagePath != null) {
        await bucket.remove([storagePath]);
        return;
      }

      // A null URL is used by account/avatar deletion. Remove the complete
      // tenant folder so old versioned uploads cannot survive the deletion.
      for (var page = 0; page < 100; page++) {
        final objects = await bucket.list(
          path: userId,
          searchOptions: const SearchOptions(limit: 100),
        );
        if (objects.isEmpty) break;
        await bucket.remove(
          objects.map((object) => '$userId/${object.name}').toList(),
        );
        if (objects.length < 100) break;
      }
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

  /// Delete all user data from every table and authentication identity.
  Future<void> deleteAllUserData(String userId) async {
    // 1. Remove avatar from Storage bucket
    try {
      await deleteAvatarObject(userId);
    } catch (_) {
      // Non-fatal if avatar doesn't exist
    }

    // 2. Try invoking the secure RPC delete_user_account function
    try {
      await _supabase.rpc('delete_user_account');
      return;
    } catch (e) {
      debugPrint('[RemoteDataSource] RPC delete_user_account fallback: $e');
      // If error is network or auth issue, rethrow immediately
      if (e is PostgrestException &&
          e.code != 'PGRST202' &&
          e.code != '42883') {
        rethrow;
      }
    }

    // 3. Fallback table-by-table deletion
    try {
      await _supabase
          .from('workout_segment_audits')
          .delete()
          .filter(
            'workout_id',
            'in',
            _supabase
                .from(DbTables.workoutSessions)
                .select('id')
                .eq('user_id', userId),
          );
    } catch (_) {}

    try {
      await _supabase
          .from(DbTables.workoutProcessingLogs)
          .delete()
          .filter(
            'workout_id',
            'in',
            _supabase
                .from(DbTables.workoutSessions)
                .select('id')
                .eq('user_id', userId),
          );
    } catch (_) {}

    try {
      await _supabase
          .from(DbTables.workoutProcessingJobs)
          .delete()
          .filter(
            'workout_id',
            'in',
            _supabase
                .from(DbTables.workoutSessions)
                .select('id')
                .eq('user_id', userId),
          );
    } catch (_) {}

    try {
      await _supabase
          .from(DbTables.rawGpsPoints)
          .delete()
          .filter(
            'workout_id',
            'in',
            _supabase
                .from(DbTables.workoutSessions)
                .select('id')
                .eq('user_id', userId),
          );
    } catch (_) {}

    try {
      await _supabase
          .from(DbTables.rawStepIntervals)
          .delete()
          .filter(
            'workout_id',
            'in',
            _supabase
                .from(DbTables.workoutSessions)
                .select('id')
                .eq('user_id', userId),
          );
    } catch (_) {}

    // Core tables must not be silently swallowed if disconnected
    await _supabase
        .from(DbTables.workoutSessions)
        .delete()
        .eq('user_id', userId);

    try {
      await _supabase
          .from('user_recovery_emails')
          .delete()
          .eq('user_id', userId);
    } catch (_) {}

    await _supabase.from(DbTables.userGoals).delete().eq('user_id', userId);

    await _supabase.from(DbTables.userProfiles).delete().eq('user_id', userId);
  }
}

bool isValidAvatarJpeg(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes.length <= 5 * 1024 * 1024 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
}

String? avatarStoragePathFromValue(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  String candidate;
  if (uri.hasScheme) {
    if (uri.scheme != 'https') return null;
    final index = uri.pathSegments.indexOf('avatars');
    if (index < 0 || index + 1 >= uri.pathSegments.length) return null;
    candidate = uri.pathSegments
        .skip(index + 1)
        .map(Uri.decodeComponent)
        .join('/');
  } else {
    candidate = trimmed;
  }
  if (!RegExp(r'^[A-Za-z0-9_-]+/[A-Za-z0-9._-]+$').hasMatch(candidate)) {
    return null;
  }
  return candidate;
}

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _serializeDate(DateTime? value) {
  if (value == null) return null;
  return value.toIso8601String().split('T').first;
}

int _resolveAge(UserProfileModel profile) {
  if (profile.legacyAge > 0) return profile.legacyAge;
  if (profile.dateOfBirth != null) {
    final now = DateTime.now();
    int calculated = now.year - profile.dateOfBirth!.year;
    if (now.month < profile.dateOfBirth!.month ||
        (now.month == profile.dateOfBirth!.month &&
            now.day < profile.dateOfBirth!.day)) {
      calculated--;
    }
    return calculated > 0 ? calculated : 20;
  }
  return 20;
}
