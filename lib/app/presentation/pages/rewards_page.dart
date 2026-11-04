import 'package:flutter/material.dart';

import '../controllers/rewards_controller.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key, required this.controller});

  final RewardsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Recompensas',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            physics: const BouncingScrollPhysics(),
            children: [
              _PointsCard(points: controller.points),
              const SizedBox(height: 28),
              const _SectionTitle(
                icon: Icons.eco_rounded,
                title: 'Missões Sustentáveis',
              ),
              const SizedBox(height: 8),
              for (final mission in RewardsController.missions)
                _MissionTile(
                  mission: mission,
                  completed: controller.isCompleted(mission),
                  claimable: controller.canClaim(mission),
                  onClaim: () => _claim(context, mission),
                ),
              const SizedBox(height: 28),
              const _SectionTitle(
                icon: Icons.storefront_rounded,
                title: 'Loja de Recompensas',
              ),
              const SizedBox(height: 4),
              Text(
                'Benefícios fictícios, apenas para demonstração.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final reward in RewardsController.rewards)
                _RewardTile(
                  reward: reward,
                  redeemed: controller.isRedeemed(reward),
                  affordable: controller.points >= reward.cost,
                  onRedeem: () => _redeem(context, reward),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _claim(BuildContext context, Mission mission) {
    final ok = controller.claimMission(mission);
    _showMessage(
      context,
      ok
          ? '+${mission.points} EcoPoints por "${mission.title}"!'
          : 'Missão indisponível no momento.',
    );
  }

  Future<void> _redeem(BuildContext context, Reward reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(reward.icon),
        title: Text(reward.title),
        content: Text(
          'Trocar ${reward.cost} EcoPoints por este benefício?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Trocar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final message = switch (controller.redeem(reward)) {
      RedeemResult.success => 'Resgatado: ${reward.title}!',
      RedeemResult.insufficientPoints => 'EcoPoints insuficientes.',
      RedeemResult.alreadyRedeemed => 'Você já resgatou este benefício.',
    };
    _showMessage(context, message);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      key: const Key('eco_points_card'),
      elevation: 0,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primary,
              child: Icon(Icons.eco_rounded, color: scheme.onPrimary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seus EcoPoints',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '$points',
                    key: const Key('eco_points_value'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.completed,
    required this.claimable,
    required this.onClaim,
  });

  final Mission mission;
  final bool completed;
  final bool claimable;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(mission.icon, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mission.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${mission.points} EcoPoints',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (completed)
              Icon(Icons.check_circle_rounded, color: scheme.primary)
            else
              FilledButton.tonal(
                key: Key('claim_${mission.id}'),
                onPressed: claimable ? onClaim : null,
                child: const Text('Concluir'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.redeemed,
    required this.affordable,
    required this.onRedeem,
  });

  final Reward reward;
  final bool redeemed;
  final bool affordable;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(reward.icon, color: scheme.tertiary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reward.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${reward.cost} EcoPoints',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (redeemed)
              Chip(
                label: const Text('Resgatado'),
                avatar: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              )
            else
              FilledButton(
                key: Key('redeem_${reward.id}'),
                onPressed: affordable ? onRedeem : null,
                child: const Text('Trocar'),
              ),
          ],
        ),
      ),
    );
  }
}
