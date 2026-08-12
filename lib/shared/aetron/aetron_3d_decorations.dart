import 'package:flutter/material.dart';
import 'aetron_ui.dart';

/// Decorative 3D Radial Glow Container
class AetronRadialGlow extends StatelessWidget {
  const AetronRadialGlow({
    super.key,
    required this.child,
    this.glowColor = AetronColors.cyan,
    this.glowRadius = 140.0,
    this.alpha = 0.25,
  });

  final Widget child;
  final Color glowColor;
  final double glowRadius;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: glowRadius * 2,
          height: glowRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                glowColor.withValues(alpha: alpha),
                glowColor.withValues(alpha: alpha * 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Floating 3D animation wrapper that moves up & down smoothly
class Aetron3DFloatingWidget extends StatefulWidget {
  const Aetron3DFloatingWidget({
    super.key,
    required this.child,
    this.floatOffset = 10.0,
    this.duration = const Duration(milliseconds: 2500),
  });

  final Widget child;
  final double floatOffset;
  final Duration duration;

  @override
  State<Aetron3DFloatingWidget> createState() => _Aetron3DFloatingWidgetState();
}

class _Aetron3DFloatingWidgetState extends State<Aetron3DFloatingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: -widget.floatOffset / 2,
      end: widget.floatOffset / 2,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: widget.child,
        );
      },
    );
  }
}

/// Modern Segmented Control Tab Bar (Image 3 Style)
class AetronSegmentedControl extends StatelessWidget {
  const AetronSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.tabs,
    required this.onTabChanged,
    this.activeColor = AetronColors.cyan,
    this.backgroundColor = const Color(0xFF0F1524),
  });

  final int selectedIndex;
  final List<String> tabs;
  final ValueChanged<int> onTabChanged;
  final Color activeColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? AetronColors.space : AetronColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// High-contrast 3D Capsule CTA Button (Image 3 Style)
class Aetron3DPrimaryButton extends StatelessWidget {
  const Aetron3DPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color = AetronColors.cyan,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: LinearGradient(
          colors: isDisabled
              ? [AetronColors.disabled, AetronColors.disabled]
              : [color, color.withValues(alpha: 0.85)],
        ),
        boxShadow: isDisabled
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(27),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AetronColors.space),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.space,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(icon, color: AetronColors.space, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 3D Action Orb Button (Search, Notifications, Quick Add)
class Aetron3DOrbButton extends StatelessWidget {
  const Aetron3DOrbButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.color = AetronColors.cyan,
    this.backgroundColor = AetronColors.panelHigh,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color color;
  final Color backgroundColor;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(
                child: Icon(
                  icon,
                  color: color,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AetronColors.danger,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Category Pill Chip (Stores / Workouts Filter from Image 1)
class AetronCategoryChip extends StatelessWidget {
  const AetronCategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AetronColors.cyan : AetronColors.panelHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AetronColors.cyan : AetronColors.borderSubtle,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AetronColors.cyan.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? AetronColors.space : AetronColors.cyanSoft,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? AetronColors.space : AetronColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

