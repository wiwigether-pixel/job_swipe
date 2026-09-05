import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_provider.dart';
import 'widgets/admin_page.dart';
import '../../../core/theme/app_colors.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _roleFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(
      adminUsersProvider(search: _search, roleFilter: _roleFilter),
    );
    final myRole = ref.watch(adminRoleProvider).valueOrNull;

    return AdminPage(
      title: '用戶管理',
      onRefresh: () => ref.invalidate(adminUsersProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Toolbar(
            controller: _searchController,
            roleFilter: _roleFilter,
            onSearch: (v) => setState(() => _search = v),
            onRoleChanged: (v) => setState(() => _roleFilter = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: adminAccent)),
              error: (e, _) => Center(
                  child: Text('載入失敗：$e',
                      style: const TextStyle(color: Colors.redAccent))),
              data: (users) => users.isEmpty
                  ? Center(
                      child: Text('沒有符合的用戶',
                          style: TextStyle(color: context.colors.textTertiary)))
                  : ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: context.colors.divider, height: 1),
                      itemBuilder: (_, i) => _UserRow(
                        user: users[i],
                        canDelete: myRole?.canDeleteUsers ?? false,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.roleFilter,
    required this.onSearch,
    required this.onRoleChanged,
  });

  final TextEditingController controller;
  final String? roleFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;

        final searchField = TextField(
          controller: controller,
          style: TextStyle(color: context.colors.textPrimary),
          onSubmitted: onSearch,
          decoration: InputDecoration(
            hintText: '搜尋姓名或 email...',
            hintStyle: TextStyle(color: context.colors.textTertiary),
            prefixIcon: Icon(Icons.search, color: context.colors.textTertiary),
            filled: true,
            fillColor: context.colors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        );

        final chips = Wrap(
          children: [
            _RoleChip('全部', null, roleFilter, onRoleChanged),
            _RoleChip('求職者', 'job_seeker', roleFilter, onRoleChanged),
            _RoleChip('雇主', 'employer', roleFilter, onRoleChanged),
            _RoleChip('同業', 'peer', roleFilter, onRoleChanged),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchField,
              const SizedBox(height: 12),
              chips,
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 320, child: searchField),
            const SizedBox(width: 16),
            Expanded(child: chips),
          ],
        );
      },
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(this.label, this.value, this.current, this.onTap);
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
        backgroundColor: context.colors.surface,
        selectedColor: adminAccent.withValues(alpha: 0.25),
        labelStyle: TextStyle(
            color: selected ? adminAccent : context.colors.textSecondary, fontSize: 13),
        side: BorderSide(
            color: selected ? adminAccent : context.colors.divider),
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user, required this.canDelete});
  final Map<String, dynamic> user;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = user['id'] as String;
    final name = user['display_name'] as String? ?? '未命名';
    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? '';
    final status = user['status'] as String? ?? 'active';
    final avatar = user['avatar_url'] as String?;
    final suspended = status == 'suspended';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: context.colors.divider,
            backgroundImage: (avatar != null && avatar.isNotEmpty)
                ? NetworkImage(avatar)
                : null,
            child: (avatar == null || avatar.isEmpty)
                ? Icon(Icons.person, color: context.colors.textTertiary, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Role badge: Colors.white24 is a neutral tint — keep as semantic badge color
                    _Badge(_roleLabel(role), Colors.white24),
                    _Badge(suspended ? '已停權' : '正常',
                        suspended
                            ? context.colors.danger
                            : const Color(0xFF0CBB78)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 停權 / 啟用
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => ref
                .read(adminActionsProvider)
                .setUserStatus(id, suspended ? 'active' : 'suspended'),
            child: Text(suspended ? '啟用' : '停權',
                style: TextStyle(
                    color: suspended
                        ? const Color(0xFF0CBB78)
                        : Colors.orangeAccent)),
          ),
          // 刪除（僅 super_admin）
          if (canDelete)
            IconButton(
              tooltip: '刪除',
              onPressed: () => _confirmDelete(context, ref, id, name),
              icon: Icon(Icons.delete_outline,
                  color: context.colors.danger, size: 20),
            ),
        ],
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'job_seeker' => '求職者',
        'employer' => '雇主',
        'peer' => '同業',
        _ => role,
      };

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: Text('確認刪除', style: TextStyle(color: ctx.colors.textPrimary)),
        content: Text('確定要永久刪除「$name」嗎？此操作無法復原。',
            style: TextStyle(color: ctx.colors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: ctx.colors.textSecondary))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminActionsProvider).deleteUser(id);
            },
            child: const Text('刪除'),
          ),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}
