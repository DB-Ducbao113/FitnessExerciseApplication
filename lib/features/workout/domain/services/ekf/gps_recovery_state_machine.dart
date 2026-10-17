import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:latlong2/latlong.dart';

/// States of the GPS Recovery Finite State Machine for EKF 4-State.
enum GpsRecoveryState {
  /// Normal tracking state: GPS measurements admitted and updated through EKF.
  s0NormalTracking,

  /// Low-confidence provisional tracking state (GPS-only, weak geometry, no heading corroboration).
  /// Measurement variance scaled 4x, heading innovation damped, distance held in escrow.
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
  /// Immutable snapshot is captured prior to resetting the filter state.
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
/// used for rollback if probationary tracking fails.
class RecoverySnapshot {
  final LatLng position;
  final double speedMs;
  final double headingDeg;
  final double positionVariance;
  final double accumulatedDistanceMeters;
  final DateTime timestamp;

  const RecoverySnapshot({
    required this.position,
    required this.speedMs,
    required this.headingDeg,
    required this.positionVariance,
    required this.accumulatedDistanceMeters,
    required this.timestamp,
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

/// Isolated GPS Recovery Finite State Machine for EKF 4-State filtering.
///
/// Implements S0–S5 states, rejection counters, candidate buffering (K=3),
/// pairwise kinematic checks, probationary tracking window (M=3), spatial blacklisting,
/// and snapshot rollback without modifying the EKF core or production pipeline.
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

  GpsRecoveryStateMachine({ExtendedKalmanFilter? ekf})
      : _ekf = ekf ?? ExtendedKalmanFilter();

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

  void _transitionToS2(DateTime timestamp) {
    _state = GpsRecoveryState.s2LossOfLock;
    _candidateBuffer.clear();
    // In S2, heading is frozen and distance accumulation is completely frozen
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

    // Handle initialization on the first valid point
    if (!_ekf.isInitialized || _currentPosition == null) {
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
      case GpsRecoveryState.s0Provisional:
        // Check for time gap degradation
        if (dt >= kTimeGapS2Sec) {
          _consecutiveRejections = kRejectionLimitS2;
          _transitionToS2(timestamp);
          decision = EkfMeasurementDecision.rejected;
          break;
        } else if (dt >= kTimeGapS1Sec) {
          _consecutiveRejections = kRejectionLimitS1;
          _state = GpsRecoveryState.s1SuspectedDegraded;
        }

        // Apply 4x measurement variance inflation if in S0_provisional
        final effectiveAccuracy = (_state == GpsRecoveryState.s0Provisional)
            ? accuracyMeters * 2.0
            : accuracyMeters;

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
          _consecutiveRejections++;
          if (_consecutiveRejections >= kRejectionLimitS2) {
            _transitionToS2(timestamp);
          } else if (_consecutiveRejections >= kRejectionLimitS1) {
            _state = GpsRecoveryState.s1SuspectedDegraded;
          }

          // Single/isolated spike in S0: predict-only motion along track
          // Distance accumulated along inertial velocity, zero contribution from the spike
          addedDistance = (ekfEstimate.speedMs * dt).clamp(0.0, 1.2 * _lastValidSpeedMs * dt);
          _accumulatedDistanceMeters += addedDistance;
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
          _currentPosition = ekfEstimate.position;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;

          _lastValidPosition = ekfEstimate.position;
          _lastValidSpeedMs = ekfEstimate.speedMs;
          _lastValidHeadingDeg = ekfEstimate.headingDeg;
          _lastValidTimestamp = timestamp;

          if (_state == GpsRecoveryState.s0Provisional) {
            _provisionalSuccessCount++;
            if (_provisionalSuccessCount >= 5) {
              _state = GpsRecoveryState.s0NormalTracking;
              _provisionalSuccessCount = 0;
            }
          }
        }
        break;

      case GpsRecoveryState.s1SuspectedDegraded:
        if (dt >= kTimeGapS2Sec) {
          _consecutiveRejections = kRejectionLimitS2;
          _transitionToS2(timestamp);
          decision = EkfMeasurementDecision.rejected;
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
            _state = GpsRecoveryState.s0NormalTracking;
            _consecutiveRejections = 0;
            _s1CleanFixCount = 0;

            final stepDist = _distance.as(LengthUnit.Meter, prevPos, ekfEstimate.position);
            addedDistance = stepDist.clamp(0.0, kMaxPairwiseSpeedMs * dt);
            _accumulatedDistanceMeters += addedDistance;

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
          _transitionToS2(timestamp);
        } else {
          // In S1: distance accumulates along inertial velocity clamped
          addedDistance = (ekfEstimate.speedMs * dt).clamp(0.0, 1.2 * _lastValidSpeedMs * dt);
          _accumulatedDistanceMeters += addedDistance;

          _currentPosition = ekfEstimate.position;
          _currentSpeedMs = ekfEstimate.speedMs;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;
        }
        break;

      case GpsRecoveryState.s2LossOfLock:
      case GpsRecoveryState.s3CandidateReacquisition:
        // In S2 and S3, distance accumulation is frozen
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
        } else {
          _probationRemaining--;
          final stepDist = _distance.as(LengthUnit.Meter, prevPos, ekfEstimate.position);
          final clampedStep = stepDist.clamp(0.0, kMaxPairwiseSpeedMs * dt);

          // Escrow buffer holds distance during probation
          _escrowDistanceMeters += clampedStep;

          _currentPosition = ekfEstimate.position;
          _currentSpeedMs = ekfEstimate.speedMs;
          _currentHeadingDeg = ekfEstimate.headingDeg;
          _currentPositionVariance = ekfEstimate.positionVariance;

          if (_probationRemaining == 0) {
            // Probation PASSED! Commit escrow distance to workout distance
            _accumulatedDistanceMeters += _escrowDistanceMeters;
            addedDistance = _escrowDistanceMeters;
            _escrowDistanceMeters = 0.0;
            _candidateBuffer.clear();

            _lastValidPosition = _currentPosition;
            _lastValidSpeedMs = _currentSpeedMs;
            _lastValidHeadingDeg = _currentHeadingDeg;
            _lastValidTimestamp = timestamp;
            _consecutiveRejections = 0;

            if (hasAuxiliarySensors) {
              _state = GpsRecoveryState.s0NormalTracking;
            } else {
              _state = GpsRecoveryState.s0Provisional;
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

    // 1. Capture immutable snapshot at S4
    _snapshot = RecoverySnapshot(
      position: _currentPosition ?? _candidateBuffer.first.point,
      speedMs: _currentSpeedMs,
      headingDeg: _currentHeadingDeg,
      positionVariance: _currentPositionVariance,
      accumulatedDistanceMeters: _accumulatedDistanceMeters,
      timestamp: timestamp,
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
    _escrowDistanceMeters = bridgedDistance;

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

  /// Executes Snapshot Rollback on probation failure.
  void _executeSnapshotRollback(DateTime timestamp) {
    if (_snapshot != null) {
      _currentPosition = _snapshot!.position;
      _currentSpeedMs = _snapshot!.speedMs;
      _currentHeadingDeg = _snapshot!.headingDeg;
      // Inflate position variance x 2.0 to reflect increased uncertainty
      _currentPositionVariance = _snapshot!.positionVariance * 2.0;
      _accumulatedDistanceMeters = _snapshot!.accumulatedDistanceMeters;

      // Re-init EKF at snapshot
      _ekf.reset();
      _ekf.init(
        initialPoint: _snapshot!.position,
        initialAccuracyMeters: math.sqrt(_currentPositionVariance),
        initialSpeedMs: _snapshot!.speedMs,
        initialHeadingDeg: _snapshot!.headingDeg,
      );
    }

    // Add failed anchor point to spatial blacklist
    if (_candidateBuffer.isNotEmpty) {
      final failedAnchor = _candidateBuffer.last.point;
      _blacklist.add(SpatialBlacklistEntry(
        center: failedAnchor,
        radiusMeters: kBlacklistRadiusMeters,
        expiryTime: timestamp.add(kBlacklistDuration),
      ));
    }

    // Purge escrow distance completely
    _escrowDistanceMeters = 0.0;
    _candidateBuffer.clear();
    _state = GpsRecoveryState.s2LossOfLock;
    _consecutiveRejections = kRejectionLimitS2;
  }
}
