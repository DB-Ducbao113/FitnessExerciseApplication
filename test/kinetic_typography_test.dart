import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kinetic typography', () {
    test('uses Space Grotesk for display and telemetry styles', () {
      expect(KineticTypography.displayFontFamily, 'SpaceGrotesk');
      expect(
        [
          KineticTypography.metricHero,
          KineticTypography.metricMedium,
          KineticTypography.displayLarge,
          KineticTypography.headlineLarge,
          KineticTypography.pageTitle,
          KineticTypography.label,
        ].map((style) => style.fontFamily),
        everyElement(KineticTypography.displayFontFamily),
      );
    });

    test('uses Be Vietnam Pro for Vietnamese body copy', () {
      expect(KineticTypography.bodyFontFamily, 'BeVietnamPro');
      expect(
        [
          KineticTypography.bodyLarge,
          KineticTypography.bodyMedium,
          KineticTypography.bodySmall,
          KineticTypography.caption,
          KineticTypography.greeting,
        ].map((style) => style.fontFamily),
        everyElement(KineticTypography.bodyFontFamily),
      );
    });

    test('uses a supported Space Grotesk weight for prominent styles', () {
      expect(KineticTypography.metricHero.fontWeight, FontWeight.w700);
      expect(KineticTypography.displayLarge.fontWeight, FontWeight.w700);
      expect(KineticTypography.pageTitle.fontWeight, FontWeight.w700);
    });

    test('defaults unstyled app text to Be Vietnam Pro', () {
      for (final brightness in Brightness.values) {
        final theme = KineticTheme.buildTheme(brightness);
        expect(theme.textTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
        expect(theme.primaryTextTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
      }
    });
  });
}
