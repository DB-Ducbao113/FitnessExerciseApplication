import 'package:fitness_exercise_application/features/workout/presentation/utils/route_display_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('route display sanitizer', () {
    test(
      'preserves a meaningful bend instead of collapsing to a straight cut',
      () {
        const raw = <LatLng>[
          LatLng(10.00000, 106.00000),
          LatLng(10.00008, 106.00000),
          LatLng(10.00016, 106.00000),
          LatLng(10.00020, 106.00005),
          LatLng(10.00020, 106.00012),
          LatLng(10.00020, 106.00020),
        ];

        final display = refineRouteForSavedDisplay(
          raw,
          activityType: 'running',
        );

        expect(display.first, raw.first);
        expect(display.last, raw.last);
        expect(display.length, greaterThanOrEqualTo(4));
        expect(
          display.any(
            (point) =>
                (point.latitude - 10.00020).abs() < 0.00003 &&
                (point.longitude - 106.00005).abs() < 0.00004,
          ),
          isTrue,
        );
      },
    );

    test('keeps endpoints unchanged for live and saved display', () {
      const raw = <LatLng>[
        LatLng(10.00000, 106.00000),
        LatLng(10.00005, 106.00002),
        LatLng(10.00010, 106.00004),
        LatLng(10.00015, 106.00006),
        LatLng(10.00020, 106.00008),
      ];

      final live = sanitizeRouteForDisplay(raw, activityType: 'walking');
      final saved = refineRouteForSavedDisplay(raw, activityType: 'walking');

      expect(live.first, raw.first);
      expect(live.last, raw.last);
      expect(saved.first, raw.first);
      expect(saved.last, raw.last);
    });

    test(
      'saved refinement remains at least as detailed as live sanitizer on a corridor',
      () {
        const raw = <LatLng>[
          LatLng(10.00000, 106.00000),
          LatLng(10.00003, 106.00001),
          LatLng(10.00006, 106.00002),
          LatLng(10.00009, 106.00003),
          LatLng(10.00012, 106.00004),
          LatLng(10.00015, 106.00005),
          LatLng(10.00018, 106.00006),
        ];

        final live = sanitizeRouteForDisplay(raw, activityType: 'running');
        final saved = refineRouteForSavedDisplay(raw, activityType: 'running');

        expect(saved.length, greaterThanOrEqualTo(live.length));
      },
    );

    test(
      'saved refinement does not introduce a large diagonal shift on a straight corridor',
      () {
        const raw = <LatLng>[
          LatLng(10.00000, 106.00000),
          LatLng(10.00004, 106.00001),
          LatLng(10.00008, 106.00002),
          LatLng(10.00012, 106.00003),
          LatLng(10.00016, 106.00004),
          LatLng(10.00020, 106.00005),
        ];

        final saved = refineRouteForSavedDisplay(raw, activityType: 'running');
        final distance = const Distance();

        for (var i = 1; i < saved.length - 1; i++) {
          final prev = saved[i - 1];
          final curr = saved[i];
          final next = saved[i + 1];
          final midpoint = LatLng(
            (prev.latitude + next.latitude) / 2,
            (prev.longitude + next.longitude) / 2,
          );
          expect(distance.distance(curr, midpoint), lessThan(6.0));
        }
      },
    );
  });
}
