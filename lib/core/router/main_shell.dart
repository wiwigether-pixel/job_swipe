import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/user_model.dart';
import '../providers/current_role_provider.dart';

import '../router/app_router.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _colorAnimController;
  AppRole _prevRole = AppRole.jobSeeker;

  @override
  void initState() {
    super.initState();
    _colorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _colorAnimController.dispose();
    super.dispose();
  }

  int _locationToIndex(String location) {
    if (location.startsWith('/swipe')) return 0;
    if (location.startsWith('/messages')) return 1;
    if (location.startsWith('/matches')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/swipe');
      case 1: context.go('/messages');
      case 2: context.go('/matches');
      case 3: context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(currentRoleProvider);
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _locationToIndex(location);
    final themeColor = currentRole.themeColor;

    if (_prevRole != currentRole) {
      _prevRole = currentRole;
      _colorAnimController.forward(from: 0);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: widget.child,
      bottomNavigationBar: _CyberpunkNavBar(
        selectedIndex: selectedIndex,
        themeColor: themeColor,
        onTap: (i) => _onTap(i, context),
      ),
    );
  }
}

class _CyberpunkNavBar extends StatelessWidget {
  const _CyberpunkNavBar({
    required this.selectedIndex,
    required this.themeColor,
    required this.onTap,
  });

  final int selectedIndex;
  final Color themeColor;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.style_rounded, Icons.style_outlined, '發現'),
      (Icons.chat_bubble_rounded, Icons.chat_bubble_outline, '訊息'),
      (Icons.favorite_rounded, Icons.favorite_border, '配對'),
      (Icons.person_rounded, Icons.person_outline, '我的'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: themeColor.withValues(alpha: 0.3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final (activeIcon, inactiveIcon, label) = items[i];
              final isSelected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isSelected ? activeIcon : inactiveIcon,
                            key: ValueKey(isSelected),
                            color: isSelected ? themeColor : Colors.white24,
                            size: isSelected ? 26 : 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? themeColor : Colors.white24,
                          ),
                          child: Text(label),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(top: 3),
                          width: isSelected ? 20 : 0,
                          height: 2,
                          decoration: BoxDecoration(
                            color: themeColor,
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: themeColor.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class RoleToggle extends ConsumerWidget {
  const RoleToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(currentRoleProvider);

    return GestureDetector(
      onTap: () => _showRolePicker(context, ref, currentRole),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: currentRole.themeColor, width: 1),
          borderRadius: BorderRadius.circular(20),
          color: currentRole.themeColor.withValues(alpha: 0.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(currentRole.icon, color: currentRole.themeColor, size: 14),
            const SizedBox(width: 6),
            Text(
              currentRole.label,
              style: TextStyle(
                color: currentRole.themeColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, color: currentRole.themeColor, size: 14),
          ],
        ),
      ),
    );
  }

  void _showRolePicker(
      BuildContext context, WidgetRef ref, AppRole currentRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RolePickerSheet(currentRole: currentRole, ref: ref),
    );
  }
}

class _RolePickerSheet extends StatelessWidget {
  const _RolePickerSheet({required this.currentRole, required this.ref});
  final AppRole currentRole;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '切換身份模式',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '不同模式將顯示不同的推薦內容',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ...AppRole.values.map((role) {
                final isSelected = role == currentRole;
                return _RoleOption(
                  role: role,
                  isSelected: isSelected,
                  onTap: () async {
                    Navigator.pop(context);
                    if (!isSelected) {
                      // switchRole 回傳 true 代表這個身份還沒填過 onboarding
                      final needsOnboarding = await ref
                          .read(currentRoleProvider.notifier)
                          .switchRole(role);

                      if (needsOnboarding && context.mounted) {
                        // 跳到該身份的 onboarding，傳入 role 字串
                        context.push(
                          AppRoutes.roleOnboarding,
                          extra: role.toDbString,
                        );
                      }
                    }
                  },
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final AppRole role;
  final bool isSelected;
  final VoidCallback onTap;

  String get _description => switch (role) {
        AppRole.jobSeeker => '瀏覽職缺、申請工作',
        AppRole.employer => '發現人才、招募團隊',
        AppRole.peer => '認識同業、交流技術',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? role.themeColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected ? role.themeColor : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: role.themeColor.withValues(alpha: 0.15),
              ),
              child: Icon(role.icon, color: role.themeColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: TextStyle(
                      color: isSelected ? role.themeColor : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _description,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: role.themeColor, size: 20),
          ],
        ),
      ),
    );
  }
}