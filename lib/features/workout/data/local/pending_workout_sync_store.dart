import 'package:fitness_exercise_application/core/storage/database_helper.dart';
import 'package:sqflite/sqflite.dart';

enum PendingWorkoutSyncType { deleteSession, deleteAll }

class PendingWorkoutSyncOperation {
  final String key;
  final String userId;
  final String? sessionId;
  final PendingWorkoutSyncType type;
  final DateTime createdAt;
  final int attemptCount;
  final DateTime nextAttemptAt;

  const PendingWorkoutSyncOperation({
    required this.key,
    required this.userId,
    required this.sessionId,
    required this.type,
    required this.createdAt,
    required this.attemptCount,
    required this.nextAttemptAt,
  });

  factory PendingWorkoutSyncOperation.deleteSession({
    required String userId,
    required String sessionId,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return PendingWorkoutSyncOperation(
      key: 'delete_session:$userId:$sessionId',
      userId: userId,
      sessionId: sessionId,
      type: PendingWorkoutSyncType.deleteSession,
      createdAt: timestamp,
      attemptCount: 0,
      nextAttemptAt: timestamp,
    );
  }

  factory PendingWorkoutSyncOperation.deleteAll({
    required String userId,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return PendingWorkoutSyncOperation(
      key: 'delete_all:$userId',
      userId: userId,
      sessionId: null,
      type: PendingWorkoutSyncType.deleteAll,
      createdAt: timestamp,
      attemptCount: 0,
      nextAttemptAt: timestamp,
    );
  }

  factory PendingWorkoutSyncOperation.fromMap(Map<String, Object?> map) {
    return PendingWorkoutSyncOperation(
      key: map['operation_key']! as String,
      userId: map['user_id']! as String,
      sessionId: map['session_id'] as String?,
      type: map['operation_type'] == 'delete_all'
          ? PendingWorkoutSyncType.deleteAll
          : PendingWorkoutSyncType.deleteSession,
      createdAt: DateTime.parse(map['created_at']! as String).toUtc(),
      attemptCount: map['attempt_count']! as int,
      nextAttemptAt: DateTime.parse(map['next_attempt_at']! as String).toUtc(),
    );
  }

  Map<String, Object?> toMap() => {
    'operation_key': key,
    'user_id': userId,
    'session_id': sessionId,
    'operation_type': type == PendingWorkoutSyncType.deleteAll
        ? 'delete_all'
        : 'delete_session',
    'created_at': createdAt.toIso8601String(),
    'attempt_count': attemptCount,
    'next_attempt_at': nextAttemptAt.toIso8601String(),
  };
}

class PendingWorkoutSyncStore {
  final DatabaseHelper _databaseHelper;

  const PendingWorkoutSyncStore(this._databaseHelper);

  static Duration retryDelay(int attemptCount) {
    final exponent = (attemptCount - 1).clamp(0, 7);
    final seconds = 30 * (1 << exponent);
    return Duration(seconds: seconds.clamp(30, 60 * 60));
  }

  static bool deletesAll(Iterable<PendingWorkoutSyncOperation> operations) {
    return operations.any(
      (operation) => operation.type == PendingWorkoutSyncType.deleteAll,
    );
  }

  static Set<String> hiddenSessionIds(
    Iterable<PendingWorkoutSyncOperation> operations,
  ) {
    return operations
        .where(
          (operation) => operation.type == PendingWorkoutSyncType.deleteSession,
        )
        .map((operation) => operation.sessionId)
        .whereType<String>()
        .toSet();
  }

  Future<void> enqueueDeleteSession({
    required String userId,
    required String sessionId,
  }) async {
    final database = await _databaseHelper.database;
    final operation = PendingWorkoutSyncOperation.deleteSession(
      userId: userId,
      sessionId: sessionId,
    );
    await database.insert(
      'pending_workout_sync_operations',
      operation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> enqueueDeleteAll(String userId) async {
    final database = await _databaseHelper.database;
    final operation = PendingWorkoutSyncOperation.deleteAll(userId: userId);
    await database.transaction((transaction) async {
      await transaction.delete(
        'pending_workout_sync_operations',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await transaction.insert(
        'pending_workout_sync_operations',
        operation.toMap(),
      );
    });
  }

  Future<List<PendingWorkoutSyncOperation>> listForUser(String userId) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      'pending_workout_sync_operations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingWorkoutSyncOperation.fromMap).toList();
  }

  Future<List<PendingWorkoutSyncOperation>> listDue(
    String userId, {
    DateTime? now,
  }) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      'pending_workout_sync_operations',
      where: 'user_id = ? AND next_attempt_at <= ?',
      whereArgs: [userId, (now ?? DateTime.now()).toUtc().toIso8601String()],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingWorkoutSyncOperation.fromMap).toList();
  }

  Future<void> complete(String operationKey) async {
    final database = await _databaseHelper.database;
    await database.delete(
      'pending_workout_sync_operations',
      where: 'operation_key = ?',
      whereArgs: [operationKey],
    );
  }

  Future<void> recordFailure(
    PendingWorkoutSyncOperation operation,
    Object error,
  ) async {
    final database = await _databaseHelper.database;
    final attemptCount = operation.attemptCount + 1;
    final nextAttemptAt = DateTime.now().toUtc().add(retryDelay(attemptCount));
    await database.update(
      'pending_workout_sync_operations',
      {
        'attempt_count': attemptCount,
        'next_attempt_at': nextAttemptAt.toIso8601String(),
        'last_error_type': error.runtimeType.toString(),
      },
      where: 'operation_key = ?',
      whereArgs: [operation.key],
    );
  }
}
