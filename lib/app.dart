import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';

/// App 根 Widget
/// 使用 ConsumerWidget 讓它能讀取 Riverpod Provider
class JobSwipeApp extends ConsumerWidget {
  const JobSwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 從 Riverpod 取得 GoRouter 實例
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'JobSwipe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      routerConfig: router,
      // 【防崩潰】Widget 層級的錯誤邊界（Builder 模式）
      builder: (context, child) {
        return _GlobalErrorBoundary(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

/// 全域 Widget 錯誤邊界
/// 當任何子 Widget 的 build 方法拋出例外時，顯示友善的錯誤畫面
class _GlobalErrorBoundary extends StatefulWidget {
  const _GlobalErrorBoundary({required this.child});
  final Widget child;

  @override
  State<_GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<_GlobalErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // 顯示友善的錯誤畫面，不讓使用者看到紅色死亡畫面
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  '哎呀，出了一點問題',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('請嘗試重新啟動 App'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('重試'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}