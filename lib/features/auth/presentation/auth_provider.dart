import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/models/user_model.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';

part 'auth_provider.g.dart';

/// Repository Provider（單例，整個 App 共用同一個 repository 實例）
@Riverpod(keepAlive: true) // keepAlive: true = 不會因為沒有 listener 而被銷毀
AuthRepository authRepository(AuthRepositoryRef ref) {
  final repo = SupabaseAuthRepository();
  // 當 Provider 被銷毀時，清理資源（避免記憶體洩漏）
  ref.onDispose(repo.dispose);
  return repo;
}

/// 登入狀態 Provider（監聽 Stream，UI 自動更新）
@riverpod
Stream<UserModel?> authState(AuthStateRef ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateStream;
}

/// 登入/登出操作的 Notifier
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<UserModel?> build() {
    // 初始狀態：從 repository 取得目前使用者
    final repo = ref.watch(authRepositoryProvider);
    return AsyncData(repo.currentUser);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    // 設定 loading 狀態（UI 會自動顯示 loading indicator）
    state = const AsyncLoading();

    final repo = ref.read(authRepositoryProvider);

    // AsyncValue.guard 自動把例外包裝成 AsyncError，不用自己寫 try-catch
    state = await AsyncValue.guard(
      () => repo.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(
      () => repo.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      ),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.signOut();
      return null; // 登出後 user 為 null
    });
  }
}