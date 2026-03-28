import '../../../shared/models/user_model.dart';

/// Auth Repository 介面（抽象層）
/// 【為什麼要有介面】
/// - 測試時可以換成 MockAuthRepository，不需要真實網路
/// - 未來換後端（Firebase、自建 API）只需要換實作，不動 UI
abstract interface class AuthRepository {
  /// 取得目前登入的使用者（未登入回傳 null）
  UserModel? get currentUser;

  /// 監聽登入狀態變化的 Stream
  Stream<UserModel?> get authStateStream;

  /// Email 登入
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  /// Email 註冊
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  });

  /// 登出
  Future<void> signOut();
}
