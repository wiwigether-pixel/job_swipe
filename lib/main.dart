import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

/// 全域 Logger
final logger = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── 【防崩潰機制】 ───
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.e('Flutter Framework Error', error: details.exception, stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Platform Error', error: error, stackTrace: stack);
    return true;
  };

  // 🚀 初始化核心服務
  await _initServices();

  runApp(
    const ProviderScope(
      child: JobSwipeApp(),
    ),
  );
}

/// 負責所有異步服務的初始化（自動相容 GitHub Secrets 與本地 .env）
Future<void> _initServices() async {
  try {
    // 1. 嘗試載入 .env (僅限本地開發，線上環境若缺失會被 catch 捕獲但不崩潰)
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      logger.w('⚠️ 未能加載 .env 檔案，將嘗試使用編譯時注入的環境變數');
    }

    // 2. 獲取變數 (優先序：dart-define > .env 檔案)
    // 注意：String.fromEnvironment 必須使用 const 關鍵字
    const String defineUrl = String.fromEnvironment('SUPABASE_URL');
    const String defineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    final String supabaseUrl = defineUrl.isNotEmpty 
        ? defineUrl 
        : (dotenv.maybeGet('SUPABASE_URL') ?? '');
        
    final String supabaseAnonKey = defineKey.isNotEmpty 
        ? defineKey 
        : (dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '');

    // 3. 驗證變數是否取得成功
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      logger.e('❌ 錯誤：找不到 Supabase 設定！\n'
               '本地請檢查 .env 檔案，線上請檢查 GitHub Secrets 是否設定為 SUPABASE_URL 與 SUPABASE_ANON_KEY');
      return; 
    }

    // 4. 正式初始化 Supabase
    await Supabase.initialize(
      url: supabaseUrl, 
      anonKey: supabaseAnonKey,
    );

    logger.i('✅ Supabase 初始化成功 (${defineUrl.isNotEmpty ? "生產模式/CI" : "本地開發模式"})');
  } catch (e) {
    logger.e('❌ Supabase 初始化失敗: $e');
  }
}