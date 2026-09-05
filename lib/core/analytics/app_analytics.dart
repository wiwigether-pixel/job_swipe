import 'package:firebase_analytics/firebase_analytics.dart';

/// 行銷數據追蹤的單一入口（Firebase Analytics）。
///
/// 集中管理事件名稱與參數，避免散落字串；UI 端只呼叫語意化方法。
class AppAnalytics {
  AppAnalytics._();

  static final FirebaseAnalytics instance = FirebaseAnalytics.instance;

  /// 掛到 GoRouter 的 observers，自動上報 screen_view（頁面瀏覽）。
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: instance);

  /// 行銷活動：使用者點擊「立即參加」。
  static Future<void> logCampaignJoin(String campaign) {
    return instance.logEvent(
      name: 'campaign_join',
      parameters: {'campaign': campaign},
    );
  }

  /// 通用事件（保留彈性）。
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) {
    return instance.logEvent(name: name, parameters: parameters);
  }
}
