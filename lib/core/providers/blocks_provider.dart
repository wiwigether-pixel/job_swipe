import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'blocks_provider.g.dart';

/// 雙向封鎖名單：我封鎖的 + 封鎖我的（後者走 SECURITY DEFINER RPC）。
@Riverpod(keepAlive: true)
class BlockedIds extends _$BlockedIds {
  @override
  Future<Set<String>> build() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return {};
    final mine = await client.from('blocks').select('blocked_id');
    final blockedMe = await client.rpc('get_blocked_me');
    return {
      ...(mine as List).map((r) => (r as Map)['blocked_id'] as String),
      ...(blockedMe as List).map((e) => e as String),
    };
  }

  Future<void> block(String userId) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    await client.from('blocks').insert({
      'blocker_id': user.id,
      'blocked_id': userId,
    });
    ref.invalidateSelf();
  }

  Future<void> unblock(String userId) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    await client
        .from('blocks')
        .delete()
        .eq('blocker_id', user.id)
        .eq('blocked_id', userId);
    ref.invalidateSelf();
  }
}
