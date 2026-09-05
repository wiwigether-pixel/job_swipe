import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_provider.dart';
import 'widgets/admin_page.dart';
import '../../../core/theme/app_colors.dart';

class AdminInboxScreen extends ConsumerStatefulWidget {
  const AdminInboxScreen({super.key});

  @override
  ConsumerState<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends ConsumerState<AdminInboxScreen> {
  String _statusFilter = 'unread';

  @override
  Widget build(BuildContext context) {
    final inboxAsync =
        ref.watch(adminInboxProvider(statusFilter: _statusFilter));

    return AdminPage(
      title: '收件夾',
      onRefresh: () => ref.invalidate(adminInboxProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip('未讀', 'unread', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
              _StatusChip('已讀', 'read', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
              _StatusChip('已回覆', 'replied', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
              _StatusChip('已封存', 'archived', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: inboxAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: adminAccent)),
              error: (e, _) => Center(
                  child: Text('載入失敗：$e',
                      style: const TextStyle(color: Colors.redAccent))),
              data: (messages) => messages.isEmpty
                  ? Center(
                      child: Text('沒有信件',
                          style: TextStyle(color: context.colors.textTertiary)))
                  : ListView.separated(
                      itemCount: messages.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: context.colors.divider, height: 1),
                      itemBuilder: (_, i) => _InboxRow(message: messages[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, this.value, this.current, this.onTap);
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(value),
        backgroundColor: context.colors.surface,
        selectedColor: adminAccent.withValues(alpha: 0.25),
        labelStyle: TextStyle(
            color: selected ? adminAccent : context.colors.textSecondary, fontSize: 13),
        side: BorderSide(color: selected ? adminAccent : context.colors.divider),
      ),
    );
  }
}

class _InboxRow extends ConsumerWidget {
  const _InboxRow({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = message['id'] as String;
    final subject = (message['subject'] as String?)?.trim();
    final body = message['body'] as String? ?? '';
    final status = message['status'] as String? ?? 'unread';
    final senderName = _senderName(message);
    final isUnread = status == 'unread';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUnread)
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 10),
              child: Icon(Icons.circle, color: adminAccent, size: 8),
            )
          else
            const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject == null || subject.isEmpty ? '（無主旨）' : subject,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                const SizedBox(height: 2),
                Text('寄件人：$senderName',
                    style:
                        TextStyle(color: context.colors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (status == 'replied')
            const _Badge('已回覆', Color(0xFF0CBB78))
          else if (status == 'archived')
            // Colors.white38 is semantic dim for archived state
            const _Badge('已封存', Colors.white38),
          TextButton.icon(
            onPressed: () => _openDetail(context, ref),
            icon: const Icon(Icons.open_in_full, color: adminAccent, size: 16),
            label: const Text('檢視', style: TextStyle(color: adminAccent)),
          ),
          if (status != 'archived')
            TextButton(
              onPressed: () => ref.read(adminActionsProvider).archiveInbox(id),
              child: Text('封存',
                  style: TextStyle(color: context.colors.textTertiary)),
            ),
        ],
      ),
    );
  }

  static String _senderName(Map<String, dynamic> m) {
    final sender = m['sender'] as Map<String, dynamic>?;
    final fromUser = sender?['display_name'] as String?;
    final name = (m['sender_name'] as String?)?.trim();
    final email =
        (m['sender_email'] as String?) ?? sender?['email'] as String?;
    final display = (name != null && name.isNotEmpty)
        ? name
        : (fromUser ?? '匿名');
    return email != null && email.isNotEmpty ? '$display〈$email〉' : display;
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    // 開啟即視為已讀（僅未讀時觸發）
    if (message['status'] == 'unread') {
      ref.read(adminActionsProvider).markInboxRead(message['id'] as String);
    }
    final width = MediaQuery.sizeOf(context).width;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: context.colors.surface,
        child: SizedBox(
          width: width < 560 ? width - 48 : 560,
          child: _MessageDetail(message: message),
        ),
      ),
    );
  }
}

class _MessageDetail extends ConsumerStatefulWidget {
  const _MessageDetail({required this.message});
  final Map<String, dynamic> message;

  @override
  ConsumerState<_MessageDetail> createState() => _MessageDetailState();
}

class _MessageDetailState extends ConsumerState<_MessageDetail> {
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) return;
    setState(() => _sending = true);
    await ref
        .read(adminActionsProvider)
        .replyInbox(widget.message['id'] as String, reply);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final subject = (m['subject'] as String?)?.trim();
    final body = m['body'] as String? ?? '';
    final existingReply = m['admin_reply'] as String?;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject == null || subject.isEmpty ? '（無主旨）' : subject,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: context.colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('寄件人：${_InboxRow._senderName(m)}',
              style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(body,
                style: TextStyle(color: context.colors.textSecondary, height: 1.5)),
          ),
          const SizedBox(height: 20),
          if (existingReply != null && existingReply.isNotEmpty) ...[
            const Text('已回覆內容',
                style: TextStyle(color: adminAccent, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: adminAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(existingReply,
                  style: TextStyle(color: context.colors.textSecondary, height: 1.5)),
            ),
          ] else ...[
            TextField(
              controller: _replyController,
              style: TextStyle(color: context.colors.textPrimary),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '撰寫回覆...',
                hintStyle: TextStyle(color: context.colors.textTertiary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.colors.divider)),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: adminAccent)),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: adminAccent),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('送出回覆'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
