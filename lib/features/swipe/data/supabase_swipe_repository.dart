// lib/features/swipe/data/supabase_swipe_repository.dart
import 'package:flutter/foundation.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/models/job_model.dart';
import '../../../shared/models/user_card_model.dart';
import '../../../shared/models/user_model.dart';

/// 統一的滑卡結果，可以是職缺或使用者卡片
class SwipeCard {
  final JobModel? job;
  final UserCardModel? userCard;

  const SwipeCard.job(this.job) : userCard = null;
  const SwipeCard.user(this.userCard) : job = null;

  String get id => job?.id ?? userCard!.id;
  bool get isJob => job != null;
}

class SupabaseSwipeRepository {
  /// 根據當前身份取得推薦卡片
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

  /// 求職者：從 jobs 表找開放職缺，排除自己已滑過、自己發的
  Future<List<SwipeCard>> _getJobCards({required String userId}) async {
    final swipedData = await SupabaseConfig.client
        .from('swipes')
        .select('target_id')
        .eq('swiper_id', userId)
        .eq('target_type', 'job');

    final swipedIds = (swipedData as List)
        .map((r) => r['target_id'] as String)
        .toList();

    var query = SupabaseConfig.client
        .from('jobs')
        .select('''
          *,
          users!jobs_employer_id_fkey (
            company_name,
            avatar_url
          )
        ''')
        .eq('status', 'open')
        .neq('employer_id', userId);

    if (swipedIds.isNotEmpty) {
      final idsStr = '(${swipedIds.map((id) => '"$id"').join(',')})';
      query = query.not('id', 'in', idsStr);
    }

    final data = await query.limit(20).order('created_at', ascending: false);

    return (data as List)
        .map((r) => SwipeCard.job(JobModel.fromSupabase(r as Map<String, dynamic>)))
        .toList();
  }

  /// 雇主：找 is_open_to_opportunity=true 的求職者
  Future<List<SwipeCard>> _getTalentCards({required String userId}) async {
    final swipedData = await SupabaseConfig.client
        .from('swipes')
        .select('target_id')
        .eq('swiper_id', userId)
        .eq('target_type', 'user');

    final swipedIds = (swipedData as List)
        .map((r) => r['target_id'] as String)
        .toList();

    var query = SupabaseConfig.client
        .from('user_cards')
        .select()
        .eq('role', 'job_seeker')
        .eq('is_open_to_opportunity', true)
        .neq('user_id', userId);

    if (swipedIds.isNotEmpty) {
      final idsStr = '(${swipedIds.map((id) => '"$id"').join(',')})';
      query = query.not('id', 'in', idsStr);
    }

    final data = await query.limit(20);

    return (data as List)
        .map((r) => SwipeCard.user(UserCardModel.fromSupabase(r as Map<String, dynamic>)))
        .toList();
  }

  /// 同業：找 is_open_to_exchange=true 且技能相近的人
  Future<List<SwipeCard>> _getPeerCards({
    required String userId,
    required List<String> mySkills,
  }) async {
    final swipedData = await SupabaseConfig.client
        .from('swipes')
        .select('target_id')
        .eq('swiper_id', userId)
        .eq('target_type', 'user');

    final swipedIds = (swipedData as List)
        .map((r) => r['target_id'] as String)
        .toList();

    try {
      var query = SupabaseConfig.client
          .from('user_cards')
          .select()
          .eq('is_open_to_exchange', true)
          .neq('user_id', userId);

      if (swipedIds.isNotEmpty) {
        final idsStr = '(${swipedIds.map((id) => '"$id"').join(',')})';
        query = query.not('id', 'in', idsStr);
      }

      if (mySkills.isNotEmpty) {
        final skillsArray = '{${mySkills.map((s) => '"$s"').join(',')}}';
        query = query.filter('skills', 'ov', skillsArray);
      }

      final data = await query.limit(20);
      return (data as List)
          .map((r) => SwipeCard.user(UserCardModel.fromSupabase(r as Map<String, dynamic>)))
          .toList();
    } catch (e) {
      // 技能篩選不支援時 fallback
      debugPrint('[SwipeRepo] peer skill filter failed, fallback: $e');
      var query = SupabaseConfig.client
          .from('user_cards')
          .select()
          .eq('is_open_to_exchange', true)
          .neq('user_id', userId);

      if (swipedIds.isNotEmpty) {
        final idsStr = '(${swipedIds.map((id) => '"$id"').join(',')})';
        query = query.not('id', 'in', idsStr);
      }

      final data = await query.limit(20);
      return (data as List)
          .map((r) => SwipeCard.user(UserCardModel.fromSupabase(r as Map<String, dynamic>)))
          .toList();
    }
  }

  /// 記錄滑卡
  Future<bool> recordSwipe({
    required String swiperId,
    required String targetId,
    required String targetType,
    required String direction,
  }) async {
    try {
      await SupabaseConfig.client.from('swipes').insert({
        'swiper_id': swiperId,
        'target_id': targetId,
        'target_type': targetType,
        'direction': direction,
      });

      if (direction != 'right') return false;

      if (targetType == 'job') {
        await SupabaseConfig.client.from('matches').upsert({
          'job_seeker_id': swiperId,
          'job_id': targetId,
          'status': 'pending',
        });
      } else {
        await SupabaseConfig.client.from('matches').upsert({
          'initiator_id': swiperId,
          'target_user_id': targetId,
          'match_type': 'user',
          'status': 'pending',
        });
      }

      return true;
    } catch (e, stack) {
      throw ErrorHandler.handle(e, stack);
    }
  }
}