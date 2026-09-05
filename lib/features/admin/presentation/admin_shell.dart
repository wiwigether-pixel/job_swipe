import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_provider.dart';
import '../../../core/theme/app_colors.dart';

const _adminAccent = Color(0xFFFF6B35);

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  static const _destinations = [
    ('/admin/dashboard', Icons.dashboard_rounded, '儀表板'),
    ('/admin/users', Icons.people_rounded, '用戶管理'),
    ('/admin/jobs', Icons.work_rounded, '職缺管理'),
    ('/admin/reports', Icons.flag_rounded, '檢舉處理'),
    ('/admin/inbox', Icons.inbox_rounded, '收件夾'),
  ];

  int _locationToIndex(String location) {
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _locationToIndex(location);
    final adminRole = ref.watch(adminRoleProvider).valueOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        // 窄螢幕（手機）：側邊欄收進 Drawer，內容佔滿全寬
        if (!isWide) {
          return Scaffold(
            backgroundColor: context.colors.surfaceAlt,
            appBar: AppBar(
              backgroundColor: context.colors.surfaceAlt,
              elevation: 0,
              iconTheme: const IconThemeData(color: _adminAccent),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded, color: _adminAccent, size: 22),
                  const SizedBox(width: 8),
                  Text('管理後台',
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            drawer: Drawer(
              backgroundColor: context.colors.surfaceAlt,
              child: _Sidebar(
                selectedIndex: selectedIndex,
                adminRoleLabel: adminRole?.label,
                closeDrawerOnTap: true,
              ),
            ),
            body: child,
          );
        }

        // 寬螢幕（桌面）：側邊欄常駐
        return Scaffold(
          backgroundColor: context.colors.surfaceAlt,
          body: Row(
            children: [
              SizedBox(
                width: 220,
                child: _Sidebar(
                  selectedIndex: selectedIndex,
                  adminRoleLabel: adminRole?.label,
                  closeDrawerOnTap: false,
                ),
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.adminRoleLabel,
    required this.closeDrawerOnTap,
  });

  final int selectedIndex;
  final String? adminRoleLabel;
  final bool closeDrawerOnTap;

  void _go(BuildContext context, String path) {
    if (closeDrawerOnTap) Navigator.of(context).pop();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surfaceAlt,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: _adminAccent, size: 26),
                  const SizedBox(width: 10),
                  Text('管理後台',
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (adminRoleLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 4, 20, 0),
                child: Text(adminRoleLabel!,
                    style: const TextStyle(color: _adminAccent, fontSize: 12)),
              ),
            const SizedBox(height: 32),
            ...AdminShell._destinations.asMap().entries.map((e) {
              final i = e.key;
              final (path, icon, label) = e.value;
              return _NavItem(
                icon: icon,
                label: label,
                selected: i == selectedIndex,
                onTap: () => _go(context, path),
              );
            }),
            const Spacer(),
            _NavItem(
              icon: Icons.exit_to_app_rounded,
              label: '返回 App',
              selected: false,
              onTap: () => _go(context, '/swipe'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: selected ? _adminAccent : Colors.transparent,
              width: 3,
            ),
          ),
          color: selected ? _adminAccent.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? _adminAccent : context.colors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: selected ? context.colors.textPrimary : context.colors.textSecondary,
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
