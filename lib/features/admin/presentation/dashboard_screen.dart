import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_provider.dart';
import 'widgets/admin_page.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return AdminPage(
      title: '儀表板',
      onRefresh: () => ref.invalidate(adminStatsProvider),
      child: statsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
        error: (e, _) => Center(
            child: Text('載入失敗：$e',
                style: const TextStyle(color: Colors.redAccent))),
        data: (stats) => LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final w = constraints.maxWidth;
            final cols = w >= 1000
                ? 5
                : w >= 760
                    ? 4
                    : w >= 520
                        ? 3
                        : 2;
            final itemWidth =
                (w - spacing * (cols - 1)) / cols;
            final cards = [
              _StatCard('總用戶', stats.totalUsers, Icons.groups_rounded,
                  const Color(0xFF6C63FF)),
              _StatCard('求職者', stats.jobSeekers,
                  Icons.person_search_rounded, const Color(0xFF00BFFF)),
              _StatCard('雇主', stats.employers,
                  Icons.business_center_rounded, const Color(0xFF14669C)),
              _StatCard('職缺總數', stats.totalJobs, Icons.work_rounded,
                  const Color(0xFFFF6B35)),
              _StatCard('成功配對', stats.acceptedMatches,
                  Icons.favorite_rounded, const Color(0xFF0CBB78)),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in cards)
                  SizedBox(width: itemWidth, child: card),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text('$value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}
