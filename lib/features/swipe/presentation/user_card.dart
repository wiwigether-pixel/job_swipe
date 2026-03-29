// lib/features/swipe/presentation/user_card.dart
import 'package:flutter/material.dart';
import '../../../shared/models/user_card_model.dart';

/// 人才/同業卡片（雇主和同業交流模式使用）
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.userCard});

  final UserCardModel userCard;

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
          _UserHeader(userCard: userCard),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 姓名
                  Text(
                    userCard.displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 角色標籤
                  _RoleBadge(role: userCard.role),
                  const SizedBox(height: 12),

                  // 資訊標籤
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (userCard.companyName != null)
                        _InfoChip(
                          icon: Icons.business_outlined,
                          label: userCard.companyName!,
                        ),
                      if (userCard.companySize != null)
                        _InfoChip(
                          icon: Icons.people_outline,
                          label: userCard.companySize!,
                        ),
                      if (userCard.expectedSalary != null)
                        _InfoChip(
                          icon: Icons.payments_outlined,
                          label:
                              '期望 ${(userCard.expectedSalary! / 1000).toStringAsFixed(0)}K',
                          color: Colors.green,
                        ),
                    ],
                  ),

                  if (userCard.bio != null && userCard.bio!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '關於我',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userCard.bio!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  if (userCard.skills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '技能',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: userCard.skills
                          .take(8)
                          .map((s) => _SkillChip(skill: s))
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
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.userCard});
  final UserCardModel userCard;

  Color _roleColor(String role) => switch (role) {
        'employer' => const Color(0xFFBF00FF),
        'peer' => const Color(0xFF00FF9F),
        _ => const Color(0xFF00BFFF),
      };

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(userCard.role);

    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.8),
            color.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: userCard.avatarUrl != null
            ? CircleAvatar(
                radius: 52,
                backgroundImage: NetworkImage(userCard.avatarUrl!),
              )
            : CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  userCard.displayName.isNotEmpty
                      ? userCard.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  String get _label => switch (role) {
        'employer' => '雇主',
        'peer' => '同業',
        _ => '求職者',
      };

  Color get _color => switch (role) {
        'employer' => const Color(0xFFBF00FF),
        'peer' => const Color(0xFF00FF9F),
        _ => const Color(0xFF00BFFF),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _color.withValues(alpha: 0.12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: c, fontWeight: FontWeight.w500)),
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