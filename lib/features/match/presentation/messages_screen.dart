import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/blocks_provider.dart';
import '../../../core/providers/current_role_provider.dart';
import '../../../core/router/main_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/block_filter.dart';
import '../../../core/utils/user_hydration.dart';
import '../../../shared/models/user_model.dart';

// ── Provider ──────────────────────────────────────────────────────────────

final matchedChatsProvider =
    AsyncNotifierProvider<MatchedChatsNotifier, List<Map<String, dynamic>>>(
  MatchedChatsNotifier.new,
);

class MatchedChatsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    ref.watch(currentRoleProvider);
    final rows = await _fetch();
    final blocked = await ref.watch(blockedIdsProvider.future);
    return filterBlockedMatchRows(rows, blocked);
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final role = ref.read(currentRoleProvider);

    if (role == AppRole.jobSeeker) {
      final data = await Supabase.instance.client
          .from('matches')
          .select('id, status, created_at, jobs ( id, title, employer_id )')
          .eq('job_seeker_id', user.id)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);
      final rows = (data as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final employerIds = rows
          .map((r) => (r['jobs'] as Map?)?['employer_id'] as String?)
          .whereType<String>()
          .toList();
      final usersMap = await fetchPublicUsersMap(employerIds);
      for (final r in rows) {
        final jobs = r['jobs'] as Map?;
        if (jobs != null) {
          r['jobs'] = {...jobs, 'users': usersMap[jobs['employer_id']]};
        }
      }
      return rows;
    } else {
      final data = await Supabase.instance.client
          .from('matches')
          .select('id, status, created_at, job_seeker_id, jobs ( id, title )')
          .eq('employer_id', user.id)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);
      final rows = (data as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final usersMap = await fetchPublicUsersMap(
          rows.map((r) => r['job_seeker_id'] as String).toList());
      for (final r in rows) {
        r['job_seeker'] = usersMap[r['job_seeker_id']];
      }
      return rows;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(currentRoleProvider);
    final themeColor = currentRole.themeColor;
    final chatsAsync = ref.watch(matchedChatsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '訊息',
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            shadows: [
              Shadow(color: themeColor.withValues(alpha: 0.5), blurRadius: 8)
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: themeColor),
            onPressed: () =>
                ref.read(matchedChatsProvider.notifier).refresh(),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: RoleToggle()),
          ),
        ],
      ),
      body: chatsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: themeColor)),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: TextStyle(color: context.colors.textTertiary)),
        ),
        data: (chats) {
          if (chats.isEmpty) {
            return _EmptyState(themeColor: themeColor, role: currentRole);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            itemBuilder: (context, i) {
              return _ChatTile(
                match: chats[i],
                themeColor: themeColor,
                role: currentRole,
              );
            },
          );
        },
      ),
    );
  }
}

// ── Chat Tile ─────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.match,
    required this.themeColor,
    required this.role,
  });
  final Map<String, dynamic> match;
  final Color themeColor;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    String name;
    String? avatarUrl;
    String subtitle;

    if (role == AppRole.jobSeeker) {
      final job = match['jobs'] as Map<String, dynamic>? ?? {};
      final employer = job['users'] as Map<String, dynamic>? ?? {};
      name = employer['company_name'] as String? ??
          employer['display_name'] as String? ??
          '未知公司';
      avatarUrl = employer['avatar_url'] as String?;
      subtitle = job['title'] as String? ?? '職缺';
    } else {
      final js = match['job_seeker'] as Map<String, dynamic>? ?? {};
      final job = match['jobs'] as Map<String, dynamic>? ?? {};
      name = js['display_name'] as String? ?? '求職者';
      avatarUrl = js['avatar_url'] as String?;
      subtitle = '對「${job['title'] ?? '職缺'}」有興趣';
    }

    return GestureDetector(
      onTap: () => context.push('/chat/${match['id']}', extra: name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: themeColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // 頭像
            Stack(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeColor.withValues(alpha: 0.15),
                    border:
                        Border.all(color: themeColor.withValues(alpha: 0.3)),
                  ),
                  child: avatarUrl != null
                      ? ClipOval(
                          child:
                              Image.network(avatarUrl, fit: BoxFit.cover))
                      : Icon(
                          role == AppRole.jobSeeker
                              ? Icons.business
                              : Icons.person,
                          color: themeColor,
                          size: 26,
                        ),
                ),
                // 配對成功綠點
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00FF9F),
                      border: Border.all(color: context.colors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style:
                        TextStyle(color: context.colors.textTertiary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 聊天按鈕
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: themeColor.withValues(alpha: 0.12),
                border:
                    Border.all(color: themeColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      color: themeColor, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    '聊天',
                    style: TextStyle(
                        color: themeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.themeColor, required this.role});
  final Color themeColor;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 80, color: themeColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            '還沒有配對成功的聊天',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            role == AppRole.jobSeeker
                ? '右滑職缺並等待雇主確認後就能聊天'
                : '在配對清單確認求職者後就能開啟聊天',
            style: TextStyle(color: context.colors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}