// lib/features/swipe/presentation/swipe_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/supabase_swipe_repository.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/providers/current_role_provider.dart';
import '../../../core/providers/profile_provider.dart';

export '../data/supabase_swipe_repository.dart' show SwipeCard;

part 'swipe_provider.g.dart';

@Riverpod(keepAlive: true)
SupabaseSwipeRepository swipeRepository(SwipeRepositoryRef ref) {
  return SupabaseSwipeRepository();
}

@riverpod
class RecommendedJobs extends _$RecommendedJobs {
  @override
  Future<List<SwipeCard>> build() async {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.valueOrNull;
    if (user == null) return [];

    final currentRole = ref.watch(currentRoleProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final mySkills = profile?.skills ?? [];

    final repo = ref.read(swipeRepositoryProvider);
    return repo.getRecommendedCards(
      userId: user.id,
      role: currentRole,
      mySkills: mySkills,
    );
  }

  Future<bool> onSwipe({
    required SwipeCard card,
    required bool isLike,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;

    final repo = ref.read(swipeRepositoryProvider);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((c) => c.id != card.id).toList());

    try {
      return await repo.recordSwipe(
        swiperId: user.id,
        targetId: card.id,
        targetType: card.isJob ? 'job' : 'user',
        direction: isLike ? 'right' : 'left',
      );
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}