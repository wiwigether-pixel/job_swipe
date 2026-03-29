
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_model.dart';
import 'profile_provider.dart';
import 'package:job_swipe/core/utils/logger.dart';
part 'current_role_provider.g.dart';

@Riverpod(keepAlive: true)
class CurrentRole extends _$CurrentRole {
  bool _manuallySet = false;

  @override
  AppRole build() {
    final profileAsync = ref.watch(profileProvider);

    if (!_manuallySet) {
      // users.role 就是當前身份，直接讀
      // profileProvider stream 更新後這裡自動跟著變
      return profileAsync.valueOrNull?.effectiveRole ?? AppRole.jobSeeker;
    }
    return state;
  }

  /// 切換身份：更新 users.role
  /// 回傳 needsOnboarding：
  ///   - peer → 不需要，回傳 false
  ///   - jobSeeker/employer → 檢查 user_profiles 是否已填寫
  Future<bool> switchRole(AppRole newRole) async {
    _manuallySet = true;
    state = newRole; // 立即更新 UI

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      // 直接更新 users.role（這就是當前身份的儲存位置）
      // profileProvider stream 會收到更新，currentRoleProvider.build() 重新執行
      // 但因為 _manuallySet=true，build() 會 return state 而不覆蓋
      await Supabase.instance.client
          .from('users')
          .update({'role': newRole.toDbString})
          .eq('id', user.id);

      logger.i('[CurrentRole] users.role 更新為 ${newRole.toDbString}');
    } catch (e) {
      logger.i('[CurrentRole] 更新 users.role 失敗: $e');
      _manuallySet = false;
      state = ref.read(profileProvider).valueOrNull?.effectiveRole
          ?? AppRole.jobSeeker;
      return false;
    }

    // peer 不需要填任何 onboarding
    if (newRole == AppRole.peer) return false;

    try {
      // 檢查這個身份的 user_profiles 是否已存在且完整
      final existing = await Supabase.instance.client
          .from('user_profiles')
          .select('is_complete')
          .eq('user_id', user.id)
          .eq('role', newRole.toDbString)
          .maybeSingle();

      final isComplete = existing?['is_complete'] == true;
      logger.i('[CurrentRole] role=${newRole.toDbString}, '
          'profileComplete=$isComplete');
      return !isComplete;
    } catch (e) {
      logger.i('[CurrentRole] 檢查 user_profiles 失敗: $e');
      return false;
    }
  }

  void reset() {
    _manuallySet = false;
  }
}