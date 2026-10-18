import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';
import 'package:latlong2/latlong.dart';

/// Output from a single benchmark step processed by [RecoveryFsmBenchmarkAdapter].
class RecoveryAdapterOutput {
  final GpsRecoveryFsmResult fsmResult;
  final bool isCovarianceInitialized;
  final double currentErrorMeters;
  final double addedDistanceMeters;
  final double totalAccumulatedDistanceMeters;
  final double escrowDistanceMeters;
  final bool wasReAnchorExecuted;
  final double reAnchorJumpMeters;

  const RecoveryAdapterOutput({
    required this.fsmResult,
    required this.isCovarianceInitialized,
    required this.currentErrorMeters,
    required this.addedDistanceMeters,
    required this.totalAccumulatedDistanceMeters,
    required this.escrowDistanceMeters,
    this.wasReAnchorExecuted = false,
    this.reAnchorJumpMeters = 0.0,
  });

  LatLng get position => fsmResult.estimatedPosition;
  double get speedMs => fsmResult.estimatedSpeedMs;
  double get headingDeg => fsmResult.estimatedHeadingDeg;
  GpsRecoveryState get state => fsmResult.state;
  EkfMeasurementDecision get decision => fsmResult.decision;
}

/// Isolated benchmark adapter connecting [GpsRecoveryStateMachine] to the 108-scenario
/// synthetic benchmark suite for Phase 5 Milestone 2A validation.
///
/// Implements:
/// - Explicit distinction between initialized EKF covariance and cold uninitialized covariance.
/// - Treatment of `hasAuxiliarySensors` as a capability hint (demands corroborating evidence).
/// - Recovery latency measurement from loss-of-lock to tracking re-establishment.
/// - Peak transient error capture during loss-of-lock episodes.
/// - Post-recovery steady-state accuracy measurement.
/// - Independent accounting of distance overcount, undercount, and re-anchor jump exclusion.
class RecoveryFsmBenchmarkAdapter {
  final GpsRecoveryStateMachine fsm;
  static const Distance _distance = Distance();

  // Recovery episode state tracking
  DateTime? _lossOfLockStartTime;
  double _currentEpisodeMaxTransientError = 0.0;
  bool _inRecoveryEpisode = false;
  int _postRecoverySamplesRemaining = 0;

  // Cumulative metrics
  final List<double> recoveryLatenciesSec = [];
  final List<double> maxTransientErrors = [];
  final List<double> postRecoveryErrors = [];

  int reAnchorEventCount = 0;
  double totalReAnchorJumpMeters = 0.0;

  int initializedCovarianceCount = 0;
  int uninitializedCovarianceCount = 0;
  int capabilityHintWithoutEvidenceCount = 0;

  double totalOvercountMeters = 0.0;
  double totalUndercountMeters = 0.0;

  RecoveryFsmBenchmarkAdapter({
    GpsRecoveryStateMachine? customFsm,
    double maxTurnHeadingNoiseScale = 14.0,
  }) : fsm = customFsm ??
            GpsRecoveryStateMachine(
              ekf: ExtendedKalmanFilter(maxTurnHeadingNoiseScale: maxTurnHeadingNoiseScale),
            );

  bool get isCovariancePositiveSemiDefinite => fsm.isCovariancePositiveSemiDefinite;
  List<List<double>> get covariance => fsm.covariance;
  GpsRecoveryState get state => fsm.state;
  double get accumulatedDistanceMeters => fsm.accumulatedDistanceMeters;
  double get escrowDistanceMeters => fsm.escrowDistanceMeters;
  LatLng? get currentPosition => fsm.currentPosition;
  List<FsmDistanceTransaction> get distanceLedger => fsm.distanceLedger;

  void setScenario(String scenario) => fsm.setScenario(scenario);
  void clearDistanceLedger() => fsm.clearDistanceLedger();

  /// Process a single benchmark measurement with ground-truth correlation.
  RecoveryAdapterOutput processMeasurement({
    required LatLng rawPoint,
    required LatLng truthPoint,
    required double accuracyMeters,
    required double timeDeltaSec,
    required DateTime timestamp,
    double? speedMs,
    double? headingDeg,
    bool hasAuxiliarySensorsHint = false,
  }) {
    // 1. Scope 8: Treat hasAuxiliarySensors as a capability hint, not proof of trustworthy evidence
    final bool hasTrustworthySensorEvidence;
    if (hasAuxiliarySensorsHint) {
      if (headingDeg != null) {
        hasTrustworthySensorEvidence = true;
      } else {
        // Capability exists on device, but sensor evidence is absent (e.g. heading dropout)
        hasTrustworthySensorEvidence = false;
        capabilityHintWithoutEvidenceCount++;
      }
    } else {
      hasTrustworthySensorEvidence = false;
    }

    final prevPos = fsm.currentPosition;

    // 2. Execute FSM measurement update
    final fsmResult = fsm.processMeasurement(
      point: rawPoint,
      accuracyMeters: accuracyMeters,
      timeDeltaSec: timeDeltaSec,
      timestamp: timestamp,
      speedMs: speedMs,
      headingDeg: headingDeg,
      hasAuxiliarySensors: hasTrustworthySensorEvidence,
    );

    // 3. Scope 7: Clearly distinguish uninitialized covariance from initialized EKF covariance
    // In S2, S3, S4, or before the session is started, EKF is cold/uninitialized.
    final bool isCovarianceInitialized = fsm.isSessionStarted &&
        (fsmResult.state == GpsRecoveryState.s0NormalTracking ||
            fsmResult.state == GpsRecoveryState.s0Provisional ||
            fsmResult.state == GpsRecoveryState.s1SuspectedDegraded ||
            fsmResult.state == GpsRecoveryState.s5SafeReset);

    if (isCovarianceInitialized) {
      initializedCovarianceCount++;
    } else {
      uninitializedCovarianceCount++;
    }

    // 4. Scope 4: Recovery latency and transient error tracking
    final currentPos = fsmResult.estimatedPosition;
    final currentError = _distance.as(LengthUnit.Meter, currentPos, truthPoint);

    if (fsmResult.state == GpsRecoveryState.s2LossOfLock ||
        fsmResult.state == GpsRecoveryState.s3CandidateReacquisition) {
      if (!_inRecoveryEpisode) {
        _inRecoveryEpisode = true;
        _lossOfLockStartTime = timestamp;
        _currentEpisodeMaxTransientError = currentError;
      } else {
        _currentEpisodeMaxTransientError = math.max(_currentEpisodeMaxTransientError, currentError);
      }
    } else if (_inRecoveryEpisode &&
        (fsmResult.state == GpsRecoveryState.s0NormalTracking ||
            fsmResult.state == GpsRecoveryState.s0Provisional)) {
      // Re-entry into active tracking: finalize recovery episode
      if (_lossOfLockStartTime != null) {
        final latency = (timestamp.difference(_lossOfLockStartTime!).inMicroseconds) / 1e6;
        recoveryLatenciesSec.add(latency);
      }
      maxTransientErrors.add(_currentEpisodeMaxTransientError);
      _inRecoveryEpisode = false;
      _lossOfLockStartTime = null;
      _currentEpisodeMaxTransientError = 0.0;
      _postRecoverySamplesRemaining = 5; // Monitor next 5 samples for post-recovery steady-state
    }

    if (_postRecoverySamplesRemaining > 0 &&
        (fsmResult.state == GpsRecoveryState.s0NormalTracking ||
            fsmResult.state == GpsRecoveryState.s0Provisional)) {
      postRecoveryErrors.add(currentError);
      _postRecoverySamplesRemaining--;
    }

    // 5. Scope 5: Re-anchor jump measurement
    var reAnchorJumpMeters = 0.0;
    var wasReAnchorExecuted = false;
    if (fsmResult.wasResetApplied && prevPos != null) {
      wasReAnchorExecuted = true;
      reAnchorEventCount++;
      reAnchorJumpMeters = _distance.as(LengthUnit.Meter, prevPos, fsmResult.estimatedPosition);
      totalReAnchorJumpMeters += reAnchorJumpMeters;

      // Verification: assert that Euclidean jump was NOT added to distance
      assert(fsmResult.addedDistanceMeters <= (speedMs ?? 20.0) * timeDeltaSec + 1e-4);
    }

    return RecoveryAdapterOutput(
      fsmResult: fsmResult,
      isCovarianceInitialized: isCovarianceInitialized,
      currentErrorMeters: currentError,
      addedDistanceMeters: fsmResult.addedDistanceMeters,
      totalAccumulatedDistanceMeters: fsmResult.totalAccumulatedDistanceMeters,
      escrowDistanceMeters: fsmResult.escrowDistanceMeters,
      wasReAnchorExecuted: wasReAnchorExecuted,
      reAnchorJumpMeters: reAnchorJumpMeters,
    );
  }
}
