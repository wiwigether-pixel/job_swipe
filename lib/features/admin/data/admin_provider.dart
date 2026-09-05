import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/admin_role.dart';
import 'package:job_swipe/core/utils/logger.dart';
import '../../../core/utils/user_hydration.dart';

part 'admin_provider.g.dart';

/// 當前登入者的管理員等級；非管理員回傳 null
@Riverpod(keepAlive: true)
Future<AdminRole?> adminRole(AdminRoleRef ref) async {
  // auth 變動時重新查詢
  ref.watch(authStateProvider);

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  try {
    final row = await Supabase.instance.client
        .from('admin_roles')
        .select('level')
        .eq('user_id', user.id)
        .maybeSingle();
    final role = AdminRole.fromString(row?['level'] as String?);
    logger.i('[Admin] adminRole = $role');
    return role;
  } catch (e) {
    logger.w('[Admin] 查詢 admin_roles 失敗: $e');
    return null;
  }
}

/// ── 後台統計（Dashboard 用）──────────────────────────────────
@riverpod
Future<AdminStats> adminStats(AdminStatsRef ref) async {
  final client = Supabase.instance.client;

  Future<int> count(String table, {String? eqCol, Object? eqVal}) async {
    var query = client.from(table).select('id');
    if (eqCol != null) query = query.eq(eqCol, eqVal!);
    final res = await query.count(CountOption.exact);
    return res.count;
  }

  final results = await Future.wait<dynamic>([
    client.rpc('admin_stats'),
    count('jobs'),
    count('matches', eqCol: 'status', eqVal: 'accepted'),
  ]);

  final stats = ((results[0] as List).first as Map);
  return AdminStats(
    totalUsers: (stats['total_users'] as num).toInt(),
    jobSeekers: (stats['job_seekers'] as num).toInt(),
    employers: (stats['employers'] as num).toInt(),
    totalJobs: results[1] as int,
    acceptedMatches: results[2] as int,
  );
}

class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.jobSeekers,
    required this.employers,
    required this.totalJobs,
    required this.acceptedMatches,
  });

  final int totalUsers;
  final int jobSeekers;
  final int employers;
  final int totalJobs;
  final int acceptedMatches;
}

/// ── 用戶管理 ─────────────────────────────────────────────────
@riverpod
Future<List<Map<String, dynamic>>> adminUsers(
  AdminUsersRef ref, {
  String search = '',
  String? roleFilter,
}) async {
  final client = Supabase.instance.client;
  final data = await client.rpc('admin_list_users', params: {
    'p_search': search,
    'p_role': roleFilter,
    'p_limit': 100,
    'p_offset': 0,
  });
  return (data as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
}

/// ── 職缺管理 ─────────────────────────────────────────────────
@riverpod
Future<List<Map<String, dynamic>>> adminJobs(
  AdminJobsRef ref, {
  String? statusFilter,
}) async {
  final client = Supabase.instance.client;
  var query = client
      .from('jobs')
      .select('id, title, status, created_at, employer_id');

  if (statusFilter != null) {
    query = query.eq('status', statusFilter);
  }

  final data = await query.order('created_at', ascending: false).limit(100);
  final rows = (data as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  final ids = rows.map((r) => r['employer_id'] as String).toSet().toList();
  final userRows = await client.rpc('admin_get_users', params: {'p_ids': ids});
  final usersMap = {
    for (final u in (userRows as List))
      (u as Map)['id'] as String: Map<String, dynamic>.from(u),
  };
  for (final r in rows) {
    r['users'] = usersMap[r['employer_id']];
  }
  return rows;
}

/// ── 檢舉管理 ─────────────────────────────────────────────────
@riverpod
Future<List<Map<String, dynamic>>> adminReports(
  AdminReportsRef ref, {
  String statusFilter = 'pending',
}) async {
  final client = Supabase.instance.client;
  var query = client.from('reports').select(
      'id, reporter_id, target_type, target_id, match_id, reason, status, admin_note, resolved_at, created_at');

  if (statusFilter.isNotEmpty) {
    query = query.eq('status', statusFilter);
  }

  final data = await query.order('created_at', ascending: false).limit(100);
  final rows = (data as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  final ids = rows
      .map((r) => r['reporter_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final userRows = await client.rpc('admin_get_users', params: {'p_ids': ids});
  final usersMap = {
    for (final u in (userRows as List))
      (u as Map)['id'] as String: Map<String, dynamic>.from(u),
  };
  for (final r in rows) {
    r['reporter'] = usersMap[r['reporter_id']];
  }
  return rows;
}

/// 載入某個對話（match）的訊息，供管理員審核
@riverpod
Future<List<Map<String, dynamic>>> reportConversation(
  ReportConversationRef ref,
  String matchId,
) async {
  final data = await Supabase.instance.client
      .from('messages')
      .select('id, sender_id, content, created_at')
      .eq('match_id', matchId)
      .order('created_at', ascending: true)
      .limit(200);
  final rows = (data as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  final ids = rows
      .map((r) => r['sender_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final usersMap = await fetchPublicUsersMap(ids);
  for (final r in rows) {
    r['sender'] = usersMap[r['sender_id']];
  }
  return rows;
}

/// ── 站內信 / 官方信箱 ────────────────────────────────────────
@riverpod
Future<List<Map<String, dynamic>>> adminInbox(
  AdminInboxRef ref, {
  String statusFilter = 'unread',
}) async {
  final client = Supabase.instance.client;
  var query = client.from('inbox_messages').select(
      'id, user_id, sender_name, sender_email, subject, body, status, admin_reply, replied_by, replied_at, created_at');

  if (statusFilter.isNotEmpty) {
    query = query.eq('status', statusFilter);
  }

  final data = await query.order('created_at', ascending: false).limit(100);
  final rows = (data as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  final ids = rows
      .map((r) => r['user_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final userRows = await client.rpc('admin_get_users', params: {'p_ids': ids});
  final usersMap = {
    for (final u in (userRows as List))
      (u as Map)['id'] as String: Map<String, dynamic>.from(u),
  };
  for (final r in rows) {
    r['sender'] = usersMap[r['user_id']];
  }
  return rows;
}

/// ── 管理操作 ─────────────────────────────────────────────────
@riverpod
AdminActions adminActions(AdminActionsRef ref) => AdminActions(ref);

class AdminActions {
  AdminActions(this.ref);
  final AdminActionsRef ref;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> setUserStatus(String userId, String status) async {
    await _client.rpc('admin_set_user_status',
        params: {'p_target': userId, 'p_status': status});
    ref.invalidate(adminUsersProvider);
  }

  Future<void> deleteUser(String userId) async {
    await _client.rpc('admin_delete_user', params: {'p_target': userId});
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminStatsProvider);
  }

  Future<void> setJobStatus(String jobId, String status) async {
    await _client.from('jobs').update({'status': status}).eq('id', jobId);
    ref.invalidate(adminJobsProvider);
  }

  Future<void> deleteJob(String jobId) async {
    await _client.from('jobs').delete().eq('id', jobId);
    ref.invalidate(adminJobsProvider);
    ref.invalidate(adminStatsProvider);
  }

  Future<void> resolveReport(String reportId, {String? note}) async =>
      _closeReport(reportId, 'resolved', note);

  Future<void> dismissReport(String reportId, {String? note}) async =>
      _closeReport(reportId, 'dismissed', note);

  Future<void> _closeReport(String reportId, String status, String? note) async {
    final me = _client.auth.currentUser;
    await _client.from('reports').update({
      'status': status,
      'admin_note': note,
      'resolved_by': me?.id,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId);
    ref.invalidate(adminReportsProvider);
  }

  // ── 站內信 ──
  Future<void> markInboxRead(String id) async {
    await _client
        .from('inbox_messages')
        .update({'status': 'read'}).eq('id', id);
    ref.invalidate(adminInboxProvider);
  }

  Future<void> replyInbox(String id, String reply) async {
    final me = _client.auth.currentUser;
    await _client.from('inbox_messages').update({
      'status': 'replied',
      'admin_reply': reply,
      'replied_by': me?.id,
      'replied_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    ref.invalidate(adminInboxProvider);
  }

  Future<void> archiveInbox(String id) async {
    await _client
        .from('inbox_messages')
        .update({'status': 'archived'}).eq('id', id);
    ref.invalidate(adminInboxProvider);
  }
}
