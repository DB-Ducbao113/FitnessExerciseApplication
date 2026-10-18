import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:latlong2/latlong.dart';

/// States of the GPS Recovery Finite State Machine for EKF 4-State.
enum GpsRecoveryState {
  /// Normal tracking state: GPS measurements admitted and updated through EKF.
  /// Distance is committed directly to workout distance.
  s0NormalTracking,

  /// Low-confidence provisional tracking state (GPS-only, weak geometry, no heading corroboration).
  /// Measurement variance scaled 4x, heading innovation damped, tentative distance held in escrow.
  /// Distance is committed only after passing the provisional validation window.
  s0Provisional,

  /// Suspected degraded state: N_reject >= 3 or time gap >= 3.0s.
  /// EKF runs predict-only; requires 2 consecutive clean fixes to return to S0 (hysteresis).
  s1SuspectedDegraded,

  /// Loss of lock: N_reject >= 5 or time gap >= 5.0s or distance error > D_max.
  /// Heading is frozen, distance accumulation is completely FROZEN (0.0 m added).
  /// Candidate buffer is opened.
  s2LossOfLock,

  /// Candidate reacquisition state: sliding candidate buffer collects K=3 fixes
  /// satisfying strict pairwise kinematic constraints.
  s3CandidateReacquisition,

  /// Validated re-anchor state: K=3 candidates verified kinematically.
  /// Snapshot is captured prior to resetting the filter state.
  s4ValidatedReAnchor,

  /// Safe reset state: State vector and diagonal covariance P_reset re-initialized.
  /// Re-anchor Euclidean jump is strictly 0.0 m added to distance.
  /// Enters M=3 probationary tracking window.
  s5SafeReset,
}

/// A candidate GPS fix collected during loss-of-lock reacquisition (S3).
class GpsCandidateFix {
  final LatLng point;
  final double accuracyMeters;
  final DateTime timestamp;
  final double? speedMs;
  final double? headingDeg;

  const GpsCandidateFix({
    required this.point,
    required this.accuracyMeters,
    required this.timestamp,
    this.speedMs,
    this.headingDeg,
  });
}

/// Spatial blacklist entry to prevent re-anchoring into known multipath or false clusters.
class SpatialBlacklistEntry {
  final LatLng center;
  final double radiusMeters;
  final DateTime expiryTime;

  static const Distance _distance = Distance();

  const SpatialBlacklistEntry({
    required this.center,
    this.radiusMeters = 40.0,
    required this.expiryTime,
  });

  bool isExpired(DateTime now) => now.isAfter(expiryTime);

  bool contains(LatLng point) {
    return _distance.as(LengthUnit.Meter, center, point) <= radiusMeters;
  }
}

/// Immutable snapshot captured at S4 before safe reset (S5),
/// used for cold reinitialization and distance recovery if probation fails.
class RecoverySnapshot {
  /// The last known trustworthy position confirmed in S0/S1 before entering loss of lock.
  final LatLng? lastValidPosition;
  final double lastValidSpeedMs;
  final double? lastValidHeadingDeg;
  final DateTime? lastValidTimestamp;

  /// The committed workout distance strictly before any tentative re-anchor.
  final double committedDistanceMeters;

  /// The baseline position variance from before re-anchor attempt.
  final double baselinePositionVariance;

  /// Timestamp when snapshot was captured at S4.
  final DateTime snapshotTimestamp;

  const RecoverySnapshot({
    required this.lastValidPosition,
    required this.lastValidSpeedMs,
    required this.lastValidHeadingDeg,
    required this.lastValidTimestamp,
    required this.committedDistanceMeters,
    required this.baselinePositionVariance,
    required this.snapshotTimestamp,
  });
}

/// Output estimation from a single measurement processing cycle in the recovery FSM.
class GpsRecoveryFsmResult {
  final GpsRecoveryState state;
  final LatLng estimatedPosition;
  final double estimatedSpeedMs;
  final double estimatedHeadingDeg;
  final double positionVariance;
  final double addedDistanceMeters;
  final double totalAccumulatedDistanceMeters;
  final double escrowDistanceMeters;
  final int consecutiveRejections;
  final bool wasResetApplied;
  final bool wasRollbackApplied;
  final bool isCandidateBuffered;
  final int candidateCount;
  final EkfMeasurementDecision decision;
  final double? nis;

  const GpsRecoveryFsmResult({
    required this.state,
    required this.estimatedPosition,
    required this.estimatedSpeedMs,
    required this.estimatedHeadingDeg,
    required this.positionVariance,
    required this.addedDistanceMeters,
    required this.totalAccumulatedDistanceMeters,
    this.escrowDistanceMeters = 0.0,
    required this.consecutiveRejections,
    this.wasResetApplied = false,
    this.wasRollbackApplied = false,
    this.isCandidateBuffered = false,
    this.candidateCount = 0,
    required this.decision,
    this.nis,
  });
}

/// Exact-once mutation types for FSM distance ledger accounting.
enum FsmDistanceMutationType {
  /// Normal tracking Euclidean step admitted in S0 or S1 hysteresis recovery.
  normalStep,

  /// Inertial predict-only velocity step during rejection in S0 or S1.
  inertialStep,

  /// Tentative distance placed into escrow (S0 provisional or S5 probation).
  escrowCreation,

  /// Validated escrow committed to workout accumulated distance (S0 provisional or S5).
  escrowCommit,

  /// Unverified escrow purged and discarded (on degradation, rejection, or rollback).
  escrowDiscard,

  /// Net gap bridging displacement placed into escrow at S4/S5 re-anchor.
  gapBridging,

  /// Snapshot distance restoration upon probation rollback failure.
  rollbackCorrection,

  /// State transition or other adjustments without distance mutation.
  otherAdjustments,
}

/// Immutable record of an exact-once FSM distance mutation.
class FsmDistanceTransaction {
  final int eventId;
  final String scenario;
  final DateTime timestamp;
  final GpsRecoveryState fromState;
  final GpsRecoveryState toState;
  final FsmDistanceMutationType mutationType;
  final double committedDeltaMeters;
  final double escrowDeltaMeters;
  final double resultingAccumulatedDistanceMeters;
  final double resultingEscrowDistanceMeters;
  final String description;

  const FsmDistanceTransaction({
    required this.eventId,
    required this.scenario,
    required this.timestamp,
    required this.fromState,
    required this.toState,
    required this.mutationType,
    required this.committedDeltaMeters,
    required this.escrowDeltaMeters,
    required this.resultingAccumulatedDistanceMeters,
    required this.resultingEscrowDistanceMeters,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'scenario': scenario,
    'timestamp': timestamp.toIso8601String(),
    'from_state': fromState.name,
    'to_state': toState.name,
    'mutation_type': mutationType.name,
    'committed_delta_meters': committedDeltaMeters,
    'escrow_delta_meters': escrowDeltaMeters,
    'resulting_accumulated_meters': resultingAccumulatedDistanceMeters,
    'resulting_escrow_meters': resultingEscrowDistanceMeters,
    'description': description,
  };
}

/// Isolated GPS Recovery Finite State Machine for EKF 4-State filtering.
///
/// Implements S0–S5 states, rejection counters, candidate buffering (K=3),
/// pairwise kinematic checks, probationary tracking window (M=3), spatial blacklisting,
/// cold reinitialization rollback, provisional distance escrow, and exact-once distance
/// ledger accounting without modifying the EKF core, NIS thresholds, or production pipeline.
class GpsRecoveryStateMachine {
  final ExtendedKalmanFilter _ekf;

  GpsRecoveryState _state = GpsRecoveryState.s0NormalTracking;
  int _consecutiveRejections = 0;
  int _s1CleanFixCount = 0;
  int _probationRemaining = 0;
  int _provisionalSuccessCount = 0;

  double _accumulatedDistanceMeters = 0.0;
  double _escrowDistanceMeters = 0.0;

  LatLng? _currentPosition;
  double _currentSpeedMs = 0.0;
  double _currentHeadingDeg = 0.0;
  double _currentPositionVariance = 25.0;
  DateTime? _lastTimestamp;
  DateTime? get lastTimestamp => _lastTimestamp;

  LatLng? _lastValidPosition;
  double _lastValidSpeedMs = 0.0;
  double? _lastValidHeadingDeg;
  DateTime? _lastValidTimestamp;

  final List<GpsCandidateFix> _candidateBuffer = [];
  final List<SpatialBlacklistEntry> _blacklist = [];
  RecoverySnapshot? _snapshot;

  static const Distance _distance = Distance();

  // Thresholds and parameters from Phase 5 Design Proposal
  static const int kRejectionLimitS1 = 3;
  static const int kRejectionLimitS2 = 5;
  static const double kTimeGapS1Sec = 3.0;
  static const double kTimeGapS2Sec = 5.0;
  static const double kCandidateBufferLifetimeSec = 6.0;
  static const int kRequiredCandidateCount = 3;
  static const int kProbationWindowSize = 3;
  static const int kProvisionalValidationFixes = 5;
  static const double kMaxPairwiseSpeedMs = 20.0; // 72 km/h
  static const double kMaxPairwiseAccelMs2 = 4.0;
  static const double kCandidateMinDtSec = 0.4;
  static const double kCandidateMaxDtSec = 2.5;
  static const double kBlacklistRadiusMeters = 40.0;
  static const Duration kBlacklistDuration = Duration(seconds: 10);
  static const double kNisG1 = 5.991;
  static const double kNisG2 = 13.816;
  static const double kStationarySpeedThresholdMs = 0.8;
  static const double kStationaryDisplacementThresholdMeters = 2.5;

  bool _isSessionStarted = false;
  bool get isSessionStarted => _isSessionStarted;

  /// Active scenario tag for distance ledger auditing.
  String currentScenario = '';

  /// Exact-once distance mutation audit ledger.
  final List<FsmDistanceTransaction> distanceLedger = [];

  GpsRecoveryStateMachine({ExtendedKalmanFilter? ekf})
      : _ekf = ekf ?? ExtendedKalmanFilter();

  void setScenario(String scenario) {
    currentScenario = scenario;
  }

  void clearDistanceLedger() {
    distanceLedger.clear();
  }

  void reset() {
    _ekf.reset();
    _state = GpsRecoveryState.s0NormalTracking;
    _consecutiveRejections = 0;
    _s1CleanFixCount = 0;
    _probationRemaining = 0;
    _provisionalSuccessCount = 0;
    _accumulatedDistanceMeters = 0.0;
    _escrowDistanceMeters = 0.0;
    _currentPosition = null;
    _currentSpeedMs = 0.0;
    _currentHeadingDeg = 0.0;
    _currentPositionVariance = 25.0;
    _lastTimestamp = null;
    _lastValidPosition = null;
    _lastValidSpeedMs = 0.0;
    _lastValidHeadingDeg = null;
    _lastValidTimestamp = null;
    _candidateBuffer.clear();
    _blacklist.clear();
    _snapshot = null;
    _isSessionStarted = false;
    distanceLedger.clear();
  }

  void _recordDistanceTransaction({
    required DateTime timestamp,
    required GpsRecoveryState fromState,
    required GpsRecoveryState toState,
    required FsmDistanceMutationType mutationType,
    required double committedDelta,
    required double escrowDelta,
    required String description,
  }) {
    distanceLedger.add(FsmDistanceTransaction(
      eventId: distanceLedger.length + 1,
      scenario: currentScenario,
      timestamp: timestamp,
      fromState: fromState,
      toState: toState,
      mutationType: mutationType,
      committedDeltaMeters: committedDelta,
      escrowDeltaMeters: escrowDelta,
      resultingAccumulatedDistanceMeters: _accumulatedDistanceMeters,
      resultingEscrowDistanceMeters: _escrowDistanceMeters,
      description: description,
    ));
    assert(
      (_accumulatedDistanceMeters -
              distanceLedger.fold<double>(0.0, (sum, t) => sum + t.committedDeltaMeters))
          .abs() < 1e-4,
      'Distance ledger reconciliation failed: accumulated $_accumulatedDistanceMeters != sum deltas',
    );
  }

  GpsRecoveryState get state => _state;
  int get consecutiveRejections => _consecutiveRejections;
  int get candidateCount => _candidateBuffer.length;
  double get accumulatedDistanceMeters => _accumulatedDistanceMeters;
  double get escrowDistanceMeters => _escrowDistanceMeters;
  LatLng? get currentPosition => _currentPosition;
  double get currentSpeedMs => _currentSpeedMs;
  double get currentHeadingDeg => _currentHeadingDeg;
  double get currentPositionVariance => _currentPositionVariance;
  RecoverySnapshot? get snapshot => _snapshot;
  List<SpatialBlacklistEntry> get blacklist => List.unmodifiable(_blacklist);
  List<List<double>> get covariance => _ekf.covariance;
  bool get isCovariancePositiveSemiDefinite => _ekf.isCovariancePositiveSemiDefinite;

  bool isPointBlacklisted(LatLng point, DateTime now) {
    _cleanupBlacklist(now);
    return _blacklist.any((entry) => entry.contains(point));
  }

  void _cleanupBlacklist(DateTime now) {
    _blacklist.removeWhere((entry) => entry.isExpired(now));
  }

  void _transitionToS2(DateTime timestamp, [String reason = 'rejection/time-gap']) {
    final from = _state;
    _state = GpsRecoveryState.s2LossOfLock;
    _candidateBuffer.clear();
    final discarded = _escrowDistanceMeters;
    _escrowDistanceMeters = 0.0;
    _provisionalSuccessCount = 0;
    if (discarded > 0.0) {
      _recordDistanceTransaction(
        timestamp: timestamp,
        fromState: from,
        toState: _state,
        mutationType: FsmDistanceMutationType.escrowDiscard,
        committedDelta: 0.0,
        escrowDelta: -discarded,
        description: 'Transition to S2 ($reason): unverified escrow discarded',
      );
    }
  }

  /// Process an incoming raw GPS measurement through the recovery state machine.
  GpsRecoveryFsmResult processMeasurement({
    required LatLng point,
    required double accuracyMeters,
    required double timeDeltaSec,
    required DateTime timestamp,
    double? speedMs,
    double? headingDeg,
    bool hasAuxiliarySensors = false,
  }) {
    _cleanupBlacklist(timestamp);

    final dt = timeDeltaSec > 0 ? timeDeltaSec : 1.0;
    var addedDistance = 0.0;
    var resetApplied = false;
    var rollbackApplied = false;
    var candidateBuffered = false;
    var decision = EkfMeasurementDecision.normal;
    double? nis;

    // Handle initialization on the first valid point of the session
    if (!_isSessionStarted) {
      _isSessionStarted = true;
      final initialEstimate = _ekf.update(
        measurementPoint: point,
        accuracyMeters: accuracyMeters,
        timeDeltaSec: dt,
        speedMs: speedMs,
        headingDeg: headingDeg,
      );
      _currentPosition = initialEstimate.position;
      _currentSpeedMs = initialEstimate.speedMs;
      _currentHeadingDeg = initialEstimate.headingDeg;
      _currentPositionVariance = initialEstimate.positionVariance;
      _lastValidPosition = point;
      _lastValidSpeedMs = initialEstimate.speedMs;
      _lastValidHeadingDeg = initialEstimate.headingDeg;
      _lastValidTimestamp = timestamp;
      _lastTimestamp = timestamp;
      _state = GpsRecoveryState.s0NormalTracking;
      _recordDistanceTransaction(
        timestamp: timestamp,
        fromState: GpsRecoveryState.s0NormalTracking,
        toState: GpsRecoveryState.s0NormalTracking,
        mutationType: FsmDistanceMutationType.otherAdjustments,
        committedDelta: 0.0,
        escrowDelta: 0.0,
        description: 'First fix initialized: filter anchored at initial position',
      );

      return GpsRecoveryFsmResult(
        state: _state,
        estimatedPosition: _currentPosition!,
        estimatedSpeedMs: _currentSpeedMs,
        estimatedHeadingDeg: _currentHeadingDeg,
        positionVariance: _currentPositionVariance,
        addedDistanceMeters: 0.0,
        totalAccumulatedDistanceMeters: _accumulatedDistanceMeters,
        consecutiveRejections: 0,
        decision: initialEstimate.diagnostics.positionDecision,
        nis: initialEstimate.diagnostics.positionNis,
      );
    }

    // Main FSM state dispatch
    switch (_state) {
      case GpsRecoveryState.s0NormalTracking:
        // Check for time gap degradation
        if (dt >= kTimeGapS2Sec) {
          _consecutiveRejections = kRejectionLimitS2;
          _transitionToS2(timestamp, 'time gap dt >= 5.0s in S0');
          decision = EkfMeasurementDecision.rejected;
          addedDistance = 0.0;
          break;
        } else if (dt >= kTimeGapS1Sec) {
          _consecutiveRejections = kRejectionLimitS1;
          _state = GpsRecoveryState.s1SuspectedDegraded;
        }

        final prevPos = _currentPosition!;
        final ekfEstimate = _ekf.update(
          measurementPoint: point,
          accuracyMeters: accuracyMeters,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: headingDeg,
        );

        decision = ekfEstimate.diagnostics.positionDecision;
        nis = ekfEstimate.diagnostics.positionNis;

        if (decision == EkfMeasurementDecision.rejected) {
          _consecutiveRejections++;
          if (_consecutiveRejections >= kRejectionLimitS2) {
            _transitionToS2(timestamp, 'N_reject >= 5 in S0');
            addedDistance = 0.0;
          } else if (_consecutiveRejections >= kRejectionLimitS1) {
            final from = _state;
            _state = GpsRecoveryState.s1SuspectedDegraded;
            addedDistance = (ekfEstimate.speedMs * dt).clamp(0.0, 1.2 * _lastValidSpeedMs * dt);
            _accumulatedDistanceMeters += addedDistance;
            _recordDistanceTransaction(
              timestamp: timestamp,
              fromState: from,
              toState: _state,
              mutationType: FsmDistanceMutationType.inertialStep,
              committedDelta: addedDistance,
              escrowDelta: 0.0,
              description: 'S0 to S1 degradation: inertial velocity step on rejection',
            );
          } else {
            // Single/isolated spike in S0: predict-only motion along track
            // Distance accumulated along inertial velocity, zero contribution from the spike
            addedDistance = (ekfEstimate.speedMs * dt).clamp(0.0, 1.2 * _lastValidSpeedMs * dt);
            _accumulatedDistanceMeters += addedDistance;
            _recordDistanceTransaction(
              timestamp: timestamp,
              fromState: GpsRecoveryState.s0NormalTracking,
              toState: GpsRecoveryState.s0NormalTracking,
              mutationType: FsmDistanceMutationType.inertialStep,
              committedDelta: addedDistance,
              escrowDelta: 0.0,
              description: 'S0 isolated spike: inertial velocity step on rejection',
            );
          }

          _currentPosition = ekfEstimate.position;
          _currentSpeedMs = ekfEstimate.speedMs;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;
        } else {
          _consecutiveRejections = 0;
          final stepDist = _distance.as(LengthUnit.Meter, prevPos, ekfEstimate.position);
          addedDistance = stepDist.clamp(0.0, kMaxPairwiseSpeedMs * dt);

          // Stationary jitter suppression: if reported speed is below threshold or motion is stationary
          final isStationary = (speedMs != null && speedMs < kStationarySpeedThresholdMs) ||
              (ekfEstimate.speedMs < kStationarySpeedThresholdMs &&
                  stepDist < kStationaryDisplacementThresholdMeters);
          if (isStationary) {
            addedDistance = 0.0;
            _currentSpeedMs = 0.0;
          } else {
            _currentSpeedMs = ekfEstimate.speedMs;
          }

          _accumulatedDistanceMeters += addedDistance;
          _recordDistanceTransaction(
            timestamp: timestamp,
            fromState: GpsRecoveryState.s0NormalTracking,
            toState: GpsRecoveryState.s0NormalTracking,
            mutationType: FsmDistanceMutationType.normalStep,
            committedDelta: addedDistance,
            escrowDelta: 0.0,
            description: isStationary
                ? 'S0 stationary fix: jitter suppressed (0.0m added)'
                : 'S0 clean fix: Euclidean step added to workout distance',
          );
          _currentPosition = ekfEstimate.position;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;

          _lastValidPosition = ekfEstimate.position;
          _lastValidSpeedMs = ekfEstimate.speedMs;
          _lastValidHeadingDeg = ekfEstimate.headingDeg;
          _lastValidTimestamp = timestamp;
        }
        break;

      case GpsRecoveryState.s0Provisional:
        // Check for time gap degradation
        if (dt >= kTimeGapS2Sec) {
          _consecutiveRejections = kRejectionLimitS2;
          _transitionToS2(timestamp, 'time gap dt >= 5.0s in S0 Provisional');
          decision = EkfMeasurementDecision.rejected;
          addedDistance = 0.0;
          break;
        } else if (dt >= kTimeGapS1Sec) {
          final from = _state;
          _consecutiveRejections = kRejectionLimitS1;
          _state = GpsRecoveryState.s1SuspectedDegraded;
          final discarded = _escrowDistanceMeters;
          _escrowDistanceMeters = 0.0; // Discard unverified escrow on degradation
          _provisionalSuccessCount = 0;
          if (discarded > 0.0) {
            _recordDistanceTransaction(
              timestamp: timestamp,
              fromState: from,
              toState: _state,
              mutationType: FsmDistanceMutationType.escrowDiscard,
              committedDelta: 0.0,
              escrowDelta: -discarded,
              description: 'S0 Provisional to S1: unverified escrow discarded on time gap',
            );
          }
        }

        // Apply 4x measurement variance inflation in provisional mode
        final effectiveAccuracy = accuracyMeters * 2.0;
        final prevPos = _currentPosition!;
        final ekfEstimate = _ekf.update(
          measurementPoint: point,
          accuracyMeters: effectiveAccuracy,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: headingDeg,
        );

        decision = ekfEstimate.diagnostics.positionDecision;
        nis = ekfEstimate.diagnostics.positionNis;

        if (decision == EkfMeasurementDecision.rejected) {
          // Rejection in provisional mode: unverified track broke down!
          final discarded = _escrowDistanceMeters;
          _escrowDistanceMeters = 0.0; // Discard escrow completely!
          _provisionalSuccessCount = 0;
          _consecutiveRejections++;
          final from = _state;
          if (_consecutiveRejections >= kRejectionLimitS2) {
            _transitionToS2(timestamp, 'N_reject >= 5 in S0 Provisional');
          } else if (_consecutiveRejections >= kRejectionLimitS1) {
            _state = GpsRecoveryState.s1SuspectedDegraded;
          }
          if (discarded > 0.0) {
            _recordDistanceTransaction(
              timestamp: timestamp,
              fromState: from,
              toState: _state,
              mutationType: FsmDistanceMutationType.escrowDiscard,
              committedDelta: 0.0,
              escrowDelta: -discarded,
              description: 'S0 Provisional rejection: unverified escrow discarded',
            );
          }
          addedDistance = 0.0;
          _currentPosition = ekfEstimate.position;
          _currentSpeedMs = ekfEstimate.speedMs;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;
        } else {
          _consecutiveRejections = 0;
          final stepDist = _distance.as(LengthUnit.Meter, prevPos, ekfEstimate.position);
          final tentativeStep = stepDist.clamp(0.0, kMaxPairwiseSpeedMs * dt);

          final isStationary = (speedMs != null && speedMs < kStationarySpeedThresholdMs) ||
              (ekfEstimate.speedMs < kStationarySpeedThresholdMs &&
                  stepDist < kStationaryDisplacementThresholdMeters);

          if (isStationary) {
            _currentSpeedMs = 0.0;
          } else {
            _currentSpeedMs = ekfEstimate.speedMs;
            // ACCUMULATE TENTATIVE DISTANCE IN ESCROW, NOT COMMITTED WORKOUT DISTANCE
            _escrowDistanceMeters += tentativeStep;
            _recordDistanceTransaction(
              timestamp: timestamp,
              fromState: GpsRecoveryState.s0Provisional,
              toState: GpsRecoveryState.s0Provisional,
              mutationType: FsmDistanceMutationType.escrowCreation,
              committedDelta: 0.0,
              escrowDelta: tentativeStep,
              description: 'S0 Provisional tentative step placed in escrow',
            );
          }

          _currentPosition = ekfEstimate.position;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;
          _lastValidPosition = ekfEstimate.position;
          _lastValidSpeedMs = ekfEstimate.speedMs;
          _lastValidHeadingDeg = ekfEstimate.headingDeg;
          _lastValidTimestamp = timestamp;

          _provisionalSuccessCount++;
          if (_provisionalSuccessCount >= kProvisionalValidationFixes) {
            // Provisional validation window passed: commit escrow to workout distance!
            final committed = _escrowDistanceMeters;
            _accumulatedDistanceMeters += committed;
            addedDistance = committed;
            _escrowDistanceMeters = 0.0;
            _state = GpsRecoveryState.s0NormalTracking;
            _provisionalSuccessCount = 0;
            _recordDistanceTransaction(
              timestamp: timestamp,
              fromState: GpsRecoveryState.s0Provisional,
              toState: GpsRecoveryState.s0NormalTracking,
              mutationType: FsmDistanceMutationType.escrowCommit,
              committedDelta: committed,
              escrowDelta: -committed,
              description: 'S0 Provisional validated ($kProvisionalValidationFixes clean fixes): escrow committed to workout distance',
            );
          } else {
            // Still in provisional window: distance remains in escrow
            addedDistance = 0.0;
          }
        }
        break;

      case GpsRecoveryState.s1SuspectedDegraded:
        if (dt >= kTimeGapS2Sec) {
          _consecutiveRejections = kRejectionLimitS2;
          _transitionToS2(timestamp, 'time gap dt >= 5.0s in S1');
          decision = EkfMeasurementDecision.rejected;
          addedDistance = 0.0;
          break;
        }

        final prevPos = _currentPosition!;
        final ekfEstimate = _ekf.update(
          measurementPoint: point,
          accuracyMeters: accuracyMeters,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: headingDeg,
        );

        decision = ekfEstimate.diagnostics.positionDecision;
        nis = ekfEstimate.diagnostics.positionNis;

        final speedDiff = (ekfEstimate.speedMs - _lastValidSpeedMs).abs();
        final isCleanFix = decision != EkfMeasurementDecision.rejected &&
            (nis ?? double.infinity) < kNisG1 &&
            accuracyMeters <= 12.0 &&
            speedDiff <= 3.0;

        if (isCleanFix) {
          _s1CleanFixCount++;
          if (_s1CleanFixCount >= 2) {
            // Hysteresis exit: 2 consecutive clean fixes -> return to S0
            final from = _state;
            _state = GpsRecoveryState.s0NormalTracking;
            _consecutiveRejections = 0;
            _s1CleanFixCount = 0;

            final stepDist = _distance.as(LengthUnit.Meter, prevPos, ekfEstimate.position);
            addedDistance = stepDist.clamp(0.0, kMaxPairwiseSpeedMs * dt);
            _accumulatedDistanceMeters += addedDistance;
            _recordDistanceTransaction(
              timestamp: timestamp,
              fromState: from,
              toState: _state,
              mutationType: FsmDistanceMutationType.normalStep,
              committedDelta: addedDistance,
              escrowDelta: 0.0,
              description: 'S1 hysteresis recovery (2 clean fixes): Euclidean step added to workout distance',
            );

            _currentPosition = ekfEstimate.position;
            _currentSpeedMs = ekfEstimate.speedMs;
            _currentHeadingDeg = ekfEstimate.headingDeg;
            _currentPositionVariance = ekfEstimate.positionVariance;

            _lastValidPosition = ekfEstimate.position;
            _lastValidSpeedMs = ekfEstimate.speedMs;
            _lastValidHeadingDeg = ekfEstimate.headingDeg;
            _lastValidTimestamp = timestamp;
            break;
          }
        } else {
          _s1CleanFixCount = 0;
          _consecutiveRejections++;
        }

        final sigmaPos = math.sqrt(ekfEstimate.positionVariance);
        final dMax = math.max(30.0, _lastValidSpeedMs * dt + 3.0 * sigmaPos);
        final innov = ekfEstimate.diagnostics.positionInnovationMeters ?? 0.0;

        if (_consecutiveRejections >= kRejectionLimitS2 || innov > dMax) {
          _transitionToS2(timestamp, 'N_reject >= 5 or innov > dMax in S1');
          addedDistance = 0.0; // Strictly zero added distance when transitioning to S2
        } else {
          // In S1: distance accumulates along inertial velocity clamped
          addedDistance = (ekfEstimate.speedMs * dt).clamp(0.0, 1.2 * _lastValidSpeedMs * dt);
          _accumulatedDistanceMeters += addedDistance;
          _recordDistanceTransaction(
            timestamp: timestamp,
            fromState: GpsRecoveryState.s1SuspectedDegraded,
            toState: GpsRecoveryState.s1SuspectedDegraded,
            mutationType: FsmDistanceMutationType.inertialStep,
            committedDelta: addedDistance,
            escrowDelta: 0.0,
            description: 'S1 degraded tracking: inertial velocity step added to workout distance',
          );

          _currentPosition = ekfEstimate.position;
          _currentSpeedMs = ekfEstimate.speedMs;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;
        }
        break;

      case GpsRecoveryState.s2LossOfLock:
      case GpsRecoveryState.s3CandidateReacquisition:
        // In S2 and S3, distance accumulation is completely frozen
        addedDistance = 0.0;

        final isBlacklisted = _blacklist.any((entry) => entry.contains(point));
        if (isBlacklisted) {
          // Reject candidate if in blacklisted area
          _candidateBuffer.clear();
          _state = GpsRecoveryState.s2LossOfLock;
          decision = EkfMeasurementDecision.rejected;
          break;
        }

        if (_candidateBuffer.isEmpty) {
          // Candidate 1 entry check
          if (accuracyMeters <= 20.0 && dt >= kCandidateMinDtSec && dt <= 60.0) {
            _candidateBuffer.add(GpsCandidateFix(
              point: point,
              accuracyMeters: accuracyMeters,
              timestamp: timestamp,
              speedMs: speedMs,
              headingDeg: headingDeg,
            ));
            _state = GpsRecoveryState.s3CandidateReacquisition;
            candidateBuffered = true;
          }
        } else {
          // Check candidate buffer lifetime: T_buf_life <= 6.0s
          final bufferLifespanSec = (timestamp.difference(_candidateBuffer.first.timestamp).inMicroseconds) / 1e6;
          if (bufferLifespanSec > kCandidateBufferLifetimeSec) {
            // Expired -> fail-closed: flush buffer, return to S2
            _candidateBuffer.clear();
            _state = GpsRecoveryState.s2LossOfLock;
            break;
          }

          final prevCandidate = _candidateBuffer.last;
          final pairDt = (timestamp.difference(prevCandidate.timestamp).inMicroseconds) / 1e6;

          if (pairDt < kCandidateMinDtSec || pairDt > kCandidateMaxDtSec) {
            // Interval violation -> fail-closed
            _candidateBuffer.clear();
            _state = GpsRecoveryState.s2LossOfLock;
            break;
          }

          final pairDist = _distance.as(LengthUnit.Meter, prevCandidate.point, point);
          final pairSpeed = pairDist / pairDt;

          var prevSpeed = prevCandidate.speedMs ?? pairSpeed;
          if (_candidateBuffer.length > 1) {
            final p0 = _candidateBuffer[_candidateBuffer.length - 2];
            final dt0 = (prevCandidate.timestamp.difference(p0.timestamp).inMicroseconds) / 1e6;
            if (dt0 > 0) {
              prevSpeed = _distance.as(LengthUnit.Meter, p0.point, prevCandidate.point) / dt0;
            }
          }

          final pairAccel = (pairSpeed - prevSpeed).abs() / pairDt;

          // Kinematic validation: speed <= 20 m/s, accel <= 4 m/s^2, acc <= 20m
          if (accuracyMeters > 20.0 ||
              pairSpeed > kMaxPairwiseSpeedMs ||
              pairAccel > kMaxPairwiseAccelMs2) {
            // Kinematic violation -> fail-closed
            _candidateBuffer.clear();
            _state = GpsRecoveryState.s2LossOfLock;
            break;
          }

          _candidateBuffer.add(GpsCandidateFix(
            point: point,
            accuracyMeters: accuracyMeters,
            timestamp: timestamp,
            speedMs: speedMs,
            headingDeg: headingDeg,
          ));
          candidateBuffered = true;

          // Check if K=3 candidates reached
          if (_candidateBuffer.length == kRequiredCandidateCount) {
            _state = GpsRecoveryState.s4ValidatedReAnchor;
            _executeReAnchorAndSafeReset(timestamp, hasAuxiliarySensors);
            resetApplied = true;
          }
        }
        break;

      case GpsRecoveryState.s4ValidatedReAnchor:
        // Transient state handled immediately upon reaching K=3
        break;

      case GpsRecoveryState.s5SafeReset:
        // Probationary tracking window: M=3 fixes after Safe Reset
        final prevPos = _currentPosition!;
        final ekfEstimate = _ekf.update(
          measurementPoint: point,
          accuracyMeters: accuracyMeters,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: headingDeg,
        );

        decision = ekfEstimate.diagnostics.positionDecision;
        nis = ekfEstimate.diagnostics.positionNis;

        // Check probation criteria: NIS >= 13.816 or v > 20 m/s triggers ROLLBACK
        if ((nis ?? double.infinity) >= kNisG2 || ekfEstimate.speedMs > kMaxPairwiseSpeedMs) {
          _executeSnapshotRollback(timestamp);
          rollbackApplied = true;
          decision = EkfMeasurementDecision.rejected;
          addedDistance = 0.0;
        } else {
          _probationRemaining--;
          final stepDist = _distance.as(LengthUnit.Meter, prevPos, ekfEstimate.position);
          final clampedStep = stepDist.clamp(0.0, kMaxPairwiseSpeedMs * dt);

          // Escrow buffer holds distance during probation
          _escrowDistanceMeters += clampedStep;
          _recordDistanceTransaction(
            timestamp: timestamp,
            fromState: GpsRecoveryState.s5SafeReset,
            toState: GpsRecoveryState.s5SafeReset,
            mutationType: FsmDistanceMutationType.escrowCreation,
            committedDelta: 0.0,
            escrowDelta: clampedStep,
            description: 'S5 probation step placed in escrow',
          );

          _currentPosition = ekfEstimate.position;
          _currentSpeedMs = ekfEstimate.speedMs;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;

          if (_probationRemaining == 0) {
            _consecutiveRejections = 0;

            if (hasAuxiliarySensors) {
              // Auxiliary sensors confirm track: commit escrow and return to S0
              final from = _state;
              final committed = _escrowDistanceMeters;
              _accumulatedDistanceMeters += committed;
              addedDistance = committed;
              _escrowDistanceMeters = 0.0;
              _candidateBuffer.clear();

              _lastValidPosition = _currentPosition;
              _lastValidSpeedMs = _currentSpeedMs;
              _lastValidHeadingDeg = _currentHeadingDeg;
              _lastValidTimestamp = timestamp;
              _state = GpsRecoveryState.s0NormalTracking;
              _recordDistanceTransaction(
                timestamp: timestamp,
                fromState: from,
                toState: _state,
                mutationType: FsmDistanceMutationType.escrowCommit,
                committedDelta: committed,
                escrowDelta: -committed,
                description: 'S5 probation verified with auxiliary sensors: escrow committed to workout distance',
              );
            } else {
              // GPS-ONLY: Do not claim verified absolute positioning solely from GPS!
              // Enter s0Provisional with distance remaining in escrow!
              final from = _state;
              _candidateBuffer.clear();
              _lastValidPosition = _currentPosition;
              _lastValidSpeedMs = _currentSpeedMs;
              _lastValidHeadingDeg = _currentHeadingDeg;
              _lastValidTimestamp = timestamp;
              _state = GpsRecoveryState.s0Provisional;
              _provisionalSuccessCount = 0;
              addedDistance = 0.0; // Distance remains in escrow!
              _recordDistanceTransaction(
                timestamp: timestamp,
                fromState: from,
                toState: _state,
                mutationType: FsmDistanceMutationType.otherAdjustments,
                committedDelta: 0.0,
                escrowDelta: 0.0,
                description: 'S5 probation complete (GPS-only): transitioned to S0 Provisional with escrow retained',
              );
            }
          }
        }
        break;
    }

    _lastTimestamp = timestamp;

    return GpsRecoveryFsmResult(
      state: _state,
      estimatedPosition: _currentPosition ?? point,
      estimatedSpeedMs: _currentSpeedMs,
      estimatedHeadingDeg: _currentHeadingDeg,
      positionVariance: _currentPositionVariance,
      addedDistanceMeters: addedDistance,
      totalAccumulatedDistanceMeters: _accumulatedDistanceMeters,
      escrowDistanceMeters: _escrowDistanceMeters,
      consecutiveRejections: _consecutiveRejections,
      wasResetApplied: resetApplied,
      wasRollbackApplied: rollbackApplied,
      isCandidateBuffered: candidateBuffered,
      candidateCount: _candidateBuffer.length,
      decision: decision,
      nis: nis,
    );
  }

  /// Executes S4 (Snapshot) -> S5 (Safe Reset) transition.
  void _executeReAnchorAndSafeReset(DateTime timestamp, bool hasAuxiliarySensors) {
    assert(_candidateBuffer.length == kRequiredCandidateCount);

    // 1. Capture snapshot before safe reset: records last known valid position and committed distance
    _snapshot = RecoverySnapshot(
      lastValidPosition: _lastValidPosition,
      lastValidSpeedMs: _lastValidSpeedMs,
      lastValidHeadingDeg: _lastValidHeadingDeg,
      lastValidTimestamp: _lastValidTimestamp,
      committedDistanceMeters: _accumulatedDistanceMeters,
      baselinePositionVariance: _currentPositionVariance,
      snapshotTimestamp: timestamp,
    );

    // 2. Re-anchor kinematic parameters
    final p1 = _candidateBuffer[0];
    final p3 = _candidateBuffer[2];
    final dt13 = (p3.timestamp.difference(p1.timestamp).inMicroseconds) / 1e6;
    final d13 = _distance.as(LengthUnit.Meter, p1.point, p3.point);
    final vCand = dt13 > 0 ? (d13 / dt13).clamp(0.0, kMaxPairwiseSpeedMs) : 0.0;

    final isStationary = d13 < kStationaryDisplacementThresholdMeters || vCand < kStationarySpeedThresholdMs;
    final effectiveSpeed = isStationary ? 0.0 : vCand;
    final double effectiveHeading;
    if (isStationary) {
      effectiveHeading = p3.headingDeg ?? _lastValidHeadingDeg ?? _currentHeadingDeg;
    } else {
      effectiveHeading = _distance.bearing(p1.point, p3.point);
    }

    // 3. Bridging distance calculation for gap
    var bridgedDistance = 0.0;
    if (_lastValidPosition != null && _lastValidTimestamp != null) {
      final gapDt = (p3.timestamp.difference(_lastValidTimestamp!).inMicroseconds) / 1e6;
      final chordDist = _distance.as(LengthUnit.Meter, _lastValidPosition!, p3.point);
      final vEquiv = gapDt > 0 ? chordDist / gapDt : 0.0;

      if (gapDt <= 10.0) {
        if (vEquiv <= kMaxPairwiseSpeedMs) {
          bridgedDistance = chordDist;
        }
      } else {
        if (vEquiv <= kMaxPairwiseSpeedMs) {
          bridgedDistance = math.min(chordDist, _lastValidSpeedMs * gapDt);
        }
      }
    }

    // Place bridged distance into escrow (committed ONLY if probation passes)
    final prevEscrow = _escrowDistanceMeters;
    _escrowDistanceMeters = bridgedDistance;
    _recordDistanceTransaction(
      timestamp: p3.timestamp,
      fromState: GpsRecoveryState.s4ValidatedReAnchor,
      toState: GpsRecoveryState.s5SafeReset,
      mutationType: FsmDistanceMutationType.gapBridging,
      committedDelta: 0.0,
      escrowDelta: bridgedDistance - prevEscrow,
      description: 'S4 to S5 safe reset: gap bridging placed into escrow',
    );

    // 4. Safe Reset of EKF state vector and covariance
    final sigmaPos = math.max(5.0, p3.accuracyMeters);
    _ekf.reset();
    _ekf.init(
      initialPoint: p3.point,
      initialAccuracyMeters: sigmaPos,
      initialSpeedMs: effectiveSpeed,
      initialHeadingDeg: effectiveHeading,
    );

    // Exclude Euclidean jump from drift state to re-anchor: accumulated distance is unchanged!
    _currentPosition = p3.point;
    _currentSpeedMs = effectiveSpeed;
    _currentHeadingDeg = effectiveHeading;
    _currentPositionVariance = sigmaPos * sigmaPos;

    _state = GpsRecoveryState.s5SafeReset;
    _probationRemaining = kProbationWindowSize;
  }

  /// Executes Cold Reinitialization with conservative uncertainty on recovery failure.
  ///
  /// Distinguishes cold reinitialization from exact state rollback:
  /// - Does NOT pretend to restore full 4x4 covariance or diverged internal state.
  /// - Resets EKF to cold uninitialized state.
  /// - Restores committed distance strictly to pre-attempt baseline.
  /// - Completely purges escrow and bridging distance.
  /// - Adds failed anchor to spatial blacklist.
  /// - Sets conservative position variance (>= 100 m^2) to indicate untrusted position.
  void _executeSnapshotRollback(DateTime timestamp) {
    // 1. Reset EKF to cold state - never treat diverged filter as trusted
    _ekf.reset();

    final prevCommitted = _accumulatedDistanceMeters;
    final prevEscrow = _escrowDistanceMeters;

    // 2. Restore committed distance strictly to pre-attempt baseline
    if (_snapshot != null) {
      _accumulatedDistanceMeters = _snapshot!.committedDistanceMeters;
      _currentPosition = _snapshot!.lastValidPosition;
      _currentSpeedMs = 0.0;
      _currentHeadingDeg = _snapshot!.lastValidHeadingDeg ?? 0.0;
      _currentPositionVariance = math.max(100.0, _snapshot!.baselinePositionVariance * 4.0);
    } else {
      _currentSpeedMs = 0.0;
      _currentPositionVariance = math.max(100.0, _currentPositionVariance * 4.0);
    }

    // 3. Blacklist failed anchor coordinates
    if (_candidateBuffer.isNotEmpty) {
      final failedAnchor = _candidateBuffer.last.point;
      _blacklist.add(SpatialBlacklistEntry(
        center: failedAnchor,
        radiusMeters: kBlacklistRadiusMeters,
        expiryTime: timestamp.add(kBlacklistDuration),
      ));
    }

    // 4. Purge all tentative distance in escrow completely
    _escrowDistanceMeters = 0.0;
    _candidateBuffer.clear();
    _state = GpsRecoveryState.s2LossOfLock;
    _consecutiveRejections = kRejectionLimitS2;
    _probationRemaining = 0;
    _provisionalSuccessCount = 0;

    _recordDistanceTransaction(
      timestamp: timestamp,
      fromState: GpsRecoveryState.s5SafeReset,
      toState: GpsRecoveryState.s2LossOfLock,
      mutationType: FsmDistanceMutationType.rollbackCorrection,
      committedDelta: _accumulatedDistanceMeters - prevCommitted,
      escrowDelta: -prevEscrow,
      description: 'Rollback executed: purged escrow (${prevEscrow.toStringAsFixed(1)}m) and restored snapshot distance',
    );
  }
}
