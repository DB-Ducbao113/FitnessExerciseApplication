import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kinetic 3D Globe Orbit Screen / Màn hình visualizer địa cầu 3D Kinetic
class AetronGlobeOrbitScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;
  final String? customTitle;
  final String? customSubtitle;
  final bool showCloseButton;
  final String? statusPillText;

  const AetronGlobeOrbitScreen({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 3600),
    this.customTitle,
    this.customSubtitle,
    this.showCloseButton = false,
    this.statusPillText,
  });

  @override
  ConsumerState<AetronGlobeOrbitScreen> createState() =>
      _AetronGlobeOrbitScreenState();
}

class _AetronGlobeOrbitScreenState extends ConsumerState<AetronGlobeOrbitScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;
  double _userRotationOffset = 0.0;

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
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final progress = _controller.value;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // 1. Ambient Radial Glow Background aligned with Kinetic palette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 1.35,
                  colors: [
                    colors.primary.withValues(alpha: 0.12),
                    colors.surface1.withValues(alpha: 0.5),
                    colors.background,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 2. Safe Area Interactive Content
          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar (Back/Close button if navigated into)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (canPop && widget.showCloseButton)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.surface2.withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 40),

                      // Orbit Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface2.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: 0.7),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.statusPillText ??
                                  (isVi ? 'ĐANG TẢI DỮ LIỆU' : 'LOADING DATA'),
                              style: KineticTypography.unitLabel.copyWith(
                                color: colors.primary,
                                fontSize: 10.5,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // ── Interactive 3D Cyber Earth Globe with Orbital Telemetry ──
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _userRotationOffset -= details.primaryDelta! / 85.0;
                    });
                  },
                  child: SizedBox.square(
                    dimension: 310,
                    child: CustomPaint(
                      painter: _CyberGlobePainter(
                        progress: progress,
                        userRotation: _userRotationOffset,
                        colors: colors,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Brand Title & Slogan (Kinetic Typography) ────────────────
                Text(
                  widget.customTitle ?? "Aetron",
                  style: KineticTypography.headlineLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: colors.primary.withValues(alpha: 0.5),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.customSubtitle ??
                        (isVi
                            ? "Đang đồng bộ dữ liệu..."
                            : "Synchronizing system data..."),
                    textAlign: TextAlign.center,
                    style: KineticTypography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Live Telemetry Chips ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.satellite_alt_rounded,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isVi ? '12 VỆ TINH GPS' : '12 GPS SATS',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.primary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_tethering_rounded,
                            size: 13,
                            color: colors.secondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isVi ? 'ĐỘ CAO 20,200 KM' : 'ALT 20,200 KM',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.secondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // ── Kinetic Glowing Progress Pill (determinate or indeterminate) ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: widget.onComplete != null
                      ? Container(
                          width: 160,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: colors.surface2,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.secondary, colors.primary],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: 0.7),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: 160,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: colors.surface2,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final barWidth = constraints.maxWidth;
                              final pillWidth = barWidth * 0.45;
                              final offset = (barWidth + pillWidth) * progress - pillWidth;
                              return Stack(
                                children: [
                                  Positioned(
                                    left: offset,
                                    top: 0,
                                    bottom: 0,
                                    width: pillWidth,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            colors.secondary.withValues(alpha: 0.3),
                                            colors.primary,
                                            colors.secondary.withValues(alpha: 0.3),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.primary.withValues(alpha: 0.8),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pure 3D Kinetic Earth Globe with Atmospheric Glow, Rotating Continents & Orbital Telemetry
class _CyberGlobePainter extends CustomPainter {
  final double progress;
  final double userRotation;
  final KineticColors colors;

  const _CyberGlobePainter({
    required this.progress,
    required this.userRotation,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final globeRadius = size.width * 0.28; // ~86px
    final orbitRadiusX = size.width * 0.44; // ~136px
    final orbitRadiusY = size.width * 0.22; // ~68px (tilted orbital plane)
    final orbitTilt = -math.pi / 7.5; // ~ -24 degrees

    // Current rotation of Earth (auto animation + touch user offset)
    final earthRotation = (progress * 2 * math.pi) + userRotation;

    // ── 0. Distant Cosmic Starfield / Data Particles ────────────────────────
    _drawStarfield(canvas, center, size, progress);

    // ── 1. Atmospheric Nebula Glow (Behind Globe) ───────────────────────────
    canvas.drawCircle(
      center,
      globeRadius + 32,
      Paint()
        ..color = colors.primary.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    canvas.drawCircle(
      center,
      globeRadius + 14,
      Paint()
        ..color = colors.secondary.withValues(alpha: 0.18)
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
        ..color = colors.primary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Clip to Globe Sphere for all surface rendering
    canvas.save();
    canvas.clipPath(
      Path()..addOval(globeRect),
    );

    // 3a. Deep Ocean 3D Gradient matching Kinetic Dark tones
    final oceanPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.95,
        colors: [
          colors.surface2,
          colors.surface1,
          colors.background,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(globeRect);
    canvas.drawRect(globeRect, oceanPaint);

    // 3b. Latitude Grid Lines (Parallels)
    final gridPaint = Paint()
      ..color = colors.primary.withValues(alpha: 0.18)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    final equatorPaint = Paint()
      ..color = colors.secondary.withValues(alpha: 0.35)
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
        ..color = colors.primary.withValues(
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
          colors.primary.withValues(alpha: 0.12),
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
          colors.background.withValues(alpha: 0.75),
          colors.background.withValues(alpha: 0.35),
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
        ..color = colors.primary.withValues(alpha: 0.65)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
    );

    // ── 5. Front Half of Tilted Orbital Telemetry Track ─────────────────────
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

  /// Draw realistic rotating continental landmasses with Kinetic styling
  void _drawContinents(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
  ) {
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

        // 1. Glowing Landmass Base Fill (Secondary kinetic mint)
        final landFillPaint = Paint()
          ..color = colors.secondary.withValues(alpha: 0.28)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, landFillPaint);

        // 2. High-Tech Kinetic Primary Coastline Contour
        final coastPaint = Paint()
          ..color = colors.primary.withValues(alpha: 0.85)
          ..strokeWidth = 1.15
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, coastPaint);
      }
    }
  }

  /// Draws 3D tilted orbital route
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
      ..color = colors.primary.withValues(alpha: isFrontHalf ? 0.40 : 0.14)
      ..strokeWidth = isFrontHalf ? 1.4 : 0.8
      ..style = PaintingStyle.stroke;

    final outerGuidePaint = Paint()
      ..color = colors.primary.withValues(alpha: isFrontHalf ? 0.18 : 0.06)
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

    final startAngle = isFrontHalf ? 0.0 : math.pi;
    final sweepAngle = isFrontHalf ? math.pi : math.pi;

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
    final orbitAngle = progress * 2 * math.pi;
    final localX = radiusX * math.cos(orbitAngle);
    final localY = radiusY * math.sin(orbitAngle);

    final cosT = math.cos(tilt);
    final sinT = math.sin(tilt);

    final beaconX = center.dx + (localX * cosT - localY * sinT);
    final beaconY = center.dy + (localX * sinT + localY * cosT);
    final beaconPos = Offset(beaconX, beaconY);

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

      final trailAlpha = (1.0 - (i / trailCount)) * 0.70 * opacity;
      final trailRadius = (3.2 - (i * 0.18)).clamp(0.8, 3.2);

      canvas.drawCircle(
        Offset(ptX, ptY),
        trailRadius,
        Paint()
          ..color = colors.primary.withValues(alpha: trailAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    // 2. Telemetry Beacon Radar Pulse Rings
    final pulseScale = (progress * 4) % 1.0;
    final pulseRadius = 5.0 + (pulseScale * 14.0);
    final pulseAlpha = (1.0 - pulseScale) * 0.75 * opacity;

    canvas.drawCircle(
      beaconPos,
      pulseRadius,
      Paint()
        ..color = colors.secondary.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 3. Glowing Satellite Beacon Head
    // Outer Neon Halo
    canvas.drawCircle(
      beaconPos,
      8.0,
      Paint()
        ..color = colors.primary.withValues(alpha: 0.40 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Core Cyan Bead
    canvas.drawCircle(
      beaconPos,
      4.2,
      Paint()
        ..color = colors.primary.withValues(alpha: 0.95 * opacity)
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
          ..color = colors.primary.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGlobePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.userRotation != userRotation ||
      oldDelegate.colors != colors;
}
