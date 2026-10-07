import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticTheme {
  const KineticTheme._();

  static ThemeData get darkTheme => buildTheme(Brightness.dark);
  static ThemeData get lightTheme => buildTheme(Brightness.light);

  static ThemeData buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? KineticColors.dark : KineticColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      fontFamily: KineticTypography.fontFamily,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        secondary: colors.secondary,
        onSecondary: colors.onPrimary,
        tertiary: colors.tertiary,
        onTertiary: colors.textPrimary,
        error: colors.error,
        onError: Colors.white,
        surface: colors.surface1,
        onSurface: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: KineticTypography.headlineMedium.copyWith(
          color: colors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: KineticTypography.label.copyWith(
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.surface2,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: colors.borderAccent, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: KineticTypography.label.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          textStyle: KineticTypography.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: KineticTypography.bodyMedium.copyWith(color: colors.textMuted),
        labelStyle: KineticTypography.bodyMedium.copyWith(color: colors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.error, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface2,
        modalBackgroundColor: colors.surface2,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface2,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.borderSubtle, width: 1),
        ),
        titleTextStyle: KineticTypography.headlineMedium.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: KineticTypography.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: KineticTypography.displayLarge.copyWith(color: colors.textPrimary),
        headlineLarge: KineticTypography.headlineLarge.copyWith(color: colors.textPrimary),
        headlineMedium: KineticTypography.headlineMedium.copyWith(color: colors.textPrimary),
        headlineSmall: KineticTypography.headlineSmall.copyWith(color: colors.textPrimary),
        bodyLarge: KineticTypography.bodyLarge.copyWith(color: colors.textPrimary),
        bodyMedium: KineticTypography.bodyMedium.copyWith(color: colors.textSecondary),
        bodySmall: KineticTypography.bodySmall.copyWith(color: colors.textMuted),
        labelLarge: KineticTypography.label.copyWith(color: colors.textPrimary),
        labelMedium: KineticTypography.unitLabel.copyWith(color: colors.textMuted),
      ),
    );
  }
}
