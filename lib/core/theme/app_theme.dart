import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const radius = 22.0;
  static const radiusSmall = 14.0;
  static const pagePadding = 20.0;

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.sky,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.sky,
          onPrimary: AppColors.ink,
          secondary: AppColors.pink,
          onSecondary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.ink,
          error: AppColors.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.white,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

    final text = GoogleFonts.poppinsTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    return base.copyWith(
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: text.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 12.5,
          height: 1.4,
          color: AppColors.inkSoft,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.skyMist,
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
        labelStyle: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _inputBorder(AppColors.line),
        enabledBorder: _inputBorder(AppColors.line),
        focusedBorder: _inputBorder(AppColors.sky, width: 1.6),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.sky,
        inactiveTrackColor: AppColors.skySoft,
        thumbColor: AppColors.pink,
        overlayColor: AppColors.pink.withValues(alpha: 0.12),
        trackHeight: 6,
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pink
              : AppColors.line,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(color: color, width: width),
      );
}
