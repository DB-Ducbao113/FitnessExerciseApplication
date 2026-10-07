import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorkoutRepository implements WorkoutRepository {
  final Map<String, List<WorkoutSession>> userSessions;

  _FakeWorkoutRepository(this.userSessions);

  @override
  Future<void> cacheSessionLocal(WorkoutSession session, {bool isSynced = false}) async {}

  @override
  Future<void> deleteAllSessions(String userId) async {
    userSessions[userId] = [];
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    for (final list in userSessions.values) {
      list.removeWhere((s) => s.id == sessionId);
    }
  }

  @override
  Future<List<WorkoutSession>> fetchSessionsRemote(String userId) async {
    return userSessions[userId] ?? [];
  }

  @override
  Future<WorkoutSession?> getSessionById(String sessionId) async {
    for (final list in userSessions.values) {
      for (final s in list) {
        if (s.id == sessionId) return s;
      }
    }
    return null;
  }

  @override
  Future<List<WorkoutSession>> getSessionsByType(String activityType) async {
    return [];
  }

  @override
  Future<List<WorkoutSession>> getSessionsLocal(String userId) async {
    return userSessions[userId] ?? [];
  }

  @override
  Future<void> replaceLocalCache(String userId, List<WorkoutSession> sessions) async {
    userSessions[userId] = List.from(sessions);
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

void main() {
  group('Account Switch Workout History Isolation', () {
    late WorkoutSession userAWorkout;
    late _FakeWorkoutRepository fakeRepo;

    setUp(() {
      userAWorkout = WorkoutSession(
        id: 'session-a-1',
        userId: 'user-a',
        activityType: 'running',
        startedAt: DateTime(2026, 10, 7, 10, 0),
        endedAt: DateTime(2026, 10, 7, 10, 30),
        durationSec: 1800,
        movingTimeSec: 1800,
        distanceKm: 5.2,
        steps: 4500,
        avgSpeedKmh: 10.4,
        caloriesKcal: 350.0,
        mode: 'outdoor',
        createdAt: DateTime(2026, 10, 7, 10, 30),
      );

      fakeRepo = _FakeWorkoutRepository({
        'user-a': [userAWorkout],
        'user-b': [],
      });
    });

    test('WorkoutList returns User A workouts when user-a is active', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'user-a'),
          workoutRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final workouts = await container.read(workoutListProvider.future);
      expect(workouts.length, 1);
      expect(workouts.first.id, 'session-a-1');
      expect(workouts.first.userId, 'user-a');
      expect(workouts.first.distanceKm, 5.2);
    });

    test('WorkoutList automatically switches to empty list when user changes to user-b', () async {
      String? activeUser = 'user-a';

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => activeUser),
          workoutRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // 1. Initial state with user-a
      final workoutsA = await container.read(workoutListProvider.future);
      expect(workoutsA.length, 1);
      expect(workoutsA.first.userId, 'user-a');

      // 2. User logs out and User B logs in
      activeUser = 'user-b';
      container.invalidate(currentUserIdProvider);

      // Read workoutListProvider again
      final workoutsB = await container.read(workoutListProvider.future);
      expect(workoutsB.isEmpty, true);
    });

    test('WorkoutList returns empty list when user is null (logged out)', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => null),
          workoutRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final workouts = await container.read(workoutListProvider.future);
      expect(workouts.isEmpty, true);
    });

    test('Empty remote sessions does not leak cached data across accounts', () async {
      String? activeUser = 'user-a';

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => activeUser),
          workoutRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Verify user-a has workouts
      expect((await container.read(workoutListProvider.future)).length, 1);

      // Switch to user-b who has 0 workouts in DB
      activeUser = 'user-b';
      container.invalidate(currentUserIdProvider);

      final result = await container.read(workoutListProvider.future);
      // User B must get empty list, not user-a's records and not phantom 0s
      expect(result, isEmpty);
    });
  });
}
