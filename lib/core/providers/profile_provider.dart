import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_model.dart';
import '../../features/auth/presentation/auth_provider.dart';

part 'profile_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<UserModel?> profile(ProfileRef ref) {
  final supabase = Supabase.instance.client;

  // 1. 監聽 authStateProvider 以觸發重建
  final authAsync = ref.watch(authStateProvider);

  // 2. 【關鍵修正】顯式指定 User? 型別，解決 Object undefined getter 'id' 的問題
  // 我們從 SDK 同步取得，或從 Provider 的異步值中取得（Fallback）
  final User? user = supabase.auth.currentUser ?? 
                    (authAsync.valueOrNull is User ? authAsync.valueOrNull as User : null);

  debugPrint('[Profile] stream build: userId=${user?.id}');

  if (user == null) {
    debugPrint('[Profile] stream: no user, returning null stream');
    return Stream.value(null);
  }

  // 3. 此時 user 已被推斷為 User，.id 就不會噴錯了
  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((data) {
        if (data.isEmpty) {
          debugPrint('[Profile] stream: data is empty');
          return null;
        }
        
        final model = UserModel.fromSupabase(data.first);
        debugPrint('[Profile] parsed: displayName=${model.displayName}, '
            'isProfileComplete=${model.isProfileComplete}');
        return model;
      });
}