-- protected_data_007_revoke
-- 核心 cutover：client 完全不能直接碰 users 表，一律走 SECURITY DEFINER RPC。
-- ⚠️ 執行前提：Task 5-11（Flutter 端全部改走 RPC）已完成。
--    套用後任何殘留的 .from('users') 直接查詢會立刻失敗。

-- 1) 撤掉 client 兩個角色對 users 的所有表層權限。
--    privilege 檢查發生在 RLS 之前，所以這是比 policy 更前面的一道關卡，
--    也是唯一能擋住「欄位級」外洩（email / expected_salary / 經緯度）的方法。
revoke all on table users from authenticated, anon;

-- 2) 第二道防線收緊：全域 SELECT policy 是當初漏洞的根源，移除。
--    保留 own-row 與 admin policy（若 REVOKE 未來被誤還原，仍只剩 own-row 存取）。
drop policy if exists "所有登入用戶可以讀取 users" on users;

-- 3) 匿名者不得呼叫本 refactor 的 RPC。
--    注意：create function 預設會 grant execute 給 PUBLIC，因此只 revoke anon 無效
--    （anon 會從 PUBLIC 繼承）。必須同時 revoke public；authenticated / service_role
--    各自有明確 grant，不受影響。
revoke execute on function
  ensure_my_profile(text, text, text),
  get_my_profile(),
  upsert_my_profile(jsonb),
  upsert_my_location(double precision, double precision, text),
  set_salary_visibility(text),
  get_swipe_cards(text, int),
  get_user_public(uuid),
  get_users_public(uuid[]),
  get_user_contact(uuid),
  get_distance_km(uuid),
  admin_stats(),
  admin_list_users(text, text, int, int),
  admin_set_user_status(uuid, text),
  admin_delete_user(uuid),
  admin_get_users(uuid[]),
  is_matched_with(uuid, uuid)
from anon, public;

-- 驗證（套用後實測結果）：
--   users.relacl            = {postgres, service_role}          -- anon/authenticated 已移除
--   16 個 RPC 的 proacl     = {postgres, authenticated, service_role}
--                             -- PUBLIC(=X) 與 anon 皆已移除
--   has_table_privilege('authenticated','users','select')       = false
--   has_function_privilege('authenticated','get_my_profile()')  = true
--   has_function_privilege('anon','get_users_public(uuid[])')   = false
--   security advisors：users 不再出現在 pg_graphql_*_table_exposed
--
-- SECURITY DEFINER 的 RPC 不受影響，因為 users 表 owner 為 postgres、
-- 且 relforcerowsecurity = false，函式以 owner 身分執行時會 bypass RLS。
