-- protected_data_008_revoke_legacy_fn_anon
-- 補齊 Task 12 範圍外的既有 SECURITY DEFINER 函式：anon 不得執行。
-- 這些函式同樣帶著 create function 預設的 PUBLIC EXECUTE grant，
-- 必須 revoke anon + public 兩者；authenticated / service_role 有明確 grant 不受影響
--（is_admin / is_super_admin / admin_level 被 RLS policy 以 authenticated 身分呼叫，不能斷）。
-- add_job_quota 尤其重要：原本拿 anon key 就能呼叫的加額度 mutation。
-- rls_auto_enable 是 event trigger 函式，本來就不應可被任何 client 角色執行。
revoke execute on function
  add_job_quota(integer),
  consume_job_quota(),
  is_admin(uuid),
  is_super_admin(uuid),
  admin_level(uuid),
  rls_auto_enable()
from anon, public;

-- 驗證（套用後實測）：
--   6 個函式 proacl = {postgres=X, authenticated=X, service_role=X}（PUBLIC 與 anon 已移除）
--   has_function_privilege('anon', ...) 全部 false；('authenticated', ...) 全部 true
--   security advisors：anon_security_definer_function_executable 由 6 筆歸零
