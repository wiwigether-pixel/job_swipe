import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/error/app_exception.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/models/user_model.dart';
import '../domain/auth_repository.dart';

// SharedPreferences 的 key
const _kPendingProfileKey = 'pending_profile';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository() {
    _initAuthListener();
  }

  UserModel? _currentUser;
  final _authStateController = StreamController<UserModel?>.broadcast();
  StreamSubscription<sb.AuthState>? _authSubscription;

  void _initAuthListener() {
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen(
      (data) async {
        final session = data.session;
        debugPrint('[AuthListener] event=${data.event}, hasSession=${session != null}');

        if (session == null) {
          _currentUser = null;
          _authStateController.add(null);
          return;
        }

        if (data.event == sb.AuthChangeEvent.signedIn ||
            data.event == sb.AuthChangeEvent.initialSession) {
          try {
            // 【方案 B 核心】先嘗試抓 profile
            // 如果沒有（新用戶驗證完信箱第一次登入），就用暫存資料建立
            final user = await _fetchOrCreateProfile(session.user.id, session.user.email);
            _currentUser = user;
            _authStateController.add(user);
          } catch (e) {
            debugPrint('[AuthListener] 抓取/建立 Profile 失敗: $e');
          }
        }
      },
    );
  }

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Stream<UserModel?> get authStateStream => _authStateController.stream;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) {
        throw AppAuthException('無法取得使用者 ID', 'AUTH_NO_USER');
      }

      return await _fetchOrCreateProfile(userId, email);
    } on sb.AuthException catch (e, stack) {
      throw ErrorHandler.handle(e, stack);
    } catch (e, stack) {
      throw ErrorHandler.handle(e, stack);
    }
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      debugPrint('[Register] Step1: 開始 signUp...');

      // 【方案 B】先把 displayName 和 role 存到本地
      // 等信箱驗證完登入後，再用這些資料建立 profile
      await _savePendingProfile(
        displayName: displayName,
        role: role,
        email: email,
      );
      debugPrint('[Register] ✅ 暫存 profile 資料到本地');

      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      debugPrint('[Register] userId=$userId');
      debugPrint('[Register] session=${response.session != null ? "有" : "無"}');

      if (userId == null) {
        throw AppAuthException('無法建立帳號', 'AUTH_SIGNUP_FAILED');
      }

      // Email Confirmation 開啟：沒有 session 是正常的
      // 告訴使用者去收信，不是錯誤
      if (response.session == null) {
        debugPrint('[Register] ✅ 驗證信已寄出，等待使用者確認');
        // 回傳一個「待驗證」的假 UserModel，讓 UI 知道註冊成功
        // 真正的 profile 會在登入後的 _fetchOrCreateProfile 建立
        throw AppAuthException(
          '註冊成功！請至信箱點擊驗證連結後再登入',
          'AUTH_EMAIL_CONFIRM_REQUIRED',
        );
      }

      // Email Confirmation 關閉時（開發模式）：直接建立 profile
      await Future.delayed(const Duration(milliseconds: 500));
      return await _fetchOrCreateProfile(userId, email);
    } on AppAuthException {
      rethrow;
    } on sb.PostgrestException catch (e, stack) {
      debugPrint('[Register] ❌ PostgrestException: code=${e.code}, message=${e.message}');
      throw ErrorHandler.handle(e, stack);
    } catch (e, stack) {
      debugPrint('[Register] ❌ 未知錯誤: $e');
      throw ErrorHandler.handle(e, stack);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await SupabaseConfig.client.auth.signOut();
      _currentUser = null;
      _authStateController.add(null);
    } catch (e, stack) {
      throw ErrorHandler.handle(e, stack);
    }
  }

  /// 抓取 profile，如果不存在就用本地暫存資料建立
  Future<UserModel> _fetchOrCreateProfile(String userId, String? email) async {
    // 先嘗試抓現有 profile
    final existing = await SupabaseConfig.client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (existing != null) {
      debugPrint('[Profile] ✅ 找到現有 profile');
      final user = UserModel.fromSupabase(existing);
      _currentUser = user;
      return user;
    }

    // 沒有 profile：嘗試用本地暫存資料建立
    debugPrint('[Profile] 無現有 profile，嘗試從暫存建立...');
    final pending = await _loadPendingProfile();

    if (pending == null) {
      debugPrint('[Profile] ❌ 無暫存資料，無法建立 profile');
      throw AppAuthException('找不到個人資料，請重新註冊', 'USER_PROFILE_NOT_FOUND');
    }

    debugPrint('[Profile] 暫存資料: $pending');

    // 建立 profile
    await SupabaseConfig.client.from('users').insert({
      'id': userId,
      'role': pending['role'],
      'display_name': pending['display_name'],
      'email': email ?? pending['email'] ?? '',
    });

    debugPrint('[Profile] ✅ profile 建立成功');

    // 清除暫存（只用一次）
    await _clearPendingProfile();

    // 抓取剛建立的 profile 回傳
    final data = await SupabaseConfig.client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    final user = UserModel.fromSupabase(data);
    _currentUser = user;
    return user;
  }

  /// 把註冊資料暫存到 SharedPreferences
  Future<void> _savePendingProfile({
    required String displayName,
    required UserRole role,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPendingProfileKey,
      jsonEncode({
        'display_name': displayName,
        'role': role.toDbString,
        'email': email,
      }),
    );
  }

  /// 讀取暫存的註冊資料
  Future<Map<String, dynamic>?> _loadPendingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingProfileKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// 清除暫存資料
  Future<void> _clearPendingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingProfileKey);
  }

  void dispose() {
    _authSubscription?.cancel();
    _authStateController.close();
  }
}