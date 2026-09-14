import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitness_exercise_application/features/profile/data/models/user_profile_model.dart';
import 'package:fitness_exercise_application/core/storage/database_helper.dart';

class UserProfileLocalDataSource {
  final DatabaseHelper _dbHelper;
  static final Map<String, UserProfileModel> _webMemoryCache = {};

  UserProfileLocalDataSource(this._dbHelper);

  Future<UserProfileModel?> getProfile(String userId) async {
    if (kIsWeb) {
      return _webMemoryCache[userId];
    }

    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'user_profile',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      if (results.isEmpty) return null;

      final map = results.first;
      final rawHeightCm = map['height_cm'];
      final rawHeightM = map['height_m'];
      return UserProfileModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        weightKg: (map['weight_kg'] as num).toDouble(),
        heightCm: rawHeightCm != null
            ? (rawHeightCm as num).toDouble()
            : ((rawHeightM as num?)?.toDouble() ?? 0) * 100.0,
        dateOfBirth: _parseDate(map['date_of_birth']),
        legacyAge: (map['age'] as num?)?.toInt() ?? 0,
        gender: map['gender'] as String,
        avatarUrl: map['avatar_url'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    } catch (e) {
      debugPrint('[UserProfileLocalDataSource] getProfile local error: $e');
      return _webMemoryCache[userId];
    }
  }

  Future<void> insertProfile(UserProfileModel profile) async {
    _webMemoryCache[profile.userId] = profile;

    if (kIsWeb) return;

    try {
      final db = await _dbHelper.database;
      await db.insert('user_profile', {
        'id': profile.id,
        'user_id': profile.userId,
        'weight_kg': profile.weightKg,
        'height_cm': profile.heightCm,
        'height_m': profile.heightCm / 100.0,
        'date_of_birth': _serializeDate(profile.dateOfBirth),
        'age': _resolveAge(profile),
        'gender': profile.gender,
        'avatar_url': profile.avatarUrl,
        'created_at': profile.createdAt.toIso8601String(),
        'updated_at': profile.updatedAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('[UserProfileLocalDataSource] insertProfile local error: $e');
    }
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    _webMemoryCache[profile.userId] = profile;

    if (kIsWeb) return;

    try {
      final db = await _dbHelper.database;
      final updated = await db.update(
        'user_profile',
        {
          'weight_kg': profile.weightKg,
          'height_cm': profile.heightCm,
          'height_m': profile.heightCm / 100.0,
          'date_of_birth': _serializeDate(profile.dateOfBirth),
          'age': _resolveAge(profile),
          'gender': profile.gender,
          'avatar_url': profile.avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'user_id = ?',
        whereArgs: [profile.userId],
      );
      if (updated == 0) {
        await insertProfile(profile);
      }
    } catch (e) {
      debugPrint('[UserProfileLocalDataSource] updateProfile local error: $e');
    }
  }

  Future<bool> hasProfile(String userId) async {
    if (kIsWeb) {
      return _webMemoryCache.containsKey(userId);
    }

    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'user_profile',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return results.isNotEmpty;
    } catch (e) {
      return _webMemoryCache.containsKey(userId);
    }
  }

  Future<void> deleteProfile(String userId) async {
    _webMemoryCache.remove(userId);
    if (kIsWeb) return;

    try {
      final db = await _dbHelper.database;
      await db.delete(
        'user_profile',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (_) {}
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

int _resolveAge(UserProfileModel profile) {
  if (profile.legacyAge > 0) return profile.legacyAge;
  if (profile.dateOfBirth != null) {
    final now = DateTime.now();
    int calculated = now.year - profile.dateOfBirth!.year;
    if (now.month < profile.dateOfBirth!.month ||
        (now.month == profile.dateOfBirth!.month && now.day < profile.dateOfBirth!.day)) {
      calculated--;
    }
    return calculated > 0 ? calculated : 20;
  }
  return 20;
}

