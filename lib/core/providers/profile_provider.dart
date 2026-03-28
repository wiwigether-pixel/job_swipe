import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_model.dart';
import '../../features/auth/presentation/auth_provider.dart';

part 'profile_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<UserModel?> profile(ProfileRef ref) {
  final supabase = Supabase.instance.client;

  // watch authRepository 讓 auth 狀態改變時重新建立 stream
  // 不直接用它的 currentUser，只是借它觸發重建
  ref.watch(authRepositoryProvider);

  // 從 Supabase SDK 直接取得當前 user
  final user = supabase.auth.currentUser;

  debugPrint('[Profile] stream build: userId=${user?.id}');

  if (user == null) {
    debugPrint('[Profile] stream: no user, returning null stream');
    return Stream.value(null);
  }

  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((data) {
        if (data.isEmpty) {
          debugPrint('[Profile] stream: data is empty');
          return null;
        }
        debugPrint('[Profile] stream raw: ${data.first}');
        final model = UserModel.fromSupabase(data.first);
        debugPrint('[Profile] parsed: displayName=${model.displayName}, avatarUrl=${model.avatarUrl}, isProfileComplete=${model.isProfileComplete}');
        return model;
      });
}