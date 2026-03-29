import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/current_role_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────

final employerJobsProvider =
    AsyncNotifierProvider<EmployerJobsNotifier, List<Map<String, dynamic>>>(
  EmployerJobsNotifier.new,
);

class EmployerJobsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetchJobs();
  }

  Future<List<Map<String, dynamic>>> _fetchJobs() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final data = await Supabase.instance.client
        .from('jobs')
        .select()
        .eq('employer_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> addJob(Map<String, dynamic> jobData) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('jobs').insert({
      ...jobData,
      'employer_id': user.id,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    ref.invalidateSelf();
  }

  Future<void> updateJob(String jobId, Map<String, dynamic> jobData) async {
    await Supabase.instance.client.from('jobs').update({
      ...jobData,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);

    ref.invalidateSelf();
  }

  Future<void> deleteJob(String jobId) async {
    await Supabase.instance.client
        .from('jobs')
        .delete()
        .eq('id', jobId);

    ref.invalidateSelf();
  }

  Future<void> toggleStatus(String jobId, String currentStatus) async {
    final newStatus = currentStatus == 'open' ? 'closed' : 'open';
    await Supabase.instance.client
        .from('jobs')
        .update({'status': newStatus})
        .eq('id', jobId);

    ref.invalidateSelf();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────

class EmployerJobsScreen extends ConsumerWidget {
  const EmployerJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(currentRoleProvider).themeColor;
    final jobsAsync = ref.watch(employerJobsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '職缺管理',
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: themeColor),
            onPressed: () => _showJobSheet(context, ref, themeColor),
          ),
        ],
      ),
      body: jobsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: themeColor)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: const TextStyle(color: Colors.white38)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(employerJobsProvider),
                child: const Text('重試'),
              ),
            ],
          ),
        ),
        data: (jobs) => jobs.isEmpty
            ? _EmptyState(
                themeColor: themeColor,
                onAdd: () => _showJobSheet(context, ref, themeColor),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                itemBuilder: (context, i) => _JobCard(
                  job: jobs[i],
                  themeColor: themeColor,
                  onEdit: () =>
                      _showJobSheet(context, ref, themeColor, job: jobs[i]),
                  onDelete: () =>
                      _confirmDelete(context, ref, jobs[i]['id'] as String),
                  onToggleStatus: () => ref
                      .read(employerJobsProvider.notifier)
                      .toggleStatus(
                        jobs[i]['id'] as String,
                        jobs[i]['status'] as String? ?? 'open',
                      ),
                ),
              ),
      ),
      floatingActionButton: jobsAsync.hasValue &&
              (jobsAsync.value?.isNotEmpty ?? false)
          ? FloatingActionButton(
              onPressed: () => _showJobSheet(context, ref, themeColor),
              backgroundColor: themeColor,
              foregroundColor: Colors.black,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showJobSheet(
    BuildContext context,
    WidgetRef ref,
    Color themeColor, {
    Map<String, dynamic>? job,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JobFormSheet(
        themeColor: themeColor,
        job: job,
        onSave: (data) async {
          if (job != null) {
            await ref
                .read(employerJobsProvider.notifier)
                .updateJob(job['id'] as String, data);
          } else {
            await ref.read(employerJobsProvider.notifier).addJob(data);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String jobId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('刪除職缺',
            style: TextStyle(color: Colors.white)),
        content: const Text('確定要刪除這個職缺嗎？此操作無法復原。',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(employerJobsProvider.notifier)
                  .deleteJob(jobId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 職缺已刪除')),
                );
              }
            },
            child: const Text('刪除',
                style: TextStyle(color: Color(0xFFFF4757))),
          ),
        ],
      ),
    );
  }
}

// ── Job Card ──────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.themeColor,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  final Map<String, dynamic> job;
  final Color themeColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final isOpen = (job['status'] as String? ?? 'open') == 'open';
    final statusColor = isOpen ? Colors.greenAccent : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isOpen
              ? themeColor.withValues(alpha: 0.3)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    job['title'] as String? ?? '未命名職缺',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 狀態 badge
                GestureDetector(
                  onTap: onToggleStatus,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: statusColor.withValues(alpha: 0.12),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      isOpen ? '招募中' : '已關閉',
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 資訊列
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 12,
              children: [
                if (job['location'] != null)
                  _MetaText(
                      icon: Icons.location_on_outlined,
                      text: job['location'] as String),
                if (job['salary_min'] != null)
                  _MetaText(
                    icon: Icons.payments_outlined,
                    text:
                        '${((job['salary_min'] as int) / 1000).toStringAsFixed(0)}K'
                        '${job['salary_max'] != null ? ' - ${((job['salary_max'] as int) / 1000).toStringAsFixed(0)}K' : '+'}',
                  ),
              ],
            ),
          ),

          // 描述預覽
          if (job['description'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                job['description'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),

          // 操作按鈕
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined,
                    size: 16, color: themeColor),
                label: Text('編輯',
                    style: TextStyle(color: themeColor, fontSize: 13)),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Color(0xFFFF4757)),
                label: const Text('刪除',
                    style: TextStyle(
                        color: Color(0xFFFF4757), fontSize: 13)),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.themeColor, required this.onAdd});
  final Color themeColor;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline,
              size: 80, color: themeColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('還沒有發布職缺',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('點擊下方按鈕新增你的第一個職缺',
              style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('新增職缺'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Job Form Sheet ────────────────────────────────────────────────────────

class _JobFormSheet extends StatefulWidget {
  const _JobFormSheet({
    required this.themeColor,
    required this.onSave,
    this.job,
  });

  final Color themeColor;
  final Map<String, dynamic>? job;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_JobFormSheet> createState() => _JobFormSheetState();
}

class _JobFormSheetState extends State<_JobFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _locationController;
  late final TextEditingController _salaryMinController;
  late final TextEditingController _salaryMaxController;
  late final TextEditingController _skillController;
  late List<String> _skills;
  String _jobType = 'full_time';
  bool _isSaving = false;

  final _jobTypes = {
    'full_time': '全職',
    'part_time': '兼職',
    'contract': '約聘',
    'internship': '實習',
    'remote': '遠端',
  };

  @override
  void initState() {
    super.initState();
    final job = widget.job;
    _titleController =
        TextEditingController(text: job?['title'] as String? ?? '');
    _descController =
        TextEditingController(text: job?['description'] as String? ?? '');
    _locationController =
        TextEditingController(text: job?['location'] as String? ?? '');
    _salaryMinController = TextEditingController(
        text: job?['salary_min']?.toString() ?? '');
    _salaryMaxController = TextEditingController(
        text: job?['salary_max']?.toString() ?? '');
    _skillController = TextEditingController();
    _skills = List<String>.from(
        (job?['required_skills'] as List<dynamic>?)?.map((e) => e.toString()) ??
            []);
    _jobType = job?['job_type'] as String? ?? 'full_time';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('職缺名稱不能為空')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.onSave({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'salary_min': int.tryParse(_salaryMinController.text),
        'salary_max': int.tryParse(_salaryMaxController.text),
        'job_type': _jobType,
        'required_skills': _skills,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                widget.job != null ? '✅ 職缺已更新' : '✅ 職缺已發布'),
            backgroundColor: widget.themeColor.withValues(alpha: 0.8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('儲存失敗：$e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.themeColor;
    final isEdit = widget.job != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEdit ? '編輯職缺' : '新增職缺',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _buildField(_titleController, '職缺名稱 *', Icons.work, color),
              const SizedBox(height: 14),

              _buildField(_descController, '職缺描述', Icons.description, color,
                  maxLines: 4),
              const SizedBox(height: 14),

              _buildField(
                  _locationController, '工作地點', Icons.location_on, color),
              const SizedBox(height: 14),

              // 工作類型
              DropdownButtonFormField<String>(
                initialValue: _jobType,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('工作類型', Icons.category, color),
                items: _jobTypes.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _jobType = v!),
              ),
              const SizedBox(height: 14),

              // 薪資範圍
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      _salaryMinController,
                      '最低月薪',
                      Icons.payments_outlined,
                      color,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      _salaryMaxController,
                      '最高月薪',
                      Icons.payments,
                      color,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 技能需求
              TextField(
                controller: _skillController,
                style: const TextStyle(color: Colors.white),
                onSubmitted: (val) {
                  final trimmed = val.trim();
                  if (trimmed.isNotEmpty) {
                    setState(() {
                      _skills.add(trimmed);
                      _skillController.clear();
                    });
                  }
                },
                decoration: _inputDeco('需求技能（按 Enter 新增）', Icons.bolt, color),
              ),
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills
                      .map((s) => Chip(
                            label: Text(s,
                                style: const TextStyle(color: Colors.white)),
                            backgroundColor: color.withValues(alpha: 0.15),
                            deleteIconColor: color,
                            onDeleted: () =>
                                setState(() => _skills.remove(s)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          isEdit ? '更新職缺' : '發布職缺',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon,
    Color color, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDeco(label, icon, color),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, Color color) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: color, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      ),
    );
  }
}