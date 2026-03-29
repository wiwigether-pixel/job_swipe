import 'package:flutter/material.dart';
import '../../../shared/models/job_model.dart';

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompanyHeader(job: job),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.companyName ?? '未公開公司',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (job.location != null)
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: job.location!,
                        ),
                      if (job.jobType != null)
                        _InfoChip(
                          icon: Icons.work_outline,
                          label: job.jobType!.label,
                        ),
                      if (job.salaryMin != null)
                        _InfoChip(
                          icon: Icons.payments_outlined,
                          label: _formatSalary(job.salaryMin, job.salaryMax),
                          color: Colors.green,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '職缺描述',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  if (job.requiredSkills.isNotEmpty) ...[
                    Text(
                      '需求技能',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: job.requiredSkills
                          .take(6)
                          .map((skill) => _SkillChip(skill: skill))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSalary(int? min, int? max) {
    if (min == null) return '面議';
    final minK = (min / 1000).toStringAsFixed(0);
    if (max == null) return '$minK K+';
    final maxK = (max / 1000).toStringAsFixed(0);
    return '$minK - $maxK K';
  }
}

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.job});
  final JobModel job;

  List<Color> _generateGradient(String seed) {
    final hash = seed.codeUnits.fold(0, (a, b) => a + b);
    final gradients = [
      [const Color(0xFF6C63FF), const Color(0xFF9C8FFF)],
      [const Color(0xFFFF6584), const Color(0xFFFF9A9E)],
      [const Color(0xFF43B89C), const Color(0xFF7FDBCA)],
      [const Color(0xFFFF8C42), const Color(0xFFFFB347)],
      [const Color(0xFF3B82F6), const Color(0xFF93C5FD)],
    ];
    return gradients[hash % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _generateGradient(job.companyName ?? job.id);
    final initials = (job.companyName ?? '?')
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: effectiveColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.skill});
  final String skill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        skill,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}