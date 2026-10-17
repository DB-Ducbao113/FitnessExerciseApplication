import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/synthetic_gps_trace_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('SyntheticGpsTraceFactory', () {
    const factory = SyntheticGpsTraceFactory();

    test('creates a labelled stationary trace with noisy raw observations', () {
      final trace = factory.stationary(
        startedAt: DateTime.utc(2026, 10, 12, 0),
        center: const LatLng(10.7769, 106.7009),
        duration: const Duration(minutes: 10),
      );

      expect(trace.isSynthetic, isTrue);
      expect(trace.scenario, SyntheticGpsScenario.stationary);
      expect(trace.points, hasLength(601));
      expect(
        trace.points.map((point) => point.groundTruth).toSet(),
        hasLength(1),
      );
      expect(
        trace.points.any(
          (point) =>
              point.rawMeasurement.latitude != point.groundTruth.latitude ||
              point.rawMeasurement.longitude != point.groundTruth.longitude,
        ),
        isTrue,
      );
    });

    test('creates an urban cycling trace with an explicit gap and outlier', () {
      final trace = factory.urbanCycling(
        startedAt: DateTime.utc(2026, 10, 12, 1),
        duration: const Duration(minutes: 6),
      );

      expect(trace.isSynthetic, isTrue);
      expect(trace.scenario, SyntheticGpsScenario.urbanCycling);
      expect(trace.points, isNotEmpty);
      expect(trace.points.any((point) => point.isInjectedOutlier), isTrue);
      expect(trace.maxObservedGap, greaterThan(const Duration(seconds: 5)));
      expect(trace.points.every((point) => point.speedMs >= 0), isTrue);
      expect(
        trace.points.every(
          (point) => point.headingDeg >= 0 && point.headingDeg < 360,
        ),
        isTrue,
      );
      expect(
        trace.points.first.groundTruth.latitude,
        closeTo(10.7380818, 1e-6),
      );
      expect(
        trace.points.first.groundTruth.longitude,
        closeTo(106.6253031, 1e-6),
      );
    });
  });
}
