import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/canonical_output_fingerprint.dart';
import 'helpers/experimental_gps_recovery_state_machine.dart';

void main() {
  group('TASK 4.3 — Output Fingerprint Determinism & Mutation Detection Tests', () {
    test('1. Float64 hex representation preserves full 64-bit precision and roundtrips', () {
      final testValues = [
        10.738082,
        106.625303,
        0.0,
        -0.0,
        double.infinity,
        -double.infinity,
        1e-15,
        1e15,
        math.pi,
        math.e,
        42.123456789012345,
      ];

      for (final val in testValues) {
        final hex = CanonicalFloatHelper.doubleToHex(val);
        expect(hex.length, equals(16));
        final roundtrip = CanonicalFloatHelper.hexToDouble(hex);

        if (val == 0.0) {
          expect(roundtrip, equals(0.0));
        } else if (val.isInfinite) {
          expect(roundtrip, equals(val));
        } else {
          expect(roundtrip, equals(val));
        }
      }

      // NaN canonicalization
      final nanHex1 = CanonicalFloatHelper.doubleToHex(double.nan);
      final nanHex2 = CanonicalFloatHelper.doubleToHex(double.nan);
      expect(nanHex1, equals('7FF8000000000000'));
      expect(nanHex2, equals(nanHex1));
    });

    test('2. Identical input stream produces bit-exact canonical fingerprint (Reproducibility)', () {
      CanonicalEpochRecord makeRecord(int index, double offset) => CanonicalEpochRecord(
            configId: 'DOpt',
            scenarioId: 1,
            sampleIndex: index,
            elapsedMs: index * 1000,
            latitude: 10.738082 + offset,
            longitude: 106.625303 + offset,
            fsmState: 's0NormalTracking',
            measurementDecision: 'acceptedClean',
            addedDistanceMeters: 5.56,
            accumulatedDistanceMeters: 5.56 * (index + 1),
            wasResetApplied: false,
            wasRollbackApplied: false,
            estimatedSpeedMs: 5.56,
            estimatedHeadingDeg: 90.0,
            positionVariance: 4.5,
          );

      final stream1 = List.generate(100, (i) => makeRecord(i, i * 0.00001));
      final stream2 = List.generate(100, (i) => makeRecord(i, i * 0.00001));

      final str1 = stream1.map((r) => r.toCanonicalString()).join();
      final str2 = stream2.map((r) => r.toCanonicalString()).join();

      final sha1 = sha256.convert(utf8.encode(str1)).toString();
      final sha2 = sha256.convert(utf8.encode(str2)).toString();

      expect(sha1, equals(sha2));
      expect(str1, equals(str2));
    });

    test('3. Deliberate Mutation: Small coordinate change hidden by 5-decimal rounding', () {
      // Base: lat = 10.738081 -> toStringAsFixed(5) is "10.73808"
      // Mutated: lat = 10.738084 -> toStringAsFixed(5) is "10.73808"
      // Delta = 0.000003 deg (~0.33m).
      // The legacy hash DOES NOT detect this regression!
      // The canonical fingerprint MUST detect this regression!

      final recBase = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 0,
        elapsedMs: 0,
        latitude: 10.738081,
        longitude: 106.625303,
        fsmState: 's0NormalTracking',
        measurementDecision: 'acceptedClean',
        addedDistanceMeters: 0.0,
        accumulatedDistanceMeters: 0.0,
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.0,
        estimatedHeadingDeg: 90.0,
        positionVariance: 4.0,
      );

      final recMutated = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 0,
        elapsedMs: 0,
        latitude: 10.738084, // Sub-5-decimal coordinate shift (~33 cm)
        longitude: 106.625303,
        fsmState: 's0NormalTracking',
        measurementDecision: 'acceptedClean',
        addedDistanceMeters: 0.0,
        accumulatedDistanceMeters: 0.0,
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.0,
        estimatedHeadingDeg: 90.0,
        positionVariance: 4.0,
      );

      // Verify that legacy 5-decimal rounding hides the change
      final legacyBase = '${recBase.latitude.toStringAsFixed(5)},${recBase.longitude.toStringAsFixed(5)};';
      final legacyMutated = '${recMutated.latitude.toStringAsFixed(5)},${recMutated.longitude.toStringAsFixed(5)};';
      expect(legacyBase, equals(legacyMutated),
          reason: 'PROVES DEFECT: Legacy 5-decimal rounding fails to detect sub-meter coordinate mutation!');

      // Verify that canonical fingerprint detects the change
      final canonicalBase = recBase.toCanonicalString();
      final canonicalMutated = recMutated.toCanonicalString();
      expect(canonicalBase, isNot(equals(canonicalMutated)));

      final shaBase = sha256.convert(utf8.encode(canonicalBase)).toString();
      final shaMutated = sha256.convert(utf8.encode(canonicalMutated)).toString();
      expect(shaBase, isNot(equals(shaMutated)),
          reason: 'Canonical fingerprint successfully catches sub-meter coordinate mutation!');
    });

    test('4. Deliberate Mutation: Small distance change hidden by 2-decimal rounding', () {
      // Base: distance = 1250.451 m -> toStringAsFixed(2) is "1250.45"
      // Mutated: distance = 1250.454 m -> toStringAsFixed(2) is "1250.45"
      // Delta = 0.003 m (3 mm).
      // Legacy hash hides the change; canonical fingerprint detects it.

      final recBase = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 10,
        elapsedMs: 10000,
        latitude: 10.738082,
        longitude: 106.625303,
        fsmState: 's0NormalTracking',
        measurementDecision: 'acceptedClean',
        addedDistanceMeters: 5.561,
        accumulatedDistanceMeters: 1250.451,
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.56,
        estimatedHeadingDeg: 90.0,
        positionVariance: 4.0,
      );

      final recMutated = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 10,
        elapsedMs: 10000,
        latitude: 10.738082,
        longitude: 106.625303,
        fsmState: 's0NormalTracking',
        measurementDecision: 'acceptedClean',
        addedDistanceMeters: 5.564,
        accumulatedDistanceMeters: 1250.454, // 3 mm shift hidden by 2 decimals
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.56,
        estimatedHeadingDeg: 90.0,
        positionVariance: 4.0,
      );

      final legacyBase = 'S1:${recBase.accumulatedDistanceMeters.toStringAsFixed(2)};';
      final legacyMutated = 'S1:${recMutated.accumulatedDistanceMeters.toStringAsFixed(2)};';
      expect(legacyBase, equals(legacyMutated),
          reason: 'PROVES DEFECT: Legacy 2-decimal rounding fails to detect millimeter distance mutation!');

      final shaBase = sha256.convert(utf8.encode(recBase.toCanonicalString())).toString();
      final shaMutated = sha256.convert(utf8.encode(recMutated.toCanonicalString())).toString();
      expect(shaBase, isNot(equals(shaMutated)),
          reason: 'Canonical fingerprint successfully catches millimeter distance mutation!');
    });

    test('5. Deliberate Mutation: FSM state change with identical coordinates', () {
      final recBase = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 10,
        elapsedMs: 10000,
        latitude: 10.738082,
        longitude: 106.625303,
        fsmState: 's0NormalTracking',
        measurementDecision: 'acceptedClean',
        addedDistanceMeters: 5.56,
        accumulatedDistanceMeters: 55.6,
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.56,
        estimatedHeadingDeg: 90.0,
        positionVariance: 4.0,
      );

      final recMutated = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 10,
        elapsedMs: 10000,
        latitude: 10.738082,
        longitude: 106.625303,
        fsmState: 's1SuspectedDegraded', // State transition mutated
        measurementDecision: 'acceptedClean',
        addedDistanceMeters: 5.56,
        accumulatedDistanceMeters: 55.6,
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.56,
        estimatedHeadingDeg: 90.0,
        positionVariance: 4.0,
      );

      // Legacy hash completely ignores FSM state
      final legacyBase = '${recBase.latitude.toStringAsFixed(5)},${recBase.longitude.toStringAsFixed(5)};';
      final legacyMutated = '${recMutated.latitude.toStringAsFixed(5)},${recMutated.longitude.toStringAsFixed(5)};';
      expect(legacyBase, equals(legacyMutated),
          reason: 'PROVES DEFECT: Legacy hash omits FSM state transitions entirely!');

      final shaBase = sha256.convert(utf8.encode(recBase.toCanonicalString())).toString();
      final shaMutated = sha256.convert(utf8.encode(recMutated.toCanonicalString())).toString();
      expect(shaBase, isNot(equals(shaMutated)),
          reason: 'Canonical fingerprint detects FSM state transition change!');
    });

    test('6. Deliberate Mutation: Measurement decision change', () {
      final recBase = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 10,
        elapsedMs: 10000,
        latitude: 10.738082,
        longitude: 106.625303,
        fsmState: 's0NormalTracking',
        measurementDecision: 'acceptedClean',
        addedDistanceMeters: 5.56,
        accumulatedDistanceMeters: 55.6,
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.56,
        estimatedHeadingDeg: 90.0,
        positionVariance: 4.0,
      );

      final recMutated = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 10,
        elapsedMs: 10000,
        latitude: 10.738082,
        longitude: 106.625303,
        fsmState: 's0NormalTracking',
        measurementDecision: 'acceptedDownweighted', // Decision mutated
        addedDistanceMeters: 5.56,
        accumulatedDistanceMeters: 55.6,
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.56,
        estimatedHeadingDeg: 90.0,
        positionVariance: 4.0,
      );

      final legacyBase = '${recBase.latitude.toStringAsFixed(5)},${recBase.longitude.toStringAsFixed(5)};';
      final legacyMutated = '${recMutated.latitude.toStringAsFixed(5)},${recMutated.longitude.toStringAsFixed(5)};';
      expect(legacyBase, equals(legacyMutated),
          reason: 'PROVES DEFECT: Legacy hash omits measurement acceptance decision!');

      final shaBase = sha256.convert(utf8.encode(recBase.toCanonicalString())).toString();
      final shaMutated = sha256.convert(utf8.encode(recMutated.toCanonicalString())).toString();
      expect(shaBase, isNot(equals(shaMutated)));
    });

    test('7. Deliberate Mutation: Reset and recovery event change', () {
      final recBase = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 10,
        elapsedMs: 10000,
        latitude: 10.738082,
        longitude: 106.625303,
        fsmState: 's5SafeReset',
        measurementDecision: 'rejectedGrossOutlier',
        addedDistanceMeters: 0.0,
        accumulatedDistanceMeters: 55.6,
        wasResetApplied: false,
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.56,
        estimatedHeadingDeg: 90.0,
        positionVariance: 40.0,
      );

      final recMutated = CanonicalEpochRecord(
        configId: 'DOpt',
        scenarioId: 1,
        sampleIndex: 10,
        elapsedMs: 10000,
        latitude: 10.738082,
        longitude: 106.625303,
        fsmState: 's5SafeReset',
        measurementDecision: 'rejectedGrossOutlier',
        addedDistanceMeters: 0.0,
        accumulatedDistanceMeters: 55.6,
        wasResetApplied: true, // Reset event applied
        wasRollbackApplied: false,
        estimatedSpeedMs: 5.56,
        estimatedHeadingDeg: 90.0,
        positionVariance: 40.0,
      );

      final legacyBase = '${recBase.latitude.toStringAsFixed(5)},${recBase.longitude.toStringAsFixed(5)};';
      final legacyMutated = '${recMutated.latitude.toStringAsFixed(5)},${recMutated.longitude.toStringAsFixed(5)};';
      expect(legacyBase, equals(legacyMutated),
          reason: 'PROVES DEFECT: Legacy hash omits reset/recovery indicators!');

      final shaBase = sha256.convert(utf8.encode(recBase.toCanonicalString())).toString();
      final shaMutated = sha256.convert(utf8.encode(recMutated.toCanonicalString())).toString();
      expect(shaBase, isNot(equals(shaMutated)));
    });

    test('8. Deliberate Mutation: Scenario order change permutes composite configuration fingerprint', () {
      final acc1 = ConfigurationFingerprintAccumulator(configId: 'DOpt', configName: 'Proposed D+Opt');
      final acc2 = ConfigurationFingerprintAccumulator(configId: 'DOpt', configName: 'Proposed D+Opt');

      CanonicalEpochRecord makeScenRecord(int scenId, int s) => CanonicalEpochRecord(
            configId: 'DOpt',
            scenarioId: scenId,
            sampleIndex: s,
            elapsedMs: s * 1000,
            latitude: 10.738082 + scenId * 0.01,
            longitude: 106.625303 + s * 0.0001,
            fsmState: 's0NormalTracking',
            measurementDecision: 'acceptedClean',
            addedDistanceMeters: 5.0,
            accumulatedDistanceMeters: 5.0 * (s + 1),
            wasResetApplied: false,
            wasRollbackApplied: false,
            estimatedSpeedMs: 5.0,
            estimatedHeadingDeg: 90.0,
            positionVariance: 4.0,
          );

      // acc1: Scenario 1 then Scenario 2
      acc1.startScenario(1);
      for (var s = 0; s < 5; s++) {
        acc1.recordEpoch(makeScenRecord(1, s));
      }
      acc1.endScenario(scenarioId: 1, description: 'Scen 1', finalDistanceMeters: 25.0);

      acc1.startScenario(2);
      for (var s = 0; s < 5; s++) {
        acc1.recordEpoch(makeScenRecord(2, s));
      }
      acc1.endScenario(scenarioId: 2, description: 'Scen 2', finalDistanceMeters: 25.0);

      // acc2: Scenario 2 then Scenario 1 (permutated order)
      acc2.startScenario(2);
      for (var s = 0; s < 5; s++) {
        acc2.recordEpoch(makeScenRecord(2, s));
      }
      acc2.endScenario(scenarioId: 2, description: 'Scen 2', finalDistanceMeters: 25.0);

      acc2.startScenario(1);
      for (var s = 0; s < 5; s++) {
        acc2.recordEpoch(makeScenRecord(1, s));
      }
      acc2.endScenario(scenarioId: 1, description: 'Scen 1', finalDistanceMeters: 25.0);

      final fp1 = acc1.finalizeFingerprint();
      final fp2 = acc2.finalizeFingerprint();

      expect(fp1.canonicalScenarioCompositeSha256, isNot(equals(fp2.canonicalScenarioCompositeSha256)),
          reason: 'Composite scenario hash enforces strict scenario ordering!');
      expect(fp1.canonicalEpochStreamSha256, isNot(equals(fp2.canonicalEpochStreamSha256)),
          reason: 'Stream hash enforces strict epoch ordering!');
    });

    test('9. Mini-simulation repeated execution produces bit-exact identical canonical fingerprints', () {
      // Run a mini 3-step scenario using real ExperimentalGpsRecoveryStateMachine twice with seed 42
      ConfigurationFingerprint runMiniSim() {
        final acc = ConfigurationFingerprintAccumulator(configId: 'DOpt', configName: 'Proposed D+Opt');
        final ekf = ExtendedKalmanFilter(maxTurnHeadingNoiseScale: 14.0);
        final fsm = ExperimentalGpsRecoveryStateMachine(
          ekf: ekf,
          enableAlongTrackProjection: false,
          enableBoundedHybridDistance: true,
          enableGapOverlapCorrection: true,
          enableProbationVarianceInflation: true,
          enableAlternativeRollbackRecovery: true,
          enableMultiFixHeadingEstimation: true,
          enableProbationConsecutiveRejections: true,
          enableAdaptiveTurnUncertainty: true,
          enableNoiseAwareKinematicScreening: true,
        );

        final rand = math.Random(42);
        final startTime = DateTime.utc(2026, 10, 15, 8, 0, 0);

        acc.startScenario(1);
        for (var s = 0; s < 20; s++) {
          final t = startTime.add(Duration(milliseconds: s * 1000));
          final rawPos = LatLng(
            10.738082 + s * 0.00005 + (rand.nextDouble() - 0.5) * 0.00002,
            106.625303 + (rand.nextDouble() - 0.5) * 0.00002,
          );
          final out = fsm.processMeasurement(
            point: rawPos,
            accuracyMeters: 5.0,
            timeDeltaSec: 1.0,
            timestamp: t,
            speedMs: 5.0,
            headingDeg: 90.0,
            hasAuxiliarySensors: true,
          );

          acc.recordEpoch(CanonicalEpochRecord(
            configId: 'DOpt',
            scenarioId: 1,
            sampleIndex: s,
            elapsedMs: s * 1000,
            latitude: out.estimatedPosition.latitude,
            longitude: out.estimatedPosition.longitude,
            fsmState: out.state.name,
            measurementDecision: out.decision.name,
            addedDistanceMeters: out.addedDistanceMeters,
            accumulatedDistanceMeters: out.totalAccumulatedDistanceMeters,
            wasResetApplied: out.wasResetApplied,
            wasRollbackApplied: out.wasRollbackApplied,
            estimatedSpeedMs: out.estimatedSpeedMs,
            estimatedHeadingDeg: out.estimatedHeadingDeg,
            positionVariance: out.positionVariance,
          ));
        }
        acc.endScenario(scenarioId: 1, description: 'MiniSim', finalDistanceMeters: fsm.accumulatedDistanceMeters);
        return acc.finalizeFingerprint();
      }

      final run1 = runMiniSim();
      final run2 = runMiniSim();

      expect(run1.canonicalEpochStreamSha256, equals(run2.canonicalEpochStreamSha256));
      expect(run1.canonicalScenarioCompositeSha256, equals(run2.canonicalScenarioCompositeSha256));
      expect(run1.legacyRoundedSha256, equals(run2.legacyRoundedSha256));
    });
  });
}
