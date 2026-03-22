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
      version: 3, // Updated version from 2 to 3
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        distance_km REAL,
        duration_min REAL,
        avg_speed_kmh REAL,
        calories INTEGER,
        mode TEXT DEFAULT 'outdoor',
        step_count INTEGER,
        stride_length REAL,
        estimated_distance_meters REAL,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE gps_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        recorded_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (workout_id) REFERENCES workouts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        weight_kg REAL NOT NULL,
        height_m REAL NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
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
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add dual-mode tracking columns for users upgrading from version 2
      await db.execute(
        'ALTER TABLE workouts ADD COLUMN mode TEXT DEFAULT "outdoor"',
      );
      await db.execute('ALTER TABLE workouts ADD COLUMN step_count INTEGER');
      await db.execute('ALTER TABLE workouts ADD COLUMN stride_length REAL');
      await db.execute(
        'ALTER TABLE workouts ADD COLUMN estimated_distance_meters REAL',
      );
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
