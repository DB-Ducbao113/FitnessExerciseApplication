import 'package:fitness_exercise_application/models/workout_session.dart';

abstract class WorkoutRepository {
  Future<void> saveSessionRemote(WorkoutSession session);
  Future<void> cacheSessionLocal(WorkoutSession session);
  Future<List<WorkoutSession>> fetchSessionsRemote(String userId);
  Future<List<WorkoutSession>> getSessionsLocal(String userId);
  Future<void> replaceLocalCache(String userId, List<WorkoutSession> sessions);

  // Keep for active use
  Future<List<WorkoutSession>> getSessionsByType(String activityType);
  Future<WorkoutSession?> getSessionById(String sessionId);
  Future<void> deleteSession(String sessionId);
  Future<void> deleteAllSessions(String userId);
  Future<void> syncPendingData();

  // Legacy alias, consider migrating to fetchSessionsRemote + replaceLocalCache
  Future<void> syncFromCloud();
}
