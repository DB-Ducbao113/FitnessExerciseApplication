import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

/// Mimics Isar 3.1's half-open state: the constructor registers the instance
/// and `isOpen` is true, but `attachCollections()` was never reached.
class _HalfOpenIsar extends Isar {
  _HalfOpenIsar() : super('half-open-regression-test');

  @override
  String get directory => '/tmp/local-db-test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('remote reconciliation', () {
    test('deletes a synced local workout that was deleted remotely', () {
      expect(
        LocalDB.shouldDeleteLocalSessionMissingFromRemote(
          isSynced: true,
          isPresentRemotely: false,
        ),
        isTrue,
      );
    });

    test('keeps an unsynced workout until it can be uploaded', () {
      expect(
        LocalDB.shouldDeleteLocalSessionMissingFromRemote(
          isSynced: false,
          isPresentRemotely: false,
        ),
        isFalse,
      );
    });

    test('keeps a workout that is still present remotely', () {
      expect(
        LocalDB.shouldDeleteLocalSessionMissingFromRemote(
          isSynced: true,
          isPresentRemotely: true,
        ),
        isFalse,
      );
    });
  });

  test('LocalDB rejects a registered Isar with unattached collections', () {
    final isar = _HalfOpenIsar();
    addTearDown(isar.close);

    expect(isar.isOpen, isTrue);
    expect(
      LocalDB.hasAttachedCollections(isar),
      isFalse,
      reason: 'a half-open instance must be closed and reopened, not reused',
    );
  });

  test(
    'LocalDB treats an invalid collection id as recoverable cache damage',
    () {
      expect(
        LocalDB.isRecoverableCacheOpenError(
          IsarError('IllegalArg: Collection id is invalid.'),
        ),
        isTrue,
      );
      expect(
        LocalDB.isRecoverableCacheOpenError(Exception('network unavailable')),
        isFalse,
      );
    },
  );

  test(
    'LocalDB preserves the old database before recreating its cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'aetron-isar-recovery-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final database = File(p.join(directory.path, 'default.isar'));
      final lock = File(p.join(directory.path, 'default.isar.lock'));
      await database.writeAsString('local workout bytes');
      await lock.writeAsString('stale lock');

      final backupPath = await LocalDB.backupCacheForRecovery(
        directory,
        timestamp: DateTime.utc(2026, 10, 12, 3, 0),
      );

      expect(await database.exists(), isFalse);
      expect(await lock.exists(), isFalse);
      expect(backupPath, isNotNull);
      expect(
        p.basename(backupPath!),
        'default.isar.recovery-20261012T030000000Z.bak',
      );
      expect(await File(backupPath).readAsString(), 'local workout bytes');
    },
  );
}
