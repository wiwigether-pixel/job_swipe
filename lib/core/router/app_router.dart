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

part 'app_router.g.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
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

      final isLoggedIn = authRepository.currentUser != null ||
          (authStateAsync.hasValue && authStateAsync.value != null);

      // auth stream 還在載入，等待
      if (authStateAsync.isLoading) return null;

      debugPrint('[Router] path=$location, loggedIn=$isLoggedIn');

      final isEntryPage = location == AppRoutes.welcome ||
          location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.splash;

      if (!isLoggedIn) {
        return isEntryPage ? null : AppRoutes.welcome;
      }

      // profile stream 還沒有發出第一個值，等待
      // hasValue=false 代表 stream 還沒回應，不是「沒有 profile」
      if (!profileAsync.hasValue) {
        debugPrint('[Router] profile not yet loaded, waiting...');
        return null;
      }

      final profile = profileAsync.value;
      final needsOnboarding = profile == null || !profile.isProfileComplete;

      debugPrint('[Router] displayName=${profile?.displayName}, '
          'isProfileComplete=${profile?.isProfileComplete}, '
          'needsOnboarding=$needsOnboarding');

      if (needsOnboarding) {
        return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
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
          body: Center(child: CircularProgressIndicator()),
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
          return OnboardingScreen(initialRole: role);
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

// WelcomeScreen 和 _RouterRefreshNotifier 不變，保留你原本的
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