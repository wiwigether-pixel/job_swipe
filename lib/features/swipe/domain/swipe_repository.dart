import '../../../shared/models/job_model.dart';

abstract interface class SwipeRepository {
  /// 取得推薦職缺（排除已滑過的）
  Future<List<JobModel>> getRecommendedJobs({required String userId});

  /// 記錄滑卡動作，並回傳是否配對成功
  Future<bool> recordSwipe({
    required String swiperId,
    required String targetId,
    required String targetType,
    required String direction, // 'left' or 'right'
  });
}