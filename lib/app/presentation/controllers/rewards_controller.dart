import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/expense_category.dart';
import 'expense_controller.dart';

class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
    this.requiredCategory,
  });

  final String id;
  final String title;
  final String description;
  final int points;
  final IconData icon;

  /// Quando definida, a missão só pode ser resgatada se houver uma despesa
  /// dessa categoria registrada hoje.
  final ExpenseCategory? requiredCategory;
}

class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final IconData icon;
}

enum RedeemResult { success, insufficientPoints, alreadyRedeemed }

class RewardsController extends ChangeNotifier {
  RewardsController({required ExpenseController expenses})
      : _expenses = expenses {
    _expenses.addListener(notifyListeners);
  }

  static const _storageKey = 'rewards_state_v1';

  static const missions = <Mission>[
    Mission(
      id: 'transport_today',
      title: 'Transporte público',
      description: 'Registre uma despesa de transporte hoje.',
      points: 50,
      icon: Icons.directions_bus_rounded,
      requiredCategory: ExpenseCategory.transport,
    ),
    Mission(
      id: 'ewaste',
      title: 'Reciclar lixo eletrônico',
      description: 'Leve pilhas, cabos ou aparelhos a um ponto de coleta.',
      points: 120,
      icon: Icons.recycling_rounded,
    ),
    Mission(
      id: 'reusable_bag',
      title: 'Sacola reutilizável',
      description: 'Faça suas compras do mercado com sacola própria.',
      points: 30,
      icon: Icons.shopping_bag_rounded,
    ),
    Mission(
      id: 'bike_walk',
      title: 'Pedalar ou caminhar',
      description: 'Substitua um trajeto de carro por bike ou a pé.',
      points: 60,
      icon: Icons.directions_bike_rounded,
    ),
    Mission(
      id: 'paperless',
      title: 'Fatura digital',
      description: 'Troque um extrato ou fatura em papel pela versão digital.',
      points: 40,
      icon: Icons.description_rounded,
    ),
  ];

  static const rewards = <Reward>[
    Reward(
      id: 'cashback_10',
      title: 'Cashback de R\$ 10',
      description: 'Crédito fictício na conta digital.',
      cost: 200,
      icon: Icons.savings_rounded,
    ),
    Reward(
      id: 'annuity_discount',
      title: '10% off na anuidade',
      description: 'Desconto fictício na anuidade do cartão Santander.',
      cost: 350,
      icon: Icons.credit_card_rounded,
    ),
    Reward(
      id: 'ted_free',
      title: 'TED sem tarifa',
      description: 'Uma transferência TED isenta de tarifa (fictício).',
      cost: 150,
      icon: Icons.swap_horiz_rounded,
    ),
    Reward(
      id: 'invest_boost',
      title: 'Bônus de investimento',
      description: 'R\$ 25 de bônus ao aplicar em renda fixa (fictício).',
      cost: 500,
      icon: Icons.trending_up_rounded,
    ),
    Reward(
      id: 'tree_donation',
      title: 'Plantio de uma árvore',
      description: 'Doação fictícia para reflorestamento em seu nome.',
      cost: 100,
      icon: Icons.park_rounded,
    ),
  ];

  final ExpenseController _expenses;

  int points = 0;
  final Set<String> _completed = {};
  final Set<String> _redeemed = {};

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      points = (map['points'] as num?)?.toInt() ?? 0;
      _completed
        ..clear()
        ..addAll((map['completed'] as List<dynamic>? ?? []).cast<String>());
      _redeemed
        ..clear()
        ..addAll((map['redeemed'] as List<dynamic>? ?? []).cast<String>());
      notifyListeners();
    } catch (e) {
      debugPrint('Não foi possível carregar as recompensas: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'points': points,
          'completed': _completed.toList(),
          'redeemed': _redeemed.toList(),
        }),
      );
    } catch (e) {
      debugPrint('Não foi possível salvar as recompensas: $e');
    }
  }

  bool isCompleted(Mission mission) => _completed.contains(mission.id);

  bool isRedeemed(Reward reward) => _redeemed.contains(reward.id);

  bool canClaim(Mission mission) {
    if (isCompleted(mission)) return false;
    final category = mission.requiredCategory;
    if (category == null) return true;
    final now = DateTime.now();
    return _expenses.expenses.any((e) =>
        e.category == category &&
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
  }

  bool claimMission(Mission mission) {
    if (!canClaim(mission)) return false;
    _completed.add(mission.id);
    points += mission.points;
    notifyListeners();
    _save();
    return true;
  }

  RedeemResult redeem(Reward reward) {
    if (isRedeemed(reward)) return RedeemResult.alreadyRedeemed;
    if (points < reward.cost) return RedeemResult.insufficientPoints;
    points -= reward.cost;
    _redeemed.add(reward.id);
    notifyListeners();
    _save();
    return RedeemResult.success;
  }

  @override
  void dispose() {
    _expenses.removeListener(notifyListeners);
    super.dispose();
  }
}
