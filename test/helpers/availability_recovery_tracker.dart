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

  const MeasurementAcceptance({
    required this.acceptedMeasurementCount,
    required this.rejectedMeasurementCount,
    required this.bufferedCandidateCount,
    required this.provisionalMeasurementCount,
  });

  Map<String, dynamic> toJson() => {
        'acceptedMeasurementCount': acceptedMeasurementCount,
        'rejectedMeasurementCount': rejectedMeasurementCount,
        'bufferedCandidateCount': bufferedCandidateCount,
        'provisionalMeasurementCount': provisionalMeasurementCount,
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

/// Operational Tracking Availability metrics distinguishing legacy, trusted, and provisional tracking.
class OperationalTrackingAvailability {
  final int trustedOperationalCount;
  final int untrustedOrProvisionalCount;
  final int unavailableCount;
  final int positionOutputAvailableCount;
  final int legacyAvailableCount;

  final double legacyAvailabilityPercent;
  final double trustedOperationalAvailabilityPercent;
  final double positionOutputAvailabilityPercent;
  final double trustedDistanceAccountingAvailabilityPercent;
  final double measurementAcceptanceRatePercent;
  final double gapDeltaPercent;

  const OperationalTrackingAvailability({
    required this.trustedOperationalCount,
    required this.untrustedOrProvisionalCount,
    required this.unavailableCount,
    required this.positionOutputAvailableCount,
    required this.legacyAvailableCount,
    required this.legacyAvailabilityPercent,
    required this.trustedOperationalAvailabilityPercent,
    required this.positionOutputAvailabilityPercent,
    required this.trustedDistanceAccountingAvailabilityPercent,
    required this.measurementAcceptanceRatePercent,
    required this.gapDeltaPercent,
  });

  Map<String, dynamic> toJson() => {
        'trustedOperationalCount': trustedOperationalCount,
        'untrustedOrProvisionalCount': untrustedOrProvisionalCount,
        'unavailableCount': unavailableCount,
        'positionOutputAvailableCount': positionOutputAvailableCount,
        'legacyAvailableCount': legacyAvailableCount,
        'legacyAvailabilityPercent': legacyAvailabilityPercent,
        'trustedOperationalAvailabilityPercent': trustedOperationalAvailabilityPercent,
        'positionOutputAvailabilityPercent': positionOutputAvailabilityPercent,
        'trustedDistanceAccountingAvailabilityPercent':
            trustedDistanceAccountingAvailabilityPercent,
        'measurementAcceptanceRatePercent': measurementAcceptanceRatePercent,
        'gapDeltaPercent': gapDeltaPercent,
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
  final int recoveryEventResidual;
  final bool allInvariantsHold;

  const ReconciliationResiduals({
    required this.inputResidual,
    required this.processingResidual,
    required this.stateOccupancyResidual,
    required this.availabilityPartitionResidual,
    required this.recoveryEventResidual,
    required this.allInvariantsHold,
  });

  Map<String, dynamic> toJson() => {
        'inputResidual': inputResidual,
        'processingResidual': processingResidual,
        'stateOccupancyResidual': stateOccupancyResidual,
        'availabilityPartitionResidual': availabilityPartitionResidual,
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

  int s0NormalCount = 0;
  int s0ProvisionalCount = 0;
  int s1DegradedCount = 0;
  int s2LossCount = 0;
  int s3ReacquisitionCount = 0;
  int s4ValidatedCount = 0;
  int s5ProbationCount = 0;
  int transitionCount = 0;

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

    // Transition tracking
    if (_lastState != null && result.state != _lastState) {
      transitionCount++;
    }

    // State occupancy & duration
    switch (result.state) {
      case GpsRecoveryState.s0NormalTracking:
        s0NormalCount++;
        timeInS0NormalSec += dt;
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

    // Measurement acceptance
    if (result.decision == EkfMeasurementDecision.rejected) {
      rejectedMeasurementCount++;
    } else {
      acceptedMeasurementCount++;
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

    s0NormalCount += other.s0NormalCount;
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
    return MeasurementAcceptance(
      acceptedMeasurementCount: acceptedMeasurementCount,
      rejectedMeasurementCount: rejectedMeasurementCount,
      bufferedCandidateCount: bufferedCandidateCount,
      provisionalMeasurementCount: provisionalMeasurementCount,
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
    final trusted = s0NormalCount;
    final provisional = s0ProvisionalCount + s1DegradedCount + s5ProbationCount;
    final unavailable = s2LossCount + s3ReacquisitionCount + s4ValidatedCount;
    final positionOutput = trusted + provisional;
    final legacy = scheduledCount - s2LossCount;

    final denom = scheduledCount > 0 ? scheduledCount.toDouble() : 1.0;

    final legacyPct = (legacy / denom) * 100.0;
    final trustedPct = (trusted / denom) * 100.0;
    final posOutputPct = (positionOutput / denom) * 100.0;
    final trustedDistPct = (trusted / denom) * 100.0;
    final acceptRatePct = (acceptedMeasurementCount / denom) * 100.0;
    final gapDeltaPct = legacyPct - trustedPct;

    return OperationalTrackingAvailability(
      trustedOperationalCount: trusted,
      untrustedOrProvisionalCount: provisional,
      unavailableCount: unavailable,
      positionOutputAvailableCount: positionOutput,
      legacyAvailableCount: legacy,
      legacyAvailabilityPercent: legacyPct,
      trustedOperationalAvailabilityPercent: trustedPct,
      positionOutputAvailabilityPercent: posOutputPct,
      trustedDistanceAccountingAvailabilityPercent: trustedDistPct,
      measurementAcceptanceRatePercent: acceptRatePct,
      gapDeltaPercent: gapDeltaPct,
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
    final recRes = lossOfLockEventCount -
        (recoveredEventCount + unresolvedEventCount);

    final holds = inputRes == 0 &&
        procRes == 0 &&
        stateRes == 0 &&
        availRes == 0 &&
        recRes == 0 &&
        totalUnavailableDurationSec >= 0.0;

    return ReconciliationResiduals(
      inputResidual: inputRes,
      processingResidual: procRes,
      stateOccupancyResidual: stateRes,
      availabilityPartitionResidual: availRes,
      recoveryEventResidual: recRes,
      allInvariantsHold: holds,
    );
  }
}
