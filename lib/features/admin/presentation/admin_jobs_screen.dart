import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_provider.dart';
import 'widgets/admin_page.dart';

class AdminJobsScreen extends ConsumerStatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  ConsumerState<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends ConsumerState<AdminJobsScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(adminJobsProvider(statusFilter: _statusFilter));

    return AdminPage(
      title: '職缺管理',
      onRefresh: () => ref.invalidate(adminJobsProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip('全部', null, _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
              _StatusChip('開放中', 'open', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
              _StatusChip('已關閉', 'closed', _statusFilter,
                  (v) => setState(() => _statusFilter = v)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: jobsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: adminAccent)),
              error: (e, _) => Center(
                  child: Text('載入失敗：$e',
                      style: const TextStyle(color: Colors.redAccent))),
              data: (jobs) => jobs.isEmpty
                  ? const Center(
                      child: Text('沒有符合的職缺',
                          style: TextStyle(color: Colors.white38)))
                  : ListView.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, i) => _JobRow(job: jobs[i]),
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
  final String? value;
  final String? current;
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(value),
        backgroundColor: const Color(0xFF1A1A1A),
        selectedColor: adminAccent.withValues(alpha: 0.25),
        labelStyle: TextStyle(
            color: selected ? adminAccent : Colors.white54, fontSize: 13),
        side: BorderSide(color: selected ? adminAccent : Colors.white12),
      ),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job});
  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = job['id'] as String;
    final title = job['title'] as String? ?? '未命名職缺';
    final status = job['status'] as String? ?? 'open';
    final employer = job['users'] as Map<String, dynamic>?;
    final company = employer?['company_name'] as String? ??
        employer?['display_name'] as String? ??
        '未知雇主';
    final isOpen = status == 'open';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.work_outline, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text(company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOpen ? const Color(0xFF0CBB78) : Colors.white24)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isOpen ? '開放中' : '已關閉',
                      style: TextStyle(
                          color:
                              isOpen ? const Color(0xFF0CBB78) : Colors.white54,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => ref
                .read(adminActionsProvider)
                .setJobStatus(id, isOpen ? 'closed' : 'open'),
            child: Text(isOpen ? '下架' : '開放',
                style: TextStyle(
                    color:
                        isOpen ? Colors.orangeAccent : const Color(0xFF0CBB78))),
          ),
          IconButton(
            tooltip: '刪除',
            onPressed: () => _confirmDelete(context, ref, id, title),
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 20),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('確認刪除', style: TextStyle(color: Colors.white)),
        content: Text('確定要永久刪除職缺「$title」嗎？此操作無法復原。',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: Colors.white54))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminActionsProvider).deleteJob(id);
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}
