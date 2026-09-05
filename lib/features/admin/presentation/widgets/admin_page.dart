import 'package:flutter/material.dart';

const adminAccent = Color(0xFFFF6B35);

/// 後台頁面共用外框（標題列 + 內距 + 重新整理）
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.child,
    this.onRefresh,
    this.actions,
  });

  final String title;
  final Widget child;
  final VoidCallback? onRefresh;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.all(narrow ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: narrow ? 22 : 26,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (actions != null) ...actions!,
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon:
                      const Icon(Icons.refresh_rounded, color: Colors.white54),
                  tooltip: '重新整理',
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}
