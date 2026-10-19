// Reusable MetricAccumulator for Phase 5 stratified analysis
import 'dart:math' as math;

class MetricAccumulator {
  double sumSqErr = 0.0;
  int sumCount = 0;
  double sumTruthDist = 0.0;
  double sumEstDist = 0.0;
  int scenarioCount = 0;
  final List<double> scenarioRmseSq = [];

  void add(double sqErr, double truthDist, double estDist, int count) {
    sumSqErr += sqErr;
    sumCount += count;
    sumTruthDist += truthDist;
    sumEstDist += estDist;
    scenarioCount++;
    final rmse = math.sqrt(sqErr / count);
    scenarioRmseSq.add(rmse * rmse);
  }

  double sampleWeightedRMSE() => sumCount > 0 ? math.sqrt(sumSqErr / sumCount) : 0.0;
  double scenarioWeightedRMSE() =>
      scenarioCount > 0 ? math.sqrt(scenarioRmseSq.reduce((a, b) => a + b) / scenarioCount) : 0.0;
  double biasPercent(double totalRouteDist) {
    if (sumTruthDist == 0) return 0.0;
    return (sumEstDist - sumTruthDist) / sumTruthDist * 100.0;
  }
}
