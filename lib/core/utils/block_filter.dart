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
