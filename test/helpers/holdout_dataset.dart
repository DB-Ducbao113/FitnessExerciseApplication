import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

/// Route definition for holdout validation.
class HoldoutRoute {
  final String id;
  final String name;
  final String description;
  final List<LatLng> vertices;
  final double defaultSpeedMs;
  final bool hasStopAndGo;

  const HoldoutRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.vertices,
    required this.defaultSpeedMs,
    this.hasStopAndGo = false,
  });

  double get totalLengthMeters {
    double d = 0;
    for (int i = 1; i < vertices.length; i++) {
      d += _distance.distance(vertices[i - 1], vertices[i]);
    }
    return d;
  }

  /// Interpolates position, bearing, and turn indicator along route.
  (LatLng, double, bool) interpolate(double distAlongRoute) {
    final totalDist = totalLengthMeters;
    if (totalDist == 0) return (vertices.first, 0.0, false);
    var remaining = distAlongRoute % totalDist;

    for (int i = 1; i < vertices.length; i++) {
      final segLen = _distance.distance(vertices[i - 1], vertices[i]);
      if (remaining <= segLen || i == vertices.length - 1) {
        final frac = segLen > 0 ? (remaining / segLen).clamp(0.0, 1.0) : 0.0;
        final lat = vertices[i - 1].latitude +
            frac * (vertices[i].latitude - vertices[i - 1].latitude);
        final lng = vertices[i - 1].longitude +
            frac * (vertices[i].longitude - vertices[i - 1].longitude);
        final bearing = _distance.bearing(vertices[i - 1], vertices[i]);
        final prevBearing =
            i > 1 ? _distance.bearing(vertices[i - 2], vertices[i - 1]) : bearing;
        final turnAngle = (bearing - prevBearing).abs();
        final isTurn = turnAngle > 10.0 && turnAngle < 350.0;
        return (LatLng(lat, lng), bearing, isTurn);
      }
      remaining -= segLen;
    }
    return (vertices.first, 0.0, false);
  }
}

/// Catalog of genuinely independent holdout routes in Da Nang, Vietnam.
///
/// Completely disjoint geographically from the canonical Ho Chi Minh City route (10.738, 106.625).
class HoldoutRouteCatalog {
  /// Route 1: Coastal Straight Highway (Da Nang Vo Nguyen Giap / My Khe)
  /// Features long 2.7 km straightaways to evaluate longitudinal stability, zero turn false triggers.
  static final HoldoutRoute routeAStraightHighway = HoldoutRoute(
    id: 'RouteA_StraightHighway',
    name: 'Coastal Straight Highway',
    description: 'Long straight coastal avenue with gentle turnaround; tests velocity convergence and straightaways',
    defaultSpeedMs: 6.94, // 25 km/h (cycling / steady run)
    vertices: const [
      LatLng(16.060000, 108.245000),
      LatLng(16.068000, 108.245500),
      LatLng(16.076000, 108.246000),
      LatLng(16.084000, 108.246500),
      LatLng(16.084600, 108.247200), // turnaround curve
      LatLng(16.084300, 108.247800),
      LatLng(16.076500, 108.247500), // return straight
      LatLng(16.068500, 108.247000),
      LatLng(16.060000, 108.245000),
    ],
  );

  /// Route 2: Mountain Hairpin Switchbacks (Hai Van Pass style)
  /// Features repeated 120°–165° sharp switchbacks every 70–120m to evaluate turn undercount restoration.
  static final HoldoutRoute routeBHairpins = HoldoutRoute(
    id: 'RouteB_Hairpins',
    name: 'Mountain Hairpin Switchbacks',
    description: 'Steep mountain switchbacks with repeated 120-165 degree sharp hairpins every 70-120m',
    defaultSpeedMs: 4.17, // 15 km/h (hill run)
    vertices: const [
      LatLng(16.185000, 108.132000),
      LatLng(16.185800, 108.133200),
      LatLng(16.185200, 108.133800), // Hairpin 1 (~150 deg)
      LatLng(16.186200, 108.134900),
      LatLng(16.185600, 108.135600), // Hairpin 2 (~160 deg)
      LatLng(16.186600, 108.136800),
      LatLng(16.186000, 108.137500), // Hairpin 3 (~150 deg)
      LatLng(16.187000, 108.138700),
      LatLng(16.186300, 108.139400), // Hairpin 4 (~160 deg)
      LatLng(16.187300, 108.140600),
      LatLng(16.186500, 108.141300), // Hairpin 5 (~165 deg)
      LatLng(16.187500, 108.142500),
      LatLng(16.186700, 108.143200), // Hairpin 6 (~160 deg)
      LatLng(16.185000, 108.132000), // return loop
    ],
  );

  /// Route 3: Urban Orthogonal Grid with Stop-and-Go Dwells (City Center)
  /// Features 90° corners every 120m and scheduled stationary periods (traffic stops).
  static final HoldoutRoute routeCUrbanGrid = HoldoutRoute(
    id: 'RouteC_UrbanGrid',
    name: 'Urban Grid with Stop-and-Go',
    description: 'Orthogonal street grid with frequent 90-degree corners and 30-second stationary dwell periods',
    defaultSpeedMs: 2.50, // 9 km/h (jogging with stops)
    hasStopAndGo: true,
    vertices: const [
      LatLng(16.065000, 108.215000),
      LatLng(16.066200, 108.215000), // North 133m
      LatLng(16.066200, 108.216200), // East 128m (90 right)
      LatLng(16.065000, 108.216200), // South 133m (90 right)
      LatLng(16.065000, 108.217400), // East 128m (90 left)
      LatLng(16.066200, 108.217400), // North 133m (90 left)
      LatLng(16.066200, 108.218600), // East 128m (90 right)
      LatLng(16.065000, 108.218600), // South 133m (90 right)
      LatLng(16.063800, 108.218600), // South 133m
      LatLng(16.063800, 108.217400), // West 128m (90 right)
      LatLng(16.063800, 108.216200), // West 128m
      LatLng(16.063800, 108.215000), // West 128m
      LatLng(16.065000, 108.215000), // North 133m (close loop)
    ],
  );

  /// Route 4: Figure-8 Self-Intersecting Loop (Sports Complex)
  /// Two smooth circular lobes crossing at center node; tests self-intersections and continuous curvature.
  static final HoldoutRoute routeDFigureEight = HoldoutRoute(
    id: 'RouteD_FigureEight',
    name: 'Figure-8 Athletic Loop',
    description: 'Smooth continuous double-lobed figure-8 crossing at central intersection node',
    defaultSpeedMs: 4.17, // 15 km/h
    vertices: _generateFigureEightVertices(
      center: const LatLng(16.040000, 108.220000),
      radiusMeters: 250.0,
      pointsPerLobe: 12,
    ),
  );

  static List<LatLng> _generateFigureEightVertices({
    required LatLng center,
    required double radiusMeters,
    required int pointsPerLobe,
  }) {
    final list = <LatLng>[];
    // North lobe (clockwise)
    for (int i = 0; i < pointsPerLobe; i++) {
      final theta = 2.0 * math.pi * i / pointsPerLobe;
      final northOffset = radiusMeters * (1.0 - math.cos(theta));
      final eastOffset = radiusMeters * math.sin(theta);
      list.add(_distance.offset(_distance.offset(center, eastOffset, 90.0), northOffset, 0.0));
    }
    // South lobe (counter-clockwise)
    for (int i = 0; i < pointsPerLobe; i++) {
      final theta = 2.0 * math.pi * i / pointsPerLobe;
      final southOffset = radiusMeters * (1.0 - math.cos(theta));
      final eastOffset = -radiusMeters * math.sin(theta);
      list.add(_distance.offset(_distance.offset(center, eastOffset, 90.0), -southOffset, 0.0));
    }
    list.add(list.first);
    return list;
  }

  static List<HoldoutRoute> get allRoutes => [
        routeAStraightHighway,
        routeBHairpins,
        routeCUrbanGrid,
        routeDFigureEight,
      ];
}

/// Holdout noise and impairment profile.
class HoldoutNoiseProfile {
  final String id;
  final String name;
  final double baseNoise;
  final double accMean;
  final bool hasHeadingDropout;
  final bool hasPeriodicMultipathBursts;
  final bool hasSustainedOutage;

  const HoldoutNoiseProfile({
    required this.id,
    required this.name,
    required this.baseNoise,
    required this.accMean,
    this.hasHeadingDropout = false,
    this.hasPeriodicMultipathBursts = false,
    this.hasSustainedOutage = false,
  });

  static const lowOpenSky = HoldoutNoiseProfile(
    id: 'Holdout_Low',
    name: 'Holdout Low (Open Sky)',
    baseNoise: 2.2,
    accMean: 3.8,
  );

  static const urbanMultipath = HoldoutNoiseProfile(
    id: 'Holdout_UrbanMultipath',
    name: 'Holdout Urban Multipath',
    baseNoise: 6.2,
    accMean: 8.8,
    hasPeriodicMultipathBursts: true,
  );

  static const severeCanyonOutage = HoldoutNoiseProfile(
    id: 'Holdout_SevereCanyonOutage',
    name: 'Holdout Severe Canyon (Heading Dropout + 30s Outage)',
    baseNoise: 8.8,
    accMean: 12.5,
    hasHeadingDropout: true,
    hasSustainedOutage: true,
  );

  static List<HoldoutNoiseProfile> get allProfiles => [
        lowOpenSky,
        urbanMultipath,
        severeCanyonOutage,
      ];
}

/// Sampling rate definition.
class HoldoutSamplingRate {
  final String name;
  final double dt;

  const HoldoutSamplingRate({required this.name, required this.dt});

  static const r05Hz = HoldoutSamplingRate(name: '0.5 Hz (dt=2.0s)', dt: 2.0);
  static const r10Hz = HoldoutSamplingRate(name: '1.0 Hz (dt=1.0s)', dt: 1.0);
  static const r20Hz = HoldoutSamplingRate(name: '2.0 Hz (dt=0.5s)', dt: 0.5);

  static List<HoldoutSamplingRate> get allRates => [r05Hz, r10Hz, r20Hz];
}
