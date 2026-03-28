import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_model.dart';
import 'profile_provider.dart';

part 'current_role_provider.g.dart';

@Riverpod(keepAlive: true)
class CurrentRole extends _$CurrentRole {
  bool _manuallySet = false; // 手動切換後不讓 profile stream 覆蓋

  @override
  AppRole build() {
    final profileAsync = ref.watch(profileProvider);

    // 只在尚未手動切換時跟隨 profile
    if (!_manuallySet) {
      return profileAsync.valueOrNull?.effectiveRole ?? AppRole.jobSeeker;
    }
    return state;
  }

  Future<void> switchRole(AppRole newRole) async {
    _manuallySet = true;
    state = newRole; // 立即更新 UI

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('users')
          .update({'current_role': newRole.toDbString}).eq('id', user.id);
      // 不 invalidate profileProvider，避免 stream 重讀覆蓋 state
    } catch (e) {
      // 失敗時回滾
      _manuallySet = false;
      final profileAsync = ref.read(profileProvider);
      state = profileAsync.valueOrNull?.effectiveRole ?? AppRole.jobSeeker;
      rethrow;
    }
  }

  /// 登出時重置
  void reset() {
    _manuallySet = false;
  }
}