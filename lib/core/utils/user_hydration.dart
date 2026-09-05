import 'package:supabase_flutter/supabase_flutter.dart';

/// 批次取多位使用者的公開資料（get_users_public RPC），回 id -> row 的 map。
/// 用來取代被 REVOKE 弄壞的 `users` embed join。
Future<Map<String, Map<String, dynamic>>> fetchPublicUsersMap(
    List<String> ids) async {
  if (ids.isEmpty) return {};
  final data = await Supabase.instance.client
      .rpc('get_users_public', params: {'p_ids': ids.toSet().toList()});
  return {
    for (final row in (data as List))
      (row as Map)['id'] as String: Map<String, dynamic>.from(row),
  };
}
