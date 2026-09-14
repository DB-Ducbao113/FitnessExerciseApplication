import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cyber Dark Globe Loading Screen / Màn hình loading quả địa cầu công nghệ
class AetronGlobeOrbitScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;
  final String? customTitle;
  final String? customSubtitle;

  const AetronGlobeOrbitScreen({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 3600),
    this.customTitle,
    this.customSubtitle,
  });

  @override
  ConsumerState<AetronGlobeOrbitScreen> createState() =>
      _AetronGlobeOrbitScreenState();
}

class _AetronGlobeOrbitScreenState extends ConsumerState<AetronGlobeOrbitScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed) {
          _completed = true;
          if (widget.onComplete != null) {
            Future<void>.delayed(const Duration(milliseconds: 180), () {
              if (mounted) widget.onComplete!();
            });
          }
        }
      });

    if (widget.onComplete != null) {
      _controller.forward();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final progress = _controller.value;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // 1. Ambient Cosmic Cyan Radial Background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 1.25,
                  colors: const [
                    Color(0xFF0D213F),
                    Color(0xFF081222),
                    Color(0xFF04070E),
                  ],
                ),
              ),
            ),
          ),

          // 2. Center Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // ── 3D Cyber Earth Globe with Orbital Telemetry ──
                    SizedBox.square(
                      dimension: 300,
                      child: CustomPaint(
                        painter: _CyberGlobePainter(progress: progress),
                      ),
                    ),
                    const SizedBox(height: 38),

                    // ── Brand Title & Slogan ────────────────────────────────
                    Text(
                      widget.customTitle ?? "Aetron",
                      style: const TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Color(0x6600E5FF),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.customSubtitle ??
                          (isVi
                              ? "Từng bước chân kiến tạo hành trình"
                              : "Every step tracks your journey"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: "Outfit",
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.2,
                      ),
                    ),

                    const Spacer(flex: 3),

                    // ── Subtle Neon Cyan Progress Pill ──────────────────────
                    if (widget.onComplete != null)
                      Container(
                        width: 130,
                        height: 4.0,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131F33),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00E5FF),
                                  Color(0xFF2AF598),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x8800E5FF),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pure 3D Cyber Earth Globe with Atmospheric Glow, Rotating Continents & Orbital Telemetry
class _CyberGlobePainter extends CustomPainter {
  final double progress;

  const _CyberGlobePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final globeRadius = size.width * 0.28; // ~84px
    final orbitRadiusX = size.width * 0.44; // ~132px
    final orbitRadiusY = size.width * 0.22; // ~66px (tilted orbital plane)
    final orbitTilt = -math.pi / 7.5; // ~ -24 degrees

    // Current rotation of Earth (0 to 2*pi)
    final earthRotation = progress * 2 * math.pi;

    // ── 0. Distant Cosmic Starfield / Data Particles ────────────────────────
    _drawStarfield(canvas, center, size, progress);

    // ── 1. Deep Space Atmospheric Nebula Glow (Behind Globe) ────────────────
    canvas.drawCircle(
      center,
      globeRadius + 32,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    canvas.drawCircle(
      center,
      globeRadius + 14,
      Paint()
        ..color = const Color(0xFF2AF598).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // ── 2. Back Half of Tilted Orbital Telemetry Track ──────────────────────
    _drawOrbitTrack(
      canvas: canvas,
      center: center,
      radiusX: orbitRadiusX,
      radiusY: orbitRadiusY,
      tilt: orbitTilt,
      isFrontHalf: false,
    );

    // ── 3. Cyber Earth Sphere Base (Obsidian Ocean with 3D Spherical Shader) ─
    final globeRect = Rect.fromCircle(center: center, radius: globeRadius);

    // Outer Globe Rim Glow (Pre-clip)
    canvas.drawCircle(
      center,
      globeRadius + 1.5,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Clip to Globe Sphere for all surface rendering
    canvas.save();
    canvas.clipPath(
      Path()..addOval(globeRect),
    );

    // 3a. Deep Ocean 3D Gradient
    final oceanPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.95,
        colors: const [
          Color(0xFF132F52), // Top-left illuminated deep cyber blue
          Color(0xFF0B1B33), // Mid tone ocean
          Color(0xFF050B16), // Dark side of Earth
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(globeRect);
    canvas.drawRect(globeRect, oceanPaint);

    // 3b. Latitude Grid Lines (Parallels)
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.16)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    final equatorPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.30)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const latAngles = [-60.0, -40.0, -20.0, 0.0, 20.0, 40.0, 60.0];
    for (final lat in latAngles) {
      final yOffset = -math.sin(lat * math.pi / 180) * globeRadius;
      final rSlice = math.cos(lat * math.pi / 180) * globeRadius;
      final rect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + yOffset),
        width: rSlice * 2,
        height: rSlice * 0.38,
      );
      canvas.drawOval(rect, lat == 0.0 ? equatorPaint : gridPaint);
    }

    // 3c. Longitude Meridians (Rotating seamlessly with Earth)
    const meridianCount = 12;
    for (var i = 0; i < meridianCount; i++) {
      final angle = earthRotation + (i * math.pi / (meridianCount / 2));
      final cosA = math.cos(angle);
      final isFacingFront = cosA > 0;

      final meridianPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(
          alpha: isFacingFront ? (0.08 + 0.14 * cosA) : 0.04,
        )
        ..strokeWidth = isFacingFront ? 1.0 : 0.6
        ..style = PaintingStyle.stroke;

      final rect = Rect.fromCenter(
        center: center,
        width: globeRadius * 2 * cosA.abs(),
        height: globeRadius * 2,
      );
      canvas.drawOval(rect, meridianPaint);
    }

    // 3d. 3D Rotating Continents (Orthographic Mathematical Projection)
    _drawContinents(canvas, center, globeRadius, earthRotation);

    // 3e. Atmospheric Rim Light & Specular 3D Lighting Overlay
    final specularPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.55, -0.55),
        radius: 0.75,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          const Color(0xFF00E5FF).withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(globeRect);
    canvas.drawRect(globeRect, specularPaint);

    // Dark Terminator Shadow on Night Side (Bottom-Right)
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.65, 0.65),
        radius: 0.85,
        colors: [
          Colors.black.withValues(alpha: 0.65),
          Colors.black.withValues(alpha: 0.30),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(globeRect);
    canvas.drawRect(globeRect, shadowPaint);

    canvas.restore(); // End Globe Clip

    // ── 4. Front Atmospheric Crescent Rim (Gives Crisp Optical Depth) ────────
    canvas.drawArc(
      globeRect,
      math.pi * 0.95,
      math.pi * 0.85,
      false,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.65)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
    );

    // ── 5. Front Half of Tilted Orbital Telemetry Track & GPS Satellite Beacon
    _drawOrbitTrack(
      canvas: canvas,
      center: center,
      radiusX: orbitRadiusX,
      radiusY: orbitRadiusY,
      tilt: orbitTilt,
      isFrontHalf: true,
    );

    // ── 6. Luminous Orbiting GPS Telemetry Beacon / Satellite Pulse ─────────
    _drawOrbitBeacon(
      canvas: canvas,
      center: center,
      radiusX: orbitRadiusX,
      radiusY: orbitRadiusY,
      tilt: orbitTilt,
      progress: progress,
    );
  }

  /// Draw realistic rotating continental landmasses with high cyber fidelity
  void _drawContinents(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
  ) {
    // Landmass Polygons defined in [latitude, longitude] degrees
    final continents = <List<List<double>>>[
      // North America
      [
        [70, -165], [72, -120], [70, -75], [58, -55], [45, -60],
        [30, -80], [25, -80], [18, -96], [12, -85], [16, -93],
        [28, -112], [38, -123], [50, -126], [60, -140], [65, -168]
      ],
      // South America
      [
        [12, -75], [8, -52], [-5, -35], [-22, -40], [-40, -62],
        [-54, -68], [-52, -75], [-35, -73], [-18, -71], [-4, -80], [8, -78]
      ],
      // Eurasia (Europe + Asia)
      [
        [70, 25], [75, 60], [75, 110], [70, 168], [60, 160],
        [45, 140], [35, 120], [22, 115], [10, 105], [15, 100],
        [22, 88], [10, 78], [25, 65], [25, 55], [15, 45],
        [30, 32], [36, 28], [38, -8], [55, -5], [60, 5], [70, 25]
      ],
      // Africa
      [
        [35, -5], [37, 10], [32, 32], [12, 44], [12, 51],
        [0, 42], [-15, 40], [-28, 32], [-34, 18], [-34, 26],
        [-18, 12], [5, 9], [5, -5], [15, -17], [25, -15], [35, -5]
      ],
      // Australia
      [
        [-12, 130], [-12, 136], [-18, 146], [-28, 153], [-38, 148],
        [-38, 140], [-35, 115], [-22, 114], [-15, 124]
      ],
      // Greenland
      [
        [80, -40], [70, -20], [60, -45], [70, -55], [80, -40]
      ],
      // Southeast Asia Islands & Japan archipelago
      [
        [45, 142], [36, 140], [33, 130], [38, 138]
      ],
      [
        [5, 115], [0, 102], [-8, 115], [-2, 120], [5, 115]
      ],
    ];

    for (final continent in continents) {
      final path = Path();
      var isFirst = true;
      var hasVisiblePoint = false;

      for (final pt in continent) {
        final lat = pt[0] * math.pi / 180;
        final lon = (pt[1] * math.pi / 180) + rotation;

        // 3D Spherical Orthographic Projection
        final cosLat = math.cos(lat);
        final sinLat = math.sin(lat);
        final cosLon = math.cos(lon);
        final sinLon = math.sin(lon);

        final z = cosLat * cosLon; // Facing camera when z > 0

        final x = center.dx + (radius * cosLat * sinLon);
        final y = center.dy - (radius * sinLat);

        if (z > -0.15) {
          hasVisiblePoint = true;
          if (isFirst) {
            path.moveTo(x, y);
            isFirst = false;
          } else {
            path.lineTo(x, y);
          }
        }
      }

      if (hasVisiblePoint && !isFirst) {
        path.close();

        // 1. Glowing Landmass Base Fill (Cyber Emerald / Mint)
        final landFillPaint = Paint()
          ..color = const Color(0xFF2AF598).withValues(alpha: 0.38)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, landFillPaint);

        // 2. High-Tech Bright Cyan Coastline Contour
        final coastPaint = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.75)
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, coastPaint);
      }
    }
  }

  /// Draws 3D tilted orbital route (split into back and front halves for proper occlusion)
  void _drawOrbitTrack({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double tilt,
    required bool isFrontHalf,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);

    final trackPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: isFrontHalf ? 0.35 : 0.12)
      ..strokeWidth = isFrontHalf ? 1.4 : 0.8
      ..style = PaintingStyle.stroke;

    final outerGuidePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: isFrontHalf ? 0.15 : 0.06)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final orbitRect = Rect.fromCenter(
      center: Offset.zero,
      width: radiusX * 2,
      height: radiusY * 2,
    );

    final outerOrbitRect = Rect.fromCenter(
      center: Offset.zero,
      width: (radiusX + 9) * 2,
      height: (radiusY + 5) * 2,
    );

    // Draw either front half (y > 0) or back half (y < 0) in rotated space
    final startAngle = isFrontHalf ? 0.0 : math.pi;
    final sweepAngle = isFrontHalf ? math.pi : math.pi;

    // Outer subtle guide line
    canvas.drawArc(outerOrbitRect, startAngle, sweepAngle, false, outerGuidePaint);

    // Dashed GPS Orbital Route
    const segments = 24;
    final segAngle = math.pi / segments;
    for (var i = 0; i < segments; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          orbitRect,
          startAngle + (i * segAngle),
          segAngle * 0.75,
          false,
          trackPaint,
        );
      }
    }

    canvas.restore();
  }

  /// Draws high-precision GPS satellite beacon orbiting smoothly around the globe
  void _drawOrbitBeacon({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double tilt,
    required double progress,
  }) {
    // Current beacon orbital angle
    final orbitAngle = progress * 2 * math.pi;

    // Position in orbital plane
    final localX = radiusX * math.cos(orbitAngle);
    final localY = radiusY * math.sin(orbitAngle);

    // Rotate by tilt
    final cosT = math.cos(tilt);
    final sinT = math.sin(tilt);

    final beaconX = center.dx + (localX * cosT - localY * sinT);
    final beaconY = center.dy + (localX * sinT + localY * cosT);
    final beaconPos = Offset(beaconX, beaconY);

    // Only render full beacon when in front or semi-visible
    final isFront = localY >= -radiusY * 0.4;
    final opacity = isFront ? 1.0 : 0.35;

    // 1. Glowing Trail Arc behind Beacon
    const trailCount = 14;
    for (var i = 1; i <= trailCount; i++) {
      final trailProgress = orbitAngle - (i * 0.035);
      final tX = radiusX * math.cos(trailProgress);
      final tY = radiusY * math.sin(trailProgress);
      final ptX = center.dx + (tX * cosT - tY * sinT);
      final ptY = center.dy + (tX * sinT + tY * cosT);

      final trailAlpha = (1.0 - (i / trailCount)) * 0.65 * opacity;
      final trailRadius = (3.2 - (i * 0.18)).clamp(0.8, 3.2);

      canvas.drawCircle(
        Offset(ptX, ptY),
        trailRadius,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: trailAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    // 2. Telemetry Beacon Radar Pulse Rings
    final pulseScale = (progress * 4) % 1.0;
    final pulseRadius = 5.0 + (pulseScale * 14.0);
    final pulseAlpha = (1.0 - pulseScale) * 0.7 * opacity;

    canvas.drawCircle(
      beaconPos,
      pulseRadius,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 3. Glowing Satellite Beacon Head
    // Outer Neon Halo
    canvas.drawCircle(
      beaconPos,
      8.0,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Core Cyan Bead
    canvas.drawCircle(
      beaconPos,
      4.2,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.95 * opacity)
        ..style = PaintingStyle.fill,
    );

    // Crisp Pure White Center Point
    canvas.drawCircle(
      beaconPos,
      2.0,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill,
    );
  }

  /// Ambient background starfield & data twinkles
  void _drawStarfield(Canvas canvas, Offset center, Size size, double progress) {
    final stars = [
      [-110.0, -100.0, 1.4, 0.4],
      [120.0, -90.0, 1.2, 0.5],
      [-125.0, 80.0, 1.6, 0.3],
      [115.0, 95.0, 1.3, 0.45],
      [-80.0, -125.0, 1.1, 0.35],
      [90.0, -120.0, 1.5, 0.55],
      [-130.0, -20.0, 1.0, 0.25],
      [135.0, 30.0, 1.4, 0.4],
      [0.0, -135.0, 1.2, 0.5],
      [-50.0, 130.0, 1.3, 0.3],
      [60.0, 125.0, 1.5, 0.45],
    ];

    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      final twinkle = math.sin((progress * math.pi * 4) + i);
      final alpha = (s[3] + (twinkle * 0.2)).clamp(0.1, 0.85);

      canvas.drawCircle(
        Offset(center.dx + s[0], center.dy + s[1]),
        s[2],
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGlobePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
