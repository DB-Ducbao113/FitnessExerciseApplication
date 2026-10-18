// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'helpers/metric_accumulator.dart';

void main() {
  group('MetricAccumulator deterministic unit tests', () {
    test('Basic accumulation and sample‑weighted RMSE', () {
      final acc = MetricAccumulator();
      // Scenario 1: sqErr = 4, truthDist = 10, estDist = 12, count = 2
      acc.add(4.0, 10.0, 12.0, 2);
      // Scenario 2: sqErr = 9, truthDist = 20, estDist = 22, count = 3
      acc.add(9.0, 20.0, 22.0, 3);

      // Verify raw numerators / denominators
      expect(acc.sumSqErr, equals(13.0));
      expect(acc.sumCount, equals(5));
      expect(acc.sumTruthDist, equals(30.0));
      expect(acc.sumEstDist, equals(34.0));
      expect(acc.scenarioCount, equals(2));

      // Sample‑weighted RMSE = sqrt(13 / 5)
      const tolerance = 1e-12;
      expect(acc.sampleWeightedRMSE(), closeTo(math.sqrt(13.0 / 5.0), tolerance));

      // Scenario‑weighted RMSE = sqrt( (4/2) + (9/3) ) / 2 = sqrt(2 + 3) / 2 = sqrt(5) / 2
      final expectedScenarioRmseSq = (4.0 / 2) + (9.0 / 3); // 2 + 3 = 5
      final expectedScenarioWeighted = math.sqrt(expectedScenarioRmseSq / 2);
      expect(acc.scenarioWeightedRMSE(), closeTo(expectedScenarioWeighted, tolerance));

      // Signed bias percent = (34 - 30) / 30 * 100 = 13.333...%
      expect(acc.biasPercent(0.0), closeTo((34.0 - 30.0) / 30.0 * 100.0, tolerance));
    });

    test('Empty accumulator edge cases', () {
      final empty = MetricAccumulator();
      // No data – sumCount is zero. Sample‑weighted RMSE would divide by zero; we guard by not calling it.
      expect(empty.sumSqErr, equals(0.0));
      expect(empty.sumCount, equals(0));
      expect(empty.sumTruthDist, equals(0.0));
      expect(empty.sumEstDist, equals(0.0));
      expect(empty.scenarioCount, equals(0));

      // Bias with zero truth distance should be defined as 0.0
      expect(empty.biasPercent(0.0), equals(0.0));
    });

    test('Bias with zero truth distance denominator', () {
      final acc = MetricAccumulator();
      acc.add(1.0, 0.0, 5.0, 1);
      // Truth distance is zero, biasPercent should return 0.0 per implementation guard.
      expect(acc.biasPercent(0.0), equals(0.0));
    });
  });
}
