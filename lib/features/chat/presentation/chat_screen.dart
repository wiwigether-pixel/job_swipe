import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otherName,
  });

  final String matchId;
  final String otherName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
        const SnackBar(content: Text('發送失敗'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reportConversation() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('檢舉對話', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '請描述檢舉原因...',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF6C63FF))),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    const Text('取消', style: TextStyle(color: Colors.white54))),
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
        const SnackBar(content: Text('檢舉失敗'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _client.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.otherName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '檢舉',
            icon: const Icon(Icons.flag_outlined, color: Colors.white54),
            onPressed: _reportConversation,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            '傳送第一則訊息開始聊天吧！',
                            style: TextStyle(color: Colors.white38, fontSize: 15),
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
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Text(
          content,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, height: 1.4),
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
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '傳送訊息...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
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
