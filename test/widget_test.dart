import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 只測試一個獨立 Widget，不啟動完整 App（避免需要真實 Supabase 連線）
void main() {
  testWidgets('Smoke test - App skeleton renders without crash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: Text('JobSwipe')),
          ),
        ),
      ),
    );

    // 確認畫面有渲染出文字，沒有拋出例外
    expect(find.text('JobSwipe'), findsOneWidget);
  });
}