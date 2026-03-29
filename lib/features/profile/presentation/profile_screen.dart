import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/current_role_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/router/main_shell.dart';
import '../../../shared/models/user_model.dart';
import 'employer_jobs_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(currentRoleProvider);
    final themeColor = currentRole.themeColor;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '我的',
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
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: RoleToggle()),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: themeColor)),
        error: (e, _) => Center(
          child:
              Text(e.toString(), style: const TextStyle(color: Colors.white38)),
        ),
        data: (profile) => profile == null
            ? const SizedBox.shrink()
            : _ProfileBody(profile: profile, themeColor: themeColor),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile, required this.themeColor});
  final UserModel profile;
  final Color themeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(currentRoleProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          // 限制最大寬度，讓寬螢幕也能居中
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              _AvatarSection(profile: profile, themeColor: themeColor),
              const SizedBox(height: 32),

              _SectionTitle(label: '個人資訊', themeColor: themeColor),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.person_outline,
                label: '姓名',
                value: profile.displayName,
                themeColor: themeColor,
              ),
              if (profile.bio != null && profile.bio!.isNotEmpty)
                _InfoTile(
                  icon: Icons.edit_outlined,
                  label: '簡介',
                  value: profile.bio!,
                  themeColor: themeColor,
                ),
              if (profile.skills.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SkillsSection(skills: profile.skills, themeColor: themeColor),
              ],
              const SizedBox(height: 28),

              // 雇主專區：只在雇主身份時顯示
              if (currentRole == AppRole.employer) ...[
                _SectionTitle(label: '雇主專區', themeColor: themeColor),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.work_outline,
                  label: '職缺管理',
                  themeColor: themeColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployerJobsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              _SectionTitle(label: '帳號', themeColor: themeColor),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.edit,
                label: '編輯個人資料',
                themeColor: themeColor,
                onTap: () => _showEditSheet(context, ref, profile),
              ),
              _ActionTile(
                icon: Icons.logout,
                label: '登出',
                themeColor: const Color(0xFFFF4757),
                onTap: () => _confirmSignOut(context, ref),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── 編輯個人資料 bottom sheet
  void _showEditSheet(BuildContext context, WidgetRef ref, UserModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: profile, themeColor: themeColor),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('確定要登出？',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text('取消', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                ref.read(currentRoleProvider.notifier).reset();
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                debugPrint('登出錯誤: $e');
              } finally {
                if (context.mounted) context.go('/welcome');
              }
            },
            child: const Text('登出',
                style: TextStyle(color: Color(0xFFFF4757))),
          ),
        ],
      ),
    );
  }
}

// ── 編輯個人資料 Sheet
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile, required this.themeColor});
  final UserModel profile;
  final Color themeColor;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _skillController;
  late List<String> _skills;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _skillController = TextEditingController();
    _skills = List<String>.from(widget.profile.skills);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('姓名不能為空')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('未登入');

      await Supabase.instance.client.from('users').update({
        'display_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'skills': _skills,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ 個人資料已更新'),
            backgroundColor: widget.themeColor.withValues(alpha: 0.8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('儲存失敗：$e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.themeColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                '編輯個人資料',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 姓名
              _buildField(_nameController, '姓名', Icons.person, color),
              const SizedBox(height: 16),

              // 簡介
              _buildField(_bioController, '個人簡介', Icons.edit, color,
                  maxLines: 3),
              const SizedBox(height: 16),

              // 技能
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
                decoration: _inputDeco('輸入技能按 Enter', Icons.bolt, color),
              ),
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
              const SizedBox(height: 24),

              // 儲存按鈕
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          '儲存',
                          style: TextStyle(
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
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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

// ── 以下 Widget 不變，只修 withOpacity → withValues ──

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.profile, required this.themeColor});
  final UserModel profile;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: themeColor, width: 2),
            boxShadow: [
              BoxShadow(
                  color: themeColor.withValues(alpha: 0.3), blurRadius: 16)
            ],
          ),
          child: ClipOval(
            child: profile.avatarUrl != null
                ? Image.network(profile.avatarUrl!, fit: BoxFit.cover)
                : Container(
                    color: themeColor.withValues(alpha: 0.15),
                    child: Icon(Icons.person, color: themeColor, size: 44),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          profile.email,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.themeColor});
  final String label;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: themeColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.themeColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: themeColor, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({required this.skills, required this.themeColor});
  final List<String> skills;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: themeColor, size: 18),
              const SizedBox(width: 8),
              const Text('技能',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: themeColor.withValues(alpha: 0.12),
                        border: Border.all(
                            color: themeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(s,
                          style: TextStyle(
                              color: themeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.themeColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color themeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: themeColor.withValues(alpha: 0.06),
          border: Border.all(color: themeColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: themeColor, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: themeColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: themeColor.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }
}