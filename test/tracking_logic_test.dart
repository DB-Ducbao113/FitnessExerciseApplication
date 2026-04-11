import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('StrideLength', () {
    test('running stride is gender-aware when height is available', () {
      final male = computeStrideLength(
        activityType: 'Running',
        heightCm: 175,
        gender: 'male',
      );
      final female = computeStrideLength(
        activityType: 'Running',
        heightCm: 175,
        gender: 'female',
      );

      expect(male, greaterThan(female));
      expect(male, closeTo(1.1725, 0.0001));
      expect(female, closeTo(1.085, 0.0001));
    });

    test('walking fallback stride is gender-aware without height', () {
      final male = computeStrideLength(activityType: 'Walking', gender: 'male');
      final female = computeStrideLength(
        activityType: 'Walking',
        gender: 'female',
      );

      expect(male, closeTo(0.73, 0.0001));
      expect(female, closeTo(0.68, 0.0001));
    });
  });

  group('EnvironmentClassifier', () {
    Position makePosition({
      required double latitude,
      required double longitude,
      required DateTime timestamp,
      double accuracy = 10,
      double speed = 0,
    }) {
      return Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        accuracy: accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: speed,
        speedAccuracy: 0,
      );
    }

    test(
      'classifier emits indoor hint and fallback suggestion on clearly weak GPS walking signal',
      () async {
        final classifier = EnvironmentClassifier(activityType: 'walking');
        addTearDown(classifier.dispose);

        final now = DateTime.now();
        final eventFuture = classifier.stateStream
            .firstWhere((event) => event.environment != TrackingEnvironment.detecting)
            .timeout(
          const Duration(seconds: 2),
        );

        classifier.addPosition(
          makePosition(
            latitude: 10.0,
            longitude: 106.0,
            timestamp: now,
            accuracy: 55,
            speed: 0.05,
          ),
        );
        classifier.addPosition(
          makePosition(
            latitude: 10.000001,
            longitude: 106.000001,
            timestamp: now.add(const Duration(seconds: 1)),
            accuracy: 55,
            speed: 0.05,
          ),
        );
        classifier.addStepDelta(5);
        classifier.addPosition(
          makePosition(
            latitude: 10.000002,
            longitude: 106.000002,
            timestamp: now.add(const Duration(seconds: 2)),
            accuracy: 55,
            speed: 0.05,
          ),
        );
        classifier.addStepDelta(4);
        classifier.addPosition(
          makePosition(
            latitude: 10.000003,
            longitude: 106.000003,
            timestamp: now.add(const Duration(seconds: 3)),
            accuracy: 55,
            speed: 0.05,
          ),
        );

        final event = await eventFuture;
        expect(event.environment, TrackingEnvironment.indoor);
        expect(event.fallbackSuggested, isTrue);
        expect(event.confidence, greaterThan(0));
      },
    );
  });
}
