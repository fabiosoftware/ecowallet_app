import 'package:flutter/material.dart';

import '../../core/notifications/notification_expense_capture_service.dart';
import '../../../features/wallet/data/repositories/carbon_score_repository.dart';
import '../../../features/wallet/presentation/pages/eco_rewards_dashboard_page.dart';
import '../../../repositories/carbon_score_repository.dart';
import '../../../src/domain/repositories/carbon_scoring_repository.dart'
    as climatiq;
import '../controllers/chatbot_controller.dart';
import '../controllers/expense_controller.dart';
import 'chatbot_page.dart';
import 'wallet_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({
    super.key,
    required this.controller,
    this.carbonScores,
    this.carbonEstimates,
    this.climatiqActivityIds = const {},
    this.notificationCapture,
  });

  final ExpenseController controller;

  /// Disponível apenas quando o Firebase inicializou com sucesso; `null`
  /// mantém o chatbot com a resposta de fallback.
  final CarbonScoreRepository? carbonScores;

  /// Estimativas de emissão da Climatiq; `null` mantém o cálculo local.
  final climatiq.CarbonScoringRepository? carbonEstimates;
  final Map<String, String> climatiqActivityIds;
  final NotificationExpenseCaptureService? notificationCapture;

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late final ChatbotController _chatbot;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final carbonScores = widget.carbonScores;
    _chatbot = ChatbotController(
      carbonScores: carbonScores,
      carbonScoring: carbonScores == null
          ? null
          : CarbonScoringRepository(userId: carbonScores.userId),
      carbonEstimates: widget.carbonEstimates,
      climatiqActivityIds: widget.climatiqActivityIds,
    );
  }

  @override
  void dispose() {
    _chatbot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          WalletPage(
            controller: widget.controller,
            notificationCapture: widget.notificationCapture,
          ),
          EcoRewardsDashboardPage(repository: widget.carbonScores),
          ChatbotPage(controller: _chatbot),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Gastos',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco_rounded),
            label: 'Recompensas',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded),
            label: 'EcoAI',
          ),
        ],
      ),
    );
  }
}
