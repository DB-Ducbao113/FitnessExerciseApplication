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
    return UserProfileModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      weightKg: map['weight_kg'] as double,
      heightM: map['height_m'] as double,
      age: map['age'] as int,
      gender: map['gender'] as String,
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
      'height_m': profile.heightM,
      'age': profile.age,
      'gender': profile.gender,
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
        'height_m': profile.heightM,
        'age': profile.age,
        'gender': profile.gender,
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
