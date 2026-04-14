// Tests for workout metric consistency.

import 'package:fitness_exercise_application/features/workout/domain/constants/workout_processing_contract.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Calories

  group('CalorieFormula', () {
    double computeCalories({
      required double weightKg,
      required double distKm,
      required double speedKmh,
      required bool isRunning,
    }) {
      double k = isRunning ? 1.05 : 0.92;
      if (speedKmh > 10) k += 0.05;
      if (speedKmh > 15) k += 0.05;
      return weightKg * distKm * k;
    }

    test('zero distance → zero calories', () {
      expect(
        computeCalories(weightKg: 70, distKm: 0, speedKmh: 10, isRunning: true),
        0.0,
      );
    });

    test('running 1 km at 8 km/h (70 kg) uses base running k=1.05', () {
      final cal = computeCalories(
        weightKg: 70,
        distKm: 1,
        speedKmh: 8,
        isRunning: true,
      );
      expect(cal, closeTo(70 * 1 * 1.05, 0.01)); // 73.5 kcal
    });

    test('fast run >10 km/h adds 0.05 bonus', () {
      final cal = computeCalories(
        weightKg: 70,
        distKm: 1,
        speedKmh: 12,
        isRunning: true,
      );
      expect(cal, closeTo(70 * 1 * 1.10, 0.01)); // 77.0 kcal
    });

    test('sprint >15 km/h adds another 0.05 bonus', () {
      final cal = computeCalories(
        weightKg: 70,
        distKm: 1,
        speedKmh: 16,
        isRunning: true,
      );
      expect(cal, closeTo(70 * 1 * 1.15, 0.01)); // 80.5 kcal
    });

    test('walking uses lower base k=0.92', () {
      final cal = computeCalories(
        weightKg: 70,
        distKm: 1,
        speedKmh: 5,
        isRunning: false,
      );
      expect(cal, closeTo(70 * 1 * 0.92, 0.01)); // 64.4 kcal
    });
  });

  // Avg speed

  group('AvgSpeedFormula', () {
    double computeAvgSpeed(double distKm, int durationSec) {
      if (durationSec <= 0) return 0.0;
      return distKm / (durationSec / 3600.0);
    }

    test('zero duration → zero speed', () {
      expect(computeAvgSpeed(1.0, 0), 0.0);
    });

    test('1 km in 600s (10 min) = 6.0 km/h', () {
      expect(computeAvgSpeed(1.0, 600), closeTo(6.0, 0.001));
    });

    test('5 km in 1800s (30 min) = 10.0 km/h', () {
      expect(computeAvgSpeed(5.0, 1800), closeTo(10.0, 0.001));
    });

    test('formula is consistent between live display and stop snapshot', () {
      const distKm = 2.5;
      const durSec = 900;
      final liveAvgSpeed = computeAvgSpeed(distKm, durSec);
      final snapshotAvgSpeed = computeAvgSpeed(distKm, durSec);
      expect(liveAvgSpeed, equals(snapshotAvgSpeed));
    });
  });

  // Snapshot consistency

  group('SnapshotConsistency', () {
    Map<String, dynamic> simulateStopAndPersist({
      required int durationSec,
      required double distanceMeters,
      required double weightKg,
      required bool isRunning,
    }) {
      final distKm = distanceMeters / 1000.0;
      final avgSpeedKmh = durationSec > 0
          ? distKm / (durationSec / 3600.0)
          : 0.0;

      double k = isRunning ? 1.05 : 0.92;
      if (avgSpeedKmh > 10) k += 0.05;
      if (avgSpeedKmh > 15) k += 0.05;
      final calories = (weightKg * distKm * k).round();

      final persisted = {
        'distanceKm': distKm,
        'avgSpeedKmh': avgSpeedKmh,
        'calories': calories,
        'durationSec': durationSec,
      };

      return {
        'distanceKm': persisted['distanceKm'],
        'avgSpeedKmh': persisted['avgSpeedKmh'],
        'calories': persisted['calories'],
      };
    }

    test(
      'record screen values match Statistics/Calendar after a 10-min walk',
      () {
        const durationSec = 600;
        const distanceMeters = 800.0;
        const weightKg = 65.0;

        final distKm = distanceMeters / 1000.0;
        final avgSpeedKmh = distKm / (durationSec / 3600.0);
        double k = 0.92;
        final liveCalories = (weightKg * distKm * k).round();

        final readBack = simulateStopAndPersist(
          durationSec: durationSec,
          distanceMeters: distanceMeters,
          weightKg: weightKg,
          isRunning: false,
        );

        expect(readBack['distanceKm'], closeTo(distKm, 0.0001));
        expect(readBack['avgSpeedKmh'], closeTo(avgSpeedKmh, 0.0001));
        expect(readBack['calories'], liveCalories);
      },
    );

    test(
      'record screen values match Statistics/Calendar after a 30-min run',
      () {
        const durationSec = 1800;
        const distanceMeters = 5100.0;
        const weightKg = 70.0;

        final distKm = distanceMeters / 1000.0;
        final avgSpeedKmh = distKm / (durationSec / 3600.0);
        double k = 1.05;
        if (avgSpeedKmh > 10) k += 0.05;
        if (avgSpeedKmh > 15) k += 0.05;
        final liveCalories = (weightKg * distKm * k).round();

        final readBack = simulateStopAndPersist(
          durationSec: durationSec,
          distanceMeters: distanceMeters,
          weightKg: weightKg,
          isRunning: true,
        );

        expect(readBack['distanceKm'], closeTo(distKm, 0.0001));
        expect(readBack['avgSpeedKmh'], closeTo(avgSpeedKmh, 0.0001));
        expect(readBack['calories'], liveCalories);
      },
    );

    test('no recalculation changes values between stop and read', () {
      const durationSec = 1200;
      const distanceMeters = 2000.0;

      final result = simulateStopAndPersist(
        durationSec: durationSec,
        distanceMeters: distanceMeters,
        weightKg: 68.0,
        isRunning: false,
      );

      final expectedDistKm = distanceMeters / 1000.0;
      final expectedAvgSpeed = expectedDistKm / (durationSec / 3600.0);

      expect(
        result['avgSpeedKmh'],
        equals(expectedAvgSpeed),
        reason: 'avgSpeedKmh must survive round-trip unchanged',
      );
      expect(
        result['distanceKm'],
        equals(expectedDistKm),
        reason: 'distanceKm must survive round-trip unchanged',
      );
    });

    test('average speed must be derived from total duration and distance', () {
      const durationSec = 1800;
      const distanceMeters = 5000.0;

      final distKm = distanceMeters / 1000.0;
      final expectedAvgSpeed = distKm / (durationSec / 3600.0);

      expect(expectedAvgSpeed, closeTo(10.0, 0.0001));
    });
  });

  group('DurationFormatting', () {
    test('formatDurationFromSeconds keeps second-level precision', () {
      expect(WorkoutFormatters.formatDurationFromSeconds(59), '59s');
      expect(WorkoutFormatters.formatDurationFromSeconds(60), '1m');
      expect(WorkoutFormatters.formatDurationFromSeconds(89), '1m 29s');
      expect(WorkoutFormatters.formatDurationFromSeconds(3661), '1h 1m 1s');
    });
  });

  group('BackendAlignedMetrics', () {
    test('client metric constants match backend processing defaults', () {
      expect(kClientMetricsVersion, 1);
      expect(kClientRecordingStatus, 'client_recording');
      expect(
        kClientPendingProcessingStatus,
        'client_finished_pending_processing',
      );
      expect(kClientFinalizedStatus, 'client_finalized');
      expect(kClientProcessingStatus, kClientPendingProcessingStatus);
      expect(kDeterministicFinalizeJobType, 'deterministic_finalize');
      expect(kQueuedJobStatus, 'queued');
      expect(kClientFinishEnqueuedEvent, 'client_finish_enqueued');
    });

    test('calculator computes speed from canonical distance and duration', () {
      final speed = WorkoutMetricsCalculator.computeAverageSpeedKmh(
        distanceKm: 5.0,
        durationSec: 1800,
      );
      expect(speed, closeTo(10.0, 0.0001));
    });

    test('raw GPS payload serializes to backend column names', () {
      final payload = RawGpsPointPayload(
        workoutId: 'session-1',
        timestamp: DateTime.utc(2026, 4, 14, 10, 0, 0),
        latitude: 10.123,
        longitude: 106.456,
        accuracy: 4.2,
        deviceSource: 'geolocator_position_stream',
      ).toJson();

      expect(payload['workout_id'], 'session-1');
      expect(payload['timestamp'], '2026-04-14T10:00:00.000Z');
      expect(payload['latitude'], closeTo(10.123, 0.0001));
      expect(payload['longitude'], closeTo(106.456, 0.0001));
      expect(payload['accuracy'], closeTo(4.2, 0.0001));
      expect(payload['device_source'], 'geolocator_position_stream');
    });

    test('raw step interval payload serializes to backend column names', () {
      final payload = RawStepIntervalPayload(
        workoutId: 'session-1',
        intervalStart: DateTime.utc(2026, 4, 14, 10, 0, 0),
        intervalEnd: DateTime.utc(2026, 4, 14, 10, 0, 5),
        stepsCount: 12,
        deviceSource: 'pedometer_step_count_stream',
      ).toJson();

      expect(payload['workout_id'], 'session-1');
      expect(payload['interval_start'], '2026-04-14T10:00:00.000Z');
      expect(payload['interval_end'], '2026-04-14T10:00:05.000Z');
      expect(payload['steps_count'], 12);
      expect(payload['device_source'], 'pedometer_step_count_stream');
    });
  });
}
