import 'package:fitness_exercise_application/features/workout/data/local/pending_workout_sync_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete operation keys are stable and tenant-scoped', () {
    expect(
      PendingWorkoutSyncOperation.deleteSession(
        userId: 'user-a',
        sessionId: 'session-1',
      ).key,
      'delete_session:user-a:session-1',
    );
    expect(
      PendingWorkoutSyncOperation.deleteAll(userId: 'user-a').key,
      'delete_all:user-a',
    );
  });

  test('retry backoff is bounded exponential', () {
    expect(PendingWorkoutSyncStore.retryDelay(1), const Duration(seconds: 30));
    expect(PendingWorkoutSyncStore.retryDelay(2), const Duration(minutes: 1));
    expect(PendingWorkoutSyncStore.retryDelay(6), const Duration(minutes: 16));
    expect(PendingWorkoutSyncStore.retryDelay(20), const Duration(hours: 1));
  });

  test('pending delete-all hides every cloud session until retry succeeds', () {
    final operations = [
      PendingWorkoutSyncOperation.deleteAll(userId: 'user-a'),
    ];
    expect(PendingWorkoutSyncStore.deletesAll(operations), isTrue);
    expect(PendingWorkoutSyncStore.hiddenSessionIds(operations), isEmpty);
  });

  test('pending session deletes expose a stable cloud filtering set', () {
    final operations = [
      PendingWorkoutSyncOperation.deleteSession(
        userId: 'user-a',
        sessionId: 'session-1',
      ),
      PendingWorkoutSyncOperation.deleteSession(
        userId: 'user-a',
        sessionId: 'session-2',
      ),
    ];
    expect(PendingWorkoutSyncStore.hiddenSessionIds(operations), {
      'session-1',
      'session-2',
    });
  });
}
