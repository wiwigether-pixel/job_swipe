import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/models/job_model.dart';
import '../data/supabase_swipe_repository.dart';
import '../domain/swipe_repository.dart';
import '../../auth/presentation/auth_provider.dart';

part 'swipe_provider.g.dart';

/// SwipeRepository Provider
@Riverpod(keepAlive: true)
SwipeRepository swipeRepository(SwipeRepositoryRef ref) {
  return SupabaseSwipeRepository();
}

/// 推薦職缺列表 Provider
/// 【設計說明】使用 AsyncNotifier 而非單純的 FutureProvider
/// 好處：可以在滑卡後動態移除卡片，不需要重新 fetch 整個列表
@riverpod
class RecommendedJobs extends _$RecommendedJobs {
  @override
  Future<List<JobModel>> build() async {
    // 依賴 authState，使用者登入後自動重新載入
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.valueOrNull;

    // 未登入：回傳空列表
    if (user == null) return [];

    final repo = ref.read(swipeRepositoryProvider);
    return repo.getRecommendedJobs(userId: user.id);
  }

  /// 處理滑卡動作
  /// [jobId]：被滑的職缺 ID
  /// [isLike]：true = 右滑（喜歡），false = 左滑（跳過）
  /// 回傳：是否配對成功
  Future<bool> onSwipe({
    required String jobId,
    required bool isLike,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;

    final repo = ref.read(swipeRepositoryProvider);

    // 【樂觀更新】先從本地列表移除卡片，讓 UI 立即響應
    // 不等網路請求完成，使用者體驗更流暢
    final currentJobs = state.valueOrNull ?? [];
    final updatedJobs = currentJobs.where((j) => j.id != jobId).toList();
    state = AsyncData(updatedJobs);

    try {
      final isMatch = await repo.recordSwipe(
        swiperId: user.id,
        targetId: jobId,
        targetType: 'job',
        direction: isLike ? 'right' : 'left',
      );
      return isMatch;
    } catch (e) {
      // 【回滾】網路失敗時，把卡片放回列表
      state = AsyncData(currentJobs);
      rethrow;
    }
  }

  /// 重新載入推薦列表（例如：用戶手動下拉刷新）
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}