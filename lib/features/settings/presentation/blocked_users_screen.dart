import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/blocks_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/user_hydration.dart';

/// 只列「我封鎖的人」（不含封鎖我的），含公開資料 hydration。
final _myBlockedListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(blockedIdsProvider); // 封鎖/解除後自動刷新
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return [];
  final rows = await client
      .from('blocks')
      .select('blocked_id, created_at')
      .order('created_at', ascending: false);
  final ids =
      (rows as List).map((r) => (r as Map)['blocked_id'] as String).toList();
  final usersMap = await fetchPublicUsersMap(ids);
  return ids
      .map((id) => usersMap[id] ?? {'id': id, 'display_name': '（已刪除的使用者）'})
      .toList();
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_myBlockedListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('封鎖名單')),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('載入失敗',
                style: TextStyle(color: context.colors.textSecondary))),
        data: (users) {
          if (users.isEmpty) {
            return Center(
                child: Text('沒有封鎖任何人',
                    style: TextStyle(color: context.colors.textTertiary)));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              final avatarUrl = u['avatar_url'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(u['display_name'] as String? ?? '未知',
                    style: TextStyle(color: context.colors.textPrimary)),
                trailing: OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(blockedIdsProvider.notifier)
                          .unblock(u['id'] as String);
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('解除封鎖失敗，請稍後再試')),
                      );
                    }
                  },
                  child: const Text('解除封鎖'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
