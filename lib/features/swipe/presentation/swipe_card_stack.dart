// lib/features/swipe/presentation/swipe_card_stack.dart
import 'package:flutter/material.dart';
import '../../../shared/widgets/swipe_card_wrapper.dart';
import '../data/supabase_swipe_repository.dart';
import 'job_card.dart';
import 'user_card.dart' as uc;

class SwipeCardStack extends StatelessWidget {
  const SwipeCardStack({
    super.key,
    required this.cards,
    required this.onSwipe,
    required this.controller,
    this.onEmpty,
  });

  final List<SwipeCard> cards;
  final void Function(SwipeCard card, bool isLike) onSwipe;
  final SwipeController controller;
  final VoidCallback? onEmpty;

  @override
  Widget build(BuildContext context) {
    final widgets = cards.map((card) {
      if (card.isJob) {
        return JobCard(job: card.job!);
      } else {
        return uc.UserCard(userCard: card.userCard!);
      }
    }).toList();

    return SwipeCardWrapper(
      controller: controller,
      cards: widgets,
      onEmpty: onEmpty,
      onSwipe: (index, direction) {
        if (index >= cards.length) return;
        final card = cards[index];
        final isLike = direction == SwipeDirection.right;
        onSwipe(card, isLike);
      },
    );
  }
}