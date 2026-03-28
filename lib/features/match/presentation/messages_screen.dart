import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/current_role_provider.dart';
import '../../../core/router/main_shell.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

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
          '訊息',
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
      body: _buildBody(themeColor),
    );
  }

  Widget _buildBody(Color themeColor) {
    // MVP 階段：顯示空狀態，後期整合 Supabase Realtime
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: themeColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            '還沒有訊息',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '配對成功後就能開始聊天',
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}