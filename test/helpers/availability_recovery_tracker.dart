import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/gps_recovery_state_machine.dart';

/// Accounting of input sample schedule vs reception and processing.
class InputAccounting {
  final int scheduledCount;
  final int receivedCount;
  final int missingCount;
  final int processedCount;
  final int unprocessedCount;

  const InputAccounting({
    required this.scheduledCount,
    required this.receivedCount,
    required this.missingCount,
    required this.processedCount,
    required this.unprocessedCount,
  });

  Map<String, dynamic> toJson() => {
        'scheduledCount': scheduledCount,
        'receivedCount': receivedCount,
        'missingCount': missingCount,
        'processedCount': processedCount,
        'unprocessedCount': unprocessedCount,
      };
}

/// Accounting of measurement acceptance and candidate buffering decisions.
class MeasurementAcceptance {
  final int acceptedMeasurementCount;
  final int rejectedMeasurementCount;
  final int bufferedCandidateCount;
  final int provisionalMeasurementCount;
  final int admittedToEkfCount;
  final int cleanFixCount;
  final int downweightedFixCount;

  const MeasurementAcceptance({
    required this.acceptedMeasurementCount,
    required this.rejectedMeasurementCount,
    required this.bufferedCandidateCount,
    required this.provisionalMeasurementCount,
    required this.admittedToEkfCount,
    required this.cleanFixCount,
    required this.downweightedFixCount,
  });

  Map<String, dynamic> toJson() => {
        'acceptedMeasurementCount': acceptedMeasurementCount,
        'rejectedMeasurementCount': rejectedMeasurementCount,
        'bufferedCandidateCount': bufferedCandidateCount,
        'provisionalMeasurementCount': provisionalMeasurementCount,
        'admittedToEkfCount': admittedToEkfCount,
        'cleanFixCount': cleanFixCount,
        'downweightedFixCount': downweightedFixCount,
      };
}

/// Precise occupancy counts and cumulative durations across all 7 FSM states.
class FsmStateOccupancy {
  final int s0NormalCount;
  final int s0ProvisionalCount;
  final int s1DegradedCount;
  final int s2LossCount;
  final int s3ReacquisitionCount;
  final int s4ValidatedCount;
  final int s5ProbationCount;
  final int transitionCount;

  final double timeInS0NormalSec;
  final double timeInS0ProvisionalSec;
  final double timeInS1DegradedSec;
  final double timeInS2LossSec;
  final double timeInS3ReacquisitionSec;
  final double timeInS4ValidatedSec;
  final double timeInS5ProbationSec;

  const FsmStateOccupancy({
    required this.s0NormalCount,
    required this.s0ProvisionalCount,
    required this.s1DegradedCount,
    required this.s2LossCount,
    required this.s3ReacquisitionCount,
    required this.s4ValidatedCount,
    required this.s5ProbationCount,
    required this.transitionCount,
    required this.timeInS0NormalSec,
    required this.timeInS0ProvisionalSec,
    required this.timeInS1DegradedSec,
    required this.timeInS2LossSec,
    required this.timeInS3ReacquisitionSec,
    required this.timeInS4ValidatedSec,
    required this.timeInS5ProbationSec,
  });

  int get totalOccupancyCount =>
      s0NormalCount +
      s0ProvisionalCount +
      s1DegradedCount +
      s2LossCount +
      s3ReacquisitionCount +
      s4ValidatedCount +
      s5ProbationCount;

  double get totalDurationSec =>
      timeInS0NormalSec +
      timeInS0ProvisionalSec +
      timeInS1DegradedSec +
      timeInS2LossSec +
      timeInS3ReacquisitionSec +
      timeInS4ValidatedSec +
      timeInS5ProbationSec;

  Map<String, dynamic> toJson() => {
        's0NormalCount': s0NormalCount,
        's0ProvisionalCount': s0ProvisionalCount,
        's1DegradedCount': s1DegradedCount,
        's2LossCount': s2LossCount,
        's3ReacquisitionCount': s3ReacquisitionCount,
        's4ValidatedCount': s4ValidatedCount,
        's5ProbationCount': s5ProbationCount,
        'transitionCount': transitionCount,
        'totalOccupancyCount': totalOccupancyCount,
        'timeInS0NormalSec': timeInS0NormalSec,
        'timeInS0ProvisionalSec': timeInS0ProvisionalSec,
        'timeInS1DegradedSec': timeInS1DegradedSec,
        'timeInS2LossSec': timeInS2LossSec,
        'timeInS3ReacquisitionSec': timeInS3ReacquisitionSec,
        'timeInS4ValidatedSec': timeInS4ValidatedSec,
        'timeInS5ProbationSec': timeInS5ProbationSec,
        'totalDurationSec': totalDurationSec,
      };
}

/// Operational Tracking Availability metrics distinguishing legacy, FSM state occupancy,
/// measurement-validated tracking, and position output.
class OperationalTrackingAvailability {
  final int trustedOperationalCount; // Backward compatibility alias to s0NormalCount
  final int s0NormalStateOccupancyCount;
  final int s0MeasurementValidatedCount;
  final int s0PredictOnlyCount;
  final int untrustedOrProvisionalCount;
  final int unavailableCount;
  final int positionOutputAvailableCount;
  final int legacyAvailableCount;
  final int directCommittedDistanceCount;
  final int measurementAnchoredDistanceCount;

  final double legacyAvailabilityPercent;
  final double s0NormalStateOccupancyPercent;
  final double trustedOperationalAvailabilityPercent; // Backward compatibility alias to s0NormalStateOccupancyPercent
  final double measurementValidatedTrustedPercent;
  final double s0PredictOnlyPercent;
  final double positionOutputAvailabilityPercent;
  final double directCommittedDistancePercent;
  final double measurementAnchoredDistancePercent;
  final double measurementAcceptanceRatePercent;
  final double gapDeltaPercent; // Legacy minus S0 state occupancy
  final double measurementValidationGapDeltaPercent; // Legacy minus Measurement-validated

  final Map<String, int> stateDecisionMatrix;

  const OperationalTrackingAvailability({
    required this.trustedOperationalCount,
    required this.s0NormalStateOccupancyCount,
    required this.s0MeasurementValidatedCount,
    required this.s0PredictOnlyCount,
    required this.untrustedOrProvisionalCount,
    required this.unavailableCount,
    required this.positionOutputAvailableCount,
    required this.legacyAvailableCount,
    required this.directCommittedDistanceCount,
    required this.measurementAnchoredDistanceCount,
    required this.legacyAvailabilityPercent,
    required this.s0NormalStateOccupancyPercent,
    required this.trustedOperationalAvailabilityPercent,
    required this.measurementValidatedTrustedPercent,
    required this.s0PredictOnlyPercent,
    required this.positionOutputAvailabilityPercent,
    required this.directCommittedDistancePercent,
    required this.measurementAnchoredDistancePercent,
    required this.measurementAcceptanceRatePercent,
    required this.gapDeltaPercent,
    required this.measurementValidationGapDeltaPercent,
    required this.stateDecisionMatrix,
  });

  Map<String, dynamic> toJson() => {
        'trustedOperationalCount': trustedOperationalCount,
        's0NormalStateOccupancyCount': s0NormalStateOccupancyCount,
        's0MeasurementValidatedCount': s0MeasurementValidatedCount,
        's0PredictOnlyCount': s0PredictOnlyCount,
        'untrustedOrProvisionalCount': untrustedOrProvisionalCount,
        'unavailableCount': unavailableCount,
        'positionOutputAvailableCount': positionOutputAvailableCount,
        'legacyAvailableCount': legacyAvailableCount,
        'directCommittedDistanceCount': directCommittedDistanceCount,
        'measurementAnchoredDistanceCount': measurementAnchoredDistanceCount,
        'legacyAvailabilityPercent': legacyAvailabilityPercent,
        's0NormalStateOccupancyPercent': s0NormalStateOccupancyPercent,
        'trustedOperationalAvailabilityPercent': trustedOperationalAvailabilityPercent,
        'measurementValidatedTrustedPercent': measurementValidatedTrustedPercent,
        's0PredictOnlyPercent': s0PredictOnlyPercent,
        'positionOutputAvailabilityPercent': positionOutputAvailabilityPercent,
        'directCommittedDistancePercent': directCommittedDistancePercent,
        'measurementAnchoredDistancePercent': measurementAnchoredDistancePercent,
        'measurementAcceptanceRatePercent': measurementAcceptanceRatePercent,
        'gapDeltaPercent': gapDeltaPercent,
        'measurementValidationGapDeltaPercent': measurementValidationGapDeltaPercent,
        'stateDecisionMatrix': stateDecisionMatrix,
      };
}

/// Recovery reliability tracking loss-of-lock events, reacquisition, and latencies.
class RecoveryReliability {
  final int lossOfLockEventCount;
  final int recoveredEventCount;
  final int unresolvedEventCount;
  final double recoveryLatencyP50;
  final double recoveryLatencyP95;
  final double recoveryLatencyMax;
  final double totalUnavailableDurationSec;
  final List<double> latencies;

  const RecoveryReliability({
    required this.lossOfLockEventCount,
    required this.recoveredEventCount,
    required this.unresolvedEventCount,
    required this.recoveryLatencyP50,
    required this.recoveryLatencyP95,
    required this.recoveryLatencyMax,
    required this.totalUnavailableDurationSec,
    required this.latencies,
  });

  Map<String, dynamic> toJson() => {
        'lossOfLockEventCount': lossOfLockEventCount,
        'recoveredEventCount': recoveredEventCount,
        'unresolvedEventCount': unresolvedEventCount,
        'recoveryLatencyP50': recoveryLatencyP50,
        'recoveryLatencyP95': recoveryLatencyP95,
        'recoveryLatencyMax': recoveryLatencyMax,
        'totalUnavailableDurationSec': totalUnavailableDurationSec,
        'recoveredLatencyCount': latencies.length,
      };
}

/// Mathematical reconciliation residuals proving conservation invariants.
class ReconciliationResiduals {
  final int inputResidual;
  final int processingResidual;
  final int stateOccupancyResidual;
  final int availabilityPartitionResidual;
  final int s0ValidationResidual;
  final int recoveryEventResidual;
  final bool allInvariantsHold;

  const ReconciliationResiduals({
    required this.inputResidual,
    required this.processingResidual,
    required this.stateOccupancyResidual,
    required this.availabilityPartitionResidual,
    required this.s0ValidationResidual,
    required this.recoveryEventResidual,
    required this.allInvariantsHold,
  });

  Map<String, dynamic> toJson() => {
        'inputResidual': inputResidual,
        'processingResidual': processingResidual,
        'stateOccupancyResidual': stateOccupancyResidual,
        'availabilityPartitionResidual': availabilityPartitionResidual,
        's0ValidationResidual': s0ValidationResidual,
        'recoveryEventResidual': recoveryEventResidual,
        'allInvariantsHold': allInvariantsHold,
      };
}

/// Accumulator class to aggregate sample-by-sample and scenario-by-scenario metrics.
class AvailabilityRecoveryAccumulator {
  int scheduledCount = 0;
  int receivedCount = 0;
  int missingCount = 0;
  int processedCount = 0;
  int unprocessedCount = 0;

  int acceptedMeasurementCount = 0;
  int rejectedMeasurementCount = 0;
  int bufferedCandidateCount = 0;
  int provisionalMeasurementCount = 0;
  int cleanFixCount = 0;
  int downweightedFixCount = 0;

  int s0NormalCount = 0;
  int s0NormalCleanCount = 0;
  int s0NormalDownweightedCount = 0;
  int s0NormalRejectedCount = 0;

  int s0ProvisionalCount = 0;
  int s1DegradedCount = 0;
  int s2LossCount = 0;
  int s3ReacquisitionCount = 0;
  int s4ValidatedCount = 0;
  int s5ProbationCount = 0;
  int transitionCount = 0;

  final Map<String, int> stateDecisionCounts = {};

  double timeInS0NormalSec = 0.0;
  double timeInS0ProvisionalSec = 0.0;
  double timeInS1DegradedSec = 0.0;
  double timeInS2LossSec = 0.0;
  double timeInS3ReacquisitionSec = 0.0;
  double timeInS4ValidatedSec = 0.0;
  double timeInS5ProbationSec = 0.0;

  int lossOfLockEventCount = 0;
  int recoveredEventCount = 0;
  int unresolvedEventCount = 0;
  final List<double> latencies = [];
  double totalUnavailableDurationSec = 0.0;

  GpsRecoveryState? _lastState;
  DateTime? _activeLossStartTime;

  void recordStep({
    required GpsRecoveryFsmResult result,
    required double dt,
    required DateTime timestamp,
  }) {
    scheduledCount++;
    receivedCount++;
    processedCount++;

    // State x Decision matrix
    final key = '${result.state.name} x ${result.decision.name}';
    stateDecisionCounts[key] = (stateDecisionCounts[key] ?? 0) + 1;

    // Transition tracking
    if (_lastState != null && result.state != _lastState) {
      transitionCount++;
    }

    // State occupancy & duration
    switch (result.state) {
      case GpsRecoveryState.s0NormalTracking:
        s0NormalCount++;
        timeInS0NormalSec += dt;
        if (result.decision == EkfMeasurementDecision.normal) {
          s0NormalCleanCount++;
        } else if (result.decision == EkfMeasurementDecision.downWeighted) {
          s0NormalDownweightedCount++;
        } else {
          s0NormalRejectedCount++;
        }
        break;
      case GpsRecoveryState.s0Provisional:
        s0ProvisionalCount++;
        timeInS0ProvisionalSec += dt;
        provisionalMeasurementCount++;
        break;
      case GpsRecoveryState.s1SuspectedDegraded:
        s1DegradedCount++;
        timeInS1DegradedSec += dt;
        break;
      case GpsRecoveryState.s2LossOfLock:
        s2LossCount++;
        timeInS2LossSec += dt;
        totalUnavailableDurationSec += dt;
        break;
      case GpsRecoveryState.s3CandidateReacquisition:
        s3ReacquisitionCount++;
        timeInS3ReacquisitionSec += dt;
        totalUnavailableDurationSec += dt;
        break;
      case GpsRecoveryState.s4ValidatedReAnchor:
        s4ValidatedCount++;
        timeInS4ValidatedSec += dt;
        totalUnavailableDurationSec += dt;
        break;
      case GpsRecoveryState.s5SafeReset:
        s5ProbationCount++;
        timeInS5ProbationSec += dt;
        provisionalMeasurementCount++;
        break;
    }

    // Measurement acceptance & decisions
    if (result.decision == EkfMeasurementDecision.rejected) {
      rejectedMeasurementCount++;
    } else {
      acceptedMeasurementCount++;
      if (result.decision == EkfMeasurementDecision.normal) {
        cleanFixCount++;
      } else if (result.decision == EkfMeasurementDecision.downWeighted) {
        downweightedFixCount++;
      }
    }

    if (result.isCandidateBuffered) {
      bufferedCandidateCount++;
    }

    // Recovery tracking: Loss-of-lock event begins upon entering S2
    if (result.state == GpsRecoveryState.s2LossOfLock) {
      if (_activeLossStartTime == null) {
        _activeLossStartTime = timestamp;
        lossOfLockEventCount++;
      }
    } else if (_activeLossStartTime != null &&
        result.state == GpsRecoveryState.s0NormalTracking) {
      // Reached full trusted normal tracking -> recovered!
      final latencySec =
          timestamp.difference(_activeLossStartTime!).inMicroseconds / 1e6;
      latencies.add(latencySec);
      recoveredEventCount++;
      _activeLossStartTime = null;
    }

    _lastState = result.state;
  }

  void finalizeScenario() {
    if (_activeLossStartTime != null) {
      // Scenario ended while still recovering or lost
      unresolvedEventCount++;
      _activeLossStartTime = null;
    }
    _lastState = null;
  }

  /// Combine another accumulator into this one.
  void merge(AvailabilityRecoveryAccumulator other) {
    scheduledCount += other.scheduledCount;
    receivedCount += other.receivedCount;
    missingCount += other.missingCount;
    processedCount += other.processedCount;
    unprocessedCount += other.unprocessedCount;

    acceptedMeasurementCount += other.acceptedMeasurementCount;
    rejectedMeasurementCount += other.rejectedMeasurementCount;
    bufferedCandidateCount += other.bufferedCandidateCount;
    provisionalMeasurementCount += other.provisionalMeasurementCount;
    cleanFixCount += other.cleanFixCount;
    downweightedFixCount += other.downweightedFixCount;

    s0NormalCount += other.s0NormalCount;
    s0NormalCleanCount += other.s0NormalCleanCount;
    s0NormalDownweightedCount += other.s0NormalDownweightedCount;
    s0NormalRejectedCount += other.s0NormalRejectedCount;

    s0ProvisionalCount += other.s0ProvisionalCount;
    s1DegradedCount += other.s1DegradedCount;
    s2LossCount += other.s2LossCount;
    s3ReacquisitionCount += other.s3ReacquisitionCount;
    s4ValidatedCount += other.s4ValidatedCount;
    s5ProbationCount += other.s5ProbationCount;
    transitionCount += other.transitionCount;

    timeInS0NormalSec += other.timeInS0NormalSec;
    timeInS0ProvisionalSec += other.timeInS0ProvisionalSec;
    timeInS1DegradedSec += other.timeInS1DegradedSec;
    timeInS2LossSec += other.timeInS2LossSec;
    timeInS3ReacquisitionSec += other.timeInS3ReacquisitionSec;
    timeInS4ValidatedSec += other.timeInS4ValidatedSec;
    timeInS5ProbationSec += other.timeInS5ProbationSec;

    lossOfLockEventCount += other.lossOfLockEventCount;
    recoveredEventCount += other.recoveredEventCount;
    unresolvedEventCount += other.unresolvedEventCount;
    latencies.addAll(other.latencies);
    totalUnavailableDurationSec += other.totalUnavailableDurationSec;

    for (final entry in other.stateDecisionCounts.entries) {
      stateDecisionCounts[entry.key] =
          (stateDecisionCounts[entry.key] ?? 0) + entry.value;
    }
  }

  InputAccounting computeInputAccounting() {
    return InputAccounting(
      scheduledCount: scheduledCount,
      receivedCount: receivedCount,
      missingCount: missingCount,
      processedCount: processedCount,
      unprocessedCount: unprocessedCount,
    );
  }

  MeasurementAcceptance computeMeasurementAcceptance() {
    // Admitted to active EKF filter: S0 admitted + S0 Prov admitted + S5 admitted
    final s0Admitted = s0NormalCleanCount + s0NormalDownweightedCount;
    final provAdmitted = (stateDecisionCounts['s0Provisional x normal'] ?? 0) +
        (stateDecisionCounts['s0Provisional x downWeighted'] ?? 0);
    final s5Admitted = (stateDecisionCounts['s5SafeReset x normal'] ?? 0) +
        (stateDecisionCounts['s5SafeReset x downWeighted'] ?? 0);
    final totalAdmittedToEkf = s0Admitted + provAdmitted + s5Admitted;

    return MeasurementAcceptance(
      acceptedMeasurementCount: acceptedMeasurementCount,
      rejectedMeasurementCount: rejectedMeasurementCount,
      bufferedCandidateCount: bufferedCandidateCount,
      provisionalMeasurementCount: provisionalMeasurementCount,
      admittedToEkfCount: totalAdmittedToEkf,
      cleanFixCount: cleanFixCount,
      downweightedFixCount: downweightedFixCount,
    );
  }

  FsmStateOccupancy computeStateOccupancy() {
    return FsmStateOccupancy(
      s0NormalCount: s0NormalCount,
      s0ProvisionalCount: s0ProvisionalCount,
      s1DegradedCount: s1DegradedCount,
      s2LossCount: s2LossCount,
      s3ReacquisitionCount: s3ReacquisitionCount,
      s4ValidatedCount: s4ValidatedCount,
      s5ProbationCount: s5ProbationCount,
      transitionCount: transitionCount,
      timeInS0NormalSec: timeInS0NormalSec,
      timeInS0ProvisionalSec: timeInS0ProvisionalSec,
      timeInS1DegradedSec: timeInS1DegradedSec,
      timeInS2LossSec: timeInS2LossSec,
      timeInS3ReacquisitionSec: timeInS3ReacquisitionSec,
      timeInS4ValidatedSec: timeInS4ValidatedSec,
      timeInS5ProbationSec: timeInS5ProbationSec,
    );
  }

  OperationalTrackingAvailability computeOperationalAvailability() {
    final denom = scheduledCount > 0 ? scheduledCount.toDouble() : 1.0;

    final s0StateOccupancy = s0NormalCount;
    final s0MeasurementValidated = s0NormalCleanCount + s0NormalDownweightedCount;
    final s0PredictOnly = s0NormalRejectedCount;

    final provisional = s0ProvisionalCount + s1DegradedCount + s5ProbationCount;
    final unavailable = s2LossCount + s3ReacquisitionCount + s4ValidatedCount;
    final positionOutput = s0StateOccupancy + provisional;
    final legacy = scheduledCount - s2LossCount;

    final legacyPct = (legacy / denom) * 100.0;
    final s0OccupancyPct = (s0StateOccupancy / denom) * 100.0;
    final measValidatedPct = (s0MeasurementValidated / denom) * 100.0;
    final s0PredictOnlyPct = (s0PredictOnly / denom) * 100.0;
    final posOutputPct = (positionOutput / denom) * 100.0;
    final directDistPct = (s0StateOccupancy / denom) * 100.0;
    final measAnchoredDistPct = (s0MeasurementValidated / denom) * 100.0;
    final acceptRatePct = (acceptedMeasurementCount / denom) * 100.0;

    final gapDeltaPct = legacyPct - s0OccupancyPct;
    final measValGapPct = legacyPct - measValidatedPct;

    return OperationalTrackingAvailability(
      trustedOperationalCount: s0StateOccupancy,
      s0NormalStateOccupancyCount: s0StateOccupancy,
      s0MeasurementValidatedCount: s0MeasurementValidated,
      s0PredictOnlyCount: s0PredictOnly,
      untrustedOrProvisionalCount: provisional,
      unavailableCount: unavailable,
      positionOutputAvailableCount: positionOutput,
      legacyAvailableCount: legacy,
      directCommittedDistanceCount: s0StateOccupancy,
      measurementAnchoredDistanceCount: s0MeasurementValidated,
      legacyAvailabilityPercent: legacyPct,
      s0NormalStateOccupancyPercent: s0OccupancyPct,
      trustedOperationalAvailabilityPercent: s0OccupancyPct,
      measurementValidatedTrustedPercent: measValidatedPct,
      s0PredictOnlyPercent: s0PredictOnlyPct,
      positionOutputAvailabilityPercent: posOutputPct,
      directCommittedDistancePercent: directDistPct,
      measurementAnchoredDistancePercent: measAnchoredDistPct,
      measurementAcceptanceRatePercent: acceptRatePct,
      gapDeltaPercent: gapDeltaPct,
      measurementValidationGapDeltaPercent: measValGapPct,
      stateDecisionMatrix: Map.unmodifiable(stateDecisionCounts),
    );
  }

  RecoveryReliability computeRecoveryReliability() {
    final sortedLatencies = List<double>.from(latencies)..sort();
    final p50 = sortedLatencies.isNotEmpty
        ? sortedLatencies[(sortedLatencies.length * 0.50).floor()]
        : 0.0;
    final p95 = sortedLatencies.isNotEmpty
        ? sortedLatencies[(sortedLatencies.length * 0.95).floor()]
        : 0.0;
    final maxLat = sortedLatencies.isNotEmpty ? sortedLatencies.last : 0.0;

    return RecoveryReliability(
      lossOfLockEventCount: lossOfLockEventCount,
      recoveredEventCount: recoveredEventCount,
      unresolvedEventCount: unresolvedEventCount,
      recoveryLatencyP50: p50,
      recoveryLatencyP95: p95,
      recoveryLatencyMax: maxLat,
      totalUnavailableDurationSec: totalUnavailableDurationSec,
      latencies: sortedLatencies,
    );
  }

  ReconciliationResiduals computeReconciliationResiduals() {
    final inputRes = scheduledCount - (receivedCount + missingCount);
    final procRes = receivedCount - (processedCount + unprocessedCount);
    final stateRes = processedCount -
        (s0NormalCount +
            s0ProvisionalCount +
            s1DegradedCount +
            s2LossCount +
            s3ReacquisitionCount +
            s4ValidatedCount +
            s5ProbationCount);
    final availRes = scheduledCount -
        (s0NormalCount +
            (s0ProvisionalCount + s1DegradedCount + s5ProbationCount) +
            (s2LossCount + s3ReacquisitionCount + s4ValidatedCount));
    final s0Res = s0NormalCount -
        (s0NormalCleanCount + s0NormalDownweightedCount + s0NormalRejectedCount);
    final recRes = lossOfLockEventCount -
        (recoveredEventCount + unresolvedEventCount);

    final holds = inputRes == 0 &&
        procRes == 0 &&
        stateRes == 0 &&
        availRes == 0 &&
        s0Res == 0 &&
        recRes == 0 &&
        totalUnavailableDurationSec >= 0.0;

    return ReconciliationResiduals(
      inputResidual: inputRes,
      processingResidual: procRes,
      stateOccupancyResidual: stateRes,
      availabilityPartitionResidual: availRes,
      s0ValidationResidual: s0Res,
      recoveryEventResidual: recRes,
      allInvariantsHold: holds,
    );
  }
}
