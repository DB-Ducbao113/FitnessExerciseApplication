class RouteMatchResult {
  static const _notProvided = Object();

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
    Object? routeMatchConfidence = _notProvided,
    String? routeDistanceSource,
    Object? matchedDistanceKm = _notProvided,
    String? routeMatchMetricsJson,
  }) {
    return RouteMatchResult(
      sessionId: sessionId ?? this.sessionId,
      matchedRouteJson: matchedRouteJson ?? this.matchedRouteJson,
      routeMatchStatus: routeMatchStatus ?? this.routeMatchStatus,
      routeMatchConfidence: identical(routeMatchConfidence, _notProvided)
          ? this.routeMatchConfidence
          : routeMatchConfidence as double?,
      routeDistanceSource: routeDistanceSource ?? this.routeDistanceSource,
      matchedDistanceKm: identical(matchedDistanceKm, _notProvided)
          ? this.matchedDistanceKm
          : matchedDistanceKm as double?,
      routeMatchMetricsJson:
          routeMatchMetricsJson ?? this.routeMatchMetricsJson,
    );
  }
}
