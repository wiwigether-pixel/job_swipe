import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/core/theme/app_colors.dart';
import 'package:job_swipe/core/theme/app_theme.dart';

void main() {
  test('dark theme 掛上 AppColors.dark 且 scaffold 背景正確', () {
    final t = AppTheme.dark();
    expect(t.brightness, Brightness.dark);
    expect(t.extension<AppColors>(), AppColors.dark);
    expect(t.scaffoldBackgroundColor, AppColors.dark.background);
  });

  test('light theme 掛上 AppColors.light', () {
    final t = AppTheme.light();
    expect(t.brightness, Brightness.light);
    expect(t.extension<AppColors>(), AppColors.light);
    expect(t.scaffoldBackgroundColor, AppColors.light.background);
  });

  test('spacing/radius 常數', () {
    expect(AppSpacing.lg, 16.0);
    expect(AppRadius.md, 16.0);
  });
}
