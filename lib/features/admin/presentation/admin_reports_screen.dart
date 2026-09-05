import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_provider.dart';
import 'widgets/admin_page.dart';
import '../../../core/theme/app_colors.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  String _statusFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    final reportsAsync =
        ref.watch(adminReportsProvider(statusFilter: _statusFilter));

    return AdminPage(
      title: '檢舉處理',
      onRefresh: () => ref.invalidate(adminReportsProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip('待處理', 'pending', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
              _StatusChip('已處理', 'resolved', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
              _StatusChip('已駁回', 'dismissed', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: adminAccent)),
              error: (e, _) => Center(
                  child: Text('載入失敗：$e',
                      style: const TextStyle(color: Colors.redAccent))),
              data: (reports) => reports.isEmpty
                  ? Center(
                      child: Text('沒有符合的檢舉',
                          style: TextStyle(color: context.colors.textTertiary)))
                  : ListView.separated(
                      itemCount: reports.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: context.colors.divider, height: 1),
                      itemBuilder: (_, i) => _ReportRow(report: reports[i]),
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

class _ReportRow extends ConsumerWidget {
  const _ReportRow({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = report['id'] as String;
    final type = report['target_type'] as String? ?? '';
    final reason = report['reason'] as String? ?? '';
    final status = report['status'] as String? ?? 'pending';
    final matchId = report['match_id'] as String?;
    final reporter = report['reporter'] as Map<String, dynamic>?;
    final reporterName = reporter?['display_name'] as String? ??
        reporter?['email'] as String? ??
        '未知';
    final note = report['admin_note'] as String?;
    final isPending = status == 'pending';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Neutral type badge — Colors.white24 is semantic for "neutral/unclassified"
              _Badge(_typeLabel(type), Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reason,
                        style: TextStyle(
                            color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('檢舉人：$reporterName',
                        style: TextStyle(
                            color: context.colors.textTertiary, fontSize: 12)),
                    if (note != null && note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('備註：$note',
                            style: TextStyle(
                                color: context.colors.textSecondary, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              if (!isPending) ...[
                const SizedBox(width: 8),
                // Status badge: green=resolved, white38=dismissed (semantic dim)
                _Badge(status == 'resolved' ? '已處理' : '已駁回',
                    status == 'resolved'
                        ? const Color(0xFF0CBB78)
                        : Colors.white38),
              ],
            ],
          ),
          if (isPending || (type == 'conversation' && matchId != null))
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  if (type == 'conversation' && matchId != null)
                    TextButton.icon(
                      onPressed: () => _showConversation(context, matchId),
                      icon: const Icon(Icons.forum_outlined,
                          color: adminAccent, size: 18),
                      label: const Text('檢視對話',
                          style: TextStyle(color: adminAccent)),
                    ),
                  if (isPending) ...[
                    TextButton(
                      onPressed: () =>
                          _showResolve(context, ref, id, resolve: true),
                      child: const Text('標記處理',
                          style: TextStyle(color: Color(0xFF0CBB78))),
                    ),
                    TextButton(
                      onPressed: () =>
                          _showResolve(context, ref, id, resolve: false),
                      child: Text('駁回',
                          style: TextStyle(color: context.colors.textTertiary)),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _typeLabel(String t) => switch (t) {
        'user' => '用戶',
        'job' => '職缺',
        'conversation' => '對話',
        _ => t,
      };

  void _showConversation(BuildContext context, String matchId) {
    final size = MediaQuery.sizeOf(context);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: context.colors.surface,
        child: SizedBox(
          width: size.width < 560 ? size.width - 48 : 520,
          height: size.height * 0.7,
          child: _ConversationView(matchId: matchId),
        ),
      ),
    );
  }

  void _showResolve(BuildContext context, WidgetRef ref, String id,
      {required bool resolve}) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: Text(resolve ? '標記為已處理' : '駁回檢舉',
            style: TextStyle(color: ctx.colors.textPrimary)),
        content: TextField(
          controller: noteController,
          style: TextStyle(color: ctx.colors.textPrimary),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '備註（選填）',
            hintStyle: TextStyle(color: ctx.colors.textTertiary),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: ctx.colors.divider)),
            focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: adminAccent)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('取消', style: TextStyle(color: ctx.colors.textSecondary))),
          FilledButton(
            style: FilledButton.styleFrom(
                // Resolve button: green=confirm, white24=dismiss (semantic action color)
                backgroundColor:
                    resolve ? const Color(0xFF0CBB78) : Colors.white24),
            onPressed: () {
              final note = noteController.text.trim();
              Navigator.pop(ctx);
              final actions = ref.read(adminActionsProvider);
              if (resolve) {
                actions.resolveReport(id, note: note.isEmpty ? null : note);
              } else {
                actions.dismissReport(id, note: note.isEmpty ? null : note);
              }
            },
            child: Text(resolve ? '確認處理' : '確認駁回'),
          ),
        ],
      ),
    );
  }
}

class _ConversationView extends ConsumerWidget {
  const _ConversationView({required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgsAsync = ref.watch(reportConversationProvider(matchId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('對話內容',
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
        Divider(color: context.colors.divider, height: 1),
        Expanded(
          child: msgsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: adminAccent)),
            error: (e, _) => Center(
                child: Text('載入失敗：$e',
                    style: const TextStyle(color: Colors.redAccent))),
            data: (msgs) => msgs.isEmpty
                ? Center(
                    child: Text('沒有訊息',
                        style: TextStyle(color: context.colors.textTertiary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final sender = m['sender'] as Map<String, dynamic>?;
                      final name =
                          sender?['display_name'] as String? ?? '未知';
                      final content = m['content'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: adminAccent, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(content,
                                style: TextStyle(color: context.colors.textSecondary)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
