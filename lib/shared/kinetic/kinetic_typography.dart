import 'package:flutter/material.dart';

class KineticTypography {
  const KineticTypography._();

  static const String fontFamily = 'Plus Jakarta Sans';

  /// Standard tabular figures feature for non-jittering telemetry digits
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];


  /// Hero Metric — Primary focal metric for recording, summary, details and streaks.
  static const TextStyle metricHero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 52,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Telemetry Metric (Medium)
  static const TextStyle metricMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.26,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Telemetry Metric (Small)
  static const TextStyle metricSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Display Large
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.64,
    height: 1.2,
  );

  /// Headline Large
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.48,
    height: 1.25,
  );

  /// Headline Medium
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.18,
    height: 1.3,
  );

  /// Headline Small
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// Body Large
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body Medium
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Body Small
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Unit Descriptors & Section Micro Labels (e.g. "BPM", "KM/H", "AVG PACE")
  static const TextStyle unitLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.88,
    height: 1.2,
  );

  /// Interactive Label
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.26,
    height: 1.2,
  );

  /// Tiêu đề page của 5 tab chính (Activity, Analytics, History, Profile, Settings).
  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.44, // -0.02em × 22
    height: 1.2,
  );

  /// Tiêu đề page con (Details, Summary, Achievements).
  static const TextStyle pageTitleCompact = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.18,
    height: 1.25,
  );

  /// Dòng nhỏ phía trên tiêu đề (eyebrow).
  static const TextStyle pageEyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
  );
}
