import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
}

abstract class AppTheme {
  static ThemeData dark() => _base(AppColors.dark, Brightness.dark);
  static ThemeData light() => _base(AppColors.light, Brightness.light);

  static ThemeData _base(AppColors c, Brightness b) {
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme:
          ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), brightness: b),
      scaffoldBackgroundColor: c.background,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface),
      dividerColor: c.divider,
      extensions: [c],
    );
  }
}
