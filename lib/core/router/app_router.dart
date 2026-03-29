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
import '../../features/profile/presentation/profile_screen.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/router/main_shell.dart';
import 'package:job_swipe/core/utils/logger.dart';

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
}

@Riverpod(keepAlive: true)
GoRouter appRouter(AppRouterRef ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final authStateAsync = ref.watch(authStateProvider);
  final profileAsync = ref.watch(profileProvider);

  final notifier = _RouterRefreshNotifier();
  ref.onDispose(notifier.dispose);

  // 監聽狀態變化，觸發 Router 重新導向
  ref.listen(authStateProvider, (_, __) => notifier.notify());
  ref.listen(profileProvider, (_, __) => notifier.notify());

  return GoRouter(
    // 將初始路徑設為 Splash，讓 App 啟動時有緩衝空間判斷登入狀態
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final location = state.uri.path;

      // 1. Auth 載入中，留在原處（或 Splash）
      if (authStateAsync.isLoading) return null;

      final user = authRepository.currentUser;
      final isLoggedIn = user != null;

      // 2. 未登入邏輯
      if (!isLoggedIn) {
        final isEntryPage = location == AppRoutes.welcome ||
            location == AppRoutes.login ||
            location == AppRoutes.register;
        // 如果不在入口頁，強制導向 welcome
        return isEntryPage ? null : AppRoutes.welcome;
      }

      // 3. 已登入，但 Profile 還在讀取或 Stream 尚未建立
      if (profileAsync.isLoading) return AppRoutes.splash;

      final profile = profileAsync.valueOrNull;
      
      // 判定是否需要進行 Onboarding (資料夾沒資料或不完整)
      final needsOnboarding = profile == null || !profile.isProfileComplete;

      // 使用我們新建立的 logger，發布後會自動靜音
      logger.i('[Router] path=$location, user=${user.email}, needsOnboarding=$needsOnboarding');

      // 4. 需要 Onboarding 的邏輯
      if (needsOnboarding) {
        // 如果已經在 onboarding 相關頁面，不動作
        if (location == AppRoutes.onboarding || location == AppRoutes.roleOnboarding) {
          return null;
        }
        return AppRoutes.onboarding;
      }

      // 5. 已登入且資料完整：如果還在入口或 Onboarding 頁面，就送去 Swipe 首頁
      final isAtEntryOrOnboarding = 
          location == AppRoutes.welcome || 
          location == AppRoutes.login || 
          location == AppRoutes.register || 
          location == AppRoutes.splash ||
          location == AppRoutes.onboarding;

      if (isAtEntryOrOnboarding) {
        return AppRoutes.swipe;
      }

      // 6. 其他情況（已經在主 App 內），不進行額外跳轉
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) {
          final container = ProviderScope.containerOf(context);
          final profile = container.read(profileProvider).valueOrNull;
          final role = profile?.role.toDbString ?? 'job_seeker';
          return OnboardingScreen(
            initialRole: role,
            isRoleSwitch: false,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.roleOnboarding,
        builder: (context, state) {
          final role = state.extra as String? ?? 'job_seeker';
          return OnboardingScreen(
            initialRole: role,
            isRoleSwitch: true,
          );
        },
      ),
      // 主 App 導覽列包裝
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.swipe,
            builder: (_, __) => const SwipeScreen(),
          ),
          GoRoute(
            path: AppRoutes.messages,
            builder: (_, __) => const MessagesScreen(),
          ),
          GoRoute(
            path: AppRoutes.matches,
            builder: (_, __) => const MatchesScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier() {
    notifyListeners();
  }
  void notify() => notifyListeners();
}

// WelcomeScreen 維持原樣...

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF6C63FF), Color(0xFF4338CA)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_motion_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'JobSwipe',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '像玩交友軟體一樣簡單。\n左右滑動，找到你的理想職缺。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  const Spacer(flex: 2),
                  _buildButton(
                    context,
                    label: '立即註冊',
                    isPrimary: true,
                    onTap: () => context.push(AppRoutes.register),
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
                    context,
                    label: '已有帳號？登入',
                    isPrimary: false,
                    onTap: () => context.push(AppRoutes.login),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : Colors.transparent,
          foregroundColor: isPrimary ? const Color(0xFF4338CA) : Colors.white,
          elevation: isPrimary ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: Colors.white, width: 2),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
