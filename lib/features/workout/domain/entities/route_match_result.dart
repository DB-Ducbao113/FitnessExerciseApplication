class RouteMatchResult {
  final String sessionId;
  final String matchedRouteJson;
  final String routeMatchStatus;
  final double? routeMatchConfidence;
  final String routeDistanceSource;
  final double? matchedDistanceKm;
  final String routeMatchMetricsJson;

  const RouteMatchResult({
    required this.sessionId,
    required this.matchedRouteJson,
    required this.routeMatchStatus,
    required this.routeDistanceSource,
    required this.routeMatchMetricsJson,
    this.routeMatchConfidence,
    this.matchedDistanceKm,
  });

  RouteMatchResult copyWith({
    String? sessionId,
    String? matchedRouteJson,
    String? routeMatchStatus,
    double? routeMatchConfidence,
    String? routeDistanceSource,
    double? matchedDistanceKm,
    String? routeMatchMetricsJson,
  }) {
    return RouteMatchResult(
      sessionId: sessionId ?? this.sessionId,
      matchedRouteJson: matchedRouteJson ?? this.matchedRouteJson,
      routeMatchStatus: routeMatchStatus ?? this.routeMatchStatus,
      routeMatchConfidence: routeMatchConfidence ?? this.routeMatchConfidence,
      routeDistanceSource: routeDistanceSource ?? this.routeDistanceSource,
      matchedDistanceKm: matchedDistanceKm ?? this.matchedDistanceKm,
      routeMatchMetricsJson:
          routeMatchMetricsJson ?? this.routeMatchMetricsJson,
    );
  }
}
