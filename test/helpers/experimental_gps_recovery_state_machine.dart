import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';
import 'package:latlong2/latlong.dart';

/// Isolated experimental copy of [GpsRecoveryStateMachine] for Phase 5 Milestone 2A
/// hypothesis validation (Task 2).
///
/// Supports isolated experimental variants:
/// - Config D (all false, identical to frozen baseline comparator)
/// - Config D + H1: along-track projection and gap-overlap correction
/// - Config D + H2: probation variance inflation and alternative rollback recovery
/// - Config D + H1 + H2: combined
class ExperimentalGpsRecoveryStateMachine {
  final ExtendedKalmanFilter _ekf;

  final bool enableAlongTrackProjection;
  final bool enableGapOverlapCorrection;
  final bool enableProbationVarianceInflation;
  final bool enableAlternativeRollbackRecovery;

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

  // Thresholds and parameters matching frozen GpsRecoveryStateMachine
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

  String currentScenario = '';
  final List<FsmDistanceTransaction> distanceLedger = [];

  ExperimentalGpsRecoveryStateMachine({
    ExtendedKalmanFilter? ekf,
    this.enableAlongTrackProjection = false,
    this.enableGapOverlapCorrection = false,
    this.enableProbationVarianceInflation = false,
    this.enableAlternativeRollbackRecovery = false,
  }) : _ekf = ekf ?? ExtendedKalmanFilter();

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

  /// Calculates along-track step displacement if H1 is active, else returns Euclidean step distance.
  double _calculateStepDistance({
    required LatLng prevPos,
    required LatLng newPos,
    required double headingDeg,
    required double dt,
  }) {
    final stepDist = _distance.as(LengthUnit.Meter, prevPos, newPos);
    if (!enableAlongTrackProjection) {
      return stepDist.clamp(0.0, kMaxPairwiseSpeedMs * dt);
    }

    final stepBearingRad = _distance.bearing(prevPos, newPos) * math.pi / 180.0;
    final headingRad = headingDeg * math.pi / 180.0;
    final cosAngle = math.cos(stepBearingRad - headingRad);
    final alongTrack = stepDist * math.max(0.0, cosAngle);
    return alongTrack.clamp(0.0, kMaxPairwiseSpeedMs * dt);
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
          final rawStepDist = _distance.as(LengthUnit.Meter, prevPos, ekfEstimate.position);
          final stepDist = _calculateStepDistance(
            prevPos: prevPos,
            newPos: ekfEstimate.position,
            headingDeg: ekfEstimate.headingDeg,
            dt: dt,
          );
          addedDistance = stepDist;

          final isStationary = (speedMs != null && speedMs < kStationarySpeedThresholdMs) ||
              (ekfEstimate.speedMs < kStationarySpeedThresholdMs &&
                  rawStepDist < kStationaryDisplacementThresholdMeters);
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
                : (enableAlongTrackProjection
                    ? 'S0 clean fix: along-track projected step added'
                    : 'S0 clean fix: Euclidean step added to workout distance'),
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
              description: 'S0 Provisional to S1: unverified escrow discarded on time gap',
            );
          }
        }

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
          final discarded = _escrowDistanceMeters;
          _escrowDistanceMeters = 0.0;
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
          final rawStepDist = _distance.as(LengthUnit.Meter, prevPos, ekfEstimate.position);
          final tentativeStep = _calculateStepDistance(
            prevPos: prevPos,
            newPos: ekfEstimate.position,
            headingDeg: ekfEstimate.headingDeg,
            dt: dt,
          );

          final isStationary = (speedMs != null && speedMs < kStationarySpeedThresholdMs) ||
              (ekfEstimate.speedMs < kStationarySpeedThresholdMs &&
                  rawStepDist < kStationaryDisplacementThresholdMeters);

          if (isStationary) {
            _currentSpeedMs = 0.0;
          } else {
            _currentSpeedMs = ekfEstimate.speedMs;
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
              description: 'S0 Provisional validated ($kProvisionalValidationFixes clean fixes): escrow committed',
            );
          } else {
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
            final from = _state;
            _state = GpsRecoveryState.s0NormalTracking;
            _consecutiveRejections = 0;
            _s1CleanFixCount = 0;

            final stepDist = _calculateStepDistance(
              prevPos: prevPos,
              newPos: ekfEstimate.position,
              headingDeg: ekfEstimate.headingDeg,
              dt: dt,
            );
            addedDistance = stepDist;
            _accumulatedDistanceMeters += addedDistance;
            _recordDistanceTransaction(
              timestamp: timestamp,
              fromState: from,
              toState: _state,
              mutationType: FsmDistanceMutationType.normalStep,
              committedDelta: addedDistance,
              escrowDelta: 0.0,
              description: 'S1 hysteresis recovery (2 clean fixes): step added to workout distance',
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
          addedDistance = 0.0;
        } else {
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
        addedDistance = 0.0;

        final isBlacklisted = _blacklist.any((entry) => entry.contains(point));
        if (isBlacklisted) {
          _candidateBuffer.clear();
          _state = GpsRecoveryState.s2LossOfLock;
          decision = EkfMeasurementDecision.rejected;
          break;
        }

        if (_candidateBuffer.isEmpty) {
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
          final bufferLifespanSec = (timestamp.difference(_candidateBuffer.first.timestamp).inMicroseconds) / 1e6;
          if (bufferLifespanSec > kCandidateBufferLifetimeSec) {
            _candidateBuffer.clear();
            _state = GpsRecoveryState.s2LossOfLock;
            break;
          }

          final prevCandidate = _candidateBuffer.last;
          final pairDt = (timestamp.difference(prevCandidate.timestamp).inMicroseconds) / 1e6;

          if (pairDt < kCandidateMinDtSec || pairDt > kCandidateMaxDtSec) {
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

          if (accuracyMeters > 20.0 ||
              pairSpeed > kMaxPairwiseSpeedMs ||
              pairAccel > kMaxPairwiseAccelMs2) {
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

          if (_candidateBuffer.length == kRequiredCandidateCount) {
            _state = GpsRecoveryState.s4ValidatedReAnchor;
            _executeReAnchorAndSafeReset(timestamp, hasAuxiliarySensors);
            resetApplied = true;
          }
        }
        break;

      case GpsRecoveryState.s4ValidatedReAnchor:
        break;

      case GpsRecoveryState.s5SafeReset:
        final prevPos = _currentPosition!;
        final effectiveAcc = enableProbationVarianceInflation ? accuracyMeters * 2.0 : accuracyMeters;
        final ekfEstimate = _ekf.update(
          measurementPoint: point,
          accuracyMeters: effectiveAcc,
          timeDeltaSec: dt,
          speedMs: speedMs,
          headingDeg: headingDeg,
        );

        decision = ekfEstimate.diagnostics.positionDecision;
        nis = ekfEstimate.diagnostics.positionNis;

        if ((nis ?? double.infinity) >= kNisG2 || ekfEstimate.speedMs > kMaxPairwiseSpeedMs) {
          _executeSnapshotRollback(timestamp);
          rollbackApplied = true;
          decision = EkfMeasurementDecision.rejected;
          addedDistance = 0.0;
        } else {
          _probationRemaining--;
          final clampedStep = _calculateStepDistance(
            prevPos: prevPos,
            newPos: ekfEstimate.position,
            headingDeg: ekfEstimate.headingDeg,
            dt: dt,
          );

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
                description: 'S5 probation verified with auxiliary sensors: escrow committed',
              );
            } else {
              final from = _state;
              _candidateBuffer.clear();
              _lastValidPosition = _currentPosition;
              _lastValidSpeedMs = _currentSpeedMs;
              _lastValidHeadingDeg = _currentHeadingDeg;
              _lastValidTimestamp = timestamp;
              _state = GpsRecoveryState.s0Provisional;
              _provisionalSuccessCount = 0;
              addedDistance = 0.0;
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

    _snapshot = RecoverySnapshot(
      lastValidPosition: _lastValidPosition,
      lastValidSpeedMs: _lastValidSpeedMs,
      lastValidHeadingDeg: _lastValidHeadingDeg,
      lastValidTimestamp: _lastValidTimestamp,
      committedDistanceMeters: _accumulatedDistanceMeters,
      baselinePositionVariance: _currentPositionVariance,
      snapshotTimestamp: timestamp,
    );

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

      // H1: Gap overlap correction
      if (enableGapOverlapCorrection) {
        final gapBearing = _distance.bearing(_lastValidPosition!, p3.point);
        final preHeading = _lastValidHeadingDeg ?? 0.0;
        final angleDiffRad = (gapBearing - preHeading) * math.pi / 180.0;
        if (math.cos(angleDiffRad) < 0.0) {
          // Re-anchor is behind last known heading: cap bridging to 0.0
          bridgedDistance = 0.0;
        }
      }
    }

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

    // H2: Safe reset variance inflation
    final sigmaPos = enableProbationVarianceInflation
        ? math.max(10.0, p3.accuracyMeters * 2.0)
        : math.max(5.0, p3.accuracyMeters);

    _ekf.reset();
    _ekf.init(
      initialPoint: p3.point,
      initialAccuracyMeters: sigmaPos,
      initialSpeedMs: effectiveSpeed,
      initialHeadingDeg: effectiveHeading,
    );

    _currentPosition = p3.point;
    _currentSpeedMs = effectiveSpeed;
    _currentHeadingDeg = effectiveHeading;
    _currentPositionVariance = sigmaPos * sigmaPos;

    _state = GpsRecoveryState.s5SafeReset;
    _probationRemaining = kProbationWindowSize;
  }

  void _executeSnapshotRollback(DateTime timestamp) {
    _ekf.reset();

    final prevCommitted = _accumulatedDistanceMeters;
    final prevEscrow = _escrowDistanceMeters;

    if (enableAlternativeRollbackRecovery) {
      // H2: Alternative rollback recovery
      // Retain position variance as high without teleporting _currentPosition back 300m
      if (_snapshot != null) {
        _accumulatedDistanceMeters = _snapshot!.committedDistanceMeters;
      }
      _currentSpeedMs = 0.0;
      _currentPositionVariance = 400.0;
    } else {
      // Config D baseline: teleport back to snapshot
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
    }

    if (_candidateBuffer.isNotEmpty) {
      final failedAnchor = _candidateBuffer.last.point;
      _blacklist.add(SpatialBlacklistEntry(
        center: failedAnchor,
        radiusMeters: kBlacklistRadiusMeters,
        expiryTime: timestamp.add(kBlacklistDuration),
      ));
    }

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
      description: enableAlternativeRollbackRecovery
          ? 'Alternative rollback: purged escrow (${prevEscrow.toStringAsFixed(1)}m), preserved local anchor without teleport'
          : 'Rollback executed: purged escrow (${prevEscrow.toStringAsFixed(1)}m) and restored snapshot distance',
    );
  }
}
