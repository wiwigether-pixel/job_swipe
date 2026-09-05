import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/blocks_provider.dart';
import '../../match/presentation/matches_screen.dart';
import '../../match/presentation/messages_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otherName,
  });

  final String matchId;
  final String otherName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _client = Supabase.instance.client;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _client
          .from('messages')
          .select('id, sender_id, content, created_at')
          .eq('match_id', widget.matchId)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _client
        .channel('chat_${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.matchId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newMsg = Map<String, dynamic>.from(payload.newRecord);
            // 避免 optimistic update 重複
            if (_messages.any((m) => m['id'] == newMsg['id'])) return;
            setState(() => _messages.add(newMsg));
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    _inputController.clear();

    // Optimistic update
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'sender_id': myId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      await _client.from('messages').insert({
        'match_id': widget.matchId,
        'sender_id': myId,
        'content': text,
      });
      // Realtime 會帶回真實資料，這裡移除暫時的
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('發送失敗'), backgroundColor: context.colors.danger),
      );
    }
  }

  Future<void> _reportConversation() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: ctx.colors.surface,
          title: Text('檢舉對話', style: TextStyle(color: ctx.colors.textPrimary)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: ctx.colors.textPrimary),
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '請描述檢舉原因...',
              hintStyle: TextStyle(color: ctx.colors.textTertiary),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: ctx.colors.divider)),
              focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF6C63FF))),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text('取消', style: TextStyle(color: ctx.colors.textSecondary))),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('送出檢舉'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await _client.from('reports').insert({
        'reporter_id': myId,
        'target_type': 'conversation',
        'target_id': widget.matchId,
        'match_id': widget.matchId,
        'reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('檢舉已送出，感謝您的回報')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('檢舉失敗'), backgroundColor: context.colors.danger),
      );
    }
  }

  Future<void> _blockOtherUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('封鎖 ${widget.otherName}？'),
        content: const Text('封鎖後將不再看到對方的卡片與訊息，可在「設定 → 封鎖名單」解除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('封鎖')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // 從 match 撈出對方 user id（自己是其中一方）
      final row = await _client
          .from('matches')
          .select('job_seeker_id, employer_id')
          .eq('id', widget.matchId)
          .single();
      final myId = _client.auth.currentUser!.id;
      final otherId = row['job_seeker_id'] == myId
          ? row['employer_id'] as String
          : row['job_seeker_id'] as String;

      await ref.read(blockedIdsProvider.notifier).block(otherId);
      ref.invalidate(matchedChatsProvider);
      ref.invalidate(pendingMatchesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已封鎖')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('封鎖失敗，請稍後再試')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _client.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceAlt,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.otherName,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.colors.textSecondary),
            onSelected: (v) {
              if (v == 'report') _reportConversation();
              if (v == 'block') _blockOtherUser();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('檢舉對話')),
              PopupMenuItem(value: 'block', child: Text('封鎖對方')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            '傳送第一則訊息開始聊天吧！',
                            style: TextStyle(color: context.colors.textTertiary, fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final msg = _messages[i];
                            final isMe = msg['sender_id'] == myId;
                            return _MessageBubble(
                              content: msg['content'] as String,
                              isMe: isMe,
                            );
                          },
                        ),
                ),
                _InputBar(
                  controller: _inputController,
                  onSend: _sendMessage,
                ),
              ],
            ),
    );
  }
}

// ── Message Bubble ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.content, required this.isMe});

  final String content;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF6C63FF)
              : context.colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
              color: isMe ? Colors.white : context.colors.textPrimary,
              fontSize: 15,
              height: 1.4),
        ),
      ),
    );
  }
}

// ── Input Bar ──────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: context.colors.textPrimary),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '傳送訊息...',
                hintStyle: TextStyle(color: context.colors.textTertiary),
                filled: true,
                fillColor: context.colors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6C63FF),
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
