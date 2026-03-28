// lib/core/services/profile_service_stub.dart

import 'dart:async';

// 確保名稱、參數與 Web 版完全一致
Future<String?> callWebUpload({
  required String storagePath,
  required String base64Data,
  required String contentType,
  required String accessToken,
}) async {
  // 在非 Web 環境下，這個函式不應該被執行到，因為主程式有 kIsWeb 判斷
  return null; 
}