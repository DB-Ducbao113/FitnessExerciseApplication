import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fitness_app.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        weight_kg REAL NOT NULL,
        height_m REAL NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        avatar_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add user_profile table for users upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL UNIQUE,
          weight_kg REAL NOT NULL,
          height_m REAL NOT NULL,
          age INTEGER NOT NULL,
          gender TEXT NOT NULL,
          avatar_url TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // Legacy workout tables were removed from sqflite. Keep existing profile
      // databases intact on upgrade and let Isar own workout persistence.
    }

    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS gps_tracks');
      await db.execute('DROP TABLE IF EXISTS workouts');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN avatar_url TEXT');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
