// Unit tests for [RouteMatchQualityService.normalize].
//
// `normalize` is the single choke point that decides, for every persisted
// session, which distance the UI is allowed to show:
//   * `matched`                  → trust the map-matched distance
//   * `filtered_display_matched` → display the filtered distance, matched
//                                  geometry attached for the route preview
//   * `filtered`                 → no usable match, fall back to filtered
//                                  distance and drop the matched distance
//
// Every test states the observable contract (status + source + distance), not
// the implementation, so this suite also acts as a regression lock for the
// fallbacks.

import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/route_match_quality_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = RouteMatchQualityService();

  /// A result that "has geometry" by default, so each test only has to vary
  /// the field it actually cares about.
  RouteMatchResult buildResult({
    String sessionId = 'session-1',
    String matchedRouteJson =
        '[[{"lat":10.0,"lng":106.0},{"lat":10.001,"lng":106.001}]]',
    String routeMatchStatus = 'matched_success_high_confidence',
    double? routeMatchConfidence,
    String routeDistanceSource = 'filtered',
    double? matchedDistanceKm,
    String routeMatchMetricsJson = '{}',
  }) {
    return RouteMatchResult(
      sessionId: sessionId,
      matchedRouteJson: matchedRouteJson,
      routeMatchStatus: routeMatchStatus,
      routeMatchConfidence: routeMatchConfidence,
      routeDistanceSource: routeDistanceSource,
      matchedDistanceKm: matchedDistanceKm,
      routeMatchMetricsJson: routeMatchMetricsJson,
    );
  }

  group('RouteMatchQualityService.normalize — empty geometry fallback', () {
    test('empty matchedRouteJson forces filtered fallback', () {
      final result = service.normalize(
        buildResult(
          matchedRouteJson: '',
          routeMatchStatus: 'matched_success_high_confidence',
          routeMatchConfidence: 0.99,
          matchedDistanceKm: 5.0,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });

    test('"[]" matchedRouteJson (serialized empty list) also falls back', () {
      final result = service.normalize(
        buildResult(
          matchedRouteJson: '[]',
          routeMatchStatus: 'matched_success_high_confidence',
          routeMatchConfidence: 0.99,
          matchedDistanceKm: 5.0,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });

    test('whitespace-only geometry falls back safely', () {
      final result = service.normalize(
        buildResult(
          matchedRouteJson: '   ',
          routeMatchStatus: 'matched_success_high_confidence',
          matchedDistanceKm: 3.2,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });

    test('malformed JSON falls back safely', () {
      final result = service.normalize(
        buildResult(matchedRouteJson: '[not-json', matchedDistanceKm: 3.2),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });

    test('a segment with fewer than two valid points is not drawable', () {
      final result = service.normalize(
        buildResult(
          matchedRouteJson: '[[{"lat":10.0,"lng":106.0}]]',
          matchedDistanceKm: 3.2,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });

    test('out-of-range coordinates are rejected', () {
      final result = service.normalize(
        buildResult(
          matchedRouteJson:
              '[[{"lat":91.0,"lng":106.0},{"lat":10.0,"lng":181.0}]]',
          matchedDistanceKm: 3.2,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });
  });

  group('normalize — explicit matched statuses', () {
    test('high confidence + positive distance → matched', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'matched_success_high_confidence',
          matchedDistanceKm: 10.42,
        ),
      );

      expect(result.routeMatchStatus, 'matched_success_high_confidence');
      expect(result.routeDistanceSource, 'matched');
      expect(result.matchedDistanceKm, 10.42);
    });

    test(
      'high confidence with zero distance downgrades to filtered display',
      () {
        final result = service.normalize(
          buildResult(
            routeMatchStatus: 'matched_success_high_confidence',
            matchedDistanceKm: 0,
          ),
        );

        expect(result.routeMatchStatus, 'matched_success_high_confidence');
        expect(result.routeDistanceSource, 'filtered_display_matched');
        expect(result.matchedDistanceKm, isNull);
      },
    );

    test(
      'high confidence with null distance downgrades to filtered display',
      () {
        final result = service.normalize(
          buildResult(
            routeMatchStatus: 'matched_success_high_confidence',
            matchedDistanceKm: null,
          ),
        );

        expect(result.routeMatchStatus, 'matched_success_high_confidence');
        expect(result.routeDistanceSource, 'filtered_display_matched');
      },
    );

    test(
      'high confidence with negative distance downgrades to filtered display',
      () {
        // Only `> 0` counts as a usable matched distance.
        final result = service.normalize(
          buildResult(
            routeMatchStatus: 'matched_success_high_confidence',
            matchedDistanceKm: -1.5,
          ),
        );

        expect(result.routeDistanceSource, 'filtered_display_matched');
        expect(result.matchedDistanceKm, isNull);
      },
    );

    test('medium confidence keeps filtered display and matched geometry', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'matched_success_medium_confidence',
          matchedDistanceKm: 7.5,
        ),
      );

      expect(result.routeMatchStatus, 'matched_success_medium_confidence');
      expect(result.routeDistanceSource, 'filtered_display_matched');
      expect(result.matchedDistanceKm, 7.5);
    });

    test('partial match keeps filtered display and matched geometry', () {
      final result = service.normalize(
        buildResult(routeMatchStatus: 'partial_match', matchedDistanceKm: 2.0),
      );

      expect(result.routeMatchStatus, 'partial_match');
      expect(result.routeDistanceSource, 'filtered_display_matched');
      expect(result.matchedDistanceKm, 2.0);
    });

    test(
      'medium confidence without distance still reports filtered display',
      () {
        final result = service.normalize(
          buildResult(
            routeMatchStatus: 'matched_success_medium_confidence',
            matchedDistanceKm: null,
          ),
        );

        expect(result.routeDistanceSource, 'filtered_display_matched');
        expect(result.matchedDistanceKm, isNull);
      },
    );
  });

  group('normalize — explicit match_failed status', () {
    test('match_failed_fallback_filtered clears matched distance', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'match_failed_fallback_filtered',
          matchedDistanceKm: 9.9,
          routeMatchConfidence: 0.95,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });

    test(
      'failure status wins even when status source was previously matched',
      () {
        final result = service.normalize(
          buildResult(
            routeMatchStatus: 'match_failed_fallback_filtered',
            routeDistanceSource: 'matched',
            matchedDistanceKm: 4.0,
          ),
        );

        expect(result.routeDistanceSource, 'filtered');
        expect(result.matchedDistanceKm, isNull);
      },
    );
  });

  group('normalize — confidence-based upgrade from unknown status', () {
    test(
      'confidence 0.95 with distance upgrades to high confidence / matched',
      () {
        final result = service.normalize(
          buildResult(
            routeMatchStatus: 'unknown',
            routeMatchConfidence: 0.95,
            matchedDistanceKm: 6.1,
          ),
        );

        expect(result.routeMatchStatus, 'matched_success_high_confidence');
        expect(result.routeDistanceSource, 'matched');
        expect(result.matchedDistanceKm, 6.1);
      },
    );

    test('exactly 0.9 confidence counts as high confidence (boundary)', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'pending',
          routeMatchConfidence: 0.9,
          matchedDistanceKm: 1.0,
        ),
      );

      expect(result.routeMatchStatus, 'matched_success_high_confidence');
      expect(result.routeDistanceSource, 'matched');
    });

    test('high confidence but zero distance degrades to medium confidence', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'unknown',
          routeMatchConfidence: 0.95,
          matchedDistanceKm: 0,
        ),
      );

      expect(result.routeMatchStatus, 'matched_success_medium_confidence');
      expect(result.routeDistanceSource, 'filtered_display_matched');
    });

    test('confidence 0.6 upgrades to medium confidence (boundary)', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'unknown',
          routeMatchConfidence: 0.6,
          matchedDistanceKm: 3.0,
        ),
      );

      expect(result.routeMatchStatus, 'matched_success_medium_confidence');
      expect(result.routeDistanceSource, 'filtered_display_matched');
    });

    test(
      'confidence just below 0.6 falls back to filtered and drops distance',
      () {
        final result = service.normalize(
          buildResult(
            routeMatchStatus: 'unknown',
            routeMatchConfidence: 0.59,
            matchedDistanceKm: 3.0,
          ),
        );

        expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
        expect(result.routeDistanceSource, 'filtered');
        expect(result.matchedDistanceKm, isNull);
      },
    );

    test('null confidence is treated as zero and falls back', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'unknown',
          routeMatchConfidence: null,
          matchedDistanceKm: 12.0,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });

    test(
      'confidence above 0.9 without distance is not promoted to matched',
      () {
        final result = service.normalize(
          buildResult(
            routeMatchStatus: 'unknown',
            routeMatchConfidence: 0.99,
            matchedDistanceKm: null,
          ),
        );

        expect(result.routeMatchStatus, 'matched_success_medium_confidence');
        expect(result.routeDistanceSource, 'filtered_display_matched');
        expect(result.matchedDistanceKm, isNull);
      },
    );

    test('confidence 0.0 with geometry falls back to filtered', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'unknown',
          routeMatchConfidence: 0.0,
          matchedDistanceKm: 2.2,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });

    test('empty status string takes the confidence-based default branch', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: '',
          routeMatchConfidence: 0.75,
          matchedDistanceKm: 4.4,
        ),
      );

      expect(result.routeMatchStatus, 'matched_success_medium_confidence');
      expect(result.routeDistanceSource, 'filtered_display_matched');
    });

    test('unrecognised status with low confidence falls back to filtered', () {
      final result = service.normalize(
        buildResult(
          routeMatchStatus: 'some_future_status',
          routeMatchConfidence: 0.2,
          matchedDistanceKm: 8.0,
        ),
      );

      expect(result.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
    });
  });

  group('normalize — fields preserved / immutability', () {
    test(
      'copyWith distinguishes omitted nullable fields from explicit null',
      () {
        final original = buildResult(
          routeMatchConfidence: 0.95,
          matchedDistanceKm: 5.5,
        );

        final unchanged = original.copyWith();
        final cleared = original.copyWith(
          routeMatchConfidence: null,
          matchedDistanceKm: null,
        );

        expect(unchanged.routeMatchConfidence, 0.95);
        expect(unchanged.matchedDistanceKm, 5.5);
        expect(cleared.routeMatchConfidence, isNull);
        expect(cleared.matchedDistanceKm, isNull);
      },
    );

    test('identity and unrelated fields survive the rewrite', () {
      final original = buildResult(
        sessionId: 'sess-42',
        routeMatchStatus: 'unknown',
        routeMatchConfidence: 0.97,
        matchedDistanceKm: 5.5,
        routeMatchMetricsJson: '{"matched_ratio":0.93}',
      );

      final result = service.normalize(original);

      expect(result.sessionId, 'sess-42');
      expect(result.matchedRouteJson, original.matchedRouteJson);
      expect(result.routeMatchMetricsJson, '{"matched_ratio":0.93}');
      expect(result.routeMatchConfidence, 0.97);
    });

    test('input entity is not mutated (copyWith semantics)', () {
      final original = buildResult(
        routeMatchStatus: 'matched_success_high_confidence',
        matchedDistanceKm: 11.0,
      );

      service.normalize(original);

      expect(original.routeDistanceSource, 'filtered');
      expect(original.matchedDistanceKm, 11.0);
    });

    test('normalize is idempotent — second pass changes nothing', () {
      final first = service.normalize(
        buildResult(
          routeMatchStatus: 'unknown',
          routeMatchConfidence: 0.93,
          matchedDistanceKm: 6.0,
        ),
      );

      final second = service.normalize(first);

      expect(second.routeMatchStatus, first.routeMatchStatus);
      expect(second.routeDistanceSource, first.routeDistanceSource);
      expect(second.matchedDistanceKm, first.matchedDistanceKm);
    });

    test('fallback result is stable when normalized again', () {
      final first = service.normalize(
        buildResult(
          routeMatchStatus: 'unknown',
          routeMatchConfidence: 0.1,
          matchedDistanceKm: 6.0,
        ),
      );

      final second = service.normalize(first);

      expect(second.routeMatchStatus, 'match_failed_fallback_filtered');
      expect(second.routeDistanceSource, 'filtered');
      expect(second.matchedDistanceKm, first.matchedDistanceKm);
    });

    test('service is usable as a const and across many calls', () {
      // Normalizing different inputs never leaks state between calls.
      final a = service.normalize(
        buildResult(routeMatchStatus: 'partial_match', matchedDistanceKm: 1.0),
      );
      final b = service.normalize(
        buildResult(matchedRouteJson: '', matchedDistanceKm: 1.0),
      );

      expect(a.routeDistanceSource, 'filtered_display_matched');
      expect(b.routeDistanceSource, 'filtered');
    });
  });
}
