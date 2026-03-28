import '../../../core/error/error_handler.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/models/job_model.dart';
import '../domain/swipe_repository.dart';

class SupabaseSwipeRepository implements SwipeRepository {
  @override
  Future<List<JobModel>> getRecommendedJobs({required String userId}) async {
    try {
      // 【查詢邏輯】
      // 1. 從 jobs 表取得開放中的職缺
      // 2. JOIN users 表取得雇主資訊（公司名稱、頭像）
      // 3. 排除使用者已經滑過的職缺（用 not in subquery）
      final data = await SupabaseConfig.client
          .from('jobs')
          .select('''
            *,
            users!jobs_employer_id_fkey (
              company_name,
              avatar_url
            )
          ''')
          .eq('status', 'open')
          .not(
            'id',
            'in',
            // Subquery：取得此使用者已滑過的所有 target_id
            SupabaseConfig.client
                .from('swipes')
                .select('target_id')
                .eq('swiper_id', userId)
                .eq('target_type', 'job'),
          )
          .limit(20) // 每次最多拿 20 張，避免一次載入太多
          .order('created_at', ascending: false);

      return (data as List)
          .map((row) => JobModel.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      throw ErrorHandler.handle(e, stack);
    }
  }

  @override
  Future<bool> recordSwipe({
    required String swiperId,
    required String targetId,
    required String targetType,
    required String direction,
  }) async {
    try {
      // 記錄滑卡
      await SupabaseConfig.client.from('swipes').insert({
        'swiper_id': swiperId,
        'target_id': targetId,
        'target_type': targetType,
        'direction': direction,
      });

      // 只有右滑才需要檢查配對
      if (direction != 'right') return false;

      // 檢查雇主是否也右滑了這個求職者（MVP 簡化：自動配對）
      // 真實版本：雇主也需要在求職者列表右滑
      // MVP 版本：求職者右滑職缺 = 自動配對成功
      await SupabaseConfig.client.from('matches').upsert({
        'job_seeker_id': swiperId,
        'job_id': targetId,
        'employer_id': targetId, // MVP 簡化，Phase 後期再完善
        'status': 'pending',
      });

      return true; // MVP 階段：右滑即配對
    } catch (e, stack) {
      throw ErrorHandler.handle(e, stack);
    }
  }
}