import 'package:sqflite/sqflite.dart';
import 'package:fitness_exercise_application/features/profile/data/models/user_profile_model.dart';
import 'package:fitness_exercise_application/core/storage/database_helper.dart';

class UserProfileLocalDataSource {
  final DatabaseHelper _dbHelper;

  UserProfileLocalDataSource(this._dbHelper);

  Future<UserProfileModel?> getProfile(String userId) async {
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
  }

  Future<void> insertProfile(UserProfileModel profile) async {
    final db = await _dbHelper.database;
    await db.insert('user_profile', {
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
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    final db = await _dbHelper.database;
    await db.update(
      'user_profile',
      {
        'weight_kg': profile.weightKg,
        'height_cm': profile.heightCm,
        'height_m': profile.heightCm / 100.0,
        'date_of_birth': _serializeDate(profile.dateOfBirth),
        'age': profile.dateOfBirth != null ? null : profile.legacyAge,
        'gender': profile.gender,
        'avatar_url': profile.avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [profile.userId],
    );
  }

  Future<bool> hasProfile(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'user_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty;
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
