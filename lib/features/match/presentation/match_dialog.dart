import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/job_model.dart';
import '../../../shared/models/user_card_model.dart';

/// 配對成功彈窗（支援 job 配對和 user 配對）
Future<void> showMatchDialog(
  BuildContext context, {
  JobModel? job,
  UserCardModel? userCard,
}) {
  assert(job != null || userCard != null, '必須提供 job 或 userCard');
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return _MatchDialogContent(job: job, userCard: userCard);
    },
  );
}

class _MatchDialogContent extends StatelessWidget {
  const _MatchDialogContent({this.job, this.userCard});
  final JobModel? job;
  final UserCardModel? userCard;

  String get _otherPartyLabel {
    if (job != null) return (job!.companyName ?? '?').substring(0, 1).toUpperCase();
    return (userCard!.displayName).substring(0, 1).toUpperCase();
  }

  String get _bodyText {
    if (job != null) {
      return '您對「${job!.title}」感興趣\n申請已送出，等待雇主確認後即可聊天！';
    }
    return '您與「${userCard!.displayName}」互相感興趣\n現在可以開始聊天了！';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          borderRadius: BorderRadius.circular(24),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 配對圖示（兩個頭像互相靠近）
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Avatar(label: 'ME'),
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite, color: Colors.white, size: 32),
                    const SizedBox(width: 8),
                    _Avatar(label: _otherPartyLabel),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  '🎉 配對成功！',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _bodyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // 按鈕列
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('繼續滑'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/messages');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '查看配對',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}