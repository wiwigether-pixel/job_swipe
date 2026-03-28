import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/current_role_provider.dart';
import '../../../core/router/main_shell.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(currentRoleProvider);
    final themeColor = currentRole.themeColor;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '配對清單',
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: themeColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              '還沒有配對',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '右滑喜歡的卡片來建立配對',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}