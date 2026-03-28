import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';  // 导入 dotenv
import 'package:supabase_flutter/supabase_flutter.dart';  // 导入 Supabase
import 'app.dart';

/// 全域 Logger（整個 App 共用）
final logger = Logger();

Future<void> main() async {
  // 1. 确保 Flutter binding 初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 加载 .env 文件
  await dotenv.load();

  // ─── 【防崩溃机制 1】捕获 Flutter Framework 内部错误 ───
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.e(
      'Flutter Framework Error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // ─── 【防崩溃机制 2】捕获所有异步异常 ───
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Platform Error', error: error, stackTrace: stack);
    return true;
  };

  // 3. 🚀 初始化核心服务
  // 这里改为 await 是为了确保 App 启动时，Auth 状态已经就绪
  // 这样 Router 才能第一时间判断用户该去 Onboarding 还是 Swipe
  await _initServices();

  // 4. 启动 App
  runApp(
    const ProviderScope(
      child: JobSwipeApp(),
    ),
  );
}

/// 负责所有异步服务的初始化
Future<void> _initServices() async {
  try {
    // 从 .env 文件中读取 Supabase URL 和 Anon Key
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    // 确保从 .env 文件加载成功
    if (supabaseUrl == null || supabaseAnonKey == null) {
      logger.e('❌ 缺少 Supabase URL 或 Anon Key');
      return;
    }

    // 初始化 Supabase
    await Supabase.initialize(
      url: supabaseUrl, 
      anonKey: supabaseAnonKey,
    );

    logger.i('✅ Supabase 初始化成功');
  } catch (e) {
    logger.e('❌ Supabase 初始化失败: $e');
  }
}