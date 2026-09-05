import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/current_role_provider.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _accent = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeSettingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _SectionLabel('外觀'),
          _Card(children: [
            _RadioTile(
              label: '深色模式',
              selected: mode == ThemeMode.dark,
              onTap: () => ref
                  .read(themeModeSettingProvider.notifier)
                  .set(ThemeMode.dark),
            ),
            _RadioTile(
              label: '淺色模式',
              selected: mode == ThemeMode.light,
              onTap: () => ref
                  .read(themeModeSettingProvider.notifier)
                  .set(ThemeMode.light),
            ),
            _RadioTile(
              label: '跟隨系統',
              selected: mode == ThemeMode.system,
              onTap: () => ref
                  .read(themeModeSettingProvider.notifier)
                  .set(ThemeMode.system),
            ),
          ]),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('帳號'),
          _Card(children: [
            _NavTile(
                label: '變更密碼',
                onTap: () => _showChangePasswordDialog(context)),
            _NavTile(
                label: '封鎖名單',
                onTap: () => context.push('/settings/blocked')),
            _NavTile(
                label: '登出',
                labelColor: context.colors.danger,
                onTap: () => _confirmSignOut(context, ref)),
          ]),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('關於'),
          _Card(children: [
            ListTile(
              title: Text('版本',
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: Text('1.0.0',
                  style: TextStyle(color: context.colors.textTertiary)),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final pwController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('變更密碼'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pwController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密碼'),
                validator: (v) =>
                    (v == null || v.length < 6) ? '密碼至少需要 6 碼' : null,
              ),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '確認新密碼'),
                validator: (v) => v != pwController.text ? '兩次輸入不一致' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: pwController.text));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('密碼已更新')));
                }
              } on AuthException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('變更失敗：${e.message}')));
                }
              }
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    // 與 profile_screen._confirmSignOut 相同流程
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('確定要登出？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                ref.read(currentRoleProvider.notifier).reset();
                await Supabase.instance.client.auth.signOut();
              } catch (_) {} finally {
                if (context.mounted) context.go('/welcome');
              }
            },
            child: Text('登出',
                style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(children: children),
      );
}

class _RadioTile extends StatelessWidget {
  const _RadioTile(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        title: Text(label,
            style: TextStyle(
                color: selected
                    ? SettingsScreen._accent
                    : context.colors.textPrimary)),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected
              ? SettingsScreen._accent
              : context.colors.textTertiary,
        ),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.label, this.labelColor, required this.onTap});
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        title: Text(label,
            style: TextStyle(
                color: labelColor ?? context.colors.textPrimary)),
        trailing: Icon(Icons.chevron_right,
            color: context.colors.textTertiary),
      );
}
