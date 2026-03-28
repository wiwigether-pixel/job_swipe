/// 基礎應用程式例外類別
sealed class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: $message ${code != null ? "($code)" : ""}';
}

/// 認證相關例外
class AppAuthException extends AppException {
  AppAuthException(super.message, [super.code]);
}

/// 網路相關例外
class AppNetworkException extends AppException {
  AppNetworkException(super.message, [super.code]);
}

/// 未知或通用例外
class AppUnknownException extends AppException {
  AppUnknownException(super.message, [super.code]);
}