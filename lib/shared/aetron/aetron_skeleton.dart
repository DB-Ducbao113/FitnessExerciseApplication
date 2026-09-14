import "package:flutter/material.dart";

/// Aetron Hardware-Accelerated Shimmer Gradient Sweeper
class AetronShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AetronShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<AetronShimmer> createState() => _AetronShimmerState();
}

class _AetronShimmerState extends State<AetronShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: [
                (progress - 0.4).clamp(0.0, 1.0),
                progress.clamp(0.0, 1.0),
                (progress + 0.4).clamp(0.0, 1.0),
              ],
              colors: const [
                Color(0xFF131D2D), // Deep Obsidian Slate
                Color(0xFF24364F), // Lighter Graphite Sweep
                Color(0xFF131D2D), // Deep Obsidian Slate
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Basic Skeleton Block
class AetronSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const AetronSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 12,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFF131D2D),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
    );
  }
}

/// Skeleton Card Container
class AetronSkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const AetronSkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1624),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ==========================================
// 1. HOME SKELETON VIEW
// ==========================================
class HomeSkeletonView extends StatelessWidget {
  const HomeSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return AetronShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Weekly Goal Progress Skeleton Card
          AetronSkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    AetronSkeletonBox(width: 120, height: 16, borderRadius: 6),
                    AetronSkeletonBox(width: 60, height: 16, borderRadius: 6),
                  ],
                ),
                const SizedBox(height: 14),
                const AetronSkeletonBox(height: 10, borderRadius: 5),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    AetronSkeletonBox(width: 80, height: 28, borderRadius: 8),
                    AetronSkeletonBox(width: 70, height: 28, borderRadius: 8),
                    AetronSkeletonBox(width: 90, height: 28, borderRadius: 8),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Recent Workout Skeleton Card (Map Preview + Stats)
          AetronSkeletonCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map Area
                const AetronSkeletonBox(
                  height: 170,
                  borderRadius: 20,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          AetronSkeletonBox(width: 140, height: 20, borderRadius: 6),
                          AetronSkeletonBox(width: 70, height: 14, borderRadius: 6),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          AetronSkeletonBox(width: 80, height: 36, borderRadius: 10),
                          AetronSkeletonBox(width: 80, height: 36, borderRadius: 10),
                          AetronSkeletonBox(width: 80, height: 36, borderRadius: 10),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Section Header Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              AetronSkeletonBox(width: 160, height: 18, borderRadius: 6),
              AetronSkeletonBox(width: 60, height: 14, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Guided Running Series Horizontal Cards
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return Container(
                  width: 200,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1624),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AetronSkeletonBox(width: 40, height: 40, borderRadius: 20),
                      Spacer(),
                      AetronSkeletonBox(width: 120, height: 16, borderRadius: 6),
                      SizedBox(height: 6),
                      AetronSkeletonBox(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 5. Start Workout Banner Skeleton
          const AetronSkeletonBox(height: 80, borderRadius: 22),
        ],
      ),
    );
  }
}

// ==========================================
// 2. ANALYTICS SKELETON VIEW
// ==========================================
class AnalyticsSkeletonView extends StatelessWidget {
  const AnalyticsSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return AetronShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Period Selector Segment
          const AetronSkeletonBox(height: 44, borderRadius: 22),
          const SizedBox(height: 18),

          // 4 Metric Tiles Grid (2x2)
          Row(
            children: const [
              Expanded(child: AetronSkeletonBox(height: 90, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: AetronSkeletonBox(height: 90, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: AetronSkeletonBox(height: 90, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: AetronSkeletonBox(height: 90, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 20),

          // Chart Card Skeleton
          AetronSkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    AetronSkeletonBox(width: 130, height: 16, borderRadius: 6),
                    AetronSkeletonBox(width: 70, height: 14, borderRadius: 6),
                  ],
                ),
                const SizedBox(height: 20),
                const AetronSkeletonBox(height: 160, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Personal Records Trophy Wall Skeleton
          AetronSkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AetronSkeletonBox(width: 150, height: 18, borderRadius: 6),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(child: AetronSkeletonBox(height: 70, borderRadius: 14)),
                    SizedBox(width: 10),
                    Expanded(child: AetronSkeletonBox(height: 70, borderRadius: 14)),
                    SizedBox(width: 10),
                    Expanded(child: AetronSkeletonBox(height: 70, borderRadius: 14)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. CALENDAR SKELETON VIEW
// ==========================================
class CalendarSkeletonView extends StatelessWidget {
  const CalendarSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return AetronShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Range Pill Selector
          const AetronSkeletonBox(height: 40, borderRadius: 20),
          const SizedBox(height: 16),

          // Calendar Card Skeleton
          AetronSkeletonCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    AetronSkeletonBox(width: 110, height: 16, borderRadius: 6),
                    AetronSkeletonBox(width: 60, height: 16, borderRadius: 6),
                  ],
                ),
                const SizedBox(height: 16),
                // 5 Weeks Grid
                for (var i = 0; i < 5; i++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var j = 0; j < 7; j++)
                        const AetronSkeletonBox(
                          width: 34,
                          height: 34,
                          borderRadius: 17,
                        ),
                    ],
                  ),
                  if (i < 4) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Daily Timeline Header
          const AetronSkeletonBox(width: 140, height: 18, borderRadius: 6),
          const SizedBox(height: 12),

          // Timeline Workout Cards
          for (var k = 0; k < 3; k++) ...[
            AetronSkeletonCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const AetronSkeletonBox(width: 44, height: 44, borderRadius: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AetronSkeletonBox(width: 110, height: 16, borderRadius: 6),
                        SizedBox(height: 6),
                        AetronSkeletonBox(width: 160, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  const AetronSkeletonBox(width: 50, height: 20, borderRadius: 6),
                ],
              ),
            ),
            if (k < 2) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// 4. PROFILE SKELETON VIEW
// ==========================================
class ProfileSkeletonView extends StatelessWidget {
  const ProfileSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return AetronShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Header: Avatar & Info
          Center(
            child: Column(
              children: const [
                AetronSkeletonBox(width: 84, height: 84, borderRadius: 42),
                SizedBox(height: 12),
                AetronSkeletonBox(width: 140, height: 20, borderRadius: 8),
                SizedBox(height: 6),
                AetronSkeletonBox(width: 180, height: 14, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Profile Settings Sections
          for (var i = 0; i < 3; i++) ...[
            AetronSkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AetronSkeletonBox(width: 120, height: 16, borderRadius: 6),
                  const SizedBox(height: 14),
                  for (var j = 0; j < 3; j++) ...[
                    Row(
                      children: const [
                        AetronSkeletonBox(width: 32, height: 32, borderRadius: 8),
                        SizedBox(width: 12),
                        Expanded(
                          child: AetronSkeletonBox(height: 16, borderRadius: 6),
                        ),
                        SizedBox(width: 12),
                        AetronSkeletonBox(width: 16, height: 16, borderRadius: 4),
                      ],
                    ),
                    if (j < 2) const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            if (i < 2) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// 5. WORKOUT DETAILS SKELETON VIEW
// ==========================================
class WorkoutDetailsSkeletonView extends StatelessWidget {
  const WorkoutDetailsSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return AetronShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Route Map Skeleton Header
          const AetronSkeletonBox(height: 260, borderRadius: 24),
          const SizedBox(height: 20),

          // Stats Grid (3 Columns)
          Row(
            children: const [
              Expanded(child: AetronSkeletonBox(height: 76, borderRadius: 16)),
              SizedBox(width: 10),
              Expanded(child: AetronSkeletonBox(height: 76, borderRadius: 16)),
              SizedBox(width: 10),
              Expanded(child: AetronSkeletonBox(height: 76, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 16),

          // Lap Splits Card Skeleton
          AetronSkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AetronSkeletonBox(width: 140, height: 18, borderRadius: 6),
                const SizedBox(height: 14),
                for (var i = 0; i < 4; i++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      AetronSkeletonBox(width: 50, height: 14, borderRadius: 4),
                      AetronSkeletonBox(width: 70, height: 14, borderRadius: 4),
                      AetronSkeletonBox(width: 60, height: 14, borderRadius: 4),
                    ],
                  ),
                  if (i < 3) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
