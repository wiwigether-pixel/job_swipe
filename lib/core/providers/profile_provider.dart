import 'package:job_swipe/core/utils/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_model.dart';
import '../../features/auth/presentation/auth_provider.dart';

part 'profile_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<UserModel?> profile(ProfileRef ref) {
  final supabase = Supabase.instance.client;

  final authAsync = ref.watch(authStateProvider);
  final sdkUser = supabase.auth.currentUser;
  final authUserId = authAsync.valueOrNull?.id;
  final userId = sdkUser?.id ?? authUserId;

  logger.i('[Profile] stream build: userId=$userId');

  if (userId == null) {
    logger.i('[Profile] stream: no user, returning null stream');
    return Stream.value(null);
  }

  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      // 過濾掉空陣列，等待 Supabase realtime 推送真正的資料
      // 不用 asyncMap，避免時序問題拿到寫入前的舊值
      .where((data) => data.isNotEmpty)
      .map((data) {
        logger.i('[Profile] stream raw: ${data.first}');
        final model = UserModel.fromSupabase(data.first);
        logger.i('[Profile] parsed: displayName=${model.displayName}, '
            'avatarUrl=${model.avatarUrl}, '
            'isProfileComplete=${model.isProfileComplete}');
        return model;
      });
}