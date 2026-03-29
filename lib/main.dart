
import 'package:flutter/foundation.dart'; // 為了使用 kReleaseMode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 引入剛才建立的 logger
import 'core/utils/logger.dart'; 
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── 【防崩潰機制】 ───
  // 只有在非發布模式下才把錯誤印到 Console
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!kReleaseMode) {
      logger.e('Flutter Framework Error', error: details.exception, stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (!kReleaseMode) {
      logger.e('Platform Error', error: error, stackTrace: stack);
    }
    return true;
  };

  await _initServices();

  runApp(
    const ProviderScope(child: JobSwipeApp()),
  );
}

Future<void> _initServices() async {
  try {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // 這裡也使用 logger，發布後會自動消失
      logger.w('⚠️ 未能加載 .env 檔案，將嘗試使用編譯時注入的環境變數');
    }

    const String defineUrl = String.fromEnvironment('SUPABASE_URL');
    const String defineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    final String supabaseUrl = defineUrl.isNotEmpty 
        ? defineUrl 
        : (dotenv.maybeGet('SUPABASE_URL') ?? '');
        
    final String supabaseAnonKey = defineKey.isNotEmpty 
        ? defineKey 
        : (dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      logger.e('❌ 找不到 Supabase 設定！');
      return; 
    }

    await Supabase.initialize(
      url: supabaseUrl, 
      anonKey: supabaseAnonKey,
    );

    logger.i('✅ Supabase 初始化成功 (${defineUrl.isNotEmpty ? "生產模式" : "開發模式"})');
  } catch (e) {
    logger.e('❌ Supabase 初始化失敗: $e');
  }
}