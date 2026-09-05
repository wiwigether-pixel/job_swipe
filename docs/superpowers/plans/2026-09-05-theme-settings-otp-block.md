# 主題 Token 化 + 設定頁 + 忘記密碼 OTP + 封鎖 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 全面主題 token 化（深/淺/系統雙主題）+ 設定頁 + Email OTP 忘記密碼 + 完整封鎖功能。

**Architecture:** `ThemeExtension<AppColors>` 承載中性色語意 token，`themeModeSettingProvider` 持久化模式；忘記密碼走 Supabase OTP 三步驟單頁；封鎖用 `blocks` 表 + RLS + `get_blocked_me()` RPC，client 端以 `Set<String>` 過濾滑卡/配對/訊息三處。

**Tech Stack:** Flutter + Riverpod codegen + go_router + Supabase（DB 改動走 Supabase MCP connector）+ shared_preferences。

**Spec:** `docs/superpowers/specs/2026-09-05-settings-theme-otp-block-design.md`

## Global Constraints

- 所有指令先 `export PATH="/opt/homebrew/bin:/Users/alice/dev/tooling/flutter/bin:$PATH"`。
- Worktree 內 build 前必須 `cp /Users/alice/job_swipe/.env <worktree>/.env`（否則 asset bundling 失敗）。
- 改了 `@riverpod`/`@Riverpod` 或 freezed 後必跑 `dart run build_runner build --delete-conflicting-outputs`。
- analyze baseline：**0 errors / 22 warnings**（既有 style warnings，不新增即可）。
- Supabase project_id = `klwsmonobcenfoyhkyuq`；免費版會 auto-pause，執行 SQL 前若 timeout 先 restore。
- `users` 表已 REVOKE：他人公開資料一律 `fetchPublicUsersMap(List<String> ids)`（`lib/core/utils/user_hydration.dart`，回 `Future<Map<String, Map<String, dynamic>>>`，key=user id，row 含 `display_name`/`avatar_url`）。
- commit message 風格：`feat:`/`fix:`/`docs:` + 中文摘要（比照 `git log`）。
- **色彩替換對照表**（所有「硬編碼替換」任務適用；品牌 accent 一律不動：#6C63FF、#FF6B35、#2E7DEF、#4338CA、AppRole.themeColor、Welcome/onboarding 品牌 gradient）：

| 原值 | 替換為 |
|---|---|
| `Colors.black` / `Color(0xFF000000)`（背景） | `context.colors.background` |
| `Color(0xFF0A0A0A)` / `Color(0xFF101010)` | `context.colors.surfaceAlt` |
| `Color(0xFF1A1A1A)` / `Color(0xFF222222)` | `context.colors.surface` |
| `Colors.white`（文字/圖示） | `context.colors.textPrimary` |
| `Colors.white70` / `white60` / `white54` | `context.colors.textSecondary` |
| `Colors.white38` / `white30` / `white24` | `context.colors.textTertiary` |
| `Colors.white12` / `white10` | `context.colors.divider` |
| `Color(0xFFFF4757)` / `Colors.red` 系（錯誤/危險） | `context.colors.danger` |

  換色後含 `context.colors` 的 widget **不能是 const** —— 把該 widget 及必要的上層 const 拿掉；`TextStyle` 從 `const TextStyle(...)` 改 `TextStyle(...)`。每檔改完立刻 `flutter analyze`。

---

### Task 1: Worktree 準備

**Files:** 無（環境準備）

**Interfaces:**
- Produces: 可 build 的 worktree，branch `feature/theme-settings-otp-block`，base = main（已含 protected-data refactor merge）

- [ ] **Step 1: 開 worktree**（用 superpowers:using-git-worktrees skill；branch 名 `feature/theme-settings-otp-block`）
- [ ] **Step 2: 複製 .env**

```bash
cp /Users/alice/job_swipe/.env <worktree>/.env
```

- [ ] **Step 3: 安裝依賴並確認 baseline**

```bash
cd <worktree> && flutter pub get && flutter analyze
```

Expected: `22 issues found`（全 warnings、0 errors）

---

### Task 2: AppColors token（TDD）

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Test: `test/core/theme/app_colors_test.dart`

**Interfaces:**
- Produces: `class AppColors extends ThemeExtension<AppColors>`，欄位 `background/surface/surfaceAlt/textPrimary/textSecondary/textTertiary/divider/danger`（皆 `Color`）；靜態常數 `AppColors.dark`、`AppColors.light`；`extension AppColorsX on BuildContext { AppColors get colors; }`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/core/theme/app_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/core/theme/app_colors.dart';

void main() {
  test('dark token 值正確', () {
    expect(AppColors.dark.background, const Color(0xFF000000));
    expect(AppColors.dark.surface, const Color(0xFF1A1A1A));
    expect(AppColors.dark.textPrimary, Colors.white);
    expect(AppColors.dark.danger, const Color(0xFFFF4757));
  });

  test('light token 值正確', () {
    expect(AppColors.light.background, const Color(0xFFF5F5F7));
    expect(AppColors.light.surface, const Color(0xFFFFFFFF));
    expect(AppColors.light.textPrimary, const Color(0xFF1A1A1A));
    expect(AppColors.light.divider, const Color(0xFFE5E5EA));
  });

  test('lerp 中點不丟例外且回傳 AppColors', () {
    final mid = AppColors.dark.lerp(AppColors.light, 0.5);
    expect(mid, isA<AppColors>());
  });

  testWidgets('context.colors 從 Theme extension 取得', (tester) async {
    late AppColors got;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.dark]),
      home: Builder(builder: (context) {
        got = context.colors;
        return const SizedBox();
      }),
    ));
    expect(got.surface, const Color(0xFF1A1A1A));
  });
}
```

注意：pubspec 的 package 名若不是 `job_swipe`，import 改成實際名稱（看 `pubspec.yaml` 第一行 `name:`）。

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/core/theme/app_colors_test.dart`
Expected: FAIL（app_colors.dart 不存在）

- [ ] **Step 3: 實作**

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// 中性色語意 token（深淺雙主題）。品牌 accent（#6C63FF 等）不在此，維持各處常數。
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color danger;

  static const dark = AppColors(
    background: Color(0xFF000000),
    surface: Color(0xFF1A1A1A),
    surfaceAlt: Color(0xFF0A0A0A),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textTertiary: Colors.white38,
    divider: Colors.white12,
    danger: Color(0xFFFF4757),
  );

  static const light = AppColors(
    background: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFEFF4),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Colors.black54,
    textTertiary: Color(0x59000000),
    divider: Color(0xFFE5E5EA),
    danger: Color(0xFFFF4757),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? danger,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/core/theme/app_colors_test.dart`
Expected: PASS（4 tests）

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_colors.dart test/core/theme/app_colors_test.dart
git commit -m "feat(theme): AppColors 語意色 token（深淺雙主題）"
```

---

### Task 3: AppTheme + AppSpacing/AppRadius（TDD）

**Files:**
- Create: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: `AppColors`（Task 2）
- Produces: `AppTheme.dark()`、`AppTheme.light()` → `ThemeData`；`AppSpacing.xs/sm/md/lg/xl/xxl`（4/8/12/16/24/32）；`AppRadius.sm/md/lg`（12/16/20）

- [ ] **Step 1: 寫失敗測試**

```dart
// test/core/theme/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/core/theme/app_colors.dart';
import 'package:job_swipe/core/theme/app_theme.dart';

void main() {
  test('dark theme 掛上 AppColors.dark 且 scaffold 背景正確', () {
    final t = AppTheme.dark();
    expect(t.brightness, Brightness.dark);
    expect(t.extension<AppColors>(), AppColors.dark);
    expect(t.scaffoldBackgroundColor, AppColors.dark.background);
  });

  test('light theme 掛上 AppColors.light', () {
    final t = AppTheme.light();
    expect(t.brightness, Brightness.light);
    expect(t.extension<AppColors>(), AppColors.light);
    expect(t.scaffoldBackgroundColor, AppColors.light.background);
  });

  test('spacing/radius 常數', () {
    expect(AppSpacing.lg, 16.0);
    expect(AppRadius.md, 16.0);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL

- [ ] **Step 3: 實作**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
}

abstract class AppTheme {
  static ThemeData dark() => _base(AppColors.dark, Brightness.dark);
  static ThemeData light() => _base(AppColors.light, Brightness.light);

  static ThemeData _base(AppColors c, Brightness b) {
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme:
          ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), brightness: b),
      scaffoldBackgroundColor: c.background,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface),
      dividerColor: c.divider,
      extensions: [c],
    );
  }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/core/theme/`
Expected: PASS（7 tests）

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_theme.dart test/core/theme/app_theme_test.dart
git commit -m "feat(theme): AppTheme 雙主題 + AppSpacing/AppRadius token"
```

---

### Task 4: ThemeModeSetting provider（TDD）

**Files:**
- Create: `lib/core/providers/theme_mode_provider.dart`
- Test: `test/core/providers/theme_mode_provider_test.dart`

**Interfaces:**
- Produces: `themeModeSettingProvider`（`NotifierProvider`，state `ThemeMode`，預設 `ThemeMode.system`）；notifier 方法 `Future<void> set(ThemeMode mode)`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/core/providers/theme_mode_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/core/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('預設 system；set 後更新 state 並寫入 prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeSettingProvider), ThemeMode.system);

    await container.read(themeModeSettingProvider.notifier).set(ThemeMode.light);
    expect(container.read(themeModeSettingProvider), ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
  });

  test('啟動時從 prefs 載入既存值', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeModeSettingProvider); // 觸發 build
    await Future<void>.delayed(Duration.zero); // 等 _load
    expect(container.read(themeModeSettingProvider), ThemeMode.dark);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/core/providers/theme_mode_provider_test.dart`
Expected: FAIL

- [ ] **Step 3: 實作 + codegen**

```dart
// lib/core/providers/theme_mode_provider.dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_mode_provider.g.dart';

@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v != null) {
      state = switch (v) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    });
  }
}
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/core/providers/theme_mode_provider_test.dart`
Expected: PASS（2 tests）

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/theme_mode_provider.dart lib/core/providers/theme_mode_provider.g.dart test/core/providers/theme_mode_provider_test.dart
git commit -m "feat(theme): themeModeSetting provider（shared_preferences 持久化）"
```

---

### Task 5: app.dart 接雙主題

**Files:**
- Modify: `lib/app.dart:15-26`

**Interfaces:**
- Consumes: `AppTheme`（Task 3）、`themeModeSettingProvider`（Task 4）

- [ ] **Step 1: 修改 MaterialApp.router**

`lib/app.dart` 的 build 內（原本只有一個 `theme:`）改成：

```dart
    return MaterialApp.router(
      title: 'JobSwipe',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeSettingProvider),
      routerConfig: router,
      builder: (context, child) {
        return _GlobalErrorBoundary(child: child ?? const SizedBox.shrink());
      },
    );
```

新增 import：

```dart
import 'core/theme/app_theme.dart';
import 'core/providers/theme_mode_provider.dart';
```

- [ ] **Step 2: analyze + 全部測試**

Run: `flutter analyze && flutter test`
Expected: 0 errors；tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/app.dart
git commit -m "feat(theme): MaterialApp 接雙主題與 themeMode"
```

---

### Task 6: 硬編碼替換 — auth + welcome + main_shell

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`、`lib/features/auth/presentation/register_screen.dart`、`lib/core/router/app_router.dart`（WelcomeScreen）、`lib/core/router/main_shell.dart`

**Interfaces:**
- Consumes: `context.colors`（Task 2；import `../../core/theme/app_colors.dart` 依相對路徑調整）

- [ ] **Step 1: 依 Global Constraints 對照表替換 4 檔中的中性色**

注意：
- WelcomeScreen 的 `[Color(0xFF6C63FF), Color(0xFF4338CA)]` 品牌 gradient 與其上白字**不動**（品牌區塊固定深底白字）。
- login/register 的輸入框底色、hint、卡片底、scaffold 背景要換。
- main_shell 的 bottom-nav 深色底換 `surfaceAlt`，icon 未選中色換 `textTertiary`（cyberpunk 光暈用 role accent 者不動）。
- 換到的 widget 拿掉 `const`。

- [ ] **Step 2: analyze**

Run: `flutter analyze`
Expected: 0 errors、warnings 不多於 22

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth lib/core/router
git commit -m "refactor(theme): auth/welcome/main_shell 改用 AppColors token"
```

---

### Task 7: 硬編碼替換 — swipe 系列

**Files:**
- Modify: `lib/features/swipe/presentation/swipe_screen.dart`、`lib/features/swipe/presentation/job_card.dart`、`lib/features/swipe/presentation/user_card.dart`、`lib/features/swipe/presentation/swipe_card_stack.dart`、`lib/shared/widgets/swipe_card_wrapper.dart`

**Interfaces:**
- Consumes: `context.colors`（Task 2）

- [ ] **Step 1: 依對照表替換**（swipe_screen.dart:231/235/271/273 的白字、卡片 `0xFF1A1A1A` 底、like/nope 標記維持綠/紅不動）
- [ ] **Step 2: analyze**：`flutter analyze` → 0 errors
- [ ] **Step 3: Commit**

```bash
git add lib/features/swipe lib/shared/widgets
git commit -m "refactor(theme): swipe 系列改用 AppColors token"
```

---

### Task 8: 硬編碼替換 — match + chat

**Files:**
- Modify: `lib/features/match/presentation/matches_screen.dart`、`lib/features/match/presentation/messages_screen.dart`、`lib/features/match/presentation/match_dialog.dart`、`lib/features/chat/presentation/chat_screen.dart`

**Interfaces:**
- Consumes: `context.colors`（Task 2）

- [ ] **Step 1: 依對照表替換**（含 empty states 的 `Colors.white`/`white38`、chat AppBar `0xFF0A0A0A`、對話氣泡：己方 #6C63FF 不動、對方氣泡底換 `surface`、檢舉 dialog `0xFF1A1A1A` 換 `surface`）
- [ ] **Step 2: analyze**：`flutter analyze` → 0 errors
- [ ] **Step 3: Commit**

```bash
git add lib/features/match lib/features/chat
git commit -m "refactor(theme): match/chat 改用 AppColors token"
```

---

### Task 9: 硬編碼替換 — profile + onboarding + campaign

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`、`lib/features/profile/presentation/employer_jobs_screen.dart`、`lib/features/onboarding/onboarding_screen.dart`、`lib/features/onboarding/widgets/image_upload_card.dart`、`lib/features/onboarding/widgets/skill_chips.dart`、`lib/features/marketing/presentation/campaign_screen.dart`

**Interfaces:**
- Consumes: `context.colors`（Task 2）

- [ ] **Step 1: 依對照表替換**（campaign 的 #2E7DEF accent 不動、WebView 內容 html 不動、只換 Flutter 外殼；onboarding 品牌 gradient 不動）
- [ ] **Step 2: analyze**：`flutter analyze` → 0 errors
- [ ] **Step 3: Commit**

```bash
git add lib/features/profile lib/features/onboarding lib/features/marketing
git commit -m "refactor(theme): profile/onboarding/campaign 改用 AppColors token"
```

---

### Task 10: 硬編碼替換 — admin 系列

**Files:**
- Modify: `lib/features/admin/presentation/admin_shell.dart`、`lib/features/admin/presentation/widgets/admin_page.dart`、`lib/features/admin/presentation/dashboard_screen.dart`、`lib/features/admin/presentation/admin_users_screen.dart`、`lib/features/admin/presentation/admin_jobs_screen.dart`、`lib/features/admin/presentation/admin_reports_screen.dart`、`lib/features/admin/presentation/admin_inbox_screen.dart`

**Interfaces:**
- Consumes: `context.colors`（Task 2）

- [ ] **Step 1: 依對照表替換**（admin accent #FF6B35 不動；側邊欄/卡片深底換 `surfaceAlt`/`surface`）
- [ ] **Step 2: analyze**：`flutter analyze` → 0 errors
- [ ] **Step 3: 淺色模式煙霧測試**（macOS debug 跑起來 → 之後 Task 11 有 UI 前先用系統淺色驗證主要頁面無白字白底）

Run: `flutter run -d macos --release`（登入後切系統外觀看 swipe/matches/messages/profile/admin）

- [ ] **Step 4: Commit**

```bash
git add lib/features/admin
git commit -m "refactor(theme): admin 系列改用 AppColors token"
```

---

### Task 11: 設定頁 + 路由 + profile 入口

**Files:**
- Create: `lib/features/settings/presentation/settings_screen.dart`
- Modify: `lib/core/router/app_router.dart`（AppRoutes + routes）、`lib/features/profile/presentation/profile_screen.dart:127-146`（帳號區加 tile）

**Interfaces:**
- Consumes: `themeModeSettingProvider`（Task 4）、`context.colors`、`AppSpacing`/`AppRadius`（Task 3）
- Produces: 路由 `/settings`；`SettingsScreen` widget

- [ ] **Step 1: 建 SettingsScreen**

```dart
// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/current_role_provider.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _accent = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeSettingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SectionLabel('外觀'),
          _Card(children: [
            _RadioTile(
              label: '深色模式',
              selected: mode == ThemeMode.dark,
              onTap: () => ref
                  .read(themeModeSettingProvider.notifier)
                  .set(ThemeMode.dark),
            ),
            _RadioTile(
              label: '淺色模式',
              selected: mode == ThemeMode.light,
              onTap: () => ref
                  .read(themeModeSettingProvider.notifier)
                  .set(ThemeMode.light),
            ),
            _RadioTile(
              label: '跟隨系統',
              selected: mode == ThemeMode.system,
              onTap: () => ref
                  .read(themeModeSettingProvider.notifier)
                  .set(ThemeMode.system),
            ),
          ]),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('帳號'),
          _Card(children: [
            _NavTile(
                label: '變更密碼',
                onTap: () => _showChangePasswordDialog(context)),
            _NavTile(
                label: '登出',
                labelColor: context.colors.danger,
                onTap: () => _confirmSignOut(context, ref)),
          ]),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('關於'),
          _Card(children: [
            ListTile(
              title: Text('版本',
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: Text('1.0.0',
                  style: TextStyle(color: context.colors.textTertiary)),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final pwController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('變更密碼'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pwController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密碼'),
                validator: (v) =>
                    (v == null || v.length < 6) ? '密碼至少需要 6 碼' : null,
              ),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '確認新密碼'),
                validator: (v) => v != pwController.text ? '兩次輸入不一致' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: pwController.text));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('密碼已更新')));
                }
              } on AuthException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('變更失敗：${e.message}')));
                }
              }
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    // 與 profile_screen._confirmSignOut 相同流程
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('確定要登出？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                ref.read(currentRoleProvider.notifier).reset();
                await Supabase.instance.client.auth.signOut();
              } catch (_) {} finally {
                if (context.mounted) context.go('/welcome');
              }
            },
            child: Text('登出',
                style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(children: children),
      );
}

class _RadioTile extends StatelessWidget {
  const _RadioTile(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        title: Text(label,
            style: TextStyle(
                color: selected
                    ? SettingsScreen._accent
                    : context.colors.textPrimary)),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected
              ? SettingsScreen._accent
              : context.colors.textTertiary,
        ),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.label, this.labelColor, required this.onTap});
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        title: Text(label,
            style: TextStyle(
                color: labelColor ?? context.colors.textPrimary)),
        trailing: Icon(Icons.chevron_right,
            color: context.colors.textTertiary),
      );
}
```

- [ ] **Step 2: 加路由**

`app_router.dart`：AppRoutes 加 `static const settings = '/settings';`；routes 列表（chat route 旁）加：

```dart
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
```

並 import `../../features/settings/presentation/settings_screen.dart`。

- [ ] **Step 3: profile 加入口**

`profile_screen.dart` 帳號區（`_ActionTile` 「限時免費刊登職缺」之後、「登出」之前）加：

```dart
              _ActionTile(
                icon: Icons.settings_outlined,
                label: '設定',
                themeColor: const Color(0xFF6C63FF),
                onTap: () => context.push('/settings'),
              ),
```

- [ ] **Step 4: analyze + 手動驗證**

Run: `flutter analyze`（0 errors）→ `flutter run -d macos --release`：進設定頁切三種模式，畫面即時變色；殺掉 App 重開，模式保留。

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings lib/core/router/app_router.dart lib/features/profile/presentation/profile_screen.dart
git commit -m "feat(settings): 設定頁（外觀切換/變更密碼/登出/關於）"
```

---

### Task 12: 忘記密碼（Email OTP）

**Files:**
- Create: `lib/features/auth/presentation/forgot_password_screen.dart`
- Modify: `lib/core/router/app_router.dart`（AppRoutes + whitelist + route）、`lib/features/auth/presentation/login_screen.dart`（密碼欄後加連結）

**Interfaces:**
- Consumes: `context.colors`（Task 2）
- Produces: 路由 `/forgot-password`

- [ ] **Step 1: 建 ForgotPasswordScreen**

```dart
// lib/features/auth/presentation/forgot_password_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

enum _Step { email, otp, password }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = Supabase.instance.client.auth;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _pwController = TextEditingController();

  _Step _step = _Step.email;
  bool _busy = false;
  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 1) {
        t.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('請輸入有效的 Email');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.resetPasswordForEmail(email);
      _startCountdown();
      setState(() => _step = _Step.otp);
    } on AuthException {
      _showError('寄送失敗，請稍後再試（免費方案每小時發信數有限）');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();
    if (token.length != 6) {
      _showError('請輸入信中的 6 位驗證碼');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.verifyOTP(
        type: OtpType.recovery,
        email: _emailController.text.trim(),
        token: token,
      );
      setState(() => _step = _Step.password);
    } on AuthException {
      _showError('驗證碼錯誤或已過期');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setNewPassword() async {
    final pw = _pwController.text;
    if (pw.length < 6) {
      _showError('密碼至少需要 6 碼');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.updateUser(UserAttributes(password: pw));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('密碼已重設')));
      context.go('/swipe'); // verifyOTP 成功後已有 session
    } on AuthException catch (e) {
      _showError('重設失敗：${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('忘記密碼')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: switch (_step) {
          _Step.email => _buildStep(
              hint: '輸入註冊時使用的 Email，我們會寄送 6 位驗證碼給你。',
              field: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              buttonLabel: '寄送驗證碼',
              onPressed: _sendEmail,
            ),
          _Step.otp => _buildStep(
              hint: '驗證碼已寄到 ${_emailController.text.trim()}',
              field: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '6 位驗證碼'),
              ),
              buttonLabel: '驗證',
              onPressed: _verifyOtp,
              extra: TextButton(
                onPressed: _resendCountdown > 0 || _busy ? null : _sendEmail,
                child: Text(_resendCountdown > 0
                    ? '重新寄送（$_resendCountdown s）'
                    : '重新寄送'),
              ),
            ),
          _Step.password => _buildStep(
              hint: '驗證成功，請設定新密碼。',
              field: TextField(
                controller: _pwController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密碼（至少 6 碼）'),
              ),
              buttonLabel: '完成重設',
              onPressed: _setNewPassword,
            ),
        },
      ),
    );
  }

  Widget _buildStep({
    required String hint,
    required Widget field,
    required String buttonLabel,
    required VoidCallback onPressed,
    Widget? extra,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(hint, style: TextStyle(color: context.colors.textSecondary)),
        const SizedBox(height: AppSpacing.xl),
        field,
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _busy ? null : onPressed,
          child: _busy
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(buttonLabel),
        ),
        if (extra != null) extra,
      ],
    );
  }
}
```

- [ ] **Step 2: 路由 + 白名單**

`app_router.dart`：
1. AppRoutes 加 `static const forgotPassword = '/forgot-password';`
2. redirect 未登入白名單（現為 `location == AppRoutes.welcome || location == AppRoutes.login || location == AppRoutes.register`）加 `|| location == AppRoutes.forgotPassword`
3. Admin 守衛之前加已登入豁免（verifyOTP 成功後 session 已建立，不能被踢去 onboarding/swipe）：

```dart
      if (location == AppRoutes.forgotPassword) return null;
```

4. routes 加：

```dart
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
```

- [ ] **Step 3: Login 頁加連結**

`login_screen.dart` 密碼欄（validator `密碼至少需要 6 碼` 那個 TextFormField）之後加：

```dart
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('忘記密碼？'),
                ),
              ),
```

（若檔內未 import go_router 則補 `import 'package:go_router/go_router.dart';`）

- [ ] **Step 4: analyze + 手動驗證**

Run: `flutter analyze`（0 errors）。
手動前置（一次性）：Supabase Dashboard → Authentication → Email Templates → **Reset Password** 確認內文含 `{{ .Token }}`（沒有就加一行「驗證碼：{{ .Token }}」）。
手動流程：登出 → Login →「忘記密碼？」→ 輸入真實 email → 收信輸碼 → 設新密碼 → 自動進 app → 登出後用新密碼登入成功。

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth lib/core/router/app_router.dart
git commit -m "feat(auth): 忘記密碼 Email OTP 三步驟流程"
```

---

### Task 13: blocks migration（Supabase MCP）

**Files:**
- Create: `sql/blocks_009_setup.sql`（存檔備查；實際套用走 MCP `apply_migration`）

**Interfaces:**
- Produces: DB 表 `public.blocks(blocker_id, blocked_id, created_at)` + RLS；RPC `get_blocked_me() returns uuid[]`（僅 authenticated 可執行）

- [ ] **Step 1: 寫 SQL 並存檔**

```sql
-- sql/blocks_009_setup.sql
create table if not exists public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

create policy blocks_select_own on public.blocks
  for select using (auth.uid() = blocker_id);
create policy blocks_insert_own on public.blocks
  for insert with check (auth.uid() = blocker_id);
create policy blocks_delete_own on public.blocks
  for delete using (auth.uid() = blocker_id);

-- 誰封鎖了我（RLS 讓我看不到，需 SECURITY DEFINER）
create or replace function public.get_blocked_me()
returns uuid[]
language sql
security definer
set search_path = public
as $$
  select coalesce(array_agg(blocker_id), '{}')
  from blocks
  where blocked_id = auth.uid();
$$;

-- create function 預設 grant 給 PUBLIC，必須連 public 一起 revoke
revoke execute on function public.get_blocked_me() from anon, public;
grant execute on function public.get_blocked_me() to authenticated;
```

- [ ] **Step 2: 套用 migration**

用 Supabase MCP `apply_migration`（project_id `klwsmonobcenfoyhkyuq`，name `blocks_009_setup`，SQL 同上）。若 timeout 表示專案 auto-pause，先 `restore_project` 再套。

- [ ] **Step 3: 驗證**

用 MCP `execute_sql` 跑：

```sql
select to_regprocedure('public.get_blocked_me()') is not null as fn_exists,
       (select relrowsecurity from pg_class where relname = 'blocks') as rls_on,
       (select proacl::text from pg_proc where proname = 'get_blocked_me') as acl;
```

Expected: `fn_exists = true`、`rls_on = true`、acl 只含 postgres 與 authenticated（無 anon、無 PUBLIC=X）。

- [ ] **Step 4: Commit**

```bash
git add sql/blocks_009_setup.sql
git commit -m "feat(db): blocks 表 + RLS + get_blocked_me RPC"
```

---

### Task 14: block filter util + BlockedIds provider（TDD）

**Files:**
- Create: `lib/core/utils/block_filter.dart`、`lib/core/providers/blocks_provider.dart`
- Test: `test/core/utils/block_filter_test.dart`

**Interfaces:**
- Consumes: DB `blocks` + `get_blocked_me`（Task 13）
- Produces:
  - `String? otherPartyIdOfMatchRow(Map<String, dynamic> row)` — match row 取對方 user id（雇主視角 `job_seeker_id`，求職者視角 `jobs.employer_id`）
  - `List<Map<String, dynamic>> filterBlockedMatchRows(List<Map<String, dynamic>> rows, Set<String> blocked)`
  - `blockedIdsProvider`（`Future<Set<String>>`，雙向：我封鎖的 + 封鎖我的）；notifier 方法 `Future<void> block(String userId)`、`Future<void> unblock(String userId)`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/core/utils/block_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/core/utils/block_filter.dart';

void main() {
  test('雇主視角 row 取 job_seeker_id', () {
    expect(otherPartyIdOfMatchRow({'job_seeker_id': 'u1', 'jobs': null}), 'u1');
  });

  test('求職者視角 row 取 jobs.employer_id', () {
    expect(
        otherPartyIdOfMatchRow({
          'jobs': {'employer_id': 'u2'}
        }),
        'u2');
  });

  test('filterBlockedMatchRows 濾掉被封鎖對象', () {
    final rows = [
      {'id': 'm1', 'job_seeker_id': 'u1'},
      {'id': 'm2', 'job_seeker_id': 'u2'},
      {
        'id': 'm3',
        'jobs': {'employer_id': 'u3'}
      },
    ];
    final out = filterBlockedMatchRows(rows, {'u2', 'u3'});
    expect(out.map((r) => r['id']), ['m1']);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/core/utils/block_filter_test.dart`
Expected: FAIL

- [ ] **Step 3: 實作**

```dart
// lib/core/utils/block_filter.dart

/// match row 取「對方」的 user id。
/// 雇主視角 select 含 job_seeker_id；求職者視角含 jobs.employer_id。
String? otherPartyIdOfMatchRow(Map<String, dynamic> row) {
  return row['job_seeker_id'] as String? ??
      (row['jobs'] as Map?)?['employer_id'] as String?;
}

List<Map<String, dynamic>> filterBlockedMatchRows(
    List<Map<String, dynamic>> rows, Set<String> blocked) {
  if (blocked.isEmpty) return rows;
  return rows.where((r) {
    final other = otherPartyIdOfMatchRow(r);
    return other == null || !blocked.contains(other);
  }).toList();
}
```

```dart
// lib/core/providers/blocks_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'blocks_provider.g.dart';

/// 雙向封鎖名單：我封鎖的 + 封鎖我的（後者走 SECURITY DEFINER RPC）。
@Riverpod(keepAlive: true)
class BlockedIds extends _$BlockedIds {
  @override
  Future<Set<String>> build() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return {};
    final mine = await client.from('blocks').select('blocked_id');
    final blockedMe = await client.rpc('get_blocked_me');
    return {
      ...(mine as List).map((r) => (r as Map)['blocked_id'] as String),
      ...(blockedMe as List).map((e) => e as String),
    };
  }

  Future<void> block(String userId) async {
    final client = Supabase.instance.client;
    await client.from('blocks').insert({
      'blocker_id': client.auth.currentUser!.id,
      'blocked_id': userId,
    });
    ref.invalidateSelf();
  }

  Future<void> unblock(String userId) async {
    final client = Supabase.instance.client;
    await client
        .from('blocks')
        .delete()
        .eq('blocker_id', client.auth.currentUser!.id)
        .eq('blocked_id', userId);
    ref.invalidateSelf();
  }
}
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/core/utils/block_filter_test.dart && flutter analyze`
Expected: PASS（3 tests）、0 errors

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/block_filter.dart lib/core/providers/blocks_provider.dart lib/core/providers/blocks_provider.g.dart test/core/utils/block_filter_test.dart
git commit -m "feat(block): blockedIds provider 與 match row 過濾工具"
```

---

### Task 15: 三處過濾接上

**Files:**
- Modify: `lib/features/swipe/presentation/swipe_provider.dart:18-35`、`lib/features/match/presentation/matches_screen.dart:21-27`、`lib/features/match/presentation/messages_screen.dart:17-23`

**Interfaces:**
- Consumes: `blockedIdsProvider`、`filterBlockedMatchRows`（Task 14）；`SwipeCard`（`isJob`、`job!.employerId`、`userCard!.userId`）

- [ ] **Step 1: swipe 過濾**

`swipe_provider.dart` 的 `RecommendedJobs.build` 尾端改：

```dart
    final repo = ref.read(swipeRepositoryProvider);
    final cards = await repo.getRecommendedCards(
      userId: user.id,
      role: currentRole,
      mySkills: mySkills,
    );
    final blocked = await ref.watch(blockedIdsProvider.future);
    if (blocked.isEmpty) return cards;
    return cards.where((c) {
      final ownerId = c.isJob ? c.job!.employerId : c.userCard!.userId;
      return !blocked.contains(ownerId);
    }).toList();
```

import 加 `import '../../../core/providers/blocks_provider.dart';`

- [ ] **Step 2: matches / messages 過濾**

兩個 notifier 的 `build()` 都改成（`PendingMatchesNotifier` 與 `MatchedChatsNotifier` 同樣模式）：

```dart
  @override
  Future<List<Map<String, dynamic>>> build() async {
    ref.watch(currentRoleProvider);
    final rows = await _fetch();
    final blocked = await ref.watch(blockedIdsProvider.future);
    return filterBlockedMatchRows(rows, blocked);
  }
```

各自 import：

```dart
import '../../../core/providers/blocks_provider.dart';
import '../../../core/utils/block_filter.dart';
```

- [ ] **Step 3: analyze + 測試**

Run: `flutter analyze && flutter test`
Expected: 0 errors、全 PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/swipe/presentation/swipe_provider.dart lib/features/match/presentation/matches_screen.dart lib/features/match/presentation/messages_screen.dart
git commit -m "feat(block): 滑卡/配對/訊息三處套用封鎖過濾"
```

---

### Task 16: 聊天室 ⋮ 選單（檢舉 + 封鎖）

**Files:**
- Modify: `lib/features/chat/presentation/chat_screen.dart`（class 宣告、AppBar actions ~219 行、新增 `_blockOtherUser`）

**Interfaces:**
- Consumes: `blockedIdsProvider.notifier.block`（Task 14）、`matchedChatsProvider`/`pendingMatchesProvider`（過濾已接）
- Produces: 聊天室 AppBar `⋮` 選單（檢舉／封鎖）

- [ ] **Step 1: ChatScreen 改 ConsumerStatefulWidget**

```dart
class ChatScreen extends ConsumerStatefulWidget { ... }          // 原 StatefulWidget
class _ChatScreenState extends ConsumerState<ChatScreen> { ... } // 原 State<ChatScreen>
```

import 加：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/blocks_provider.dart';
import '../../match/presentation/matches_screen.dart';
import '../../match/presentation/messages_screen.dart';
```

（`createState` 改回傳 `ConsumerState<ChatScreen>`；其餘程式不變，`setState` 等照舊可用。）

- [ ] **Step 2: AppBar actions 換成 PopupMenu**

原本的檢舉 IconButton（`tooltip: '檢舉'`）整段換成：

```dart
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.colors.textSecondary),
            onSelected: (v) {
              if (v == 'report') _reportConversation();
              if (v == 'block') _blockOtherUser();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('檢舉對話')),
              PopupMenuItem(value: 'block', child: Text('封鎖對方')),
            ],
          ),
        ],
```

- [ ] **Step 3: 實作 _blockOtherUser**

```dart
  Future<void> _blockOtherUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('封鎖 ${widget.otherName}？'),
        content: const Text('封鎖後將不再看到對方的卡片與訊息，可在「設定 → 封鎖名單」解除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('封鎖')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // 從 match 撈出對方 user id（自己是其中一方）
      final row = await _client
          .from('matches')
          .select('job_seeker_id, employer_id')
          .eq('id', widget.matchId)
          .single();
      final myId = _client.auth.currentUser!.id;
      final otherId = row['job_seeker_id'] == myId
          ? row['employer_id'] as String
          : row['job_seeker_id'] as String;

      await ref.read(blockedIdsProvider.notifier).block(otherId);
      ref.invalidate(matchedChatsProvider);
      ref.invalidate(pendingMatchesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已封鎖')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('封鎖失敗，請稍後再試')));
      }
    }
  }
```

- [ ] **Step 4: analyze + 手動驗證**

Run: `flutter analyze`（0 errors）。手動：兩個測試帳號配對後，A 在聊天室封鎖 B → A 的訊息列表該對話消失、B 的卡片不再出現在 A 的滑卡；B 側（被封鎖）滑卡也看不到 A。

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/presentation/chat_screen.dart
git commit -m "feat(block): 聊天室 ⋮ 選單（檢舉/封鎖對方）"
```

---

### Task 17: 封鎖名單頁

**Files:**
- Create: `lib/features/settings/presentation/blocked_users_screen.dart`
- Modify: `lib/core/router/app_router.dart`（AppRoutes + route）、`lib/features/settings/presentation/settings_screen.dart`（帳號區加 tile）

**Interfaces:**
- Consumes: `blockedIdsProvider.notifier.unblock`（Task 14）、`fetchPublicUsersMap`（`lib/core/utils/user_hydration.dart`）
- Produces: 路由 `/settings/blocked`

- [ ] **Step 1: 建 BlockedUsersScreen**

```dart
// lib/features/settings/presentation/blocked_users_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/blocks_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/user_hydration.dart';

/// 只列「我封鎖的人」（不含封鎖我的），含公開資料 hydration。
final _myBlockedListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(blockedIdsProvider); // 封鎖/解除後自動刷新
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return [];
  final rows = await client
      .from('blocks')
      .select('blocked_id, created_at')
      .order('created_at', ascending: false);
  final ids =
      (rows as List).map((r) => (r as Map)['blocked_id'] as String).toList();
  final usersMap = await fetchPublicUsersMap(ids);
  return ids
      .map((id) => usersMap[id] ?? {'id': id, 'display_name': '（已刪除的使用者）'})
      .toList();
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_myBlockedListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('封鎖名單')),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('載入失敗',
                style: TextStyle(color: context.colors.textSecondary))),
        data: (users) {
          if (users.isEmpty) {
            return Center(
                child: Text('沒有封鎖任何人',
                    style: TextStyle(color: context.colors.textTertiary)));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              final avatarUrl = u['avatar_url'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(u['display_name'] as String? ?? '未知',
                    style: TextStyle(color: context.colors.textPrimary)),
                trailing: OutlinedButton(
                  onPressed: () => ref
                      .read(blockedIdsProvider.notifier)
                      .unblock(u['id'] as String),
                  child: const Text('解除封鎖'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: 路由 + 設定頁入口**

`app_router.dart`：AppRoutes 加 `static const settingsBlocked = '/settings/blocked';`，routes 加：

```dart
      GoRoute(
        path: AppRoutes.settingsBlocked,
        builder: (_, __) => const BlockedUsersScreen(),
      ),
```

`settings_screen.dart` 帳號區 `_Card`（變更密碼與登出之間）加：

```dart
            _NavTile(
                label: '封鎖名單',
                onTap: () => context.push('/settings/blocked')),
```

- [ ] **Step 3: analyze + 手動驗證**

Run: `flutter analyze`（0 errors）。手動：封鎖名單顯示 Task 16 封鎖的帳號 → 解除封鎖 → 列表移除、對方卡片重新出現在滑卡。

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings lib/core/router/app_router.dart
git commit -m "feat(block): 封鎖名單頁（檢視/解除封鎖）"
```

---

### Task 18: 最終驗證

**Files:** 無

- [ ] **Step 1: 全量檢查**

```bash
flutter analyze && flutter test && flutter build macos --release
```

Expected: 0 errors；全部測試 PASS；build 成功。

- [ ] **Step 2: 手動驗收清單**

- 設定頁三種外觀模式即時切換；重啟 App 保留選擇
- 淺色模式走過：welcome/login/swipe/matches/messages/profile/chat/admin/campaign —— 無白字白底、無深字深底
- 忘記密碼完整流程（真實 email）→ 新密碼可登入
- A 封鎖 B：A 的滑卡/配對/訊息不再出現 B；B 滑卡不出現 A；封鎖名單可解除，解除後恢復
- 檢舉功能仍正常（⋮ 選單內）

- [ ] **Step 3: 收尾**

用 superpowers:finishing-a-development-branch skill 決定合併方式。
