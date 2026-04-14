# MVVM For Workout Recording

## Scope

This document describes the MVVM structure that has been implemented for the workout recording flow, especially the GPS, step tracking, session lifecycle, and backend ingestion pipeline.

Current scope:

- `features/workout/presentation/screens/record`
- GPS and step recording
- session start, pause, resume, stop
- raw tracking upload and processing enqueue

This is the strongest MVVM example in the app right now. Other areas of the app may still use lighter Riverpod presentation patterns.

## Why This Refactor Exists

The old recording flow concentrated too many responsibilities inside one notifier:

- session state
- GPS filtering decisions
- sensor startup and shutdown
- environment classifier lifecycle
- backend raw ingestion
- final session snapshot building
- UI-facing state updates

That made the GPS flow harder to debug and the code harder to evolve safely.

The new structure keeps `record_providers.dart` as the ViewModel layer, but moves business rules and infrastructure orchestration into focused classes.

## MVVM Mapping

### View

The View layer renders UI and sends user intents.

Main examples:

- `lib/features/workout/presentation/screens/record/record_screen.dart`
- `lib/features/workout/presentation/widgets/record/tracking_map_widget.dart`

Responsibilities:

- render timer, pace, distance, calories, route, buttons
- observe Riverpod state
- call ViewModel intents such as start, pause, resume, stop, recenter

The View should not:

- calculate workout business rules
- talk directly to GPS or step services
- build canonical workout snapshots

### ViewModel

The ViewModel is still centered around:

- `lib/features/workout/presentation/screens/record/record_providers.dart`

Main provider:

- `workoutSessionProvider`
- `WorkoutSessionNotifier`

Responsibilities:

- expose `WorkoutSessionState`
- receive UI intents
- orchestrate helpers and controllers
- react to GPS and step callbacks
- update UI-facing state

The ViewModel should coordinate, not own every rule.

## Current Supporting Classes

### State Model

- `lib/features/workout/presentation/screens/record/workout_session_state.dart`

Contains:

- `RecordingState`
- `WorkoutSessionState`

Responsibilities:

- represent the full UI state of an active recording session
- keep route points, metrics, status, source, tracking mode, and map state

### Lifecycle Helper

- `lib/features/workout/presentation/screens/record/workout_session_lifecycle.dart`

Responsibilities:

- create initializing state
- transition state for active, paused, stopping, finished

This keeps repetitive `copyWith(...)` transition logic out of the ViewModel.

### Starter

- `lib/features/workout/presentation/screens/record/workout_session_starter.dart`

Responsibilities:

- create a `WorkoutSessionStartPlan`
- determine initial mode and recording source
- apply startup bootstrap states for GPS and indoor fallback

### Finalizer

- `lib/features/workout/presentation/screens/record/workout_session_finalizer.dart`

Responsibilities:

- create final workout snapshot
- compute canonical distance and average speed
- estimate steps when needed
- build `WorkoutSession`

This keeps `stopWorkout()` from owning canonical snapshot construction directly.

### Tracking Engine

- `lib/features/workout/domain/services/workout_tracking_engine.dart`

Responsibilities:

- decide whether a GPS update should be skipped, seeded, anchor-reset, or accepted
- evaluate step fallback activation
- compute indoor step contribution
- centralize GPS thresholds such as speed, segment size, accuracy, and bearing rules

This is the main business-rule layer for live tracking.

### Recording Coordinator

- `lib/features/workout/presentation/screens/record/workout_recording_coordinator.dart`

Responsibilities:

- create remote workout shell
- buffer raw GPS points and raw step intervals
- flush raw batches
- enqueue processing jobs after workout stop

This is the backend orchestration layer for recording.

### Sensor Bootstrapper

- `lib/features/workout/presentation/screens/record/workout_sensor_bootstrapper.dart`

Responsibilities:

- adapt sensor startup results into `WorkoutSessionState`
- apply last known position
- convert sensor startup failures into state changes

### Sensor Controller

- `lib/features/workout/presentation/screens/record/workout_sensor_controller.dart`

Responsibilities:

- start and stop GPS tracking
- start and stop step tracking
- own service-level stream subscription lifecycle

### Environment Controller

- `lib/features/workout/presentation/screens/record/workout_environment_controller.dart`

Responsibilities:

- start and stop `EnvironmentClassifier`
- feed positions and step deltas into the classifier
- forward classifier events back to the ViewModel

## Data Flow

### GPS Flow

```text
Device GPS
-> Geolocator stream
-> LocationTrackingService
-> WorkoutSensorController
-> WorkoutSessionNotifier._onPosition()
-> WorkoutTrackingEngine.evaluateGpsUpdate()
-> WorkoutSessionState update
-> TrackingMapWidget / RecordScreen
-> WorkoutRecordingCoordinator raw GPS buffer
-> remote raw_gps_points upload
```

### Step Flow

```text
Pedometer stream
-> StepTrackingService
-> WorkoutSensorController
-> WorkoutSessionNotifier._onStep()
-> WorkoutTrackingEngine.evaluateStepUpdate()
-> WorkoutSessionState update
-> WorkoutRecordingCoordinator raw step buffer
-> remote raw_step_intervals upload
```

### Finish Flow

```text
User taps stop
-> WorkoutSessionNotifier.stopWorkout()
-> WorkoutSessionLifecycle.stopping(...)
-> WorkoutSensorController stop
-> WorkoutEnvironmentController stop
-> WorkoutSessionFinalizer.finalize(...)
-> workoutListProvider.saveSession(...)
-> WorkoutRecordingCoordinator.flushPendingRawTracking(...)
-> WorkoutRecordingCoordinator.enqueueProcessingForSession(...)
```

## File-Level Ownership

### Presentation

- `record_screen.dart`
  UI
- `record_providers.dart`
  ViewModel
- `tracking_map_widget.dart`
  map rendering

### Presentation Support

- `workout_session_state.dart`
  session state model
- `workout_session_lifecycle.dart`
  state transitions
- `workout_session_starter.dart`
  start plan
- `workout_session_finalizer.dart`
  stop snapshot builder
- `workout_sensor_bootstrapper.dart`
  sensor state adaptation
- `workout_sensor_controller.dart`
  GPS and step service lifecycle
- `workout_environment_controller.dart`
  classifier lifecycle
- `workout_recording_coordinator.dart`
  backend recording orchestration

### Domain

- `workout_tracking_engine.dart`
  live tracking business rules
- `workout_metrics_calculator.dart`
  canonical metrics formulas

### Core Services

- `core/services/location_tracking_service.dart`
  low-level GPS stream and permissions
- `core/services/step_tracking_service.dart`
  low-level step stream and permissions
- `core/services/environment_detector.dart`
  environment classification algorithm

## Dependency Direction

The intended dependency direction for this flow is:

```text
View
-> ViewModel
-> Presentation support classes / domain services / controllers / coordinator
-> core services / repositories / datasources
```

Important rules:

- Views should not call GPS or step services directly.
- Business rules should prefer `WorkoutTrackingEngine`.
- Session state transitions should prefer `WorkoutSessionLifecycle`.
- Final session snapshot building should prefer `WorkoutSessionFinalizer`.
- Raw upload and processing enqueue should prefer `WorkoutRecordingCoordinator`.

## What Improved

Compared to the old structure, the current design gives us:

- clearer separation between UI state and business rules
- clearer separation between business rules and sensor infrastructure
- clearer separation between client recording flow and backend ingestion flow
- smaller, easier-to-read files
- easier unit testing for tracking decisions and session lifecycle

## Current Limitations

This is a strong improvement, but not a perfect end state yet.

Remaining limitations:

- `WorkoutSessionNotifier` is still the main orchestration point and is still relatively large
- some timer orchestration still lives inside the ViewModel
- the recording flow has stronger MVVM boundaries than the rest of the app
- full integration tests for `WorkoutSessionNotifier` event flow are still a good next step

## Recommended Next Steps

Short-term:

- add notifier integration tests for `start -> GPS update -> stop`
- add tests for pause/resume edge cases
- add tests for fallback transitions under weak GPS

Medium-term:

- apply the same MVVM split pattern to other complex workout flows
- introduce more use-case style classes if the ViewModel grows again
- keep backend ingestion and deterministic processing vocabulary aligned with docs

## Summary

For the workout recording flow, the app now follows a practical Flutter MVVM style:

- `View` renders and sends intents
- `ViewModel` exposes state and orchestrates
- helper classes own lifecycle/state transitions
- domain services own workout rules
- controllers own sensor and classifier lifecycle
- coordinator owns backend recording workflow

This keeps realtime tracking code easier to debug, safer to refactor, and more maintainable as the backend processing pipeline grows.
