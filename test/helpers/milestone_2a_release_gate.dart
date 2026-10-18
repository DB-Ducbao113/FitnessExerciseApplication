/// Explicit evaluation structure for Phase 5 Milestone 2A frozen release gates.
/// Retains strict release thresholds without silent relaxation.
class Milestone2AReleaseGate {
  final double allScheduledRmse;
  final double allScheduledP95;
  final double availabilityPercent;
  final double overcountPercent;
  final double aggregateDistanceBiasPercent;
  final double recoveryLatencyP95;
  final double maxTransientError;
  final double psdPercent;

  static const double kRequiredMaxAllScheduledRmse = 8.0;
  static const double kRequiredMaxAllScheduledP95 = 15.0;
  static const double kRequiredMinAvailabilityPercent = 99.0;
  static const double kRequiredMaxOvercountPercent = 1.0;
  static const double kRequiredMaxAggregateDistanceBiasPercent = 1.0;
  static const double kRequiredMaxRecoveryLatencyP95Sec = 30.0;
  static const double kRequiredMinPsdPercent = 100.0;

  bool get isAllScheduledRmsePassing => allScheduledRmse < kRequiredMaxAllScheduledRmse;
  bool get isAllScheduledP95Passing => allScheduledP95 < kRequiredMaxAllScheduledP95;
  bool get isAvailabilityPassing => availabilityPercent >= kRequiredMinAvailabilityPercent;
  bool get isOvercountPassing => overcountPercent <= kRequiredMaxOvercountPercent;
  bool get isAggregateDistanceBiasPassing => aggregateDistanceBiasPercent.abs() <= kRequiredMaxAggregateDistanceBiasPercent;
  bool get isRecoveryLatencyPassing => recoveryLatencyP95 <= kRequiredMaxRecoveryLatencyP95Sec;
  bool get isPsdPassing => psdPercent >= kRequiredMinPsdPercent;

  bool get isReleaseAuthorized =>
      isAllScheduledRmsePassing &&
      isAllScheduledP95Passing &&
      isAvailabilityPassing &&
      isOvercountPassing &&
      isAggregateDistanceBiasPassing &&
      isRecoveryLatencyPassing &&
      isPsdPassing;

  const Milestone2AReleaseGate({
    required this.allScheduledRmse,
    required this.allScheduledP95,
    required this.availabilityPercent,
    required this.overcountPercent,
    required this.aggregateDistanceBiasPercent,
    required this.recoveryLatencyP95,
    required this.maxTransientError,
    required this.psdPercent,
  });

  factory Milestone2AReleaseGate.evaluate({
    required double allScheduledRmse,
    required double allScheduledP95,
    required double availabilityPercent,
    required double overcountPercent,
    required double aggregateDistanceBiasPercent,
    required double recoveryLatencyP95,
    required double maxTransientError,
    required double psdPercent,
  }) = Milestone2AReleaseGate.evaluateFromMetrics;

  factory Milestone2AReleaseGate.evaluateFromMetrics({
    required double allScheduledRmse,
    required double allScheduledP95,
    required double availabilityPercent,
    required double overcountPercent,
    required double aggregateDistanceBiasPercent,
    required double recoveryLatencyP95,
    required double maxTransientError,
    required double psdPercent,
  }) {
    return Milestone2AReleaseGate(
      allScheduledRmse: allScheduledRmse,
      allScheduledP95: allScheduledP95,
      availabilityPercent: availabilityPercent,
      overcountPercent: overcountPercent,
      aggregateDistanceBiasPercent: aggregateDistanceBiasPercent,
      recoveryLatencyP95: recoveryLatencyP95,
      maxTransientError: maxTransientError,
      psdPercent: psdPercent,
    );
  }

  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('\n========================================================================================================================');
    buffer.writeln('PHASE 5 MILESTONE 2A FROZEN ACCEPTANCE GATE EVALUATION');
    buffer.writeln('========================================================================================================================');
    buffer.writeln('| Gate Metric | Measured Value | Frozen Acceptance Threshold | Gate Result | Status |');
    buffer.writeln('|---|:---:|:---:|:---:|:---:|');
    buffer.writeln('| All-Scheduled RMSE | ${allScheduledRmse.toStringAsFixed(2)} m | < 8.00 m | ${isAllScheduledRmsePassing ? "PASS" : "FAIL"} | ${isAllScheduledRmsePassing ? "🟢 PASS" : "🔴 FAIL — Target < 8.0m not met"} |');
    buffer.writeln('| All-Scheduled P95 | ${allScheduledP95.toStringAsFixed(2)} m | < 15.00 m | ${isAllScheduledP95Passing ? "PASS" : "FAIL"} | ${isAllScheduledP95Passing ? "🟢 PASS" : "🔴 FAIL — Target < 15.0m not met"} |');
    buffer.writeln('| Sample Availability | ${availabilityPercent.toStringAsFixed(2)}% | >= 99.00% | ${isAvailabilityPassing ? "PASS" : "FAIL"} | ${isAvailabilityPassing ? "🟢 PASS" : "🔴 FAIL — Availability < 99%"} |');
    buffer.writeln('| Distance Overcount | +${overcountPercent.toStringAsFixed(2)}% | <= 1.00% | ${isOvercountPassing ? "PASS" : "FAIL"} | ${isOvercountPassing ? "🟢 PASS" : "🔴 FAIL — Target <= 1.0% not met"} |');
    buffer.writeln('| Aggregate Distance Bias | ${aggregateDistanceBiasPercent >= 0 ? "+" : ""}${aggregateDistanceBiasPercent.toStringAsFixed(2)}% | <= 1.00% | ${isAggregateDistanceBiasPassing ? "PASS" : "FAIL"} | ${isAggregateDistanceBiasPassing ? "🟢 PASS" : "🔴 FAIL — Bias <= 1.0% not met"} |');
    buffer.writeln('| Recovery Latency P95 | ${recoveryLatencyP95.toStringAsFixed(1)} s | <= 30.0 s | ${isRecoveryLatencyPassing ? "PASS" : "FAIL"} | ${isRecoveryLatencyPassing ? "🟢 PASS" : "🔴 FAIL — Latency <= 30s exceeded"} |');
    buffer.writeln('| Max Transient Error | ${maxTransientError.toStringAsFixed(1)} m | Informational | N/A | Peak during heading dropout |');
    buffer.writeln('| Covariance PSD Stability | ${psdPercent.toStringAsFixed(1)}% | 100.0% | ${isPsdPassing ? "PASS" : "FAIL"} | ${isPsdPassing ? "🟢 PASS" : "🔴 FAIL — PSD violations detected"} |');
    buffer.writeln('------------------------------------------------------------------------------------------------------------------------');
    buffer.writeln('OVERALL GATE DECISION: ${isReleaseAuthorized ? "APPROVED" : "HOLD — Milestone 2B, production integration, merge and deployment NOT AUTHORIZED"}');
    buffer.writeln('========================================================================================================================\n');
    return buffer.toString();
  }

  void printReport() {
    // ignore: avoid_print
    print(generateReport());
  }

  Map<String, dynamic> toJson() => {
    'all_scheduled_rmse_meters': allScheduledRmse,
    'all_scheduled_rmse_required_meters': kRequiredMaxAllScheduledRmse,
    'all_scheduled_rmse_pass': isAllScheduledRmsePassing,
    'all_scheduled_p95_meters': allScheduledP95,
    'all_scheduled_p95_required_meters': kRequiredMaxAllScheduledP95,
    'all_scheduled_p95_pass': isAllScheduledP95Passing,
    'availability_percent': availabilityPercent,
    'availability_required_percent': kRequiredMinAvailabilityPercent,
    'availability_pass': isAvailabilityPassing,
    'overcount_percent': overcountPercent,
    'overcount_required_percent': kRequiredMaxOvercountPercent,
    'overcount_pass': isOvercountPassing,
    'aggregate_distance_bias_percent': aggregateDistanceBiasPercent,
    'aggregate_distance_bias_required_percent': kRequiredMaxAggregateDistanceBiasPercent,
    'aggregate_distance_bias_pass': isAggregateDistanceBiasPassing,
    'recovery_latency_p95_sec': recoveryLatencyP95,
    'recovery_latency_p95_required_sec': kRequiredMaxRecoveryLatencyP95Sec,
    'recovery_latency_pass': isRecoveryLatencyPassing,
    'max_transient_error_meters': maxTransientError,
    'covariance_psd_percent': psdPercent,
    'covariance_psd_pass': isPsdPassing,
    'overall_decision': isReleaseAuthorized ? 'APPROVED' : 'HOLD',
    'is_release_authorized': isReleaseAuthorized,
  };
}
