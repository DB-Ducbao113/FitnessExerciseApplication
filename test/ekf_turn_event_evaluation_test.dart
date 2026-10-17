// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

class TurnEventResult {
  final double angleDeg;
  final bool hasHeading;
  final bool detected;
  final double delaySeconds;
  final double maxHeadingScale;

  TurnEventResult({
    required this.angleDeg,
    required this.hasHeading,
    required this.detected,
    required this.delaySeconds,
    required this.maxHeadingScale,
  });
}

void main() {
  group('Task 3: Turn Event Precision, Recall, and Detection Delay Evaluation', () {
    const startPoint = LatLng(10.7380, 106.6252);
    final angles = [30.0, 60.0, 90.0, 180.0];
    const speedMs = 5.0; // 18 km/h
    const dt = 1.0;

    for (final hasHeading in [true, false]) {
      final condition = hasHeading ? 'With Compass Heading' : 'With Heading Dropout (COG Only)';

      for (final angle in angles) {
        test('Turn event evaluation: $angle° corner ($condition)', () {
          final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
          ekf.init(
            initialPoint: startPoint,
            initialSpeedMs: speedMs,
            initialHeadingDeg: hasHeading ? 0.0 : null,
          );

          // 1. Straight approach (10 steps North = 50m)
          var truth = startPoint;
          int straightFalseTurns = 0;
          int straightSamples = 0;

          for (int i = 0; i < 10; i++) {
            truth = _distance.offset(truth, speedMs * dt, 0.0);
            straightSamples++;
            final est = ekf.update(
              measurementPoint: truth,
              accuracyMeters: 4.0,
              timeDeltaSec: dt,
              speedMs: speedMs,
              headingDeg: hasHeading ? 0.0 : null,
            );
            if (est.diagnostics.turnDetected) straightFalseTurns++;
          }

          expect(straightFalseTurns, equals(0), reason: 'Zero false turns on straight approach');

          // 2. Corner execution (5 steps along turn angle)
          bool turnDetectedInEvent = false;
          double delaySec = -1.0;
          double maxScale = 1.0;

          for (int i = 0; i < 5; i++) {
            truth = _distance.offset(truth, speedMs * dt, angle);
            final est = ekf.update(
              measurementPoint: truth,
              accuracyMeters: 4.0,
              timeDeltaSec: dt,
              speedMs: speedMs,
              headingDeg: hasHeading ? angle : null,
            );

            final scale = (est.diagnostics.headingProcessVariance ?? 0.25) / 0.25;
            if (scale > maxScale) maxScale = scale;

            if (est.diagnostics.turnDetected && !turnDetectedInEvent) {
              turnDetectedInEvent = true;
              delaySec = i * dt;
            }
          }

          // 3. Straight exit (10 steps along new angle = 50m)
          for (int i = 0; i < 10; i++) {
            truth = _distance.offset(truth, speedMs * dt, angle);
            straightSamples++;
            final est = ekf.update(
              measurementPoint: truth,
              accuracyMeters: 4.0,
              timeDeltaSec: dt,
              speedMs: speedMs,
              headingDeg: hasHeading ? angle : null,
            );
            // After settling on new heading, should not detect turn
            if (i >= 2 && est.diagnostics.turnDetected) {
              straightFalseTurns++;
            }
          }

          print('Result $angle° ($condition):');
          print('  Detected: $turnDetectedInEvent');
          print('  Delay: ${delaySec >= 0 ? "${delaySec.toStringAsFixed(1)}s" : "N/A"}');
          print('  Max Heading Scale: ${maxScale.toStringAsFixed(2)}x');
          print('  Straight False Turns: $straightFalseTurns / $straightSamples (${(straightFalseTurns / straightSamples * 100).toStringAsFixed(1)}%)');

          expect(turnDetectedInEvent, isTrue, reason: 'Turn of $angle° MUST be detected ($condition)');
          expect(maxScale, greaterThan(2.0), reason: 'Heading Q scale must adapt');
          expect(straightFalseTurns / straightSamples, lessThan(0.05), reason: 'False turn rate < 5% on straight portions');
        });
      }
    }
  });
}
