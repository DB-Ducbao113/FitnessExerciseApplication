import 'dart:math' as math;

import 'package:fitness_exercise_application/core/l10n/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _welcomeSeenKey = 'aetron_welcome_seen_v1';

class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  late final Future<bool> _shouldShowWelcome = _loadShouldShowWelcome();
  bool _showResourceLoading = false;

  Future<bool> _loadShouldShowWelcome() async {
    if (Supabase.instance.client.auth.currentSession != null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_welcomeSeenKey) ?? false);
  }

  Future<void> _completeWelcome() async {
    if (!mounted) return;
    setState(() => _showResourceLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeSeenKey, true);
    } catch (error) {
      debugPrint('[WelcomeGate] Could not persist welcome state: $error');
    }
  }

  void _openAuth() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
  }

  @override
  Widget build(BuildContext context) {
    if (_showResourceLoading) {
      return ResourceLoadingScreen(onComplete: _openAuth);
    }

    return FutureBuilder<bool>(
      future: _shouldShowWelcome,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AetronLoadingScaffold(
            label: 'BOOTING AETRON',
            message: 'Initializing performance interface.',
          );
        }
        return snapshot.data!
            ? WelcomeScreen(onNext: _completeWelcome)
            : ResourceLoadingScreen(onComplete: _openAuth);
      },
    );
  }
}

class ResourceLoadingScreen extends StatefulWidget {
  const ResourceLoadingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<ResourceLoadingScreen> createState() => _ResourceLoadingScreenState();
}

class _ResourceLoadingScreenState extends State<ResourceLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;

  static const _steps = [
    'Loading visual assets',
    'Calibrating HUD grid',
    'Preparing auth gateway',
    'Syncing telemetry cache',
    'Aetron ready',
  ];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2600),
          )
          ..addListener(() => setState(() {}))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && !_completed) {
              _completed = true;
              Future<void>.delayed(const Duration(milliseconds: 260), () {
                if (mounted) widget.onComplete();
              });
            }
          });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheResources();
      _controller.forward();
    });
  }

  Future<void> _precacheResources() async {
    await Future.wait([
      precacheImage(const AssetImage('assets/logo.png'), context),
      precacheImage(const AssetImage('assets/welcome_runner.png'), context),
      precacheImage(const AssetImage('assets/GoogleLogo.jpg'), context),
      precacheImage(const AssetImage('assets/screen.png'), context),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = Curves.easeInOutCubic.transform(_controller.value);
    final stepIndex = (progress * _steps.length).floor().clamp(
      0,
      _steps.length - 1,
    );

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: AetronBackground(
        withGrid: true,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 190,
                    child: CustomPaint(
                      painter: _ResourceLoaderPainter(progress: progress),
                      child: Center(
                        child: Container(
                          width: 82,
                          height: 82,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AetronColors.space.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AetronColors.cyan.withValues(alpha: 0.55),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AetronColors.cyan.withValues(
                                  alpha: 0.24,
                                ),
                                blurRadius: 32,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'LOADING RESOURCES',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AetronColors.cyanSoft,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _steps[stepIndex].toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AetronText.label.copyWith(
                      color: AetronColors.muted,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: AetronColors.panelBright.withValues(
                        alpha: 0.35,
                      ),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AetronColors.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(progress * 100).round().clamp(0, 100)}%',
                    style: const TextStyle(
                      color: AetronColors.cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, required this.onNext});

  final Future<void> Function() onNext;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isCompleting = false;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      eyebrow: 'PERFORMANCE OS ONLINE',
      titlePrefix: 'WELCOME TO\nTHE ',
      titleAccent: 'FUTURE',
      titleSuffix: ' OF\nFITNESS',
      description:
          'Precision tracking meets kinetic intelligence. Your journey to elite performance starts here.',
      primaryPill: 'BIO-SYNC\nACTIVE',
      secondaryPill: '98% KINETIC\nREADY',
      primaryIcon: Icons.sensors_rounded,
      secondaryIcon: Icons.bolt_rounded,
      heroType: _OnboardingHeroType.runner,
    ),
    _OnboardingPageData(
      eyebrow: 'GPS LOCK READY',
      titlePrefix: 'TRACK EVERY\n',
      titleAccent: 'ROUTE',
      titleSuffix: ' WITH\nPRECISION',
      description:
          'Record outdoor sessions with route tracing, pace, distance, calories, and live workout controls.',
      primaryPill: 'LIVE ROUTE\nTRACE',
      secondaryPill: 'PACE SIGNAL\nONLINE',
      primaryIcon: Icons.route_rounded,
      secondaryIcon: Icons.speed_rounded,
      heroType: _OnboardingHeroType.tracking,
    ),
    _OnboardingPageData(
      eyebrow: 'TELEMETRY CORE',
      titlePrefix: 'ADVANCED\n',
      titleAccent: 'ANALYSIS',
      titleSuffix: ' FOR\nPROGRESS',
      description:
          'Turn every workout into weekly trends, records, goal progress, and performance telemetry.',
      primaryPill: 'TREND ENGINE\nACTIVE',
      secondaryPill: 'GOAL DATA\nSYNCED',
      primaryIcon: Icons.query_stats_rounded,
      secondaryIcon: Icons.track_changes_rounded,
      heroType: _OnboardingHeroType.analysis,
    ),
    _OnboardingPageData(
      eyebrow: 'MILESTONE SYSTEM',
      titlePrefix: 'UNLOCK\n',
      titleAccent: 'ACHIEVEMENTS',
      titleSuffix: ' AND\nSTREAKS',
      description:
          'Stay motivated with workout streaks, personal milestones, records, and achievement signals.',
      primaryPill: 'STREAK MODE\nREADY',
      secondaryPill: 'RECORDS\nARMED',
      primaryIcon: Icons.local_fire_department_rounded,
      secondaryIcon: Icons.emoji_events_rounded,
      heroType: _OnboardingHeroType.achievements,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_isCompleting) return;
    if (_currentPage == _pages.length - 1) {
      await _completeOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _goPrevious() {
    if (_currentPage == 0 || _isCompleting) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await widget.onNext();
    } catch (error) {
      debugPrint('[WelcomeScreen] Could not finish onboarding: $error');
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final size = MediaQuery.sizeOf(context);
    final isShort = size.height < 720;
    final heroHeight = isShort ? 230.0 : 320.0;
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AetronColors.voidBlack,
      body: AetronBackground(
        withGrid: false,
        child: Stack(
          children: [
            const Positioned.fill(child: _WelcomeGrid()),
            SafeArea(
              child: Column(
                children: [
                  _WelcomeTopBar(
                    canGoBack: _currentPage > 0,
                    onBack: _goPrevious,
                    onSkip: _completeOnboarding,
                    isProcessing: _isCompleting,
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                      },
                      itemBuilder: (context, index) {
                        final data = _pages[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _OnboardingHero(
                              data: data,
                              height: heroHeight,
                              animation: _controller,
                            ),
                            Transform.translate(
                              offset: const Offset(0, -44),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _WelcomeCopyCard(data: data),
                                    const SizedBox(height: 14),
                                    _TelemetryPills(data: data),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, isShort ? 14 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _NextButton(
                          label: isLastPage
                              ? AppTranslations.get('get_started', currentLang).toUpperCase()
                              : (currentLang == AppLanguage.vi ? 'TIẾP TỤC' : 'NEXT'),
                          onPressed: _goNext,
                          isProcessing: _isCompleting,
                        ),
                        const SizedBox(height: 16),
                        _PageDots(count: _pages.length, current: _currentPage),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OnboardingHeroType { runner, tracking, analysis, achievements }

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.eyebrow,
    required this.titlePrefix,
    required this.titleAccent,
    required this.titleSuffix,
    required this.description,
    required this.primaryPill,
    required this.secondaryPill,
    required this.primaryIcon,
    required this.secondaryIcon,
    required this.heroType,
  });

  final String eyebrow;
  final String titlePrefix;
  final String titleAccent;
  final String titleSuffix;
  final String description;
  final String primaryPill;
  final String secondaryPill;
  final IconData primaryIcon;
  final IconData secondaryIcon;
  final _OnboardingHeroType heroType;
}

class _WelcomeTopBar extends StatelessWidget {
  const _WelcomeTopBar({
    required this.canGoBack,
    required this.onBack,
    required this.onSkip,
    required this.isProcessing,
  });

  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: canGoBack
                    ? IconButton(
                        onPressed: onBack,
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AetronColors.cyan,
                      )
                    : const Icon(
                        Icons.signal_cellular_alt_rounded,
                        color: AetronColors.cyan,
                      ),
              ),
            ),
            const Spacer(),
            Text(
              'AETRON',
              style: AetronText.header.copyWith(
                color: AetronColors.cyan,
                fontSize: 24,
                letterSpacing: 4.4,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 64,
              height: 44,
              child: TextButton(
                onPressed: isProcessing ? null : onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AetronColors.cyan,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'SKIP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceLoaderPainter extends CustomPainter {
  const _ResourceLoaderPainter({required this.progress});

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
      ..color = AetronColors.cyan.withValues(alpha: 0.28);
    canvas.drawCircle(center, radius, glow);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AetronColors.cyan.withValues(alpha: 0.18);
    for (final scale in [0.62, 0.82, 1.04, 1.24]) {
      canvas.drawCircle(center, radius * scale, gridPaint);
    }

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = AetronColors.cyan.withValues(alpha: 0.44);
    for (var i = 0; i < 48; i++) {
      final angle = i * math.pi * 2 / 48 + progress * math.pi * 2;
      final inner = radius * (i % 4 == 0 ? 1.05 : 1.13);
      final outer = radius * 1.26;
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

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          AetronColors.cyan,
          AetronColors.blue,
          AetronColors.cyan.withValues(alpha: 0.08),
        ],
        stops: const [0, 0.62, 1],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AetronColors.cyan.withValues(alpha: 0.52);
    for (final tilt in [-0.7, 0.7]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(tilt + progress * math.pi * 0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2.7,
          height: radius * 0.62,
        ),
        orbitPaint,
      );
      canvas.restore();
    }

    final dotAngle = -math.pi / 2 + math.pi * 2 * progress;
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(dotAngle) * radius,
        center.dy + math.sin(dotAngle) * radius,
      ),
      4,
      Paint()..color = AetronColors.cyanSoft,
    );
  }

  @override
  bool shouldRepaint(covariant _ResourceLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({
    required this.data,
    required this.height,
    required this.animation,
  });

  final _OnboardingPageData data;
  final double height;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (data.heroType == _OnboardingHeroType.runner)
            Image.asset(
              'assets/welcome_runner.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            )
          else
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FeatureHeroPainter(
                    progress: animation.value,
                    heroType: data.heroType,
                    icon: data.primaryIcon,
                  ),
                );
              },
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xAA0A0D1C),
                  Color(0x000A0D1C),
                  Color(0xFF0A0D1C),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return CustomPaint(
                painter: _HeroScanPainter(progress: animation.value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WelcomeCopyCard extends StatelessWidget {
  const _WelcomeCopyCard({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: AetronColors.voidBlack.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AetronColors.border),
        boxShadow: [
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.08),
            blurRadius: 32,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.eyebrow,
            style: const TextStyle(
              color: AetronColors.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: const TextStyle(
                color: AetronColors.cyanSoft,
                fontSize: 30,
                height: 0.98,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
              children: [
                TextSpan(text: data.titlePrefix),
                TextSpan(
                  text: data.titleAccent,
                  style: const TextStyle(color: AetronColors.cyan),
                ),
                TextSpan(text: data.titleSuffix),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.description,
            style: AetronText.label.copyWith(
              color: AetronColors.muted,
              height: 1.4,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryPills extends StatelessWidget {
  const _TelemetryPills({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TelemetryPill(
            icon: data.primaryIcon,
            label: data.primaryPill,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TelemetryPill(
            icon: data.secondaryIcon,
            label: data.secondaryPill,
          ),
        ),
      ],
    );
  }
}

class _TelemetryPill extends StatelessWidget {
  const _TelemetryPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AetronColors.space.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AetronColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AetronColors.cyan, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AetronColors.cyanSoft,
                fontSize: 9,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.label,
    required this.onPressed,
    required this.isProcessing,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: isProcessing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AetronColors.cyan,
          foregroundColor: const Color(0xFF00272D),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: isProcessing
              ? const [
                  SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ]
              : [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.arrow_forward_rounded, size: 22),
                ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 30 : 7,
          height: 3,
          decoration: BoxDecoration(
            color: selected ? AetronColors.cyan : AetronColors.panelBright,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _WelcomeGrid extends StatelessWidget {
  const _WelcomeGrid();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _WelcomeGridPainter()));
  }
}

class _WelcomeGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AetronColors.cyan.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 38.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroScanPainter extends CustomPainter {
  const _HeroScanPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AetronColors.cyan.withValues(alpha: 0.72),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 12, size.width, 24))
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final particlePaint = Paint()
      ..color = AetronColors.cyan.withValues(alpha: 0.34);
    for (var i = 0; i < 18; i++) {
      final seed = i * 41.0;
      final x = (math.sin(progress * math.pi * 2 + i) * 0.5 + 0.5) * size.width;
      final py = (y + seed) % size.height;
      canvas.drawCircle(Offset(x, py), i.isEven ? 1.5 : 1, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroScanPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _FeatureHeroPainter extends CustomPainter {
  const _FeatureHeroPainter({
    required this.progress,
    required this.heroType,
    required this.icon,
  });

  final double progress;
  final _OnboardingHeroType heroType;
  final IconData icon;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.44);
    final radius = math.min(size.width, size.height) * 0.25;

    final glowPaint = Paint()
      ..color = AetronColors.cyan.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(center, radius * 1.5, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AetronColors.cyan.withValues(alpha: 0.44);
    for (final scale in [0.72, 1.0, 1.28]) {
      canvas.drawCircle(center, radius * scale, ringPaint);
    }

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          AetronColors.cyan.withValues(alpha: 0),
          AetronColors.cyan,
          AetronColors.cyan.withValues(alpha: 0),
        ],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.16));
    canvas.drawCircle(center, radius * 1.16, sweepPaint);

    switch (heroType) {
      case _OnboardingHeroType.tracking:
        _drawRoute(canvas, center, radius, progress);
      case _OnboardingHeroType.analysis:
        _drawChart(canvas, center, radius, progress);
      case _OnboardingHeroType.achievements:
        _drawAchievement(canvas, center, radius, progress);
      case _OnboardingHeroType.runner:
        break;
    }

    _drawIcon(canvas, center, icon, radius);
  }

  void _drawRoute(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final path = Path()
      ..moveTo(center.dx - radius * 1.15, center.dy + radius * 0.45)
      ..cubicTo(
        center.dx - radius * 0.7,
        center.dy - radius * 0.8,
        center.dx + radius * 0.35,
        center.dy + radius * 0.85,
        center.dx + radius * 1.12,
        center.dy - radius * 0.35,
      );
    final routeGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = AetronColors.cyan.withValues(alpha: 0.32);
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = AetronColors.cyan;
    canvas.drawPath(path, routeGlow);
    canvas.drawPath(path, routePaint);

    final markerPaint = Paint()..color = AetronColors.cyanSoft;
    for (final t in [0.0, 0.42, 0.78]) {
      final angle = (t + progress) * math.pi * 2;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius * 0.55,
        ),
        4,
        markerPaint,
      );
    }
  }

  void _drawChart(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final baseY = center.dy + radius * 0.55;
    final barPaint = Paint()
      ..color = AetronColors.cyan.withValues(alpha: 0.72)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    for (var i = 0; i < 6; i++) {
      final x = center.dx - radius * 0.75 + i * radius * 0.3;
      final h =
          radius *
          (0.28 + 0.5 * ((math.sin(progress * math.pi * 2 + i) + 1) / 2));
      canvas.drawLine(Offset(x, baseY), Offset(x, baseY - h), barPaint);
    }

    final line = Path()..moveTo(center.dx - radius, center.dy + radius * 0.25);
    for (var i = 1; i <= 5; i++) {
      final x = center.dx - radius + i * radius * 0.4;
      final y =
          center.dy + math.sin(progress * math.pi * 2 + i) * radius * 0.25;
      line.lineTo(x, y);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AetronColors.gold,
    );
  }

  void _drawAchievement(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final medalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AetronColors.gold;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius * 0.52 : radius * 0.24;
      final a = -math.pi / 2 + i * math.pi / 5 + progress * 0.25;
      final p = Offset(
        center.dx + math.cos(a) * r,
        center.dy + math.sin(a) * r,
      );
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(star, medalPaint);
    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AetronColors.cyan.withValues(alpha: 0.8),
    );
  }

  void _drawIcon(Canvas canvas, Offset center, IconData icon, double radius) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: radius * 0.42,
          color: AetronColors.cyanSoft,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _FeatureHeroPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.heroType != heroType ||
        oldDelegate.icon != icon;
  }
}
