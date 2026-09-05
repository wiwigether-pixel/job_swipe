import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/core/theme/app_colors.dart';

void main() {
  test('dark token 值正確', () {
    expect(AppColors.dark.background, const Color(0xFF000000));
    expect(AppColors.dark.surface, const Color(0xFF1A1A1A));
    expect(AppColors.dark.textPrimary, Colors.white);
    expect(AppColors.dark.danger, const Color(0xFFFF4757));
  });

  test('light token 值正確', () {
    expect(AppColors.light.background, const Color(0xFFF5F5F7));
    expect(AppColors.light.surface, const Color(0xFFFFFFFF));
    expect(AppColors.light.textPrimary, const Color(0xFF1A1A1A));
    expect(AppColors.light.divider, const Color(0xFFE5E5EA));
  });

  test('lerp 中點不丟例外且回傳 AppColors', () {
    final mid = AppColors.dark.lerp(AppColors.light, 0.5);
    expect(mid, isA<AppColors>());
  });

  testWidgets('context.colors 從 Theme extension 取得', (tester) async {
    late AppColors got;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.dark]),
      home: Builder(builder: (context) {
        got = context.colors;
        return const SizedBox();
      }),
    ));
    expect(got.surface, const Color(0xFF1A1A1A));
  });
}
