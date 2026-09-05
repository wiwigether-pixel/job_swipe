import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/core/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('預設 system；set 後更新 state 並寫入 prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeSettingProvider), ThemeMode.system);

    await container.read(themeModeSettingProvider.notifier).set(ThemeMode.light);
    expect(container.read(themeModeSettingProvider), ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
  });

  test('啟動時從 prefs 載入既存值', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeModeSettingProvider); // 觸發 build
    await Future<void>.delayed(Duration.zero); // 等 _load
    expect(container.read(themeModeSettingProvider), ThemeMode.dark);
  });
}
