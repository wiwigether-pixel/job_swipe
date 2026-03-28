import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 設定類別
/// 【安全實踐】URL 和 Key 應從環境變數讀取，永遠不要硬編碼在 git 裡！
class SupabaseConfig {
  // 【使用方式】
  // 開發時：在 .env 檔案設定，並加入 .gitignore
  // CI/CD：在 GitHub Secrets 設定
  // 這裡用 String.fromEnvironment 讀取編譯時環境變數
  static const _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    // 【防呆】如果忘記設定環境變數，會在啟動時立即報錯，而不是靜默失敗
    defaultValue: '',
  );

  static const _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// 初始化 Supabase，必須在 main() 中 await 這個方法
  static Future<void> initialize() async {
    // 防呆檢查：確保環境變數有設定
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw Exception(
        '''
        ❌ Supabase 環境變數未設定！
        請確認以下步驟：
        1. 複製 .env.example 為 .env
        2. 填入你的 Supabase URL 和 Anon Key
        3. 執行時加上 --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
        或在 launch.json 中設定 dart-defines
        ''',
      );
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      // 開發模式下開啟詳細 log，正式環境關閉
      debug: kDebugMode,
    );
  }

  /// 取得 Supabase Client 的便捷 getter
  /// 使用方式：SupabaseConfig.client.from('users').select()
  static SupabaseClient get client => Supabase.instance.client;
}