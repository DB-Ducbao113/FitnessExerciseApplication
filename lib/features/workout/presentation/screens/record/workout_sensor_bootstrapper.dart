import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:latlong2/latlong.dart';

class WorkoutSensorBootstrapper {
  const WorkoutSensorBootstrapper();

  WorkoutSessionState applyLastKnownPosition({
    required WorkoutSessionState current,
    required double latitude,
    required double longitude,
  }) {
    final latLng = LatLng(latitude, longitude);
    return current.copyWith(initialPosition: latLng, currentLatLng: latLng);
  }

  WorkoutSessionState applyGpsStartupFailure(
    WorkoutSessionState current,
    String errorMessage,
  ) {
    return current.copyWith(
      trackingMode: 'indoor',
      environmentHint: 'indoor',
      recordingSource: 'step_fallback',
      gpsFallbackActive: true,
      modeDecisionLocked: true,
      errorMessage: errorMessage,
    );
  }

  WorkoutSessionState applyStepStartupFailure(
    WorkoutSessionState current,
    String errorMessage,
  ) {
    return current.copyWith(errorMessage: errorMessage);
  }
}
