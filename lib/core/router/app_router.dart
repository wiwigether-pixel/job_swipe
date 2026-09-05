// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/swipe/presentation/swipe_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/match/presentation/messages_screen.dart';
import '../../features/match/presentation/matches_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/marketing/presentation/campaign_screen.dart';
import '../../features/admin/data/admin_provider.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/dashboard_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/admin/presentation/admin_jobs_screen.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/admin/presentation/admin_inbox_screen.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/router/main_shell.dart';
import '../../shared/models/user_model.dart';
import '../utils/logger.dart';
import '../analytics/app_analytics.dart';

part 'app_router.g.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
  static const roleOnboarding = '/role-onboarding';
  static const swipe = '/swipe';
  static const messages = '/messages';
  static const matches = '/matches';
  static const profile = '/profile';
  static const campaign = '/campaign';
  static const admin = '/admin';
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminJobs = '/admin/jobs';
  static const adminReports = '/admin/reports';
  static const adminInbox = '/admin/inbox';
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6C63FF), Color(0xFF4338CA)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.auto_awesome_motion_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                const Text('JobSwipe', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                _buildButton(context, '立即註冊', true, () => context.push(AppRoutes.register)),
                const SizedBox(height: 16),
                _buildButton(context, '已有帳號？登入', false, () => context.push(AppRoutes.login)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String label, bool primary, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? Colors.white : Colors.transparent,
          foregroundColor: primary ? const Color(0xFF4338CA) : Colors.white,
          side: primary ? BorderSide.none : const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(AppRouterRef ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final authStateAsync = ref.watch(authStateProvider);

  final notifier = _RouterRefreshNotifier();
  ref.onDispose(notifier.dispose);

  ref.listen(authStateProvider, (_, __) => notifier.notify());
  ref.listen(profileProvider, (_, __) => notifier.notify());
  ref.listen(adminRoleProvider, (_, __) => notifier.notify());

  return GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: notifier,
    observers: [AppAnalytics.observer],
    redirect: (context, state) {
      final location = state.uri.path;
      if (authStateAsync.isLoading) return null;

      final isLoggedIn = authRepository.currentUser != null;

      if (!isLoggedIn) {
        final isAuthPage = location == AppRoutes.welcome || location == AppRoutes.login || location == AppRoutes.register;
        return isAuthPage ? null : AppRoutes.welcome;
      }

      // ── Admin 守衛 ──
      // 進入 /admin/* 需要是管理員；非管理員一律踢回 /swipe
      final isAtAdmin = location.startsWith(AppRoutes.admin);
      if (isAtAdmin) {
        final adminAsync = ref.read(adminRoleProvider);
        if (adminAsync.isLoading) return null;
        final isAdmin = adminAsync.valueOrNull != null;
        if (!isAdmin) return AppRoutes.swipe;
        // 管理員進後台，豁免 onboarding 檢查
        if (location == AppRoutes.admin) return AppRoutes.adminDashboard;
        return null;
      }

      final profileAsync = ref.read(profileProvider);
      if (profileAsync.isLoading) return null;

      final profile = profileAsync.valueOrNull;
      final currentRole = profile?.effectiveRole ?? AppRole.jobSeeker;
      
      // ✅ 修正點 1：判斷是否已經在 Onboarding 頁面
      final bool isAtOnboarding = location == AppRoutes.onboarding || location == AppRoutes.roleOnboarding;

      // ✅ 修正點 2：增加豁免邏輯
      final bool needsOnboarding = profile == null || !profile.isCompleteFor(currentRole);

      if (needsOnboarding) {
        // 如果資料不全，但使用者已經在 Onboarding 頁面，就不要重導向（讓它繼續填）
        if (isAtOnboarding) return null;
        return AppRoutes.onboarding;
      }

      // 資料齊全後，如果還待在入口頁，導向首頁
      if (location == AppRoutes.onboarding || location == AppRoutes.welcome || location == AppRoutes.login) {
        return AppRoutes.swipe;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: AppRoutes.welcome, builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) {
          final profile = ref.read(profileProvider).valueOrNull;
          return OnboardingScreen(
            initialRole: profile?.role.toDbString ?? 'job_seeker',
            isRoleSwitch: false,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.roleOnboarding,
        builder: (context, state) {
          final roleStr = state.extra as String? ?? 'job_seeker';
          return OnboardingScreen(
            initialRole: roleStr,
            isRoleSwitch: true,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.swipe, builder: (_, __) => const SwipeScreen()),
          GoRoute(path: AppRoutes.matches, builder: (_, __) => const MatchesScreen()),
          GoRoute(path: AppRoutes.messages, builder: (_, __) => const MessagesScreen()),
          GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;
          final otherName = state.extra as String? ?? '對方';
          return ChatScreen(matchId: matchId, otherName: otherName);
        },
      ),
      GoRoute(
        path: AppRoutes.campaign,
        builder: (context, state) =>
            CampaignScreen(campaignUrl: state.extra as String?),
      ),
      // ── Admin 後台 ──
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
              path: AppRoutes.adminDashboard,
              builder: (_, __) => const DashboardScreen()),
          GoRoute(
              path: AppRoutes.adminUsers,
              builder: (_, __) => const AdminUsersScreen()),
          GoRoute(
              path: AppRoutes.adminJobs,
              builder: (_, __) => const AdminJobsScreen()),
          GoRoute(
              path: AppRoutes.adminReports,
              builder: (_, __) => const AdminReportsScreen()),
          GoRoute(
              path: AppRoutes.adminInbox,
              builder: (_, __) => const AdminInboxScreen()),
        ],
      ),
    ],
  );
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier() { notifyListeners(); }
  void notify() => notifyListeners();
}