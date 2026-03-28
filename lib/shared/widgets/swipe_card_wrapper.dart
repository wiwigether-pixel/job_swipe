import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

/// 滑卡方向（我們自己定義，與套件解耦）
enum SwipeDirection { left, right, up, down }

/// 滑卡事件回呼
/// [index]：被滑掉的卡片索引
/// [direction]：滑動方向
typedef OnSwipeCallback = void Function(int index, SwipeDirection direction);

/// 【隔離層】封裝 flutter_card_swiper
/// 對外只暴露我們定義的介面，套件的細節完全藏在這裡
/// 未來換套件：只需要修改這個檔案，上層完全不受影響
class SwipeCardWrapper extends StatefulWidget {
  const SwipeCardWrapper({
    super.key,
    required this.cards,
    required this.onSwipe,
    this.onEmpty,
    this.controller,
  });

  /// 要顯示的卡片 Widget 列表
  final List<Widget> cards;

  /// 滑卡時的回呼
  final OnSwipeCallback onSwipe;

  /// 所有卡片都滑完時的回呼
  final VoidCallback? onEmpty;

  /// 外部控制器（用於程式觸發滑卡，例如按鈕）
  final SwipeController? controller;

  @override
  State<SwipeCardWrapper> createState() => _SwipeCardWrapperState();
}

class _SwipeCardWrapperState extends State<SwipeCardWrapper> {
  late final CardSwiperController _innerController;

  @override
  void initState() {
    super.initState();
    _innerController = CardSwiperController();
    // 把外部 controller 的指令橋接到套件的 controller
    widget.controller?._attach(_innerController);
  }

  @override
  void dispose() {
    _innerController.dispose();
    widget.controller?._detach();
    super.dispose();
  }

  /// 將套件的方向枚舉轉換成我們自己的枚舉
  SwipeDirection _mapDirection(CardSwiperDirection direction) {
    return switch (direction) {
      CardSwiperDirection.left  => SwipeDirection.left,
      CardSwiperDirection.right => SwipeDirection.right,
      CardSwiperDirection.top   => SwipeDirection.up,
      CardSwiperDirection.bottom => SwipeDirection.down,
      _ => SwipeDirection.left,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return CardSwiper(
      controller: _innerController,
      cardsCount: widget.cards.length,
      // 同時顯示最多 3 張卡（有層次感）
      numberOfCardsDisplayed: widget.cards.length.clamp(1, 3),
      cardBuilder: (context, index, horizontalOffset, verticalOffset) {
        return widget.cards[index];
      },
      onSwipe: (previousIndex, currentIndex, direction) {
        widget.onSwipe(previousIndex, _mapDirection(direction));
        // 滑完最後一張
        if (currentIndex == null) widget.onEmpty?.call();
        return true; // 返回 true 允許這次滑動
      },
      // 視覺參數
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      scale: 0.92,          // 後方卡片的縮放比例
      backCardOffset: const Offset(0, 24), // 後方卡片的偏移
      isDisabled: false,
      allowedSwipeDirection: const AllowedSwipeDirection.only(
        left: true,
        right: true,
      ),
    );
  }
}

/// 外部控制器（Bridge Pattern）
/// 讓 SwipeScreen 可以用按鈕觸發滑卡，但不直接碰套件的 Controller
class SwipeController {
  CardSwiperController? _inner;

  void _attach(CardSwiperController inner) => _inner = inner;
  void _detach() => _inner = null;

  /// 程式觸發左滑
  void swipeLeft() =>
      _inner?.swipe(CardSwiperDirection.left);

  /// 程式觸發右滑
  void swipeRight() =>
      _inner?.swipe(CardSwiperDirection.right);
}