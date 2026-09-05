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
