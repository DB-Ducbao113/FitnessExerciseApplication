import 'package:fitness_exercise_application/features/workout/domain/services/polyline_compression_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const service = PolylineCompressionService();

  group('PolylineCompressionService - Standard Algorithm Compliance', () {
    test('encodes Google standard reference vector correctly', () {
      // Google Official Documentation Vector:
      // (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
      // Expect: "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
      final points = [
        const LatLng(38.5, -120.2),
        const LatLng(40.7, -120.95),
        const LatLng(43.252, -126.453),
      ];

      final encoded = service.encode(points);
      expect(encoded, equals('_p~iF~ps|U_ulLnnqC_mqNvxq`@'));

      final decoded = service.decode(encoded);
      expect(decoded.length, equals(3));
      expect(decoded[0].latitude, closeTo(38.5, 0.00001));
      expect(decoded[0].longitude, closeTo(-120.2, 0.00001));
      expect(decoded[1].latitude, closeTo(40.7, 0.00001));
      expect(decoded[1].longitude, closeTo(-120.95, 0.00001));
      expect(decoded[2].latitude, closeTo(43.252, 0.00001));
      expect(decoded[2].longitude, closeTo(-126.453, 0.00001));
    });

    test('handles empty points and empty string gracefully', () {
      expect(service.encode([]), equals(''));
      expect(service.decode(''), isEmpty);
      expect(service.encodeSegments([]), isEmpty);
      expect(service.decodeSegments([]), isEmpty);
    });

    test('handles single point correctly', () {
      final points = [const LatLng(10.77689, 106.70081)];
      final encoded = service.encode(points);
      expect(encoded, isNotEmpty);

      final decoded = service.decode(encoded);
      expect(decoded.length, equals(1));
      expect(decoded.first.latitude, closeTo(10.77689, 0.00001));
      expect(decoded.first.longitude, closeTo(106.70081, 0.00001));
    });

    test('encodes and decodes with high precision (precision 6)', () {
      final points = [
        const LatLng(10.776889, 106.700806),
        const LatLng(10.776912, 106.700835),
      ];

      final encoded6 = service.encode(points, precision: 6);
      final decoded6 = service.decode(encoded6, precision: 6);

      expect(decoded6.length, equals(2));
      expect(decoded6[0].latitude, closeTo(10.776889, 0.000001));
      expect(decoded6[0].longitude, closeTo(106.700806, 0.000001));
      expect(decoded6[1].latitude, closeTo(10.776912, 0.000001));
      expect(decoded6[1].longitude, closeTo(106.700835, 0.000001));
    });

    test('encodes and decodes multi-segment routes cleanly', () {
      final segment1 = [
        const LatLng(10.770, 106.700),
        const LatLng(10.771, 106.701),
      ];
      final segment2 = [
        const LatLng(10.775, 106.705),
        const LatLng(10.776, 106.706),
        const LatLng(10.777, 106.707),
      ];

      final encodedSegments = service.encodeSegments([segment1, segment2]);
      expect(encodedSegments.length, equals(2));

      final decodedSegments = service.decodeSegments(encodedSegments);
      expect(decodedSegments.length, equals(2));
      expect(decodedSegments[0].length, equals(2));
      expect(decodedSegments[1].length, equals(3));
    });
  });

  group('PolylineCompressionService - Scale & Compression Benchmarks', () {
    test('verifies >90% payload reduction on a 3,000-point running session', () {
      // Simulate 3,000 GPS points representing a 50-minute running workout
      final workoutRoute = <LatLng>[];
      var currentLat = 10.77688;
      var currentLng = 106.70080;

      for (var i = 0; i < 3000; i++) {
        // Small realistic GPS movement ~1-2 meters per second
        currentLat += 0.000015;
        currentLng += 0.000012;
        workoutRoute.add(LatLng(currentLat, currentLng));
      }

      final encoded = service.encode(workoutRoute);
      final stats = service.calculateCompressionStats(
        originalPoints: workoutRoute,
        encodedPolyline: encoded,
      );

      // Verify stats
      expect(stats.coordinateCount, equals(3000));
      expect(stats.savedBytesPercentage, greaterThan(90.0));
      expect(stats.compressionFactor, greaterThan(10.0));

      // Decode and verify 100% data recovery
      final decoded = service.decode(encoded);
      expect(decoded.length, equals(3000));
      for (var i = 0; i < 3000; i += 100) {
        expect(decoded[i].latitude, closeTo(workoutRoute[i].latitude, 0.00001));
        expect(
          decoded[i].longitude,
          closeTo(workoutRoute[i].longitude, 0.00001),
        );
      }
    });
  });
}
