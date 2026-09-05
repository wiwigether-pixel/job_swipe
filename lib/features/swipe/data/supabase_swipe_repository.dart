
import '../../../core/error/error_handler.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/models/job_model.dart';
import '../../../shared/models/user_card_model.dart';
import '../../../shared/models/user_model.dart';

/// 統一的滑卡結果
class SwipeCard {
  final JobModel? job;
  final UserCardModel? userCard;

  const SwipeCard.job(this.job) : userCard = null;
  const SwipeCard.user(this.userCard) : job = null;

  String get id => job?.id ?? userCard!.userId;
  bool get isJob => job != null;
}

class SupabaseSwipeRepository {
  /// 取得推薦卡片（求職者、雇主、同業）
  Future<List<SwipeCard>> getRecommendedCards({
    required String userId,
    required AppRole role,
    List<String> mySkills = const [],
  }) async {
    return switch (role) {
      AppRole.jobSeeker => _getJobCards(userId: userId),
      AppRole.employer  => _getTalentCards(userId: userId),
      AppRole.peer      => _getPeerCards(userId: userId, mySkills: mySkills),
    };
  }

  // --- 推薦邏輯 (內部實作) ---

  Future<List<SwipeCard>> _getJobCards({required String userId}) async {
    final swipedData = await SupabaseConfig.client
        .from('swipes')
        .select('target_id')
        .eq('swiper_id', userId)
        .eq('target_type', 'job');

    final swipedIds = (swipedData as List).map((r) => r['target_id'] as String).toList();

    var query = SupabaseConfig.client
        .from('jobs')
        .select('*, users!jobs_employer_id_fkey(company_name, avatar_url)')
        .eq('status', 'open')
        .neq('employer_id', userId);

    if (swipedIds.isNotEmpty) {
      query = query.not('id', 'in', '(${swipedIds.map((id) => '"$id"').join(',')})');
    }

    final data = await query.limit(20).order('created_at', ascending: false);
    return (data as List).map((r) => SwipeCard.job(JobModel.fromSupabase(r as Map<String, dynamic>))).toList();
  }

  Future<List<SwipeCard>> _getTalentCards({required String userId}) async {
    final swipedData = await SupabaseConfig.client.from('swipes').select('target_id').eq('swiper_id', userId).eq('target_type', 'user');
    final swipedIds = (swipedData as List).map((r) => r['target_id'] as String).toList();

    var query = SupabaseConfig.client.from('user_cards').select().eq('role', 'job_seeker').eq('is_open_to_opportunity', true).neq('user_id', userId);
    if (swipedIds.isNotEmpty) {
      query = query.not('user_id', 'in', '(${swipedIds.map((id) => '"$id"').join(',')})');
    }

    final data = await query.limit(20);
    return (data as List).map((r) => SwipeCard.user(UserCardModel.fromSupabase(r as Map<String, dynamic>))).toList();
  }

  Future<List<SwipeCard>> _getPeerCards({required String userId, required List<String> mySkills}) async {
    final swipedData = await SupabaseConfig.client.from('swipes').select('target_id').eq('swiper_id', userId).eq('target_type', 'user');
    final swipedIds = (swipedData as List).map((r) => r['target_id'] as String).toList();

    var query = SupabaseConfig.client.from('user_cards').select().eq('is_open_to_exchange', true).neq('user_id', userId);
    if (swipedIds.isNotEmpty) {
      query = query.not('user_id', 'in', '(${swipedIds.map((id) => '"$id"').join(',')})');
    }
    if (mySkills.isNotEmpty) {
      query = query.filter('skills', 'ov', '{${mySkills.map((s) => '"$s"').join(',')}}');
    }

    final data = await query.limit(20);
    return (data as List).map((r) => SwipeCard.user(UserCardModel.fromSupabase(r as Map<String, dynamic>))).toList();
  }

  // --- 核心邏輯：滑卡動作 ---

  Future<bool> recordSwipe({
    required String swiperId,
    required String targetId,
    required String targetType,
    required String direction,
  }) async {
    try {
      // 1. 紀錄基礎滑卡行為 (解決 409 Conflict)
      await SupabaseConfig.client.from('swipes').upsert({
        'swiper_id': swiperId,
        'target_id': targetId,
        'target_type': targetType,
        'direction': direction,
      }, onConflict: 'swiper_id, target_id');

      // 2. 左滑：拒絕即消除
      if (direction == 'left') {
        await _handleDeleteMatch(swiperId, targetId, targetType);
        return false;
      }

      // 3. 右滑：檢查是否能從 pending 轉向 accepted
      if (targetType == 'job') {
        return await _processJobMatch(swiperId, targetId);
      } else {
        return await _processUserMatch(swiperId, targetId);
      }
    } catch (e, stack) {
      throw ErrorHandler.handle(e, stack);
    }
  }

  /// 處理職缺配對
  Future<bool> _processJobMatch(String swiperId, String jobId) async {
    final jobData = await SupabaseConfig.client.from('jobs').select('employer_id').eq('id', jobId).single();
    final employerId = jobData['employer_id'] as String;

    // 檢查是否有對方的 pending 紀錄
    final existing = await SupabaseConfig.client.from('matches')
        .select()
        .eq('job_seeker_id', swiperId)
        .eq('job_id', jobId)
        .maybeSingle();

    if (existing != null) {
      // 如果對方(雇主)先 Like 了我
      if (existing['status'] == 'pending' && existing['initiator_id'] != swiperId) {
        await SupabaseConfig.client.from('matches').update({'status': 'accepted'}).eq('id', existing['id']);
        return true; // 配對成功，顯示 Dialog
      }
      return false;
    } else {
      // 第一次 Like，建立 pending
      await SupabaseConfig.client.from('matches').insert({
        'job_seeker_id': swiperId,
        'job_id': jobId,
        'employer_id': employerId,
        'initiator_id': swiperId,
        'status': 'pending',
      });
      return false;
    }
  }

  /// 處理人與人配對 (雇主看人才、同業交流)
  Future<bool> _processUserMatch(String swiperId, String targetUserId) async {
    // 情境 1：雇主右滑求職者
    // 查詢求職者是否曾右滑過自己發布的職缺（job match pending）
    final jobMatchData = await SupabaseConfig.client
        .from('matches')
        .select()
        .eq('job_seeker_id', targetUserId)
        .eq('employer_id', swiperId)
        .eq('status', 'pending')
        .limit(1);

    if ((jobMatchData as List).isNotEmpty) {
      await SupabaseConfig.client
          .from('matches')
          .update({'status': 'accepted'})
          .eq('id', jobMatchData[0]['id'] as String);
      return true;
    }

    // 情境 2：同業互滑（peer-to-peer）
    // 查詢對方是否已建立 pending 紀錄等待我確認
    final peerMatchData = await SupabaseConfig.client
        .from('matches')
        .select()
        .eq('status', 'pending')
        .eq('initiator_id', targetUserId)
        .eq('target_user_id', swiperId)
        .limit(1);

    if ((peerMatchData as List).isNotEmpty) {
      await SupabaseConfig.client
          .from('matches')
          .update({'status': 'accepted'})
          .eq('id', peerMatchData[0]['id'] as String);
      return true;
    }

    // 第一個滑的人：建立 pending 等對方確認
    await SupabaseConfig.client.from('matches').upsert({
      'initiator_id': swiperId,
      'target_user_id': targetUserId,
      'match_type': 'user',
      'status': 'pending',
    }, onConflict: 'initiator_id, target_user_id');
    return false;
  }

  /// 刪除邏輯
  Future<void> _handleDeleteMatch(String swiperId, String targetId, String targetType) async {
    if (targetType == 'job') {
      await SupabaseConfig.client.from('matches').delete()
          .eq('job_seeker_id', swiperId)
          .eq('job_id', targetId)
          .eq('status', 'pending');
    } else {
      await SupabaseConfig.client.from('matches').delete()
          .eq('status', 'pending')
          .or('and(initiator_id.eq.$targetId,target_user_id.eq.$swiperId)');
    }
  }
}