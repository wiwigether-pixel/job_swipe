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
  static const onboarding = '/onboarding';       // 初始 onboarding（註冊後）
  static const roleOnboarding = '/role-onboarding'; // 切換身份後的 onboarding
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

  ref.listen(authStateProvider, (_, __) => notifier.notify());
  ref.listen(profileProvider, (_, __) => notifier.notify());

  return GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: notifier,
    redirect: (context, state) {
      final location = state.uri.path;

      // auth 還在載入，維持原位
      if (authStateAsync.isLoading) return null;

      final isLoggedIn = authRepository.currentUser != null ||
          (authStateAsync.hasValue && authStateAsync.value != null);

      logger.i('[Router] path=$location, loggedIn=$isLoggedIn');

      final isEntryPage = location == AppRoutes.welcome ||
          location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.splash;

      if (!isLoggedIn) {
        return isEntryPage ? null : AppRoutes.welcome;
      }

      // 已登入，等待 profile stream
      // 注意：profileAsync.hasValue=true 但 value=null 有兩種情況：
      // 1. stream 剛建立，推了初始 null（user 還在載入）→ 等待
      // 2. DB 真的沒有這個 user 的資料 → 需要 onboarding
      // 用 authStateAsync 是否有 user 來區分這兩種情況
      if (!profileAsync.hasValue) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // profileAsync.value == null 但 auth 有 user
      // → stream 可能剛切換還沒拿到值，等一下
      if (profileAsync.value == null &&
          authStateAsync.hasValue &&
          authStateAsync.value != null) {
        // 給一個緩衝：如果已經在 splash 就繼續等，否則去 splash
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final profile = profileAsync.value;

      // profile 為 null = DB 沒有這筆 → 需要 onboarding
      // isProfileComplete = false → 還沒填過頭像或姓名 → 需要 onboarding
      final needsOnboarding = profile == null || !profile.isProfileComplete;

      logger.i('[Router] displayName=${profile?.displayName}, '
          'isProfileComplete=${profile?.isProfileComplete}, '
          'needsOnboarding=$needsOnboarding');

      if (needsOnboarding) {
        // role-onboarding 是切換身份後的，不受此邏輯影響
        if (location == AppRoutes.onboarding) return null;
        if (location == AppRoutes.roleOnboarding) return null;
        return AppRoutes.onboarding;
      }

      if (isEntryPage || location == AppRoutes.onboarding) {
        return AppRoutes.swipe;
      }

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
          // extra 傳入要填寫的 role
          final role = state.extra as String? ?? 'job_seeker';
          return OnboardingScreen(
            initialRole: role,
            isRoleSwitch: true, // 告訴 onboarding 這是切換身份，存到 user_profiles
          );
        },
      ),
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

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier() {
    notifyListeners();
  }

  void notify() => notifyListeners();
}