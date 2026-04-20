import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';

class RouteMatchQualityService {
  const RouteMatchQualityService();

  RouteMatchResult normalize(RouteMatchResult result) {
    final hasMatchedGeometry =
        result.matchedRouteJson.isNotEmpty && result.matchedRouteJson != '[]';

    if (!hasMatchedGeometry) {
      return result.copyWith(
        routeMatchStatus: 'match_failed_fallback_filtered',
        routeDistanceSource: 'filtered',
        matchedDistanceKm: null,
      );
    }

    switch (result.routeMatchStatus) {
      case 'matched_success_high_confidence':
        if ((result.matchedDistanceKm ?? 0) > 0) {
          return result.copyWith(routeDistanceSource: 'matched');
        }
        return result.copyWith(routeDistanceSource: 'filtered_display_matched');
      case 'matched_success_medium_confidence':
      case 'partial_match':
        return result.copyWith(routeDistanceSource: 'filtered_display_matched');
      case 'match_failed_fallback_filtered':
        return result.copyWith(
          routeDistanceSource: 'filtered',
          matchedDistanceKm: null,
        );
      default:
        final confidence = result.routeMatchConfidence ?? 0;
        if (confidence >= 0.9 && (result.matchedDistanceKm ?? 0) > 0) {
          return result.copyWith(
            routeMatchStatus: 'matched_success_high_confidence',
            routeDistanceSource: 'matched',
          );
        }
        if (confidence >= 0.6) {
          return result.copyWith(
            routeMatchStatus: 'matched_success_medium_confidence',
            routeDistanceSource: 'filtered_display_matched',
          );
        }
        return result.copyWith(
          routeMatchStatus: 'match_failed_fallback_filtered',
          routeDistanceSource: 'filtered',
          matchedDistanceKm: null,
        );
    }
  }
}
