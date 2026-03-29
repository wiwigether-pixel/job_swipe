import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/swipe_card_wrapper.dart';
import '../../match/presentation/match_dialog.dart';
import '../../../core/providers/current_role_provider.dart';
import '../../../core/router/main_shell.dart';

import 'swipe_card_stack.dart';
import 'swipe_provider.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  late final SwipeController _swipeController;

  @override
  void initState() {
    super.initState();
    _swipeController = SwipeController();
  }

  Future<void> _handleSwipe(SwipeCard card, bool isLike) async {
    try {
      final isMatch = await ref
          .read(recommendedJobsProvider.notifier)
          .onSwipe(card: card, isLike: isLike);
      if (isMatch && isLike && mounted && card.isJob) {
        await showMatchDialog(context, job: card.job!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失敗，請稍後再試'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleSuperLike() async {
    // 用 controller 觸發動畫，讓 CardSwiper 正常走滑卡流程
    // 不直接呼叫 onSwipe，避免狀態不一致 crash
    _swipeController.swipeRight();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(recommendedJobsProvider);
    final currentRole = ref.watch(currentRoleProvider);
    final themeColor = currentRole.themeColor;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'JobSwipe',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeColor,
            fontSize: 24,
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: KeyedSubtree(
          key: ValueKey(currentRole),
          child: cardsAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: themeColor)),
            error: (error, stack) => _ErrorView(
              message: error.toString(),
              themeColor: themeColor,
              onRetry: () => ref.invalidate(recommendedJobsProvider),
            ),
            data: (cards) {
              if (cards.isEmpty) {
                return _EmptyView(
                  themeColor: themeColor,
                  currentRole: currentRole,
                  onRefresh: () => ref.read(recommendedJobsProvider.notifier).refresh(),
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '還有 ${cards.length} 個${_cardLabel(currentRole)}',
                          style: TextStyle(color: themeColor.withValues(alpha: 0.7), fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () => ref.read(recommendedJobsProvider.notifier).refresh(),
                          child: Text('重新整理', style: TextStyle(color: themeColor, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SwipeCardStack(
                      cards: cards,
                      controller: _swipeController,
                      onSwipe: _handleSwipe,
                      onEmpty: () {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('所有${_cardLabel(currentRole)}都看過了！'),
                              backgroundColor: themeColor.withValues(alpha: 0.8),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  _ActionButtons(
                    controller: _swipeController,
                    themeColor: themeColor,
                    onSuperLike: _handleSuperLike,
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _cardLabel(AppRole role) => switch (role) {
        AppRole.jobSeeker => '職缺',
        AppRole.employer => '人才',
        AppRole.peer => '同業',
      };
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.controller,
    required this.themeColor,
    required this.onSuperLike,
  });
  final SwipeController controller;
  final Color themeColor;
  final VoidCallback onSuperLike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircleButton(icon: Icons.close, color: const Color(0xFFFF4757), size: 64, iconSize: 32, onPressed: () => controller.swipeLeft()),
          _CircleButton(icon: Icons.star, color: const Color(0xFF3498DB), size: 48, iconSize: 24, onPressed: onSuperLike),
          _CircleButton(icon: Icons.favorite, color: themeColor, size: 64, iconSize: 32, onPressed: () => controller.swipeRight()),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111111),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.themeColor, required this.currentRole, required this.onRefresh});
  final Color themeColor;
  final AppRole currentRole;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: themeColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('今天的都看完了', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            '明天再來看看新的${switch (currentRole) { AppRole.jobSeeker => '職缺', AppRole.employer => '人才', AppRole.peer => '同業' }}吧！',
            style: const TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('重新整理'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor.withValues(alpha: 0.15),
              foregroundColor: themeColor,
              side: BorderSide(color: themeColor.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.themeColor, required this.onRetry});
  final String message;
  final Color themeColor;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFFF4757)),
            const SizedBox(height: 16),
            const Text('載入失敗', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor.withValues(alpha: 0.15),
                foregroundColor: themeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}