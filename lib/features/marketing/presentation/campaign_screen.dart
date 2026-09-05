import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../profile/presentation/employer_jobs_screen.dart';

/// 行銷活動頁：把行銷網頁內容嵌入 Flutter（WebView）。
///
/// 透過 [JavaScriptChannel] `FlutterBridge` 與網頁雙向溝通：
/// 網頁的「立即參加活動」按鈕會把事件回呼到 Flutter 端處理
/// （例如記錄參加、上報分析、發放徽章）。
class CampaignScreen extends ConsumerStatefulWidget {
  const CampaignScreen({super.key, this.campaignUrl});

  /// 可選的遠端行銷頁網址；未提供時載入內建的活動頁 asset。
  final String? campaignUrl;

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    _load();
  }

  Future<void> _load() async {
    final url = widget.campaignUrl;
    if (url != null && url.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(url));
    } else {
      final html = await rootBundle.loadString('assets/marketing/campaign.html');
      await _controller.loadHtmlString(html);
    }
  }

  Future<void> _onBridgeMessage(JavaScriptMessage message) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (data['action'] == 'join_campaign') {
      final campaign = data['campaign'] as String? ?? 'unknown';
      // 上報行銷成效到 Firebase Analytics
      AppAnalytics.logCampaignJoin(campaign);
      // 參加活動 → 解鎖免費刊登額度 +3
      try {
        await Supabase.instance.client
            .rpc('add_job_quota', params: {'p_amount': 3});
      } catch (_) {
        // 額度發放失敗不阻擋流程，使用者仍可進入刊登頁
      }
      ref.invalidate(freeJobQuotaProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0CBB78),
          content: Text('✅ 已啟用免費刊登，請發布你的職缺'),
        ),
      );
      // 「按參加」即進入真正的職缺刊登流程（自動彈出新增職缺表單）
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const EmployerJobsScreen(autoOpenCreate: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          '限時活動',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ),
        ],
      ),
    );
  }
}
