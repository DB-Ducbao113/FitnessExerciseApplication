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
        height_m REAL,
        height_cm REAL NOT NULL,
        age INTEGER,
        date_of_birth TEXT,
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
          height_m REAL,
          height_cm REAL NOT NULL,
          age INTEGER,
          date_of_birth TEXT,
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
      await _addColumnIfMissing(db, 'user_profile', 'height_cm', 'REAL');
      await _addColumnIfMissing(db, 'user_profile', 'date_of_birth', 'TEXT');
      await _addColumnIfMissing(db, 'user_profile', 'avatar_url', 'TEXT');

      await db.execute('''
        UPDATE user_profile
        SET height_cm = COALESCE(height_cm, height_m * 100.0)
        WHERE height_cm IS NULL
      ''');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String columnName,
    String columnType,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((column) => column['name'] == columnName);
    if (!exists) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnName $columnType',
      );
    }
  }
}
