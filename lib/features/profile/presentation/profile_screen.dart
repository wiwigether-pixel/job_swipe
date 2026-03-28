import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/current_role_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/router/main_shell.dart';
import '../../../shared/models/user_model.dart';

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
            shadows: [Shadow(color: themeColor.withValues(alpha: 0.5), blurRadius: 8)],
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
        loading: () => Center(child: CircularProgressIndicator(color: themeColor)),
        error: (e, _) => Center(
          child: Text(e.toString(), style: const TextStyle(color: Colors.white38)),
        ),
        data: (profile) => profile == null
            ? const SizedBox.shrink()
            : _ProfileBody(
                profile: profile,
                themeColor: themeColor,
              ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // ── 頭像 + 名字
          _AvatarSection(profile: profile, themeColor: themeColor),
          const SizedBox(height: 32),

          // ── 身份模式切換
          _SectionTitle(label: '身份模式', themeColor: themeColor),
          const SizedBox(height: 12),
          ...AppRole.values.map((role) => _RoleRow(
                role: role,
                isActive: profile.effectiveRole == role,
                themeColor: themeColor,
                onTap: () =>
                    ref.read(currentRoleProvider.notifier).switchRole(role),
              )),
          const SizedBox(height: 28),

          // ── 個人資訊
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

          // ── 操作按鈕
          _SectionTitle(label: '帳號', themeColor: themeColor),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.edit,
            label: '編輯個人資料',
            themeColor: themeColor,
            onTap: () {
              // TODO: 導向編輯頁（Phase 後期）
            },
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
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog( // 使用獨立的 dialogContext
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('確定要登出？',
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // 安全關閉對話框
              child: const Text('取消', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () async {
                // 1. 先關閉對話框
                Navigator.pop(dialogContext);

                try {
                  // 2. 重置 Provider 狀態
                  ref.read(currentRoleProvider.notifier).reset();
                  
                  // 3. 執行登出 (加上 try-catch 防止資料庫欄位錯誤卡死流程)
                  await Supabase.instance.client.auth.signOut();
                } catch (e) {
                  debugPrint('登出過程中發生錯誤 (可能是資料庫欄位問題): $e');
                } finally {
                  // 4. 無論 API 成功或失敗，只要 context 還在，就強制跳轉回歡迎頁
                  if (context.mounted) {
                    // 使用 go 會重置路由棧，最安全
                    context.go('/welcome'); 
                  }
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
              BoxShadow(color: themeColor.withValues(alpha: 0.3), blurRadius: 16)
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

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.isActive,
    required this.themeColor,
    required this.onTap,
  });
  final AppRole role;
  final bool isActive;
  final Color themeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = role.themeColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isActive ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isActive ? color : Colors.white10,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(role.icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                role.label,
                style: TextStyle(
                  color: isActive ? color : Colors.white54,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(color: color, blurRadius: 6)
                  ],
                ),
              ),
          ],
        ),
      ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
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
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
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
                        border:
                            Border.all(color: themeColor.withValues(alpha: 0.3)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            Icon(Icons.chevron_right, color: themeColor.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }
}