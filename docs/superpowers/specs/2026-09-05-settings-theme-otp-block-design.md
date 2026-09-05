# 設計文件：全面主題 Token 化 + 設定頁 + 忘記密碼（OTP）+ 封鎖

日期：2026-09-05
來源：Figma UI 審查結論 #1/#3/#4/#8/#9/#10

## 背景與範圍

UI 審查發現四項缺口，經探索後實際 code 端待開發項目：

| 審查項 | 現況 | 本次範圍 |
|---|---|---|
| #3 設定頁 + #10 雙主題 | 完全沒有；23 檔 112 處硬編碼深色 | ✅ 全面 token 化（含 admin/campaign/auth/onboarding）+ 設定頁 |
| #8/#9 視覺 token | 無 color/spacing/radius token | ✅ 併入 token 化 |
| #1 忘記密碼 | 完全沒有 | ✅ Email OTP 流程 |
| #4 檢舉/封鎖 | 檢舉已有（chat_screen.dart:219 `_reportConversation`）；封鎖完全沒有 | ✅ 完整封鎖（含 DB + 三處過濾 + 封鎖名單頁） |
| #5 Empty states | 三種都已存在（matches_screen.dart:532、messages_screen.dart:277、swipe_screen.dart:225） | ❌ 無 code 工作（僅缺 Figma 稿，另案） |

已定案的決策：
- 主題範圍：**C 全面 token 化**（使用者選定）
- 忘記密碼：**Email OTP**（免 deep link、免費；使用者確認）
- 封鎖：**完整封鎖**（使用者選定）

## 1. 全面 Token 化 + 雙主題

新增 `lib/core/theme/`：

### `app_colors.dart`
- `ThemeExtension<AppColors>`，中性色語意 token，深淺各一組值：
  - `background`（深 #000000 / 淺 #F5F5F7）
  - `surface`（深 #1A1A1A / 淺 #FFFFFF）
  - `surfaceAlt`（深 #0A0A0A 一類次層 / 淺 #EFEFF4）
  - `textPrimary`（深 white / 淺 #1A1A1A）
  - `textSecondary`（深 white70 / 淺 black 54%）
  - `textTertiary`（深 white38 / 淺 black 35%）
  - `divider`（深 white12 / 淺 #E5E5EA）
  - `danger`（#FF4757，兩模式同）
- 實作時對照現有硬編碼值歸納，超出上表的色階（如 white54、white24）併入最接近的語意 token，不另開一對一 token。
- BuildContext extension：`context.colors` 取得目前模式的 AppColors。
- 角色 accent（jobSeeker #6C63FF / employer / peer / admin #FF6B35 / campaign #2E7DEF）為品牌色，兩模式共用，維持現有 `AppRole.themeColor` 與各處常數，**不納入** AppColors。

### `app_theme.dart`
- `AppTheme.dark()` / `AppTheme.light()` 回傳完整 ThemeData（scaffoldBackgroundColor、appBarTheme、dialogTheme、inputDecorationTheme、bottomSheetTheme 等），掛上 AppColors extension。
- `AppSpacing`：4/8/12/16/24/32；`AppRadius`：12/16/20。新 code 一律用常數；既有硬編碼間距**不強制**全面替換（避免無謂 diff），只在本次觸碰的檔案順手換。

### `theme_mode_provider.dart`
- Riverpod codegen provider，狀態 `ThemeMode`，預設 `ThemeMode.system`。
- 持久化 `shared_preferences`（既有依賴），key `theme_mode`，值 `dark`/`light`/`system`。

### 替換策略
- `app.dart` 掛 `theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ref.watch(themeModeProvider)`。
- 23 檔 112 處硬編碼中性色全部改 `context.colors.xxx`；**逐檔改、逐檔 `flutter analyze`**。
- admin 桌面版、campaign WebView 外殼、auth、onboarding 都含在內。
- `assets/marketing/campaign.html`（WebView 內容）不動。

## 2. 設定頁

- 路由 `/settings`（standalone push，需登入），入口：profile 帳號區新增「設定」tile。
- 區塊：
  - **外觀**：深色/淺色/跟隨系統 三選一（radio 樣式，selected 用 #6C63FF），點選即時生效並持久化。
  - **帳號**：變更密碼（dialog：輸新密碼 → `updateUser`）、封鎖名單（→ `/settings/blocked`）、登出（既有 signOut 邏輯）。
  - **關於**：版本號（硬編 pubspec version 即可，不新增 package_info 依賴）。
- **不做通知區**（FCM 未接，不放假開關）。
- 版面對齊 `figma_scripts/03_theme_section_settings.js` 的設計（黑底/surface 卡片/圓角 16）。

## 3. 忘記密碼（Email OTP）

- Login 頁密碼欄下方加「忘記密碼？」文字按鈕 → `/forgot-password`。
- `/forgot-password` 加入 go_router 未登入白名單（redirect 不踢走）。
- 單頁三步驟（同頁 stepper 狀態機，不拆路由）：
  1. 輸入 email → `supabase.auth.resetPasswordForEmail(email)`
  2. 輸入 6 位驗證碼 → `verifyOTP(email: ..., token: ..., type: OtpType.recovery)`
  3. 輸入新密碼（含確認欄）→ `updateUser(UserAttributes(password: ...))` → 成功後導回 app（verifyOTP 成功即有 session）
- 錯誤處理：驗證碼錯誤/過期顯示中文訊息；步驟 2 提供重寄，60 秒倒數防連點。
- ⚠️ 前置手動作業：Supabase Dashboard → Auth → Email Templates → Reset Password 需含 `{{ .Token }}`（MCP 無法改 template）。免費內建 SMTP 每小時發信數低（約 2–4 封），測試時注意。

## 4. 完整封鎖

### DB（Supabase MCP `apply_migration`，project klwsmonobcenfoyhkyuq）
```sql
create table blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);
-- RLS：select/insert/delete 僅限 blocker_id = auth.uid()
```
- 遵循既有慣例：RLS enable + policy；不碰 users 表（已 REVOKE，公開資料走 `get_users_public` RPC）。

### Client
- `blocksProvider`：撈自己的封鎖關係（**雙向**：我封鎖的 + 封鎖我的——封鎖我的一側需 SECURITY DEFINER RPC `get_blocked_me()` 回傳 uuid[]，因 RLS 只讓我看到自己是 blocker 的列）。
- 過濾三處（client 端，拿 Set<uuid> 過濾）：
  - 滑卡推薦（swipe deck）
  - 配對列表（matches）
  - 訊息列表（messages）
- 聊天室 AppBar：現有檢舉 IconButton 改為 `⋮` PopupMenu：檢舉（既有邏輯搬入）+ 封鎖（確認 dialog → insert blocks → invalidate 相關 provider → pop 回列表）。
- 封鎖名單頁 `/settings/blocked`：列出我封鎖的人（`fetchPublicUsersMap` hydrate 顯示名稱/頭像）+ 解除封鎖（delete → invalidate）。

## 執行方式

- `superpowers:using-git-worktrees` 開 worktree，**先 `cp /Users/alice/job_swipe/.env <worktree>/.env`**（否則 build 失敗）。
- 單一 feature branch，實作順序：token 化 → 設定頁 → 忘記密碼 → 封鎖。
- 每段驗證：`dart run build_runner build --delete-conflicting-outputs`（有 provider/model 變更時）+ `flutter analyze` + macOS/iOS simulator build。
- 測試：TDD——provider 邏輯（themeMode 持久化、blocks 過濾）寫 unit test；UI 手動驗證（切主題、OTP 全流程、封鎖後三處消失）。

## 錯誤處理原則

- 沿用既有 `_ErrorView` / SnackBar 模式與中文文案。
- OTP/封鎖的 Supabase 錯誤轉中文提示，不裸露原始訊息。

## 不做（明確排除）

- 通知設定區（FCM 未接）
- Empty states（code 已有）
- Magic link / deep link
- 既有間距硬編碼的全面替換（僅新 code 與觸碰檔案採用 AppSpacing/AppRadius）
