import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for: "after recording, the Summary screen shows the
/// workout but opening it in History says 'Workout not found'".
///
/// Summary gets its data via the constructor from the recording screen, so it
/// renders regardless. The Details screen resolves the id through
/// `workoutProvider(id)` -> `repository.getSessionById(id)`.
///
/// The lookup returned null for a workout that really existed because
/// `replaceLocalCache` wiped the local cache and rehydrated it only from the
/// *filtered* server list (`getSessionsByUser` hides `client_recording` shells
/// and zero-metric rows).
///
/// These tests pin the lookup contract: a finished workout must be retrievable
/// by id even when the list query does not return it.
class _DetailLookupRepository implements WorkoutRepository {
  _DetailLookupRepository({required this.byId, required this.listResult});

  final Map<String, WorkoutSession> byId;
  final List<WorkoutSession> listResult;

  List<WorkoutSession> lastCachedSessions = const [];

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
      listResult;

  @override
  Future<WorkoutSession?> getSessionById(String sessionId) async =>
      byId[sessionId];

  @override
  Future<List<WorkoutSession>> getSessionsByType(String activityType) async =>
      const [];

  @override
  Future<List<WorkoutSession>> getSessionsLocal(String userId) async =>
      listResult;

  @override
  Future<void> replaceLocalCache(
    String userId,
    List<WorkoutSession> sessions,
  ) async {
    lastCachedSessions = List<WorkoutSession>.from(sessions);
  }

  @override
  Future<void> saveSessionRemote(WorkoutSession session) async {}

  @override
  Future<void> syncFromCloud() async {}

  @override
  Future<void> syncPendingData() async {}

  @override
  Future<bool> syncRouteMatchResult(String sessionId) async => true;
}

WorkoutSession _finishedWorkout(String id) => WorkoutSession(
  id: id,
  userId: 'user-a',
  activityType: 'running',
  startedAt: DateTime.utc(2026, 10, 7, 10, 0),
  endedAt: DateTime.utc(2026, 10, 7, 10, 30),
  durationSec: 1800,
  movingTimeSec: 1800,
  distanceKm: 5.2,
  steps: 4500,
  avgSpeedKmh: 10.4,
  caloriesKcal: 350.0,
  mode: 'outdoor',
  createdAt: DateTime.utc(2026, 10, 7, 10, 30),
);

void main() {
  group('Details screen resolves a just-recorded workout by id', () {
    test(
      'uses the optimistic finished workout while local and remote saves lag',
      () async {
        final finished = _finishedWorkout('session-in-flight');
        final repo = _DetailLookupRepository(
          byId: const {},
          listResult: const [],
        );

        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'user-a'),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(workoutListProvider.future);
        container
            .read(workoutListProvider.notifier)
            .insertLocalSession(finished);

        final resolved = await container.read(
          workoutProvider('session-in-flight').future,
        );

        expect(
          resolved,
          same(finished),
          reason:
              'Details must reuse the workout already visible in History '
              'until Isar or Supabase catches up',
        );
      },
    );

    test(
      'workout(id) returns the session even when the list query hides it',
      () async {
        final finished = _finishedWorkout('session-new');
        // The list query returns nothing: only the `client_recording` shell
        // exists so far, which `getSessionsByUser` filters out.
        final repo = _DetailLookupRepository(
          byId: {'session-new': finished},
          listResult: const [],
        );

        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'user-a'),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final resolved = await container.read(
          workoutProvider('session-new').future,
        );

        expect(
          resolved,
          isNotNull,
          reason: 'History -> Details must find the workout it just listed',
        );
        expect(resolved!.distanceKm, 5.2);
        expect(resolved.durationSec, 1800);
      },
    );

    test(
      'a list refresh that returns no rows does not hide the workout from Details',
      () async {
        // The filtered server list is empty while the save is in flight.
        final repo = _DetailLookupRepository(
          byId: {'session-new': _finishedWorkout('session-new')},
          listResult: const [],
        );

        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'user-a'),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(workoutListProvider.notifier).refresh();

        // The detail lookup is independent of the list cache and must still
        // resolve — this is exactly what broke before.
        final resolved = await container.read(
          workoutProvider('session-new').future,
        );
        expect(
          resolved,
          isNotNull,
          reason: 'the workout must stay reachable after a filtered refresh',
        );
      },
    );

    test(
      'workout(id) returns null only when the id truly does not exist',
      () async {
        final repo = _DetailLookupRepository(
          byId: {'session-new': _finishedWorkout('session-new')},
          listResult: const [],
        );

        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'user-a'),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final missing = await container.read(workoutProvider('nope').future);
        expect(missing, isNull);
      },
    );
  });
}
