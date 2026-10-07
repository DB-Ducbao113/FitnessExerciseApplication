import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum ShareCardTheme {
  cyberNeon,
  solarFlare,
  matrixMint,
  quantumViolet,
}

/// Renders a premium Social Share Card with 4 aesthetic themes,
/// dedicated social app targets (Facebook, Zalo, Messenger, Instagram),
/// Save to Gallery, Copy Caption, and Native OS Share.
class WorkoutShareCardSheet extends StatefulWidget {
  final String activityType;
  final double distanceKm;
  final int durationSeconds;
  final double avgSpeedKmh;
  final int calories;
  final int steps;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const WorkoutShareCardSheet({
    super.key,
    required this.activityType,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgSpeedKmh,
    required this.calories,
    required this.steps,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  State<WorkoutShareCardSheet> createState() => _WorkoutShareCardSheetState();
}

class _WorkoutShareCardSheetState extends State<WorkoutShareCardSheet>
    with SingleTickerProviderStateMixin {
  final GlobalKey _captureKey = GlobalKey();
  bool _isProcessing = false;
  ShareCardTheme _selectedTheme = ShareCardTheme.cyberNeon;
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  String _buildCaption() {
    final isVi = widget.currentLang == AppLanguage.vi;
    final distStr = WorkoutFormatters.formatDistance(widget.distanceKm,
        useMetric: widget.useMetricUnits, decimals: 2);
    final durationStr =
        WorkoutFormatters.formatDurationFromSeconds(widget.durationSeconds);
    final paceStr = WorkoutFormatters.formatPaceFromSpeedKmh(widget.avgSpeedKmh,
        useMetric: widget.useMetricUnits);

    if (isVi) {
      return '🏃 Vừa hoàn thành $distStr trong $durationStr (Pace: $paceStr) cùng Aetron! 🔥 ${widget.calories} kcal\n\n#Aetron #Fitness #ChayBo #Workout';
    } else {
      return '🏃 Just crushed $distStr in $durationStr (Avg Pace: $paceStr) with Aetron! 🔥 ${widget.calories} kcal\n\n#Aetron #Fitness #Running #Workout';
    }
  }

  Future<Uint8List?> _captureCardBytes() async {
    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[ShareCard] Capture error: $e');
      return null;
    }
  }

  Future<void> _shareToApp({
    required String scheme,
    required String appName,
  }) async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse(scheme);
    final canOpen = await canLaunchUrl(uri);

    if (canOpen) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final bytes = await _captureCardBytes();
      if (bytes != null && mounted) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/aetron_workout_share.png');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: _buildCaption(),
        );
      }
    }
  }

  Future<void> _shareToNative() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final bytes = await _captureCardBytes();
      if (bytes == null || !mounted) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aetron_workout_share.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? (box.localToGlobal(Offset.zero) & box.size)
          : const Rect.fromLTWH(0, 0, 100, 100);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _buildCaption(),
        sharePositionOrigin: origin,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToPhotos() async {
    HapticFeedback.selectionClick();
    setState(() => _isProcessing = true);
    final isVi = widget.currentLang == AppLanguage.vi;
    final colors = context.kinetic;

    try {
      final bytes = await _captureCardBytes();
      if (bytes == null || !mounted) return;

      if (kIsWeb) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'aetron_workout.png',
            ),
          ],
          text: _buildCaption(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colors.surface2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: 0.6),
                ),
              ),
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isVi
                          ? 'Đã tải ảnh buổi tập thành công!'
                          : 'Workout card image ready to save!',
                      style: KineticTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return;
      }

      final ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth || ps.hasAccess) {
        await PhotoManager.editor.saveImage(
          bytes,
          filename: 'aetron_workout_${DateTime.now().millisecondsSinceEpoch}.png',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colors.surface2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: 0.6),
                ),
              ),
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isVi
                          ? 'Đã lưu ảnh buổi tập vào Thư viện ảnh!'
                          : 'Workout card saved to Photos!',
                      style: KineticTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colors.surface2,
              content: Text(
                isVi
                    ? 'Vui lòng cấp quyền truy cập ảnh để lưu'
                    : 'Please allow photo access to save',
                style: TextStyle(color: colors.textPrimary),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _copyCaption() async {
    HapticFeedback.lightImpact();
    final isVi = widget.currentLang == AppLanguage.vi;
    final colors = context.kinetic;
    await Clipboard.setData(ClipboardData(text: _buildCaption()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.surface2,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colors.primary.withValues(alpha: 0.6),
            ),
          ),
          content: Row(
            children: [
              Icon(Icons.copy_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isVi
                      ? 'Đã sao chép nội dung buổi tập vào Clipboard!'
                      : 'Workout caption copied to clipboard!',
                  style: KineticTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = widget.currentLang == AppLanguage.vi;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: colors.borderSubtle.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.15),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(Icons.ios_share_rounded,
                          color: colors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'CHIA SẺ BUỔI TẬP' : 'SHARE WORKOUT',
                          style: KineticTypography.pageEyebrow.copyWith(
                            color: colors.primary,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isVi ? 'Thẻ Vinh Danh Thành Tích' : 'Achievement Card',
                          style: KineticTypography.headlineSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Theme Selector Chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _ThemePill(
                      label: '⚡ Cyber Neon',
                      color: const Color(0xFF00E5FF),
                      isSelected: _selectedTheme == ShareCardTheme.cyberNeon,
                      onTap: () => setState(
                          () => _selectedTheme = ShareCardTheme.cyberNeon),
                    ),
                    const SizedBox(width: 8),
                    _ThemePill(
                      label: '🔥 Solar Flare',
                      color: const Color(0xFFF8C15C),
                      isSelected: _selectedTheme == ShareCardTheme.solarFlare,
                      onTap: () => setState(
                          () => _selectedTheme = ShareCardTheme.solarFlare),
                    ),
                    const SizedBox(width: 8),
                    _ThemePill(
                      label: '🌿 Matrix Mint',
                      color: const Color(0xFF7DF9A8),
                      isSelected: _selectedTheme == ShareCardTheme.matrixMint,
                      onTap: () => setState(
                          () => _selectedTheme = ShareCardTheme.matrixMint),
                    ),
                    const SizedBox(width: 8),
                    _ThemePill(
                      label: '💜 Quantum Violet',
                      color: const Color(0xFFA55EEA),
                      isSelected:
                          _selectedTheme == ShareCardTheme.quantumViolet,
                      onTap: () => setState(
                          () => _selectedTheme = ShareCardTheme.quantumViolet),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Capturable Card View
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ScaleTransition(
                  scale: _enterAnim,
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: _ShareCardContent(
                      activityType: widget.activityType,
                      distanceKm: widget.distanceKm,
                      durationSeconds: widget.durationSeconds,
                      avgSpeedKmh: widget.avgSpeedKmh,
                      calories: widget.calories,
                      steps: widget.steps,
                      useMetricUnits: widget.useMetricUnits,
                      currentLang: widget.currentLang,
                      theme: _selectedTheme,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section 1: Social Targets (FB, Zalo, Messenger, Instagram)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'CHỌN MẠNG XÃ HỘI' : 'SHARE TO SOCIALS',
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Facebook
                        _SocialAppButton(
                          label: 'Facebook',
                          color: const Color(0xFF1877F2),
                          icon: Icons.facebook_rounded,
                          onTap: () => _shareToApp(
                            scheme: 'fb://',
                            appName: 'Facebook',
                          ),
                        ),
                        // Zalo
                        _SocialAppButton(
                          label: 'Zalo',
                          color: const Color(0xFF0068FF),
                          customText: 'Zalo',
                          onTap: () => _shareToApp(
                            scheme: 'zalo://',
                            appName: 'Zalo',
                          ),
                        ),
                        // Messenger
                        _SocialAppButton(
                          label: 'Messenger',
                          color: const Color(0xFF0084FF),
                          icon: Icons.chat_bubble_rounded,
                          onTap: () => _shareToApp(
                            scheme: 'fb-messenger://',
                            appName: 'Messenger',
                          ),
                        ),
                        // Instagram
                        _SocialAppButton(
                          label: 'Instagram',
                          color: const Color(0xFFE1306C),
                          icon: Icons.camera_alt_rounded,
                          onTap: () => _shareToApp(
                            scheme: 'instagram://',
                            appName: 'Instagram',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Quick Utility Actions (Save, Copy, Native Share)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Save to Photos
                    Expanded(
                      child: _ActionSquareButton(
                        icon: Icons.save_alt_rounded,
                        label: isVi ? 'Lưu ảnh' : 'Save Image',
                        color: const Color(0xFF7DF9A8),
                        onTap: _saveToPhotos,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Copy Caption
                    Expanded(
                      child: _ActionSquareButton(
                        icon: Icons.copy_rounded,
                        label: isVi ? 'Sao chép' : 'Copy Text',
                        color: const Color(0xFFF8C15C),
                        onTap: _copyCaption,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Native Share Sheet
                    Expanded(
                      child: _ActionSquareButton(
                        icon: Icons.share_rounded,
                        label: isVi ? 'Khác...' : 'More...',
                        color: colors.primary,
                        onTap: _shareToNative,
                      ),
                    ),
                  ],
                ),
              ),

              if (_isProcessing) ...[
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : colors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : colors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: -1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: KineticTypography.label.copyWith(
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? color : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SocialAppButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final String? customText;
  final VoidCallback onTap;

  const _SocialAppButton({
    required this.label,
    required this.color,
    this.icon,
    this.customText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: customText != null
                  ? Text(
                      customText!,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: 26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: KineticTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionSquareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.borderSubtle.withValues(alpha: 0.8),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: KineticTypography.label.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The actual share card visual that gets captured.
class _ShareCardContent extends StatelessWidget {
  final String activityType;
  final double distanceKm;
  final int durationSeconds;
  final double avgSpeedKmh;
  final int calories;
  final int steps;
  final bool useMetricUnits;
  final AppLanguage currentLang;
  final ShareCardTheme theme;

  const _ShareCardContent({
    required this.activityType,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgSpeedKmh,
    required this.calories,
    required this.steps,
    required this.useMetricUnits,
    required this.currentLang,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final distStr = WorkoutFormatters.formatDistance(distanceKm,
        useMetric: useMetricUnits, decimals: 2);
    final paceStr = WorkoutFormatters.formatPaceFromSpeedKmh(avgSpeedKmh,
        useMetric: useMetricUnits);
    final durationStr =
        WorkoutFormatters.formatDurationFromSeconds(durationSeconds);
    final actLabel =
        WorkoutFormatters.formatActivityType(activityType, currentLang)
            .toUpperCase();
    final hasSteps = (activityType.toLowerCase() == 'running' ||
            activityType.toLowerCase() == 'walking') &&
        steps > 0;

    final (accentColor, glowColor, bgColors) = switch (theme) {
      ShareCardTheme.solarFlare => (
          const Color(0xFFF8C15C),
          const Color(0xFFFF9F1C),
          const [Color(0xFF140A04), Color(0xFF221105), Color(0xFF100702)],
        ),
      ShareCardTheme.matrixMint => (
          const Color(0xFF7DF9A8),
          const Color(0xFF2EC4B6),
          const [Color(0xFF031410), Color(0xFF06201B), Color(0xFF02100C)],
        ),
      ShareCardTheme.quantumViolet => (
          const Color(0xFFA55EEA),
          const Color(0xFF8854D0),
          const [Color(0xFF11071F), Color(0xFF1B0C30), Color(0xFF0C0416)],
        ),
      ShareCardTheme.cyberNeon => (
          const Color(0xFF00E5FF),
          const Color(0xFF7DF9A8),
          const [Color(0xFF060C1C), Color(0xFF0B1530), Color(0xFF05111F)],
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgColors,
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Stack(
          children: [
            // Background Grid Lines
            Positioned.fill(
                child: CustomPaint(
                    painter: _GridLinePainter(lineColor: accentColor))),

            // Background Ambient Glow Orbs
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glowColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Card Foreground Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row: Logo + Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withValues(alpha: 0.18),
                              border: Border.all(
                                  color: accentColor.withValues(alpha: 0.5)),
                            ),
                            child: Icon(
                              Icons.bolt_rounded,
                              color: accentColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AETRON',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Activity Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '⚡ $actLabel',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Big Hero Distance
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        distStr,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          fontFeatures: KineticTypography.tabularFigures,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          isVi ? 'KHOẢNG CÁCH' : 'DISTANCE',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Neon Divider
                  Container(
                    height: 1.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.8),
                          accentColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stats Row 1
                  Row(
                    children: [
                      Expanded(
                        child: _ShareStat(
                          icon: Icons.timer_rounded,
                          label: isVi ? 'THỜI GIAN' : 'DURATION',
                          value: durationStr,
                          color: accentColor,
                        ),
                      ),
                      Expanded(
                        child: _ShareStat(
                          icon: Icons.speed_rounded,
                          label: isVi ? 'PACE TB' : 'AVG PACE',
                          value: paceStr,
                          color: glowColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stats Row 2
                  Row(
                    children: [
                      Expanded(
                        child: _ShareStat(
                          icon: Icons.local_fire_department_rounded,
                          label: isVi ? 'CALO ĐỐT' : 'CALORIES',
                          value: '$calories kcal',
                          color: const Color(0xFFF8C15C),
                        ),
                      ),
                      if (hasSteps)
                        Expanded(
                          child: _ShareStat(
                            icon: Icons.directions_walk_rounded,
                            label: isVi ? 'SỐ BƯỚC' : 'STEPS',
                            value: '$steps',
                            color: const Color(0xFFA55EEA),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bottom Watermark
                  Center(
                    child: Text(
                      isVi
                          ? 'Đồng hành cùng mỗi bước chạy của bạn — Aetron'
                          : 'Your personal fitness telemetry companion — Aetron',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 0.4,
                      ),
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

class _ShareStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ShareStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontFeatures: KineticTypography.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GridLinePainter extends CustomPainter {
  final Color lineColor;

  _GridLinePainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    const spacing = 28.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final cornerPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width, 0), radius: 80),
      math.pi / 2,
      math.pi / 2,
      false,
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GridLinePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
