import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_exception.dart';

class ErrorHandler {
  static AppException handle(Object error, [StackTrace? stackTrace]) {
    // 1. 處理 Supabase 的認證錯誤
    if (error is AuthException) {
      return AppAuthException(error.message, error.statusCode);
    }

    // 2. 處理已經是 AppException 的錯誤
    if (error is AppException) {
      return error;
    }

    // 3. 處理其他未知錯誤
    return AppUnknownException(error.toString());
  }
}