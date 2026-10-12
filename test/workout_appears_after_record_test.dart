import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for: "workout is written to Supabase but never shows up
/// in the app".
///
/// The remote list is NOT a faithful mirror of the table. `getSessionsByUser`
/// hides two kinds of rows:
///   * `processing_status == 'client_recording'` — the shell inserted when the
///     workout STARTED (`WorkoutRemoteDataSource.createSessionShell`);
///   * rows with no metrics at all (duration/distance/steps all zero).
/// A finished workout therefore legitimately returns *nothing* from the server
/// for a short window, before the background `saveSession()` lands.
///
/// `_mergePendingLocalSessions` must keep the locally-finalized (optimistic)
/// session visible through that window. Using "the id is in the server result"
/// as proof of persistence dropped the session instead, so the workout was in
/// the DB but invisible in History/Analytics.
class _FakeWorkoutRepository implements WorkoutRepository {
  _FakeWorkoutRepository(this.remoteSessions);

  /// What the (filtered) server query would return right now.
  List<WorkoutSession> remoteSessions;

  @override
  Future<void> cacheSessionLocal(
    WorkoutSession session, {
    bool isSynced = false,
  }) async {}

  @override
  Future<void> deleteAllSessions(String userId) async {}

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<WorkoutSession>> fetchSessionsRemote(String userId) async =>
      remoteSessions;

  @override
  Future<WorkoutSession?> getSessionById(String sessionId) async {
    for (final s in remoteSessions) {
      if (s.id == sessionId) return s;
    }
    return null;
  }

  @override
  Future<List<WorkoutSession>> getSessionsByType(String activityType) async =>
      const [];

  @override
  Future<List<WorkoutSession>> getSessionsLocal(String userId) async =>
      remoteSessions;

  @override
  Future<void> replaceLocalCache(
    String userId,
    List<WorkoutSession> sessions,
  ) async {}

  @override
  Future<void> saveSessionRemote(WorkoutSession session) async {}

  @override
  Future<void> syncFromCloud() async {}

  @override
  Future<void> syncPendingData() async {}

  @override
  Future<bool> syncRouteMatchResult(String sessionId) async => true;
}

WorkoutSession _session({
  required String id,
  int durationSec = 1800,
  double distanceKm = 5.2,
  int steps = 4500,
}) {
  return WorkoutSession(
    id: id,
    userId: 'user-a',
    activityType: 'running',
    startedAt: DateTime(2026, 10, 7, 10, 0),
    endedAt: DateTime(2026, 10, 7, 10, 30),
    durationSec: durationSec,
    movingTimeSec: durationSec,
    distanceKm: distanceKm,
    steps: steps,
    avgSpeedKmh: 10.4,
    caloriesKcal: 350.0,
    mode: 'outdoor',
    createdAt: DateTime(2026, 10, 7, 10, 30),
  );
}

void main() {
  group('Finished workout stays visible while its remote save is in flight', () {
    test(
      'keeps the local session when the filtered server list omits it',
      () async {
        // The server query returns nothing yet: only the `client_recording`
        // shell exists, which `getSessionsByUser` filters out.
        final repo = _FakeWorkoutRepository([]);
        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'user-a'),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(workoutListProvider.future);

        final finished = _session(id: 'session-new');
        container
            .read(workoutListProvider.notifier)
            .insertLocalSession(finished);

        // A refresh happens while the background save has not landed yet.
        await container.read(workoutListProvider.notifier).refresh();

        final visible = container.read(workoutListProvider).valueOrNull ?? [];
        expect(
          visible.map((s) => s.id),
          contains('session-new'),
          reason: 'the in-flight workout must not disappear from the list',
        );
      },
    );

    test('drops the local copy once the server confirms it with metrics',
        () async {
      final repo = _FakeWorkoutRepository([]);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'user-a'),
          workoutRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workoutListProvider.future);

      final finished = _session(id: 'session-new');
      final notifier = container.read(workoutListProvider.notifier);
      notifier.insertLocalSession(finished);

      // The server now returns the persisted row (save completed).
      repo.remoteSessions = [finished];
      await notifier.refresh();

      final visible = container.read(workoutListProvider).valueOrNull ?? [];
      final matching = visible.where((s) => s.id == 'session-new');
      expect(
        matching.length,
        1,
        reason: 'the confirmed server row must not be duplicated',
      );
    });

    test(
      'the shell row without metrics does not count as confirmation',
      () async {
        // This is the exact shape of the bug: the id IS present in the server
        // result, but only as a zero-metric shell. Treating it as "persisted"
        // erased the real workout from the UI.
        final shell = _session(
          id: 'session-new',
          durationSec: 0,
          distanceKm: 0,
          steps: 0,
        );
        final repo = _FakeWorkoutRepository([shell]);
        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'user-a'),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(workoutListProvider.future);

        final notifier = container.read(workoutListProvider.notifier);
        notifier.insertLocalSession(_session(id: 'session-new'));

        await notifier.refresh();

        final visible = container.read(workoutListProvider).valueOrNull ?? [];
        final matching = visible
            .where((s) => s.id == 'session-new')
            .toList(growable: false);
        expect(matching.length, 1);
        expect(
          matching.single.durationSec,
          greaterThan(0),
          reason: 'the real workout must win over the empty shell',
        );
      },
    );
  });
}
