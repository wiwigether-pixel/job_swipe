import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/current_role_provider.dart';
import '../../../core/router/main_shell.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/user_card_model.dart';
import '../../../shared/widgets/swipe_card_wrapper.dart';
import '../../swipe/presentation/user_card.dart';

// ── Providers ─────────────────────────────────────────────────────────────

/// 等待雇主確認的求職者列表（pending matches）
final pendingMatchesProvider =
    AsyncNotifierProvider<PendingMatchesNotifier, List<Map<String, dynamic>>>(
  PendingMatchesNotifier.new,
);

class PendingMatchesNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    ref.watch(currentRoleProvider);
    return _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final role = ref.read(currentRoleProvider);

    if (role == AppRole.employer) {
      // 雇主：看求職者右滑自己職缺的 pending 列表
      final data = await Supabase.instance.client
          .from('matches')
          .select('''
            id, status, created_at,
            job_seeker:users!matches_job_seeker_id_fkey (
              id, display_name, avatar_url, bio, skills
            ),
            jobs ( id, title )
          ''')
          .eq('employer_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } else {
      // 求職者：看自己已配對成功的職缺
      final data = await Supabase.instance.client
          .from('matches')
          .select('''
            id, status, created_at,
            jobs (
              id, title,
              users!jobs_employer_id_fkey ( display_name, company_name, avatar_url )
            )
          ''')
          .eq('job_seeker_id', user.id)
          .inFilter('status', ['pending', 'matched'])
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    }
  }

  /// 雇主確認配對（右滑）
  Future<void> acceptMatch(String matchId) async {
    await Supabase.instance.client
        .from('matches')
        .update({'status': 'accepted'}).eq('id', matchId);
    // 移除這張卡
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((m) => m['id'] != matchId).toList());
  }

  /// 雇主拒絕（左滑）
  Future<void> rejectMatch(String matchId) async {
    await Supabase.instance.client
        .from('matches')
        .update({'status': 'rejected'}).eq('id', matchId);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((m) => m['id'] != matchId).toList());
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(currentRoleProvider);
    final themeColor = currentRole.themeColor;
    final matchesAsync = ref.watch(pendingMatchesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '配對清單',
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
                ref.read(pendingMatchesProvider.notifier).refresh(),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: RoleToggle()),
          ),
        ],
      ),
      body: matchesAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: themeColor)),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          themeColor: themeColor,
          onRetry: () => ref.read(pendingMatchesProvider.notifier).refresh(),
        ),
        data: (matches) {
          if (matches.isEmpty) {
            return _EmptyState(
                themeColor: themeColor, currentRole: currentRole);
          }
          // 雇主：滑卡確認介面
          if (currentRole == AppRole.employer) {
            return _EmployerSwipeConfirm(
              matches: matches,
              themeColor: themeColor,
            );
          }
          // 求職者：列表顯示
          return _JobSeekerMatchList(
              matches: matches, themeColor: themeColor);
        },
      ),
    );
  }
}

// ── 雇主滑卡確認區 ────────────────────────────────────────────────────────

class _EmployerSwipeConfirm extends ConsumerStatefulWidget {
  const _EmployerSwipeConfirm(
      {required this.matches, required this.themeColor});
  final List<Map<String, dynamic>> matches;
  final Color themeColor;

  @override
  ConsumerState<_EmployerSwipeConfirm> createState() =>
      _EmployerSwipeConfirmState();
}

class _EmployerSwipeConfirmState
    extends ConsumerState<_EmployerSwipeConfirm> {
  late final SwipeController _controller;
  late List<Map<String, dynamic>> _cards;

  @override
  void initState() {
    super.initState();
    _controller = SwipeController();
    _cards = List.of(widget.matches);
  }

  @override
  void didUpdateWidget(_EmployerSwipeConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.matches != oldWidget.matches) {
      _cards = List.of(widget.matches);
    }
  }

  UserCardModel _toUserCard(Map<String, dynamic> match) {
    final js = match['job_seeker'] as Map<String, dynamic>? ?? {};
    return UserCardModel(
      id: match['id'] as String,
      userId: js['id'] as String? ?? '',
      role: 'job_seeker',
      displayName: js['display_name'] as String? ?? '求職者',
      avatarUrl: js['avatar_url'] as String?,
      bio: js['bio'] as String?,
      skills: (js['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  void _handleSwipe(int index, SwipeDirection direction) {
    if (index >= _cards.length) return;
    final match = _cards[index];
    final matchId = match['id'] as String;
    final isAccept = direction == SwipeDirection.right;

    if (isAccept) {
      ref.read(pendingMatchesProvider.notifier).acceptMatch(matchId);
      _showMatchedDialog(match);
    } else {
      ref.read(pendingMatchesProvider.notifier).rejectMatch(matchId);
    }
  }

  void _showMatchedDialog(Map<String, dynamic> match) {
    final js = match['job_seeker'] as Map<String, dynamic>? ?? {};
    final job = match['jobs'] as Map<String, dynamic>? ?? {};
    final name = js['display_name'] as String? ?? '求職者';
    final jobTitle = job['title'] as String? ?? '職缺';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '關閉',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
        child: FadeTransition(opacity: animation, child: child),
      ),
      pageBuilder: (context, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            borderRadius: BorderRadius.circular(24),
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFFBF00FF), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    '🎉 配對成功！',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$name 對「$jobTitle」感興趣\n雙方已成功配對，可以開始聊天！',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('繼續確認'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFBF00FF),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('查看訊息',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards
        .map((m) => UserCard(userCard: _toUserCard(m)))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14, color: widget.themeColor.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                '右滑接受，左滑跳過 · 共 ${_cards.length} 位求職者',
                style: TextStyle(
                    color: widget.themeColor.withValues(alpha: 0.6),
                    fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: SwipeCardWrapper(
            controller: _controller,
            cards: cards,
            onSwipe: _handleSwipe,
            onEmpty: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('所有求職者都確認完了！'),
                    backgroundColor:
                        widget.themeColor.withValues(alpha: 0.8),
                  ),
                );
              }
            },
          ),
        ),
        // 操作按鈕
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircleBtn(
                icon: Icons.close,
                color: const Color(0xFFFF4757),
                size: 64,
                onPressed: () => _controller.swipeLeft(),
              ),
              _CircleBtn(
                icon: Icons.favorite,
                color: widget.themeColor,
                size: 64,
                onPressed: () => _controller.swipeRight(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn(
      {required this.icon,
      required this.color,
      required this.size,
      required this.onPressed});
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111111),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

// ── 求職者列表 ────────────────────────────────────────────────────────────

class _JobSeekerMatchList extends StatelessWidget {
  const _JobSeekerMatchList(
      {required this.matches, required this.themeColor});
  final List<Map<String, dynamic>> matches;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final match = matches[i];
        final job = match['jobs'] as Map<String, dynamic>?;
        final employer = job?['users'] as Map<String, dynamic>?;
        final status = match['status'] as String? ?? 'pending';
        final isMatched = status == 'accepted';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isMatched
                  ? themeColor.withValues(alpha: 0.5)
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor.withValues(alpha: 0.15),
                ),
                child: employer?['avatar_url'] != null
                    ? ClipOval(
                        child: Image.network(
                          employer!['avatar_url'] as String,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.business, color: themeColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job?['title'] as String? ?? '未命名職缺',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employer?['company_name'] as String? ??
                          employer?['display_name'] as String? ??
                          '未知公司',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: (isMatched ? themeColor : Colors.orange)
                      .withValues(alpha: 0.15),
                  border: Border.all(
                    color: (isMatched ? themeColor : Colors.orange)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isMatched ? '配對成功' : '等待確認',
                  style: TextStyle(
                    color: isMatched ? themeColor : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.themeColor, required this.currentRole});
  final Color themeColor;
  final AppRole currentRole;

  @override
  Widget build(BuildContext context) {
    final isEmployer = currentRole == AppRole.employer;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEmployer ? Icons.people_outline : Icons.favorite_border,
            size: 80,
            color: themeColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            isEmployer ? '目前沒有待確認的求職者' : '還沒有配對',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            isEmployer ? '當求職者右滑你的職缺時，會出現在這裡讓你確認' : '右滑喜歡的職缺來建立配對',
            style: const TextStyle(color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(
      {required this.message,
      required this.themeColor,
      required this.onRetry});
  final String message;
  final Color themeColor;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.white38),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.white38),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}