import 'dart:math' as math;
import 'package:flutter/material.dart';

export 'app_badge.dart';
export 'app_button.dart';
export 'app_card.dart';
export 'app_progress_bar.dart';
export 'app_states.dart';
export 'app_text_field.dart';
export 'section_header.dart';
export 'stat_card.dart';

class AetronColors {
  const AetronColors._();

  // Core Palette
  static const voidBlack = Color(0xff0a0d1c);
  static const space = Color(0xff0f1321);
  static const panel = Color(0xff171b2a);
  static const panelHigh = Color(0xff1b1f2e);
  static const panelBright = Color(0xff303444);
  static const cyan = Color(0xff00e5ff);
  static const cyanDim = Color(0xff00daf3);
  static const cyanSoft = Color(0xffc3f5ff);
  static const blue = Color(0xff14d1ff);
  static const gold = Color(0xffffba20);
  static const mint = Color(0xff39f2b8);
  static const danger = Color(0xffff4f57);
  static const muted = Color(0xff7d8da6);
  static const text = Color(0xffdfe1f6);
  static const border = Color(0x3300e5ff);

  // Semantic Tokens
  static const primary = cyan;
  static const secondary = blue;
  static const background = voidBlack;
  static const surface = space;
  static const card = panel;
  static const cardElevated = panelHigh;
  static const textPrimary = text;
  static const textSecondary = muted;
  static const borderSubtle = Color(0x22ffffff);
  static const borderAccent = border;
  static const success = mint;
  static const warning = gold;
  static const error = danger;
  static const disabled = Color(0xff4a5568);
  static const workoutActive = mint;
}

class AetronSpacing {
  const AetronSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const page = 16.0;
  static const gutter = 12.0;
  static const cardRadius = 14.0;
  static const controlRadius = 12.0;
}

class AetronRadius {
  const AetronRadius._();

  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double extraLarge = 24.0;
  static const double pill = 999.0;
}

class AetronTypography {
  const AetronTypography._();

  static const display = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );

  static const headingLarge = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.cyanSoft,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
  );

  static const headingMedium = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  static const headingSmall = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.cyan,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  static const bodyLarge = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const body = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const bodySmall = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const caption = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );

  static const label = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  static const button = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.space,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  );
}

class AetronText {
  const AetronText._();

  static const header = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.cyanSoft,
    fontSize: 26,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
  );

  static const section = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.cyan,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.8,
  );

  static const label = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.muted,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  static const metric = TextStyle(
    fontFamily: 'Outfit',
    color: AetronColors.text,
    fontSize: 24,
    height: 1,
    fontWeight: FontWeight.w900,
  );
}


class AetronBackground extends StatelessWidget {
  const AetronBackground({
    super.key,
    required this.child,
    this.withGrid = true,
    this.padding,
  });

  final Widget child;
  final bool withGrid;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AetronColors.voidBlack, AetronColors.space],
        ),
      ),
      child: Stack(
        children: [
          if (withGrid) const Positioned.fill(child: _HudGrid()),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}

class _HudGrid extends StatefulWidget {
  const _HudGrid();

  @override
  State<_HudGrid> createState() => _HudGridState();
}

class _HudGridState extends State<_HudGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) =>
            CustomPaint(painter: _HudGridPainter(_controller.value)),
      ),
    );
  }
}

class _HudGridPainter extends CustomPainter {
  const _HudGridPainter(this.phase);

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.31;
    final vanishingPoint = Offset(size.width * 0.5, horizon);
    final glowCenter = Offset(
      size.width * (0.56 + math.sin(phase * math.pi * 2) * 0.04),
      horizon,
    );
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AetronColors.cyan.withValues(alpha: 0.13),
          AetronColors.cyan.withValues(alpha: 0.025),
          Colors.transparent,
        ],
        stops: const [0, 0.32, 1],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: size.width));
    canvas.drawCircle(glowCenter, size.width, glow);

    final horizonPaint = Paint()
      ..color = AetronColors.cyan.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, horizon),
      Offset(size.width, horizon),
      horizonPaint,
    );

    final gridPaint = Paint()
      ..color = AetronColors.cyan.withValues(alpha: 0.075)
      ..strokeWidth = 1;
    const columnCount = 11;
    for (var column = 0; column <= columnCount; column++) {
      final x = size.width * column / columnCount;
      canvas.drawLine(vanishingPoint, Offset(x, size.height), gridPaint);
    }

    // Spaced depth lines make the lower grid read like a receding floor.
    const depthLines = 12;
    for (var line = 1; line <= depthLines; line++) {
      final depth = line / depthLines;
      final easedDepth = depth * depth;
      final y = horizon + (size.height - horizon) * easedDepth;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final scanY = horizon + (size.height - horizon) * phase;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AetronColors.cyan.withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 1, size.width, 2));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 1, size.width, 2), scanPaint);

    final upperGridPaint = Paint()
      ..color = AetronColors.cyan.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const upperStep = 34.0;
    for (var x = 0.0; x <= size.width; x += upperStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, horizon), upperGridPaint);
    }
    for (var y = 0.0; y < horizon; y += upperStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), upperGridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HudGridPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class AetronHeader extends StatelessWidget {
  const AetronHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.leading,
    this.trailing,
    this.compact = false,
    this.titleSize,
  });

  final String title;
  final String? eyebrow;
  final Widget? leading;
  final Widget? trailing;
  final bool compact;
  final double? titleSize;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final style = AetronText.header.copyWith(
      fontSize: titleSize ?? (compact ? 20 : 24),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(
        AetronSpacing.page,
        MediaQuery.of(context).padding.top + 10,
        AetronSpacing.page,
        10,
      ),
      decoration: BoxDecoration(
        color: AetronColors.space.withValues(alpha: 0.86),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.58)),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AetronText.label.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    style: scale.scale(style.fontSize!) > 36
                        ? style.copyWith(fontSize: 24)
                        : style,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class AetronGlassCard extends StatelessWidget {
  const AetronGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = AetronSpacing.cardRadius,
    this.borderColor = AetronColors.border,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Ink(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AetronColors.panel.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.07),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: box,
      ),
    );
  }
}

class AetronLoadingScaffold extends StatelessWidget {
  const AetronLoadingScaffold({
    super.key,
    this.label = 'LOADING',
    this.message,
    this.withGrid = true,
  });

  final String label;
  final String? message;
  final bool withGrid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AetronLoadingPanel(label: label, message: message),
          ),
        ),
      ),
    );
  }
}

class AetronLoadingPanel extends StatefulWidget {
  const AetronLoadingPanel({
    super.key,
    this.label = 'LOADING',
    this.message,
    this.size = 190,
  });

  final String label;
  final String? message;
  final double size;

  @override
  State<AetronLoadingPanel> createState() => _AetronLoadingPanelState();
}

class _AetronLoadingPanelState extends State<AetronLoadingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final floatOffset = math.sin(_controller.value * math.pi * 2) * 4;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(widget.size),
                      painter: _AetronLoaderPainter(progress: _controller.value),
                    ),
                    Transform.translate(
                      offset: Offset(0, floatOffset),
                      child: Container(
                        width: widget.size * 0.45,
                        height: widget.size * 0.45,
                        padding: EdgeInsets.all(widget.size * 0.09),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AetronColors.space,
                          border: Border.all(
                            color: AetronColors.cyan.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AetronColors.cyan.withValues(alpha: 0.35),
                              blurRadius: 22,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              color: AetronColors.textPrimary,
              fontSize: scale.scale(15) > 18 ? 13 : 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 140,
            height: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: AetronColors.space,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AetronColors.cyan,
                ),
              ),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AetronColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      );
  }
}

class _AetronLoaderPainter extends CustomPainter {
  const _AetronLoaderPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = AetronColors.cyan.withValues(alpha: 0.4);
    canvas.drawCircle(center, radius, glow);

    final baseRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AetronColors.cyan.withValues(alpha: 0.25);
    canvas.drawCircle(center, radius * 0.75, baseRing);
    canvas.drawCircle(center, radius, baseRing);
    canvas.drawCircle(center, radius * 1.18, baseRing);

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = AetronColors.cyan.withValues(alpha: 0.5);
    for (var i = 0; i < 36; i++) {
      final angle = (math.pi * 2 / 36) * i + progress * math.pi * 2;
      final inner = radius * (i % 3 == 0 ? 1.02 : 1.1);
      final outer = radius * 1.22;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * inner,
          center.dy + math.sin(angle) * inner,
        ),
        Offset(
          center.dx + math.cos(angle) * outer,
          center.dy + math.sin(angle) * outer,
        ),
        tickPaint,
      );
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          AetronColors.cyan.withValues(alpha: 0),
          AetronColors.cyan,
          AetronColors.mint,
          AetronColors.cyan.withValues(alpha: 0.08),
        ],
        stops: const [0, 0.5, 0.8, 1],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.5, false, arcPaint);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AetronColors.cyan.withValues(alpha: 0.6);
    for (final tilt in [-0.62, 0.62]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(tilt + progress * math.pi * 0.4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2.55,
          height: radius * 0.65,
        ),
        orbitPaint,
      );
      canvas.restore();
    }

    final sweepAngle = -math.pi / 2 + progress * math.pi * 2;
    final dotPaint = Paint()..color = AetronColors.cyanSoft;
    final dotAngle = sweepAngle + math.pi * 0.22;
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(dotAngle) * radius,
        center.dy + math.sin(dotAngle) * radius,
      ),
      3.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AetronLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class AetronMetricTile extends StatelessWidget {
  const AetronMetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent = AetronColors.cyan,
    this.minHeight = 116,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: minHeight,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AetronColors.panelHigh.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 22),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.70),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: AetronText.metric),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AetronText.label,
            ),
          ],
        ),
      ),
    );
  }
}

class AetronSegmented<T> extends StatelessWidget {
  const AetronSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.height = 48,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: values.map((value) {
          final active = value == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AetronColors.cyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: active
                      ? Border.all(color: AetronColors.cyanSoft.withValues(alpha: 0.6))
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labelBuilder(value).toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                      color: active ? AetronColors.space : AetronColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AetronPrimaryButton extends StatelessWidget {
  const AetronPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AetronColors.cyan,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AetronColors.cyan.withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.arrow_forward_rounded),
          label: Text(label.toUpperCase()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: AetronColors.space,
            shadowColor: Colors.transparent,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

class AetronAvatar extends StatelessWidget {
  const AetronAvatar({
    super.key,
    this.image,
    this.label = 'BA',
    this.size = 48,
    this.onTap,
  });

  final ImageProvider? image;
  final String label;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayImage = image ?? const AssetImage('assets/screen.png');
    final child = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AetronColors.panelBright,
        shape: BoxShape.circle,
        border: Border.all(color: AetronColors.cyanSoft, width: 2),
        image: DecorationImage(image: displayImage, fit: BoxFit.cover),
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

class AetronStreakPill extends StatelessWidget {
  const AetronStreakPill({
    super.key,
    required this.streak,
    this.onTap,
    this.compact = false,
  });

  final int streak;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: compact ? 36 : 54,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 20),
        decoration: BoxDecoration(
          color: const Color(0xff3d1c1c).withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AetronColors.gold, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: AetronColors.gold,
              size: compact ? 16 : 20,
            ),
            SizedBox(width: compact ? 5 : 8),
            Text(
              compact ? '$streak' : '${streak}D\nSTREAK',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AetronColors.gold,
                fontSize: compact ? 12 : 14,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AetronProgressRing extends StatelessWidget {
  const AetronProgressRing({
    super.key,
    required this.value,
    required this.center,
    this.size = 132,
    this.color = AetronColors.cyan,
  });

  final double value;
  final Widget center;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(value: animated, color: color),
              ),
              center,
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final active = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
    canvas.drawArc(rect.deflate(9), -math.pi / 2, math.pi * 2, false, base);
    canvas.drawArc(
      rect.deflate(9),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
