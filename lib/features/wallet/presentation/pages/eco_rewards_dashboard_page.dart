import 'package:flutter/material.dart';

import '../../data/models/carbon_score_model.dart';
import '../../data/repositories/carbon_score_repository.dart';

class EcoRewardsDashboardPage extends StatefulWidget {
  const EcoRewardsDashboardPage({super.key, this.repository});

  /// `null` quando o Firebase está indisponível: o painel abre sem transações.
  final CarbonScoreRepository? repository;

  @override
  State<EcoRewardsDashboardPage> createState() =>
      _EcoRewardsDashboardPageState();
}

class _RewardOption {
  const _RewardOption({
    required this.title,
    required this.description,
    required this.cost,
    required this.icon,
  });

  final String title;
  final String description;
  final int cost;
  final IconData icon;
}

class _EcoRewardsDashboardPageState extends State<EcoRewardsDashboardPage> {
  static const _green = Color(0xFF2E7D32);
  static const _lightGreen = Color(0xFF66BB6A);
  static const _graphite = Color(0xFF263238);
  static const _graphiteSoft = Color(0xFF37474F);
  static const _historyLimit = 20;

  static const _rewards = <_RewardOption>[
    _RewardOption(
      title: 'Desconto em Patinete Elétrico',
      description: '20% off em corridas de patinete compartilhado.',
      cost: 150,
      icon: Icons.electric_scooter_rounded,
    ),
    _RewardOption(
      title: 'Voucher de Alimentação Saudável',
      description: 'R\$ 30 em restaurantes e mercados orgânicos parceiros.',
      cost: 300,
      icon: Icons.restaurant_rounded,
    ),
    _RewardOption(
      title: 'CDB ESG Santander',
      description: 'Bônus de rentabilidade ao aplicar em CDB com foco ESG.',
      cost: 500,
      icon: Icons.account_balance_rounded,
    ),
  ];

  late final Stream<List<CarbonScoreModel>> _scores;

  @override
  void initState() {
    super.initState();
    _scores = widget.repository?.getCarbonScoresStream() ??
        Stream<List<CarbonScoreModel>>.value(const []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F2),
      appBar: AppBar(
        title: const Text(
          'Recompensas Eco',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _graphite,
      ),
      body: SafeArea(
        child: StreamBuilder<List<CarbonScoreModel>>(
          stream: _scores,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _ErrorState();
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }

            final scores = snapshot.data!;
            final totalPoints = scores.fold<int>(
              0,
              (total, score) => total + score.greenPointsEarned,
            );
            final history = scores.take(_historyLimit).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              physics: const BouncingScrollPhysics(),
              children: [
                _BalanceHeader(points: totalPoints),
                const SizedBox(height: 28),
                const _SectionTitle(
                  icon: Icons.card_giftcard_rounded,
                  title: 'Resgatar recompensas',
                ),
                const SizedBox(height: 8),
                for (final reward in _rewards)
                  _RewardCard(
                    reward: reward,
                    affordable: totalPoints >= reward.cost,
                    onTap: () => _onRewardTap(reward, totalPoints),
                  ),
                const SizedBox(height: 28),
                const _SectionTitle(
                  icon: Icons.history_rounded,
                  title: 'Últimas transações ecológicas',
                ),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  const _EmptyHistory()
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    itemBuilder: (context, index) =>
                        _TransactionTile(score: history[index]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _onRewardTap(_RewardOption reward, int totalPoints) async {
    if (totalPoints < reward.cost) {
      final missing = reward.cost - totalPoints;
      _showMessage('Faltam $missing pontos para "${reward.title}".');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(reward.icon, color: _green),
        title: Text(reward.title),
        content: Text(
          '${reward.description}\n\nCusto: ${reward.cost} pontos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resgatar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _showMessage('Resgate solicitado: ${reward.title}!');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('rewards_balance_header'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _EcoRewardsDashboardPageState._graphite,
            _EcoRewardsDashboardPageState._green
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: _EcoRewardsDashboardPageState._lightGreen,
              size: 32,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo de pontos verdes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$points',
                  key: const Key('rewards_total_points'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
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
    return Row(
      children: [
        Icon(icon, color: _EcoRewardsDashboardPageState._green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _EcoRewardsDashboardPageState._graphite,
                ),
          ),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.affordable,
    required this.onTap,
  });

  final _RewardOption reward;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: _EcoRewardsDashboardPageState._graphiteSoft,
      margin: const EdgeInsets.only(top: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        key: Key('reward_${reward.title}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _EcoRewardsDashboardPageState._green
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  reward.icon,
                  color: _EcoRewardsDashboardPageState._lightGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reward.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${reward.cost} pontos',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _EcoRewardsDashboardPageState._lightGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                affordable
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: affordable ? Colors.white : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.score});

  final CarbonScoreModel score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = score.timestamp;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              _EcoRewardsDashboardPageState._green.withValues(alpha: 0.12),
          child: const Icon(
            Icons.recycling_rounded,
            color: _EcoRewardsDashboardPageState._green,
          ),
        ),
        title: Text(
          'Transação ${score.transactionId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _EcoRewardsDashboardPageState._graphite,
          ),
        ),
        subtitle: Text(
          '$day/$month/${date.year} · '
          '${score.carbonFootprintKg.toStringAsFixed(1)} kg CO₂',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          '+${score.greenPointsEarned} pts',
          style: theme.textTheme.titleSmall?.copyWith(
            color: _EcoRewardsDashboardPageState._green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(
            Icons.eco_outlined,
            size: 48,
            color: _EcoRewardsDashboardPageState._green,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma transação ecológica ainda',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Faça escolhas sustentáveis para ganhar pontos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _EcoRewardsDashboardPageState._graphiteSoft,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: _EcoRewardsDashboardPageState._graphiteSoft,
            ),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar suas recompensas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
